# =============================================================================
# Module: alb-internal
# -----------------------------------------------------------------------------
# Internal Application Load Balancer in the private VPC. It is the only
# target of the public ALB (via IP attachments over VPC peering) and the only
# client of the web ASG (instance target group).
#
# scheme = internal  →  ENIs receive private IPs only, no internet mapping.
# =============================================================================

resource "aws_lb" "this" {
  name               = var.name
  internal           = true
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids
  ip_address_type    = "ipv4"

  idle_timeout                     = var.idle_timeout
  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true
  drop_invalid_header_fields       = true

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = "internal-alb"
      enabled = true
    }
  }

  tags = merge(var.tags, {
    Name = var.name
    Role = "internal-alb"
  })
}

resource "aws_lb_target_group" "instances" {
  name        = substr("${var.name}-tg", 0, 32)
  vpc_id      = var.vpc_id
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "instance"

  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200-399"
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = false
    cookie_duration = 86400
  }

  tags = merge(var.tags, {
    Name = "${var.name}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }

  tags = var.tags
}
