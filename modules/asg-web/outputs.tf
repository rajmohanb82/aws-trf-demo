output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.this.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.this.arn
}

output "launch_template_id" {
  description = "Launch template ID."
  value       = aws_launch_template.this.id
}

output "instance_profile_arn" {
  description = "IAM instance profile ARN (SSM)."
  value       = aws_iam_instance_profile.instance.arn
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI used by the launch template."
  value       = data.aws_ami.al2023.id
}
