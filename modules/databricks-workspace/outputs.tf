# Outputs for Databricks Workspace Module

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Databricks root storage"
  value       = aws_s3_bucket.databricks_root.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Databricks root storage"
  value       = aws_s3_bucket.databricks_root.arn
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account IAM role for Databricks"
  value       = aws_iam_role.databricks_cross_account.arn
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile for Databricks clusters"
  value       = aws_iam_instance_profile.databricks.arn
}

output "security_group_id" {
  description = "ID of the security group for Databricks"
  value       = aws_security_group.databricks.id
}

output "workspace_config" {
  description = "Configuration values for Databricks workspace setup"
  value = {
    credentials_id     = aws_iam_role.databricks_cross_account.arn
    storage_config_id  = aws_s3_bucket.databricks_root.id
    network_config = {
      security_group_ids = [aws_security_group.databricks.id]
      subnet_ids         = var.subnet_ids
      vpc_id             = var.vpc_id
    }
  }
}
