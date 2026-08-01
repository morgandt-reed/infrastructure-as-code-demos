# Databricks Workspace Prerequisites Module

Creates the **AWS-side** resources a Databricks E2 workspace needs.

**This module does not create a Databricks workspace.** It declares no
`databricks_*` resources and does not configure the Databricks provider. It
produces the credentials, storage and network inputs that
`databricks_mws_credentials`, `databricks_mws_storage_configurations`,
`databricks_mws_networks` and `databricks_mws_workspaces` consume — you register
them from a configuration that has account-level Databricks credentials.

The module was previously named `databricks-workspace`, which overstated what it
does.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_s3_bucket` (+ versioning, SSE, public access block) | Workspace root storage (DBFS root) |
| `aws_iam_role` / `aws_iam_role_policy` | Cross-account role Databricks assumes to manage EC2 in your account |
| `aws_iam_role` + `aws_iam_instance_profile` | Instance profile clusters use to reach the root bucket |
| `aws_security_group` | Cluster security group (intra-cluster ingress, egress to the control plane) |

## Usage

```hcl
module "databricks_prereqs" {
  source = "../../modules/databricks-workspace-prerequisites"

  workspace_name        = "data-engineering"
  environment           = "prod"
  databricks_account_id = var.databricks_account_id # used as the sts:ExternalId
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids

  tags = {
    Project   = "DataPlatform"
    ManagedBy = "Terraform"
  }
}
```

Registering the workspace afterwards, in a configuration that has the Databricks
provider configured:

```hcl
resource "databricks_mws_credentials" "this" {
  account_id       = var.databricks_account_id
  credentials_name = "data-engineering-creds"
  role_arn         = module.databricks_prereqs.cross_account_role_arn
}

resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  storage_configuration_name = "data-engineering-storage"
  bucket_name                = module.databricks_prereqs.s3_bucket_name
}

resource "databricks_mws_networks" "this" {
  account_id         = var.databricks_account_id
  network_name       = "data-engineering-network"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.databricks_prereqs.security_group_id]
}

resource "databricks_mws_workspaces" "this" {
  account_id               = var.databricks_account_id
  aws_region               = "us-west-2"
  workspace_name           = "data-engineering"
  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
  pricing_tier             = "PREMIUM"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| workspace_name | Name prefix for every resource. Lowercase letters, digits and hyphens. | `string` | n/a | yes |
| databricks_account_id | Databricks account ID, used as the `sts:ExternalId` on the cross-account role | `string` | n/a | yes |
| vpc_id | VPC the security group is created in | `string` | n/a | yes |
| subnet_ids | Subnets for clusters. Passed through to `workspace_config`; at least 2 required. | `list(string)` | n/a | yes |
| environment | `dev`, `staging` or `prod`. Applied as a tag. | `string` | `"dev"` | no |
| s3_kms_key_arn | KMS key for root bucket encryption. Empty means AES256. | `string` | `""` | no |
| tags | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| s3_bucket_name | Root storage bucket name — feed to `databricks_mws_storage_configurations` |
| s3_bucket_arn | Root storage bucket ARN |
| cross_account_role_arn | Cross-account role ARN — feed to `databricks_mws_credentials` |
| instance_profile_arn | Instance profile ARN — register with `databricks_instance_profile` |
| security_group_id | Security group ID — feed to `databricks_mws_networks` |
| workspace_config | The above, grouped for convenience |

## Prerequisites

1. A Databricks account ID (account console → account ID)
2. An existing VPC with at least 2 private subnets — `modules/vpc` produces one
3. AWS credentials able to create S3 buckets, IAM roles and security groups

## Known limitations

- The cross-account trust policy hardcodes the Databricks AWS account
  `414351767826`, which is correct for commercial AWS regions and wrong for
  GovCloud.
- The security group allows unrestricted egress. Locking that down requires the
  PrivateLink (back-end and front-end) topology, which this module does not
  build; the exception is annotated inline in `main.tf`.
- The bucket policy Databricks requires on the root bucket is not created here.
