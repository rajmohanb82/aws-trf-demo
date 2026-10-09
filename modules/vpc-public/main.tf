# =============================================================================
# Module: vpc-public
# -----------------------------------------------------------------------------
# Internet-facing VPC that hosts the public Application Load Balancer.
#
# Layout (per AZ):
#   Internet ──► Internet Gateway ──► Public subnet (ALB ENIs)
#
# No NAT Gateway is created. Private instances live in the peer VPC and reach
# AWS APIs through VPC endpoints (cheaper and does not break the "private VPC"
# boundary). VPC peering cannot carry 0.0.0.0/0 (no edge-to-edge routing).
#
# DNS hostnames are enabled so the public ALB DNS name resolves inside the VPC.
# =============================================================================

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
    Tier = "public"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = { for idx, az in var.azs : az => idx }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = var.public_subnet_cidrs[each.value]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  })
}

# One public route table is enough: every public subnet shares 0.0.0.0/0 → IGW.
# The peering route (private VPC CIDR) is injected by the vpc-peering module.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "default_ipv4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Optional restrictive Network ACL (stateless — ephemeral ports are mandatory)
# -----------------------------------------------------------------------------

resource "aws_network_acl" "public" {
  count = var.enable_network_acls ? 1 : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.public : s.id]

  tags = merge(var.tags, {
    Name = "${var.name}-public-nacl"
  })
}

locals {
  nacl_id = var.enable_network_acls ? aws_network_acl.public[0].id : null
}

# Inbound HTTP / HTTPS from the internet (clients hitting the public ALB).
resource "aws_network_acl_rule" "ingress_http" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "ingress_https" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# Return traffic from the private VPC (internal ALB responses) plus internet.
resource "aws_network_acl_rule" "ingress_ephemeral" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# Outbound to clients (internet) and to the peered private VPC (ports 80/443).
resource "aws_network_acl_rule" "egress_http" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "egress_https" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "egress_ephemeral" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "egress_peer_http" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 130
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.peer_vpc_cidr
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "egress_peer_https" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 140
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.peer_vpc_cidr
  from_port      = 443
  to_port        = 443
}

# -----------------------------------------------------------------------------
# Optional VPC Flow Logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.name}-flow-logs"
  })
}

resource "aws_iam_role" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name = "cloudwatch-write"
  role = aws_iam_role.flow[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.flow[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow[0].arn
  iam_role_arn         = aws_iam_role.flow[0].arn

  tags = merge(var.tags, {
    Name = "${var.name}-flow-logs"
  })
}
