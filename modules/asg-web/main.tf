# =============================================================================
# Module: asg-web
# -----------------------------------------------------------------------------
# Production-style Auto Scaling Group for the private-VPC web application.
#
# Resilience
#   • Multi-AZ subnet list (ASG spreads instances automatically).
#   • ELB health checks — unhealthy instances are replaced.
#   • Instance refresh on launch-template changes (rolling, 50% healthy).
#   • IMDSv2 required (SSRF mitigation).
#
# Cost
#   • gp3 (baseline included) instead of gp2.
#   • Detailed monitoring off unless requested.
#   • No public IP, no Elastic IP. NAT (when enabled) is in the VPC module.
#
# Access
#   • IAM instance profile with AmazonSSMManagedInstanceCore only.
#   • No SSH key pair is associated.
# =============================================================================

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name}-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least-privilege read of the GitHub PAT. The token is never placed in user-data.
data "aws_iam_policy_document" "github_pat" {
  count = var.ssm_parameter_arn != "" ? 1 : 0

  statement {
    sid       = "ReadGithubPat"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [var.ssm_parameter_arn]
  }

  statement {
    sid       = "DecryptSsmSecureString"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["ssm.*.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_pat" {
  count  = var.ssm_parameter_arn != "" ? 1 : 0
  name   = "github-pat-ssm"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.github_pat[0].json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-ec2"
  role = aws_iam_role.instance.name
  tags = var.tags
}

resource "aws_launch_template" "this" {
  name_prefix            = "${var.name}-"
  image_id               = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = var.security_group_ids
  user_data              = base64encode(var.user_data)
  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = var.detailed_monitoring
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
      iops                  = 3000
      throughput            = 125
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name    = "${var.name}-web"
      Role    = "web"
      WebPort = tostring(var.web_listen_port)
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name}-web"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.name}-lt"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = var.name
  vpc_zone_identifier       = var.subnet_ids
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  target_group_arns         = var.target_group_arns
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period
  wait_for_capacity_timeout = "20m"

  # Spread across AZs; do not pack onto one host.
  default_cooldown      = 60
  capacity_rebalance    = true
  max_instance_lifetime = 0
  metrics_granularity   = "1Minute"
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances",
  ]

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 90
    }
    triggers = ["tag"]
  }

  dynamic "tag" {
    for_each = merge(var.tags, {
      Name = "${var.name}-web"
      Role = "web"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    # CPU target-tracking adjusts desired_capacity; do not fight it on every apply.
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "cpu" {
  count = var.enable_cpu_autoscaling ? 1 : 0

  name                   = "${var.name}-cpu-tt"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.cpu_target_percent
    disable_scale_in = false
  }
}
