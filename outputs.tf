# =============================================================================
# Stack outputs — consumed by README, showcase.sh and GitHub Actions summaries
# =============================================================================

output "environment" {
  description = "Environment this state file belongs to."
  value       = var.environment
}

output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account the stack was applied in."
  value       = data.aws_caller_identity.current.account_id
}

output "public_vpc_id" {
  description = "Public VPC ID."
  value       = module.public_vpc.vpc_id
}

output "public_vpc_cidr" {
  description = "Public VPC CIDR."
  value       = module.public_vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.public_vpc.public_subnet_ids
}

output "internet_gateway_id" {
  description = "Internet Gateway attached to the public VPC."
  value       = module.public_vpc.igw_id
}

output "private_vpc_id" {
  description = "Private VPC ID."
  value       = module.private_vpc.vpc_id
}

output "private_vpc_cidr" {
  description = "Private VPC CIDR."
  value       = module.private_vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.private_vpc.private_subnet_ids
}

output "vpc_peering_connection_id" {
  description = "Peering connection between the public and private VPCs."
  value       = module.peering.peering_connection_id
}

output "vpc_peering_status" {
  description = "Peering acceptance status."
  value       = module.peering.peering_status
}

output "public_alb_dns_name" {
  description = "Internet-facing ALB DNS name."
  value       = module.public_alb.dns_name
}

output "public_alb_url" {
  description = "Browser URL for the platform."
  value       = module.public_alb.url
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS name (private VPC only)."
  value       = module.internal_alb.dns_name
}

output "internal_alb_ips" {
  description = "Private IPs of the internal ALB (registered on the public ALB)."
  value       = [for nic in data.aws_network_interface.internal_alb : nic.private_ip]
}

output "asg_name" {
  description = "Web Auto Scaling Group name."
  value       = module.asg_web.asg_name
}

output "asg_ami_id" {
  description = "AMI used by the web launch template."
  value       = module.asg_web.ami_id
}

output "nat_gateway_id" {
  description = "NAT Gateway in the private VPC (null when container deploy is off)."
  value       = module.private_vpc.nat_gateway_id
}

output "app_repository" {
  description = "GitHub repository cloned onto the ASG instances (empty = demo page)."
  value       = var.github_repository
}

output "app_branch" {
  description = "Git ref checked out on the instances."
  value       = var.github_branch
}

output "github_pat_ssm_parameter" {
  description = "SSM parameter name the instances read for the GitHub PAT."
  value       = nonsensitive(local.github_pat_parameter_name)
}

output "redeploy_hint" {
  description = "Re-run the container deploy on a live instance without replacing it."
  value       = "aws ssm start-session --target <instance-id> --region ${var.aws_region}  # then: sudo /usr/local/bin/deploy-app.sh"
}

output "ssm_instance_connect" {
  description = "Hint for Session Manager access (no SSH)."
  value       = "aws ssm start-session --target <instance-id> --region ${var.aws_region}"
}

output "deployment_summary" {
  description = "Human-readable snapshot of the live stack (used by CI showcase)."
  value = {
    environment      = var.environment
    region           = var.aws_region
    public_vpc       = module.public_vpc.vpc_id
    private_vpc      = module.private_vpc.vpc_id
    peering          = module.peering.peering_connection_id
    public_alb_url   = module.public_alb.url
    internal_alb_dns = module.internal_alb.dns_name
    asg              = module.asg_web.asg_name
    instance_type    = var.instance_type
    asg_capacity     = "${var.asg_min_size}/${var.asg_desired_capacity}/${var.asg_max_size}"
    allowed_ingress  = var.allowed_ingress_cidrs
    https_enabled    = var.public_alb_https_certificate_arn != ""
    app_mode         = local.container_deploy ? "github-container" : "demo"
    app_repository   = var.github_repository
    app_branch       = var.github_branch
    nat_gateway      = module.private_vpc.nat_gateway_id
  }
}
