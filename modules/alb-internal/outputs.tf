output "arn" {
  description = "ARN of the internal ALB."
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ARN suffix used to look up ALB ENIs (ELB <suffix>)."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "Internal DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Route 53 zone ID of the ALB."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the instance target group (attach to the ASG)."
  value       = aws_lb_target_group.instances.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix used by CloudWatch dimensions."
  value       = aws_lb_target_group.instances.arn_suffix
}

output "security_group_ids" {
  description = "Security groups on the ALB."
  value       = var.security_group_ids
}
