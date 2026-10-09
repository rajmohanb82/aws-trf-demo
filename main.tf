# =============================================================================
# Dual-VPC web platform — root composition
# -----------------------------------------------------------------------------
# Traffic path:
#
#   Client ──:80/:443──► Public ALB (public VPC, IGW)
#                         │
#                         │  VPC peering  (routes + SG allow 80/443 only)
#                         ▼
#                       Internal ALB (private VPC)
#                         │
#                         ▼
#                       ASG × N  (Amazon Linux 2023 web app)
#
# Apply order is encoded with depends_on / attribute references so a single
# `terraform apply` provisions the full path, including IP target registration
# of the internal ALB ENIs onto the public ALB.
# =============================================================================

# -----------------------------------------------------------------------------
# 1. VPCs
# -----------------------------------------------------------------------------

module "public_vpc" {
  source = "./modules/vpc-public"

  name                = local.public_vpc_name
  cidr_block          = var.public_vpc_cidr
  azs                 = local.azs
  public_subnet_cidrs = local.public_subnet_cidrs
  peer_vpc_cidr       = var.private_vpc_cidr
  enable_flow_logs    = var.enable_flow_logs
  enable_network_acls = var.enable_network_acls
  tags                = local.required_tags
}

module "private_vpc" {
  source = "./modules/vpc-private"

  name                    = local.private_vpc_name
  cidr_block              = var.private_vpc_cidr
  azs                     = local.azs
  private_subnet_cidrs    = local.private_subnet_cidrs
  peer_vpc_cidr           = var.public_vpc_cidr
  enable_flow_logs        = var.enable_flow_logs
  enable_network_acls     = var.enable_network_acls
  enable_ssm_endpoints    = var.enable_ssm_endpoints
  ssm_endpoint_ha         = var.ssm_endpoint_ha
  enable_nat_gateway      = local.enable_nat_gateway
  nat_public_subnet_cidrs = local.nat_subnet_cidrs
  tags                    = local.required_tags
}

# -----------------------------------------------------------------------------
# 2. Peering (CIDR routes only — ports are enforced by security groups / NACLs)
# -----------------------------------------------------------------------------

module "peering" {
  source = "./modules/vpc-peering"

  name                      = "${local.name_prefix}-peer"
  tags                      = local.required_tags
  requester_vpc_id          = module.public_vpc.vpc_id
  accepter_vpc_id           = module.private_vpc.vpc_id
  requester_cidr            = module.public_vpc.vpc_cidr
  accepter_cidr             = module.private_vpc.vpc_cidr
  requester_route_table_ids = [module.public_vpc.public_route_table_id]
  accepter_route_table_ids  = [module.private_vpc.private_route_table_id]
}

# -----------------------------------------------------------------------------
# 3. Security groups (80 / 443 only across the peer)
# -----------------------------------------------------------------------------

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix            = local.name_prefix
  public_vpc_id          = module.public_vpc.vpc_id
  private_vpc_id         = module.private_vpc.vpc_id
  allowed_ingress_cidrs  = var.allowed_ingress_cidrs
  public_subnet_cidrs    = module.public_vpc.public_subnet_cidrs
  private_vpc_cidr       = module.private_vpc.vpc_cidr
  web_listen_port        = var.web_listen_port
  enable_https           = var.public_alb_https_certificate_arn != ""
  enable_internet_egress = local.enable_nat_gateway
  tags                   = local.required_tags

  depends_on = [module.peering]
}

# -----------------------------------------------------------------------------
# 4. Optional ALB access-logs bucket
# -----------------------------------------------------------------------------

