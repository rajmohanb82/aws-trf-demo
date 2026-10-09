# =============================================================================
# Prod — deletion protection, HA endpoints, slightly larger ASG ceiling
# =============================================================================

project_name = "dualvpc"
environment  = "prod"
aws_region   = "us-east-1"
owner        = "platform-team"

additional_tags = {
  CostCenter = "production"
  Pipeline   = "github-actions"
}

public_vpc_name  = ""
private_vpc_name = ""

public_vpc_cidr  = "10.30.0.0/16"
private_vpc_cidr = "10.31.0.0/16"

availability_zones   = []
az_count             = 2
public_subnet_cidrs  = []
private_subnet_cidrs = []

instance_type        = "t3.small"
asg_min_size         = 2
asg_desired_capacity = 2
asg_max_size         = 6
root_volume_size_gb  = 20

enable_cpu_autoscaling     = true
cpu_target_percent         = 50
enable_deletion_protection = true
enable_flow_logs           = false
enable_network_acls        = true
enable_ssm_endpoints       = true
ssm_endpoint_ha            = true
enable_alb_access_logs     = false
detailed_monitoring        = false

allowed_ingress_cidrs            = ["0.0.0.0/0"]
public_alb_https_certificate_arn = ""
health_check_path                = "/"
web_listen_port                  = 80

# github_repository             = "your-org/your-app"
# github_branch                 = "prod"
# github_pat_ssm_parameter_name = "/dualvpc/prod/github-pat"
# dockerfile_directory          = "."
# container_port                = 80
