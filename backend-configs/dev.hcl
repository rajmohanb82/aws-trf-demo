# Replace the bucket after `cd bootstrap && terraform apply`.
# GitHub Actions overrides `bucket` from secret TF_STATE_BUCKET when set.
bucket       = "REPLACE_ME-tfstate"
key          = "dual-vpc/dev/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
