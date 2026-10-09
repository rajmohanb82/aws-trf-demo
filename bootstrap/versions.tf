# =============================================================================
# Bootstrap: remote-state bucket
# -----------------------------------------------------------------------------
# Run ONCE from your laptop with local AWS credentials:
#   cd bootstrap
#   terraform init
#   terraform apply
#
# Then copy the `state_bucket` output into GitHub secret TF_STATE_BUCKET
# and into backend-configs/*.hcl.
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  backend "local" {
    path = "state/bootstrap.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Purpose   = "terraform-state"
      ManagedBy = "terraform"
    }
  }
}
