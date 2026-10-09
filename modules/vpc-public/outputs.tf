output "vpc_id" {
  description = "ID of the public VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR of the public VPC."
  value       = aws_vpc.this.cidr_block
}

output "igw_id" {
  description = "Internet Gateway ID."
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ordered by AZ)."
  value       = [for az in var.azs : aws_subnet.public[az].id]
}

output "public_subnet_cidrs" {
  description = "Public subnet CIDRs (ordered by AZ)."
  value       = [for az in var.azs : aws_subnet.public[az].cidr_block]
}

output "public_route_table_id" {
  description = "Shared public route table (peering routes are added here)."
  value       = aws_route_table.public.id
}
