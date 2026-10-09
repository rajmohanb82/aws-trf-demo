variable "name" {
  description = "Name tag for the public VPC and a prefix for child resources."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR assigned to the public VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones that receive a public subnet."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR for each public subnet, aligned with azs."
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
  description = "Private VPC CIDR — permitted across the NACL for return / forwarded traffic."
  type        = string
}

variable "tags" {
  description = "Tags merged with Name on every resource."
  type        = map(string)
  default     = {}
}
