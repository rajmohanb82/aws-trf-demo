variable "name" {
  description = "Name of the public ALB (max 32 chars for the AWS name)."
  type        = string
}

variable "vpc_id" {
  description = "Public VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs (one per AZ, minimum two)."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the public ALB."
  type        = list(string)
}

variable "target_ips" {
  description = "Private IPs of the internal ALB ENIs (registered as ip targets)."
  type        = list(string)
}

variable "target_port" {
  description = "Port on the internal ALB listener (80)."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "HTTP health-check path against the internal ALB."
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

variable "certificate_arn" {
  description = "ACM certificate ARN. Empty = HTTP only."
  type        = string
  default     = ""
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
