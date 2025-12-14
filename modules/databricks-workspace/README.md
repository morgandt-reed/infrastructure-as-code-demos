# Databricks Workspace Module

Terraform module to create AWS infrastructure for a Databricks workspace.

## Features

- S3 bucket for workspace root storage with encryption
- Cross-account IAM role for Databricks
- IAM instance profile for cluster nodes
- Security group for cluster communication
- KMS encryption support (optional)

## Usage

```hcl
module "databricks_workspace" {
  source = "./modules/databricks-workspace"

  workspace_name        = "my-databricks-workspace"
  environment           = "prod"
  databricks_account_id = "your-databricks-account-id"
  vpc_id                = "vpc-12345678"
  subnet_ids            = ["subnet-111", "subnet-222"]
  pricing_tier          = "PREMIUM"

  tags = {
    Project     = "DataPlatform"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| workspace_name | Name of the Databricks workspace | string | n/a | yes |
| environment | Environment name | string | "dev" | no |
| databricks_account_id | Databricks account ID | string | n/a | yes |
| vpc_id | VPC ID for deployment | string | n/a | yes |
| subnet_ids | Subnet IDs for clusters | list(string) | n/a | yes |
| s3_kms_key_arn | KMS key for S3 encryption | string | "" | no |
| pricing_tier | Databricks pricing tier | string | "PREMIUM" | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| s3_bucket_name | Name of the root storage bucket |
| s3_bucket_arn | ARN of the root storage bucket |
| cross_account_role_arn | ARN of the cross-account role |
| instance_profile_arn | ARN of the instance profile |
| security_group_id | ID of the security group |
| workspace_config | Configuration for workspace setup |

## Prerequisites

1. Databricks account ID
2. Existing VPC with at least 2 subnets
3. AWS credentials with appropriate permissions
