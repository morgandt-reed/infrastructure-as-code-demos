variable "name" {
  description = "Name prefix for every resource in this stack"
  type        = string
  default     = "complete-setup"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to span"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Share one NAT Gateway across all AZs. Cheaper, but a single point of failure."
  type        = bool
  default     = true
}

variable "key_name" {
  description = <<-EOT
    Name of an existing EC2 key pair for the Docker host. Leave null to rely on
    Session Manager, which is enabled by default and needs no key.
  EOT
  type        = string
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the Docker host. Empty creates no SSH rule."
  type        = list(string)
  default     = []
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to reach the Docker host over HTTP/HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "EC2 instance type for the Docker host"
  type        = string
  default     = "t3.small"
}

variable "alarm_actions" {
  description = "SNS topic ARNs notified by the Docker host CloudWatch alarms"
  type        = list(string)
  default     = []
}

variable "enable_databricks_prerequisites" {
  description = <<-EOT
    Also create the AWS-side prerequisites for a Databricks workspace. Requires
    databricks_account_id. Off by default because it creates IAM roles and an S3
    bucket you may not want.
  EOT
  type        = bool
  default     = false
}

variable "databricks_account_id" {
  description = "Databricks account ID, used as the sts:ExternalId on the cross-account role"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.databricks_account_id == null || can(regex("^[0-9a-f-]+$", coalesce(var.databricks_account_id, "0")))
    error_message = "Databricks account ID must be a UUID-style identifier."
  }
}

variable "tags" {
  description = "Extra tags merged into the default tags applied to every resource"
  type        = map(string)
  default     = {}
}
