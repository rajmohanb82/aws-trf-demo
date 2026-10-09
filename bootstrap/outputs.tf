output "state_bucket" {
  description = "S3 bucket name for Terraform remote state. Store as GitHub secret TF_STATE_BUCKET."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "backend_example" {
  description = "Copy-paste backend-config snippet."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.id}"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
    key          = "dual-vpc/<env>/terraform.tfstate"
  EOT
}
