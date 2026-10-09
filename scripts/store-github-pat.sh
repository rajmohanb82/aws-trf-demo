#!/usr/bin/env bash
# =============================================================================
# Store a GitHub PAT in SSM Parameter Store (SecureString).
# The instance IAM role reads this at boot — Terraform never needs the token.
#
# Usage:
#   export GITHUB_PAT=ghp_xxxxxxxx
#   ./scripts/store-github-pat.sh /dualvpc/dev/github-pat
# =============================================================================
set -euo pipefail

NAME="${1:-}"
REGION="${AWS_REGION:-us-east-1}"

if [[ -z "${NAME}" ]]; then
  echo "Usage: $0 /<project>/<env>/github-pat" >&2
  exit 1
fi

if [[ -z "${GITHUB_PAT:-}" ]]; then
  echo "Set GITHUB_PAT in the environment (do not pass it as a CLI argument)." >&2
  exit 1
fi

aws ssm put-parameter \
  --name "${NAME}" \
  --type SecureString \
  --value "${GITHUB_PAT}" \
  --overwrite \
  --region "${REGION}" \
  --tags "Key=Purpose,Value=github-clone" "Key=ManagedBy,Value=script"

echo "Stored SecureString ${NAME} in ${REGION}."
echo "Set github_pat_ssm_parameter_name = \"${NAME}\" in your tfvars."
