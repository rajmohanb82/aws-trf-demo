variable "name" {
  description = "Name prefix for the launch template and ASG."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (user-supplied)."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs the ASG may launch into."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to each instance."
  type        = list(string)
}

variable "target_group_arns" {
  description = "Internal ALB target groups the ASG registers with."
  type        = list(string)
}

variable "min_size" {
  description = "ASG minimum size."
  type        = number
}

variable "max_size" {
  description = "ASG maximum size."
  type        = number
}

variable "desired_capacity" {
  description = "ASG desired capacity."
  type        = number
}

variable "root_volume_size_gb" {
  description = "Encrypted gp3 root volume size."
  type        = number
}

variable "detailed_monitoring" {
  description = "Enable 1-minute EC2 detailed monitoring."
  type        = bool
}

variable "enable_cpu_autoscaling" {
  description = "Attach a CPU target-tracking scaling policy."
  type        = bool
}

variable "cpu_target_percent" {
  description = "Target average CPU for the scaling policy."
  type        = number
}

variable "user_data" {
  description = "Cloud-init / user-data script (already rendered)."
  type        = string
}

variable "web_listen_port" {
  description = "Used only for tagging / documentation."
  type        = number
}

variable "health_check_grace_period" {
  description = "Seconds the ASG waits before ELB health checks count (raise for docker build)."
  type        = number
  default     = 180
}

variable "ssm_parameter_arn" {
  description = "SSM parameter ARN the instance may read (GitHub PAT). Empty = no extra IAM."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags merged onto the launch template, ASG and instances."
  type        = map(string)
  default     = {}
}
