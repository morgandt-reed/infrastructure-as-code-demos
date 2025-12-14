output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.docker_host.id
}

output "instance_public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.docker_host.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the instance"
  value       = aws_instance.docker_host.private_ip
}

output "elastic_ip" {
  description = "Elastic IP (if enabled)"
  value       = var.enable_elastic_ip ? aws_eip.docker_host[0].public_ip : null
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.docker_host.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i <your-key>.pem ubuntu@${var.enable_elastic_ip ? aws_eip.docker_host[0].public_ip : aws_instance.docker_host.public_ip}"
}
