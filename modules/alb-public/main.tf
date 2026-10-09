# =============================================================================
# Module: alb-public
# -----------------------------------------------------------------------------
# Internet-facing Application Load Balancer in the public VPC.
#
# Cross-VPC forwarding:
#   AWS does not let an ALB register another ALB as a target_type=alb
#   (that pairing is NLB → ALB). The supported pattern is:
#
#     target_type = "ip"
#     attachments = private IPs of the internal ALB elastic network interfaces
#
#   Those IPs are discovered in the root module after the internal ALB is
#   provisioned, then passed in as target_ips.
# =============================================================================

locals {
  enable_https = var.certificate_arn != ""
}

resource "aws_lb" "this" {
  name               = var.name
  internal           = false
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
      prefix  = "public-alb"
      enabled = true
    }
  }

  tags = merge(var.tags, {
    Name = var.name
    Role = "public-alb"
  })
}

resource "aws_lb_target_group" "internal_alb" {
  name        = substr("${var.name}-ip", 0, 32)
  vpc_id      = var.vpc_id
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "ip"

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

  tags = merge(var.tags, {
    Name = "${var.name}-to-internal"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "internal_alb" {
  for_each = toset(var.target_ips)

  target_group_arn = aws_lb_target_group.internal_alb.arn
  target_id        = each.value
  port             = var.target_port

  # Peered VPC IPs are outside this ALB's VPC — required for the API to accept them.
  availability_zone = "all"
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.enable_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.enable_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.internal_alb.arn
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  count = local.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_alb.arn
  }

  tags = var.tags
}
