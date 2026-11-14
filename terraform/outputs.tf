output "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  description = "Jenkins EC2 public IP"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins dashboard URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_iam_role" {
  description = "Jenkins EC2 IAM role"
  value       = aws_iam_role.jenkins_role.name
}
