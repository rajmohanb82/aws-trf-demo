# =============================================================================
# AWS provider
# -----------------------------------------------------------------------------
# Authentication uses the standard AWS credential chain (laptop first):
#   1. Environment variables (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)
#   2. Shared config (~/.aws/credentials, ~/.aws/config) + AWS_PROFILE
#   3. GitHub Actions secrets (same keys, copied from the laptop)
#
# No OIDC / assumed GitHub role is configured — by design.
# Default tags are merged onto every taggable resource.
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.required_tags
  }
}
