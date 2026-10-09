# =============================================================================
# Root input variables
# -----------------------------------------------------------------------------
# Everything environment-specific is meant to be supplied via
# environments/<env>.tfvars (or -var / TF_VAR_*). Defaults exist so a laptop
# `terraform plan` works out of the box after bootstrap.
# =============================================================================

# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Short name used as a prefix on every resource (e.g. webapp, payments)."
  type        = string
  default     = "dualvpc"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name)) && length(var.project_name) <= 24
    error_message = "project_name must be lowercase alphanumeric plus hyphens, max 24 characters."
  }
}

variable "environment" {
  description = "Deployment environment. Must match the Git branch convention: dev | uat | prod."
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of: dev, uat, prod."
  }
}

variable "aws_region" {
  description = "AWS region for all resources. Both VPCs live in the same region (required for SG-free IP targeting across peering)."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Human or team that owns this stack. Applied as the Owner tag."
  type        = string
  default     = "platform-team"
}

variable "additional_tags" {
  description = "Extra tags merged onto every resource (CostCenter, Application, Ticket, ...)."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Availability zones
# -----------------------------------------------------------------------------

variable "availability_zones" {
  description = "Explicit AZs to use. Leave empty to pick the first az_count AZs in the region."
  type        = list(string)
  default     = []
}

variable "az_count" {
  description = "Number of AZs when availability_zones is empty. ALB requires at least 2."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4 (ALB minimum is 2)."
  }
}

# -----------------------------------------------------------------------------
# Public VPC
# -----------------------------------------------------------------------------

variable "public_vpc_name" {
  description = "Name tag for the internet-facing (public) VPC. Empty = \"<project>-<env>-public\"."
  type        = string
  default     = ""
}

variable "public_vpc_cidr" {
  description = "CIDR block for the public VPC. Must not overlap the private VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.public_vpc_cidr, 0))
    error_message = "public_vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ). Empty = auto-carve /24s from public_vpc_cidr."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Private VPC
# -----------------------------------------------------------------------------

variable "private_vpc_name" {
  description = "Name tag for the workload (private) VPC. Empty = \"<project>-<env>-private\"."
  type        = string
  default     = ""
}

variable "private_vpc_cidr" {
  description = "CIDR block for the private VPC. Must not overlap the public VPC."
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.private_vpc_cidr, 0))
    error_message = "private_vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (one per AZ). Empty = auto-carve /24s from private_vpc_cidr."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Cost / resilience toggles
# -----------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch. Useful for forensics; incurs log-ingestion cost."
  type        = bool
  default     = false
}

variable "enable_network_acls" {
  description = "Attach restrictive NACLs (80/443 + ephemeral) in addition to security groups."
  type        = bool
  default     = true
}

variable "enable_ssm_endpoints" {
  description = "Create SSM / EC2Messages / SSMMessages interface endpoints in the private VPC (no NAT, no bastion). Disable to save endpoint hourly cost."
  type        = bool
  default     = true
}

variable "ssm_endpoint_ha" {
  description = "Place SSM endpoints in every AZ (HA) vs a single AZ (cheaper). Ignored when enable_ssm_endpoints is false."
  type        = bool
  default     = false
}

variable "enable_alb_access_logs" {
  description = "Persist public & internal ALB access logs to S3. Disable by default to keep the template cheap."
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Protect ALBs from accidental terraform destroy. Recommended true in prod."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Load balancing
# -----------------------------------------------------------------------------

variable "public_alb_https_certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the public ALB. Empty = HTTP only (port 80)."
  type        = string
  default     = ""
}

variable "alb_idle_timeout" {
  description = "ALB idle timeout in seconds."
  type        = number
  default     = 60
}

variable "alb_deregistration_delay" {
  description = "Seconds to drain connections when a target is deregistered."
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "HTTP path used by both ALBs and the ASG ELB health check."
  type        = string
  default     = "/"
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the public ALB on 80/443. Default is the public internet."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# Compute (ASG + EC2)
# -----------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type for the web ASG (user-supplied; keep small for cost)."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum healthy instances in the ASG."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Desired instance count. Production baseline is 2."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum instances the target-tracking policy may scale to."
  type        = number
  default     = 4
}

variable "enable_cpu_autoscaling" {
  description = "Attach a target-tracking policy on ASG average CPU."
  type        = bool
  default     = true
}

variable "cpu_target_percent" {
  description = "Target average CPU utilization for the scaling policy."
  type        = number
  default     = 60
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size (gp3, encrypted)."
  type        = number
  default     = 8
}

variable "detailed_monitoring" {
  description = "Enable 1-minute EC2 detailed monitoring (extra CloudWatch cost)."
  type        = bool
  default     = false
}

variable "web_listen_port" {
  description = "Host port the ALB forwards to (Docker publishes the container here)."
  type        = number
  default     = 80
}

# -----------------------------------------------------------------------------
# Application deploy (GitHub → Docker on EC2)
# -----------------------------------------------------------------------------

variable "github_repository" {
  description = "GitHub repository to clone (owner/repo or https://github.com/owner/repo.git). Empty = built-in demo page (no Docker)."
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "Git branch, tag, or SHA to check out."
  type        = string
  default     = "main"
}

variable "github_pat_ssm_parameter_name" {
  description = "Existing SSM SecureString that holds the GitHub PAT. Preferred: the token never enters Terraform state. Create it with scripts/store-github-pat.sh."
  type        = string
  default     = ""
}

variable "github_pat" {
  description = "GitHub PAT with contents:read (and packages:read if the Dockerfile pulls from GHCR). Used only when github_pat_ssm_parameter_name is empty. Terraform writes it to SSM; it will appear in state. Prefer the SSM parameter path."
  type        = string
  default     = ""
  sensitive   = true
}

variable "dockerfile_directory" {
  description = "Directory inside the repo that contains the Dockerfile (relative path)."
  type        = string
  default     = "."
}

variable "container_port" {
  description = "Port the container process listens on (mapped to web_listen_port on the host)."
  type        = number
  default     = 80
}

variable "enable_nat_gateway" {
  description = "Force a single NAT Gateway in the private VPC. Automatically enabled when github_repository is set (dnf / git / docker pull need egress)."
  type        = bool
  default     = false
}

variable "private_nat_subnet_cidrs" {
  description = "Public subnet CIDRs in the private VPC used only by the NAT Gateway. Empty = auto-carve /24s at index 20+."
  type        = list(string)
  default     = []
}
