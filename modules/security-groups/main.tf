# =============================================================================
# Module: security-groups
# -----------------------------------------------------------------------------
# Least-privilege security groups for the dual-VPC path:
#
#   Internet ──:80/:443──► public ALB ──:80/:443──► internal ALB ──:app──► EC2
#
# Cross-VPC rules use CIDR blocks (the public subnet CIDRs) rather than SG
# references. SG-to-SG references across a peer work in the same account/region
# but create a circular dependency; CIDRs keep the graph acyclic and still
# restrict traffic to the ALB subnets (not the whole public VPC).
#
# Port 22 is never opened. Day-2 access is SSM Session Manager.
# =============================================================================

# -----------------------------------------------------------------------------
# Public ALB (internet-facing)
# -----------------------------------------------------------------------------

resource "aws_security_group" "public_alb" {
  name        = "${var.name_prefix}-public-alb"
  description = "Internet-facing ALB — ingress 80/443 from allowed CIDRs, egress 80/443 to private subnets"
  vpc_id      = var.public_vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-alb"
    Role = "public-alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "public_alb_http" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.public_alb.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Client HTTP"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "public_alb_https" {
  for_each = var.enable_https ? toset(var.allowed_ingress_cidrs) : toset([])

  security_group_id = aws_security_group.public_alb.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Client HTTPS"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "public_alb_to_internal_http" {
  security_group_id = aws_security_group.public_alb.id
  cidr_ipv4         = var.private_vpc_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Forward HTTP to internal ALB via peering"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "public_alb_to_internal_https" {
  count = var.enable_https ? 1 : 0

  security_group_id = aws_security_group.public_alb.id
  cidr_ipv4         = var.private_vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Forward HTTPS to internal ALB via peering"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Internal ALB (private VPC)
# -----------------------------------------------------------------------------

resource "aws_security_group" "internal_alb" {
  name        = "${var.name_prefix}-internal-alb"
  description = "Internal ALB — ingress 80/443 from public ALB subnets, egress to instances"
  vpc_id      = var.private_vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-internal-alb"
    Role = "internal-alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_http" {
  for_each = toset(var.public_subnet_cidrs)

  security_group_id = aws_security_group.internal_alb.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from public ALB subnets over peering"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_https" {
  for_each = var.enable_https ? toset(var.public_subnet_cidrs) : toset([])

  security_group_id = aws_security_group.internal_alb.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from public ALB subnets over peering"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "internal_alb_to_instances" {
  security_group_id            = aws_security_group.internal_alb.id
  referenced_security_group_id = aws_security_group.instances.id
  from_port                    = var.web_listen_port
  to_port                      = var.web_listen_port
  ip_protocol                  = "tcp"
  description                  = "Forward to ASG instances"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# ASG instances
# -----------------------------------------------------------------------------

resource "aws_security_group" "instances" {
  name        = "${var.name_prefix}-web-instances"
  description = "Web ASG — ingress from internal ALB only, egress 443 to VPC endpoints"
  vpc_id      = var.private_vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-web-instances"
    Role = "web"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "instances_from_alb" {
  security_group_id            = aws_security_group.instances.id
  referenced_security_group_id = aws_security_group.internal_alb.id
  from_port                    = var.web_listen_port
  to_port                      = var.web_listen_port
  ip_protocol                  = "tcp"
  description                  = "HTTP from internal ALB"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "instances_https_vpc" {
  security_group_id = aws_security_group.instances.id
  cidr_ipv4         = var.private_vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS to SSM / interface endpoints"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "instances_https_internet" {
  count = var.enable_internet_egress ? 1 : 0

  security_group_id = aws_security_group.instances.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS to GitHub, registries, package mirrors (via NAT)"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "instances_http_internet" {
  count = var.enable_internet_egress ? 1 : 0

  security_group_id = aws_security_group.instances.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP to package mirrors (via NAT)"

  tags = var.tags
}
