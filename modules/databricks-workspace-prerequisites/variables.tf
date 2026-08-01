# Variables for the Databricks workspace prerequisites module.
#
# enable_serverless and pricing_tier used to live here. They are attributes of
# a databricks_mws_workspaces resource, which this module does not create, so
# nothing read them.

variable "workspace_name" {
  description = "Name of the Databricks workspace"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.workspace_name))
    error_message = "Workspace name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "databricks_account_id" {
  description = "Databricks account ID for cross-account access"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID where Databricks will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Databricks clusters"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets are required for high availability."
  }
}

variable "s3_kms_key_arn" {
  description = "KMS key ARN for S3 bucket encryption (leave empty for AES256)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
