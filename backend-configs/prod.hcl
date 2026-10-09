# Replace the bucket after `cd bootstrap && terraform apply`.
bucket       = "REPLACE_ME-tfstate"
key          = "dual-vpc/prod/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
