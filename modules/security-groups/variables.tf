variable "name_prefix" {
  description = "Prefix for security group names."
  type        = string
}

variable "public_vpc_id" {
  description = "VPC that hosts the internet-facing ALB."
  type        = string
}

variable "private_vpc_id" {
  description = "VPC that hosts the internal ALB and ASG."
  type        = string
}

variable "allowed_ingress_cidrs" {
  description = "Client CIDRs allowed to hit the public ALB (80/443)."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs — the only sources allowed onto the internal ALB."
  type        = list(string)
}

variable "private_vpc_cidr" {
  description = "Private VPC CIDR (used for ALB→instance path documentation / fallback)."
  type        = string
}

variable "web_listen_port" {
  description = "Application port on the ASG instances."
  type        = number
}

variable "enable_https" {
  description = "When true, also open 443 on both ALBs."
  type        = bool
}

variable "enable_internet_egress" {
  description = "Allow instances to reach the internet on 80/443 (GitHub, dnf, Docker registries via NAT)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags merged with Name."
  type        = map(string)
  default     = {}
}
