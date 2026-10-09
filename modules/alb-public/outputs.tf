output "arn" {
  description = "ARN of the public ALB."
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ARN suffix used by CloudWatch dimensions."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "Public DNS name — the internet entry point of the stack."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Route 53 zone ID of the ALB."
  value       = aws_lb.this.zone_id
}

output "url" {
  description = "Browser URL for the public ALB."
  value       = var.certificate_arn != "" ? "https://${aws_lb.this.dns_name}" : "http://${aws_lb.this.dns_name}"
}

output "target_group_arn" {
  description = "ARN of the IP target group that points at the internal ALB."
  value       = aws_lb_target_group.internal_alb.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix used by CloudWatch dimensions."
  value       = aws_lb_target_group.internal_alb.arn_suffix
}
