output "vpc_id" {
  description = "ID of the private VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR of the private VPC."
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs (ordered by AZ)."
  value       = [for az in var.azs : aws_subnet.private[az].id]
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDRs (ordered by AZ)."
  value       = [for az in var.azs : aws_subnet.private[az].cidr_block]
}

output "private_route_table_id" {
  description = "Shared private route table (peering routes are added here)."
  value       = aws_route_table.private.id
}

output "ssm_endpoint_ids" {
  description = "Interface VPC endpoint IDs (empty when disabled)."
  value       = [for ep in aws_vpc_endpoint.ssm : ep.id]
}

output "nat_gateway_id" {
  description = "NAT Gateway ID (empty when egress is disabled)."
  value       = var.enable_nat_gateway ? aws_nat_gateway.this[0].id : null
}
