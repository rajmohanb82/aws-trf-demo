# =============================================================================
# Derived names, tags, AZs and subnet CIDRs
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_vpc_name  = var.public_vpc_name != "" ? var.public_vpc_name : "${var.project_name}-${var.environment}-public"
  private_vpc_name = var.private_vpc_name != "" ? var.private_vpc_name : "${var.project_name}-${var.environment}-private"

  # Auto-carve /24s when the user does not pass explicit subnet lists.
  # Public:  indexes 0..N-1     → 10.0.0.0/24, 10.0.1.0/24, ...
  # Private: indexes 10..10+N-1 → 10.1.10.0/24, 10.1.11.0/24, ...
  public_subnet_cidrs = length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : [
    for i in range(length(local.azs)) : cidrsubnet(var.public_vpc_cidr, 8, i)
  ]

  private_subnet_cidrs = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : [
    for i in range(length(local.azs)) : cidrsubnet(var.private_vpc_cidr, 8, i + 10)
  ]

  # Egress-only public subnets inside the private VPC (NAT). Indexes 20.. so they
  # stay clear of the workload /24s at 10..
  nat_subnet_cidrs = length(var.private_nat_subnet_cidrs) > 0 ? var.private_nat_subnet_cidrs : [
    for i in range(length(local.azs)) : cidrsubnet(var.private_vpc_cidr, 8, i + 20)
  ]

  container_deploy   = var.github_repository != ""
  enable_nat_gateway = var.enable_nat_gateway || local.container_deploy

  github_pat_parameter_name = var.github_pat_ssm_parameter_name != "" ? var.github_pat_ssm_parameter_name : (
    var.github_pat != "" ? "/${var.project_name}/${var.environment}/github-pat" : ""
  )

  github_pat_parameter_arn = local.github_pat_parameter_name == "" ? "" : "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${startswith(local.github_pat_parameter_name, "/") ? "" : "/"}${local.github_pat_parameter_name}"

  required_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      Repository  = "Terraform-Infra-demo"
    },
    var.additional_tags,
  )

  name_prefix = "${var.project_name}-${var.environment}"
}

# Guard rails that fail plan when the topology cannot work.
check "az_subnet_alignment" {
  assert {
    condition     = length(local.azs) == length(local.public_subnet_cidrs) && length(local.azs) == length(local.private_subnet_cidrs)
    error_message = "availability_zones, public_subnet_cidrs and private_subnet_cidrs must have the same length."
  }
}

check "container_deploy_has_pat" {
  assert {
    condition     = !local.container_deploy || local.github_pat_parameter_name != ""
    error_message = "github_repository is set: provide github_pat_ssm_parameter_name (preferred) or github_pat."
  }
}

check "nat_subnets_align" {
  assert {
    condition     = !local.enable_nat_gateway || length(local.nat_subnet_cidrs) == length(local.azs)
    error_message = "private_nat_subnet_cidrs must have one CIDR per AZ when NAT is enabled."
  }
}

check "vpc_cidrs_do_not_overlap" {
  assert {
    condition = (
      !cidrcontains(var.public_vpc_cidr, cidrhost(var.private_vpc_cidr, 0)) &&
      !cidrcontains(var.private_vpc_cidr, cidrhost(var.public_vpc_cidr, 0))
    )
    error_message = "public_vpc_cidr and private_vpc_cidr must not overlap (VPC peering requirement)."
  }
}
