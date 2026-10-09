variable "name" {
  description = "Name of the internal ALB (max 32 chars for the AWS name)."
  type        = string
}

variable "vpc_id" {
  description = "Private VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs (one per AZ, minimum two)."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the internal ALB."
  type        = list(string)
}

variable "target_port" {
  description = "Port on the ASG instances."
  type        = number
}

variable "health_check_path" {
  description = "HTTP health-check path."
  type        = string
}

variable "deregistration_delay" {
  description = "Target-group deregistration delay in seconds."
  type        = number
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds."
  type        = number
}

variable "enable_deletion_protection" {
  description = "Block accidental ALB deletion."
  type        = bool
}

variable "enable_access_logs" {
  description = "Persist access logs to the provided S3 bucket."
  type        = bool
}

variable "access_logs_bucket" {
  description = "S3 bucket for access logs (empty when disabled)."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags merged with Name."
  type        = map(string)
  default     = {}
}
