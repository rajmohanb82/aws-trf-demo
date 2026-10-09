output "public_alb_sg_id" {
  description = "Security group ID for the internet-facing ALB."
  value       = aws_security_group.public_alb.id
}

output "internal_alb_sg_id" {
  description = "Security group ID for the internal ALB."
  value       = aws_security_group.internal_alb.id
}

output "instance_sg_id" {
  description = "Security group ID for ASG instances."
  value       = aws_security_group.instances.id
}
