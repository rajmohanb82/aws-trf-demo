# =============================================================================
# Dev — cheap, two-AZ, easy to destroy
# =============================================================================

project_name = "dualvpc"
environment  = "dev"
aws_region   = "us-east-1"
owner        = "platform-team"

additional_tags = {
  CostCenter = "engineering"
  Pipeline   = "github-actions"
}

# Names (empty = auto "<project>-<env>-public|private")
public_vpc_name  = ""
private_vpc_name = ""

public_vpc_cidr  = "10.10.0.0/16"
private_vpc_cidr = "10.11.0.0/16"

# Empty lists → auto-carve /24s across az_count AZs
availability_zones   = []
az_count             = 2
public_subnet_cidrs  = []
private_subnet_cidrs = []

instance_type        = "t3.micro"
asg_min_size         = 2
asg_desired_capacity = 2
asg_max_size         = 4
root_volume_size_gb  = 8

enable_cpu_autoscaling     = true
cpu_target_percent         = 70
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

# Container deploy from GitHub (uncomment and set the SSM parameter).
# Store the PAT first:  GITHUB_PAT=ghp_xxx ./scripts/store-github-pat.sh /dualvpc/dev/github-pat
# github_repository              = "your-org/your-app"
# github_branch                  = "main"
# github_pat_ssm_parameter_name  = "/dualvpc/dev/github-pat"
# dockerfile_directory           = "."
# container_port                 = 80
# instance_type                  = "t3.small"
# root_volume_size_gb            = 20
