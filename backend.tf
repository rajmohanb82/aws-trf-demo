# =============================================================================
# Remote state (S3 + native lockfile)
# -----------------------------------------------------------------------------
# Partial configuration: bucket / key / region are supplied at `terraform init`
# via backend-configs/<env>.hcl or -backend-config CLI flags.
#
# Why S3 (not local) for this template:
#   • GitHub Actions runners are ephemeral — local state would be lost.
#   • Dev / UAT / Prod must not share one state file.
#   • Native S3 lockfile avoids a DynamoDB lock table (cost).
#
# Bootstrap the bucket once from your laptop:
#   cd bootstrap && terraform init && terraform apply
# =============================================================================

terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
