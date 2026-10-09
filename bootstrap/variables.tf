variable "project_name" {
  description = "Project prefix used in the state-bucket name."
  type        = string
  default     = "dualvpc"
}

variable "aws_region" {
  description = "Region for the state bucket (same region as the workload)."
  type        = string
  default     = "us-east-1"
}
