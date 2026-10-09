# =============================================================================
# UAT — mirrors production topology at a smaller instance size
# =============================================================================

project_name = "dualvpc"
environment  = "uat"
aws_region   = "us-east-1"
owner        = "platform-team"

additional_tags = {
  CostCenter = "engineering"
  Pipeline   = "github-actions"
}

public_vpc_name  = ""
private_vpc_name = ""

public_vpc_cidr  = "10.20.0.0/16"
private_vpc_cidr = "10.21.0.0/16"

availability_zones   = []
az_count             = 2
public_subnet_cidrs  = []
private_subnet_cidrs = []

instance_type        = "t3.small"
asg_min_size         = 2
asg_desired_capacity = 2
asg_max_size         = 4
root_volume_size_gb  = 10

enable_cpu_autoscaling     = true
cpu_target_percent         = 60
enable_deletion_protection = false
enable_flow_logs           = false
enable_network_acls        = true
enable_ssm_endpoints       = true
ssm_endpoint_ha            = false
enable_alb_access_logs     = false
detailed_monitoring        = false

allowed_ingress_cidrs            = ["0.0.0.0/0"]
public_alb_https_certificate_arn = ""
health_check_path                = "/"
web_listen_port                  = 80

# github_repository             = "your-org/your-app"
# github_branch                 = "uat"
# github_pat_ssm_parameter_name = "/dualvpc/uat/github-pat"
# dockerfile_directory          = "."
# container_port                = 80
