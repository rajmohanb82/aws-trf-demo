#!/usr/bin/env bash
# =============================================================================
# Live infrastructure showcase
# -----------------------------------------------------------------------------
# Reads Terraform outputs + a few AWS APIs and prints a markdown snapshot
# (GitHub Actions job summary when GITHUB_STEP_SUMMARY is set, otherwise stdout).
#
# Prerequisites: terraform init'd in repo root, AWS CLI authenticated.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! terraform output -json >/dev/null 2>&1; then
  echo "No readable Terraform state. Run 'make apply ENV=...' first." >&2
  exit 1
fi

JSON="$(terraform output -json)"
jq_out() { jq -r "$1" <<<"${JSON}"; }

ENV_NAME="$(jq_out '.environment.value')"
REGION="$(jq_out '.aws_region.value')"
ACCOUNT="$(jq_out '.aws_account_id.value')"
URL="$(jq_out '.public_alb_url.value')"
PUB_VPC="$(jq_out '.public_vpc_id.value')"
PRIV_VPC="$(jq_out '.private_vpc_id.value')"
PEER="$(jq_out '.vpc_peering_connection_id.value')"
ASG="$(jq_out '.asg_name.value')"
PUB_DNS="$(jq_out '.public_alb_dns_name.value')"
INT_DNS="$(jq_out '.internal_alb_dns_name.value')"
IGW="$(jq_out '.internet_gateway_id.value')"

ASG_JSON="$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${ASG}" \
  --region "${REGION}" \
  --output json 2>/dev/null || echo '{}')"

IN_SERVICE="$(jq -r '.AutoScalingGroups[0].Instances // [] | map(select(.LifecycleState=="InService")) | length' <<<"${ASG_JSON}")"
DESIRED="$(jq -r '.AutoScalingGroups[0].DesiredCapacity // "n/a"' <<<"${ASG_JSON}")"
MIN="$(jq -r '.AutoScalingGroups[0].MinSize // "n/a"' <<<"${ASG_JSON}")"
MAX="$(jq -r '.AutoScalingGroups[0].MaxSize // "n/a"' <<<"${ASG_JSON}")"
INSTANCE_TYPE="$(jq -r '.deployment_summary.value.instance_type' <<<"${JSON}")"

HEALTHY="unknown"
if command -v curl >/dev/null 2>&1; then
  CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "${URL}" || true)"
  if [[ "${CODE}" =~ ^2 ]]; then
    HEALTHY="HTTP ${CODE} ✅"
  else
    HEALTHY="HTTP ${CODE:-timeout} ⚠️"
  fi
fi

read -r -d '' MD <<EOF || true
# 🛰️ Live infrastructure — \`${ENV_NAME}\`

| | |
|---|---|
| 🌍 **Region / account** | \`${REGION}\` / \`${ACCOUNT}\` |
| 🌐 **Public URL** | ${URL} |
| ❤️ **Edge health** | ${HEALTHY} |
| 🚪 **Internet Gateway** | \`${IGW}\` |
| 🟦 **Public VPC** | \`${PUB_VPC}\` |
| 🟪 **Private VPC** | \`${PRIV_VPC}\` |
| 🔗 **Peering** | \`${PEER}\` |
| ⚖️ **Public ALB** | \`${PUB_DNS}\` |
| 🔒 **Internal ALB** | \`${INT_DNS}\` |
| 🖥️ **ASG** | \`${ASG}\` (\`${INSTANCE_TYPE}\`) |
| 📊 **Capacity** | in-service **${IN_SERVICE}** · desired ${DESIRED} · min ${MIN} · max ${MAX} |

\`\`\`
Internet  →  Public ALB  →  VPC peering :80/:443  →  Internal ALB  →  ASG
\`\`\`
EOF

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf '%s\n' "${MD}" >> "${GITHUB_STEP_SUMMARY}"
fi
printf '%s\n' "${MD}"
