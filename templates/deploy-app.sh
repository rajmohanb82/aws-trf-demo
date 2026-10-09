#!/bin/bash
# Idempotent GitHub → Docker deploy. Sourced config: /etc/webapp/deploy.env
# The GitHub PAT is read from SSM at runtime and never written to disk.
set -euo pipefail

CONFIG=/etc/webapp/deploy.env
# shellcheck disable=SC1090
source "${CONFIG}"

log() { echo "[deploy-app] $*"; }

normalize_repo() {
  local raw="$1"
  raw="${raw%.git}"
  raw="${raw#https://github.com/}"
  raw="${raw#git@github.com:}"
  echo "${raw}"
}

install_runtime() {
  if ! command -v docker >/dev/null 2>&1; then
    log "Installing docker + git"
    dnf install -y docker git
    systemctl enable --now docker
  fi
  usermod -aG docker ec2-user 2>/dev/null || true
}

fetch_pat() {
  aws ssm get-parameter \
    --name "${GITHUB_PAT_PARAMETER}" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text \
    --region "${AWS_REGION}"
}

clone_or_pull() {
  local repo owner_repo clone_url
  repo="$(normalize_repo "${GITHUB_REPOSITORY}")"
  owner_repo="${repo}"
  clone_url="https://github.com/${owner_repo}.git"

  export GIT_TERMINAL_PROMPT=0
  git config --global --add safe.directory "${APP_ROOT}" || true

  local pat
  pat="$(fetch_pat)"
  if [[ -z "${pat}" || "${pat}" == "None" ]]; then
    echo "ERROR: empty GitHub PAT from SSM ${GITHUB_PAT_PARAMETER}" >&2
    return 1
  fi

  mkdir -p "${APP_ROOT}"
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0="http.extraheader"
  export GIT_CONFIG_VALUE_0="AUTHORIZATION: bearer ${pat}"

  if [[ -d "${APP_ROOT}/.git" ]]; then
    log "Fetching ${owner_repo}@${GITHUB_BRANCH}"
    git -C "${APP_ROOT}" fetch --depth 1 origin "${GITHUB_BRANCH}"
    git -C "${APP_ROOT}" checkout --force "FETCH_HEAD"
  else
    rm -rf "${APP_ROOT}"
    log "Cloning ${owner_repo}@${GITHUB_BRANCH}"
    git clone --depth 1 --branch "${GITHUB_BRANCH}" "${clone_url}" "${APP_ROOT}"
  fi

  git -C "${APP_ROOT}" remote set-url origin "${clone_url}"
  unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 pat
}

build_and_run() {
  local context="${APP_ROOT}/${DOCKERFILE_DIRECTORY}"
  if [[ ! -f "${context}/Dockerfile" ]]; then
    echo "ERROR: no Dockerfile at ${context}/Dockerfile" >&2
    return 1
  fi

  log "Building ${IMAGE_NAME} from ${context}"
  docker build --pull -t "${IMAGE_NAME}" "${context}"

  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  log "Starting ${CONTAINER_NAME} ${WEB_LISTEN_PORT}->${CONTAINER_PORT}"
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    --log-driver json-file \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    -p "${WEB_LISTEN_PORT}:${CONTAINER_PORT}" \
    -e ENVIRONMENT="${ENVIRONMENT}" \
    -e PROJECT_NAME="${PROJECT_NAME}" \
    "${IMAGE_NAME}"
}

install_runtime
clone_or_pull
build_and_run
log "Ready. docker ps:"
docker ps --filter "name=${CONTAINER_NAME}"
