# =============================================================================
# Root Terraform & provider version pins
# -----------------------------------------------------------------------------
# Pin both Terraform and providers so Dev / UAT / Prod apply the same graph.
# S3 native state locking (use_lockfile) requires Terraform >= 1.10.
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
