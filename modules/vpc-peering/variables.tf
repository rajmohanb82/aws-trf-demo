variable "name" {
  description = "Name tag for the peering connection."
  type        = string
}

variable "requester_vpc_id" {
  description = "Public VPC ID (requester)."
  type        = string
}

variable "accepter_vpc_id" {
  description = "Private VPC ID (accepter)."
  type        = string
}

variable "requester_cidr" {
  description = "Public VPC CIDR — installed in the private route table."
  type        = string
}

variable "accepter_cidr" {
  description = "Private VPC CIDR — installed in the public route table."
  type        = string
}

variable "requester_route_table_ids" {
  description = "Route tables in the public VPC that must reach the private VPC."
  type        = list(string)
}

variable "accepter_route_table_ids" {
  description = "Route tables in the private VPC that must reach the public VPC."
  type        = list(string)
}

variable "tags" {
  description = "Tags merged with Name."
  type        = map(string)
  default     = {}
}
