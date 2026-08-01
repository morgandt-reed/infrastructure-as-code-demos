output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = module.vpc.nat_gateway_ips
}

output "docker_host_public_ip" {
  description = "Public IP of the Docker host (its Elastic IP)"
  value       = module.docker_host.elastic_ip
}

output "docker_host_instance_id" {
  description = "Instance ID of the Docker host"
  value       = module.docker_host.instance_id
}

output "session_manager_command" {
  description = "Connect to the Docker host without SSH"
  value       = "aws ssm start-session --target ${module.docker_host.instance_id}"
}

output "databricks_cross_account_role_arn" {
  description = "Cross-account role ARN, null unless the Databricks prerequisites are enabled"
  value       = var.enable_databricks_prerequisites ? module.databricks_prerequisites[0].cross_account_role_arn : null
}

output "databricks_root_bucket" {
  description = "Databricks root bucket name, null unless the prerequisites are enabled"
  value       = var.enable_databricks_prerequisites ? module.databricks_prerequisites[0].s3_bucket_name : null
}
