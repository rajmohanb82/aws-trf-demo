variable "name" {
  description = "Name tag for the private VPC and a prefix for child resources."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR assigned to the private VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones that receive a private subnet."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR for each private subnet, aligned with azs."
  type        = list(string)
}

variable "enable_flow_logs" {
  description = "Ship VPC Flow Logs to a CloudWatch log group."
  type        = bool
}

variable "enable_network_acls" {
  description = "Replace the default NACL with a 80/443 + ephemeral allow-list."
  type        = bool
}

variable "peer_vpc_cidr" {
  description = "Public VPC CIDR — the only remote network allowed through the NACL."
  type        = string
}

variable "enable_ssm_endpoints" {
  description = "Create Interface endpoints so instances can use SSM Session Manager without a NAT/bastion."
  type        = bool
}

variable "ssm_endpoint_ha" {
  description = "true = endpoint ENIs in every AZ; false = a single AZ (cheaper)."
  type        = bool
}

variable "enable_nat_gateway" {
  description = "Create one public subnet per AZ plus a single NAT Gateway for egress (git / dnf / docker)."
  type        = bool
}

variable "nat_public_subnet_cidrs" {
  description = "CIDRs for the NAT public subnets, aligned with azs."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags merged with Name on every resource."
  type        = map(string)
  default     = {}
}