data "aws_elb_service_account" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = "${local.name_prefix}-alb-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.required_tags, {
    Name = "${local.name_prefix}-alb-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket                  = aws_s3_bucket.alb_logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "expire"
    status = "Enabled"
    filter {
      prefix = ""
    }
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.current.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.current.arn
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs[0].arn
      },
      {
        Sid    = "AWSLogDeliveryWriteModern"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# 5. GitHub PAT in SSM (only when the token is supplied to Terraform)
#    Preferred path: create the parameter yourself with scripts/store-github-pat.sh
#    so the token never enters Terraform state.
# -----------------------------------------------------------------------------

resource "aws_ssm_parameter" "github_pat" {
  count = local.container_deploy && var.github_pat_ssm_parameter_name == "" && var.github_pat != "" ? 1 : 0

  name        = local.github_pat_parameter_name
  description = "GitHub PAT used by ASG instances to clone ${var.github_repository}"
  type        = "SecureString"
  value       = var.github_pat

  tags = merge(local.required_tags, {
    Name    = local.github_pat_parameter_name
    Purpose = "github-clone"
  })
}

# -----------------------------------------------------------------------------
# 6. Internal ALB + ASG (private VPC)
# -----------------------------------------------------------------------------

module "internal_alb" {
  source = "./modules/alb-internal"

  name                       = substr("${local.name_prefix}-int", 0, 32)
  vpc_id                     = module.private_vpc.vpc_id
  subnet_ids                 = module.private_vpc.private_subnet_ids
  security_group_ids         = [module.security_groups.internal_alb_sg_id]
  target_port                = var.web_listen_port
  health_check_path          = var.health_check_path
  deregistration_delay       = var.alb_deregistration_delay
  idle_timeout               = var.alb_idle_timeout
  enable_deletion_protection = var.enable_deletion_protection
  enable_access_logs         = var.enable_alb_access_logs
  access_logs_bucket         = var.enable_alb_access_logs ? aws_s3_bucket.alb_logs[0].id : ""
  tags                       = local.required_tags
}

module "asg_web" {
  source = "./modules/asg-web"

  name                      = "${local.name_prefix}-web"
  instance_type             = var.instance_type
  subnet_ids                = module.private_vpc.private_subnet_ids
  security_group_ids        = [module.security_groups.instance_sg_id]
  target_group_arns         = [module.internal_alb.target_group_arn]
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  root_volume_size_gb       = var.root_volume_size_gb
  detailed_monitoring       = var.detailed_monitoring
  enable_cpu_autoscaling    = var.enable_cpu_autoscaling
  cpu_target_percent        = var.cpu_target_percent
  web_listen_port           = var.web_listen_port
  health_check_grace_period = local.container_deploy ? 600 : 180
  ssm_parameter_arn         = local.github_pat_parameter_arn
  tags                      = local.required_tags

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    project_name                  = var.project_name
    environment                   = var.environment
    aws_region                    = var.aws_region
    web_listen_port               = var.web_listen_port
    container_port                = var.container_port
    github_repository             = var.github_repository
    github_branch                 = var.github_branch
    github_pat_ssm_parameter_name = local.github_pat_parameter_name
    dockerfile_directory          = var.dockerfile_directory
    container_deploy              = local.container_deploy ? "true" : "false"
    deploy_script                 = file("${path.module}/templates/deploy-app.sh")
  })

  depends_on = [aws_ssm_parameter.github_pat]
}

# -----------------------------------------------------------------------------
# 7. Discover internal ALB private IPs, then register them on the public ALB
# -----------------------------------------------------------------------------

resource "time_sleep" "wait_internal_alb_enis" {
  depends_on      = [module.internal_alb]
  create_duration = "45s"
}

data "aws_network_interfaces" "internal_alb" {
  filter {
    name   = "description"
    values = ["ELB ${module.internal_alb.arn_suffix}"]
  }

  filter {
    name   = "vpc-id"
    values = [module.private_vpc.vpc_id]
  }

  depends_on = [time_sleep.wait_internal_alb_enis]
}

# count is known (az_count) so Terraform can plan attachments while the IDs
# themselves remain unknown until apply (data source is deferred).
data "aws_network_interface" "internal_alb" {
  count = length(local.azs)
  id    = data.aws_network_interfaces.internal_alb.ids[count.index]
}

module "public_alb" {
  source = "./modules/alb-public"

  name                       = substr("${local.name_prefix}-pub", 0, 32)
  vpc_id                     = module.public_vpc.vpc_id
  subnet_ids                 = module.public_vpc.public_subnet_ids
  security_group_ids         = [module.security_groups.public_alb_sg_id]
  target_ips                 = [for nic in data.aws_network_interface.internal_alb : nic.private_ip]
  target_port                = 80
  health_check_path          = var.health_check_path
  deregistration_delay       = var.alb_deregistration_delay
  idle_timeout               = var.alb_idle_timeout
  enable_deletion_protection = var.enable_deletion_protection
  certificate_arn            = var.public_alb_https_certificate_arn
  enable_access_logs         = var.enable_alb_access_logs
  access_logs_bucket         = var.enable_alb_access_logs ? aws_s3_bucket.alb_logs[0].id : ""
  tags                       = local.required_tags
}

# -----------------------------------------------------------------------------
# 8. Lightweight CloudWatch alarms (console-visible; no SNS = no extra cost)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "public_alb_unhealthy" {
  alarm_name          = "${local.name_prefix}-public-alb-unhealthy"
  alarm_description   = "Public ALB has unhealthy targets (internal ALB IPs)."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = module.public_alb.arn_suffix
    TargetGroup  = module.public_alb.target_group_arn_suffix
  }

  tags = local.required_tags
}

resource "aws_cloudwatch_metric_alarm" "internal_alb_unhealthy" {
  alarm_name          = "${local.name_prefix}-internal-alb-unhealthy"
  alarm_description   = "Internal ALB has unhealthy ASG instances."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = module.internal_alb.arn_suffix
    TargetGroup  = module.internal_alb.target_group_arn_suffix
  }

  tags = local.required_tags
}
