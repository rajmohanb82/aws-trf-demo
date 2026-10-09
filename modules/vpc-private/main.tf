# =============================================================================
# Module: vpc-private
# -----------------------------------------------------------------------------
# Isolated workload VPC. Instances never receive a public IP.
#
#   Public ALB (peer VPC) ──peering──► Internal ALB ──► ASG (this VPC)
#
# Outbound internet (optional, required to clone GitHub + docker build):
#   • VPC peering cannot carry 0.0.0.0/0 (no edge-to-edge / borrowed NAT).
#   • A single NAT Gateway lives in an egress-only public subnet in THIS VPC.
#   • Workloads stay in private subnets (no public IP, no inbound from IGW).
#   • SSM interface endpoints still cover Session Manager / Parameter Store.
# =============================================================================

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
    Tier = "private"
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in var.azs : az => idx }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = var.private_subnet_cidrs[each.value]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  })
}

# Dedicated private route table. The peering module adds the public VPC CIDR.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-rt"
    Tier = "private"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Optional egress: single NAT Gateway (cost-effective) + IGW
# Workloads never sit in these public subnets.
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
    Role = "egress"
  })
}

resource "aws_subnet" "nat_public" {
  for_each = var.enable_nat_gateway ? { for idx, az in var.azs : az => idx } : {}

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = var.nat_public_subnet_cidrs[each.value]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${each.key}"
    Tier = "egress"
  })
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.nat_public[var.azs[0]].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat"
  })
}

resource "aws_route_table" "nat_public" {
  count = var.enable_nat_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-rt"
    Tier = "egress"
  })
}

resource "aws_route" "nat_public_default" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.nat_public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "nat_public" {
  for_each = aws_subnet.nat_public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.nat_public[0].id
}

resource "aws_route" "private_default" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# -----------------------------------------------------------------------------
# Optional restrictive Network ACL
# Only 80/443 from the public VPC, intra-VPC 80/443 (ALB→instances, SSM), and
# ephemeral return ports. SSH (22) is not opened.
# -----------------------------------------------------------------------------

resource "aws_network_acl" "private" {
  count = var.enable_network_acls ? 1 : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = merge(var.tags, {
    Name = "${var.name}-private-nacl"
  })
}

locals {
  nacl_id = var.enable_network_acls ? aws_network_acl.private[0].id : null
}

resource "aws_network_acl_rule" "ingress_peer_http" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.peer_vpc_cidr
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "ingress_peer_https" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.peer_vpc_cidr
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "ingress_local_http" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.cidr_block
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "ingress_local_https" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.cidr_block
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "ingress_ephemeral_peer" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 140
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.peer_vpc_cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "ingress_ephemeral_local" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 150
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.cidr_block
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "egress_peer_http" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 100
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
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.peer_vpc_cidr
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "egress_local_http" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.cidr_block
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "egress_local_https" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 130
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.cidr_block
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "egress_ephemeral_peer" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 140
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.peer_vpc_cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "egress_ephemeral_local" {
  count = var.enable_network_acls ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 150
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.cidr_block
  from_port      = 1024
  to_port        = 65535
}

# NAT path: GitHub (443), package mirrors (80/443), Docker registries, return traffic.
resource "aws_network_acl_rule" "ingress_ephemeral_internet" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 160
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "egress_internet_http" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 160
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "egress_internet_https" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  network_acl_id = local.nacl_id
  rule_number    = 170
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl" "nat_public" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.nat_public : s.id]

  tags = merge(var.tags, {
    Name = "${var.name}-nat-nacl"
  })
}

resource "aws_network_acl_rule" "nat_ingress_ephemeral" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  network_acl_id = aws_network_acl.nat_public[0].id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "nat_ingress_https_vpc" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  network_acl_id = aws_network_acl.nat_public[0].id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.cidr_block
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "nat_ingress_http_vpc" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  network_acl_id = aws_network_acl.nat_public[0].id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.cidr_block
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "nat_egress_http" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  network_acl_id = aws_network_acl.nat_public[0].id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "nat_egress_https" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  network_acl_id = aws_network_acl.nat_public[0].id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "nat_egress_ephemeral_vpc" {
  count = var.enable_network_acls && var.enable_nat_gateway ? 1 : 0

  network_acl_id = aws_network_acl.nat_public[0].id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.cidr_block
  from_port      = 1024
  to_port        = 65535
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

# -----------------------------------------------------------------------------
# SSM interface endpoints (Session Manager, no inbound SSH)
# Private DNS must be enabled so agent traffic stays on the AWS network.
# -----------------------------------------------------------------------------

locals {
  endpoint_subnet_ids = var.ssm_endpoint_ha ? [for s in aws_subnet.private : s.id] : [aws_subnet.private[var.azs[0]].id]

  ssm_services = var.enable_ssm_endpoints ? toset([
    "ssm",
    "ssmmessages",
    "ec2messages",
  ]) : toset([])
}

# Endpoints live in this module so the SG does not circular-depend on the ASG.
resource "aws_security_group" "endpoints" {
  count = var.enable_ssm_endpoints ? 1 : 0

  name        = "${var.name}-vpce"
  description = "Interface endpoints — inbound 443 from the private VPC only"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-vpce"
    Role = "vpce"
  })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  count = var.enable_ssm_endpoints ? 1 : 0

  security_group_id = aws_security_group.endpoints[0].id
  cidr_ipv4         = var.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from private VPC (SSM agents)"

  tags = var.tags
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = local.ssm_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name}-vpce-${each.value}"
  })
}

data "aws_region" "current" {}
