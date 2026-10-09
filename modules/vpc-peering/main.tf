# =============================================================================
# Module: vpc-peering
# -----------------------------------------------------------------------------
# Same-account, same-region peering between the public (requester) VPC and the
# private (accepter) VPC.
#
# What this module does:
#   1. Creates the peering connection and auto-accepts it.
#   2. Enables DNS resolution across the peer (ALB DNS names keep working).
#   3. Installs non-transitive IPv4 routes for the peer CIDRs only.
#
# What this module deliberately does NOT do:
#   • 0.0.0.0/0 through the peer (AWS rejects edge-to-edge / IGW / NAT).
#   • Open security groups — ports are enforced in the security-groups module
#     (80 / 443 only).
# =============================================================================

resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = merge(var.tags, {
    Name = var.name
    Side = "requester-public"
  })
}

resource "aws_route" "public_to_private" {
  for_each = toset(var.requester_route_table_ids)

  route_table_id            = each.value
  destination_cidr_block    = var.accepter_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "private_to_public" {
  for_each = toset(var.accepter_route_table_ids)

  route_table_id            = each.value
  destination_cidr_block    = var.requester_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
