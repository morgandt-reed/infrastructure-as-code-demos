# VPC Terraform Module

Production-ready VPC module with public and private subnets, NAT gateways, and VPC flow logs.

## Features

- Multi-AZ deployment (configurable 2-6 AZs)
- Public, private, and optional database subnets
- NAT Gateway (single or per-AZ)
- VPC Flow Logs to CloudWatch
- S3 VPC Endpoint
- Network ACLs

## Architecture

```
                          ┌─────────────────────────────────────┐
                          │              VPC                     │
                          │           10.0.0.0/16                │
                          └─────────────────────────────────────┘
                                          │
              ┌───────────────────────────┼───────────────────────────┐
              │                           │                           │
    ┌─────────┴─────────┐       ┌─────────┴─────────┐       ┌─────────┴─────────┐
    │      AZ-a         │       │       AZ-b        │       │       AZ-c        │
    └───────────────────┘       └───────────────────┘       └───────────────────┘
              │                           │                           │
    ┌─────────┴─────────┐       ┌─────────┴─────────┐       ┌─────────┴─────────┐
    │  Public Subnet    │       │  Public Subnet    │       │  Public Subnet    │
    │   10.0.0.0/20     │       │   10.0.16.0/20    │       │   10.0.32.0/20    │
    │   ┌───────────┐   │       │   ┌───────────┐   │       │   ┌───────────┐   │
    │   │    NAT    │   │       │   │    NAT    │   │       │   │    NAT    │   │
    │   └───────────┘   │       │   └───────────┘   │       │   └───────────┘   │
    └───────────────────┘       └───────────────────┘       └───────────────────┘
              │                           │                           │
    ┌─────────┴─────────┐       ┌─────────┴─────────┐       ┌─────────┴─────────┐
    │  Private Subnet   │       │  Private Subnet   │       │  Private Subnet   │
    │   10.0.48.0/20    │       │   10.0.64.0/20    │       │   10.0.80.0/20    │
    └───────────────────┘       └───────────────────┘       └───────────────────┘
              │                           │                           │
    ┌─────────┴─────────┐       ┌─────────┴─────────┐       ┌─────────┴─────────┐
    │  Database Subnet  │       │  Database Subnet  │       │  Database Subnet  │
    │   10.0.96.0/20    │       │   10.0.112.0/20   │       │   10.0.128.0/20   │
    └───────────────────┘       └───────────────────┘       └───────────────────┘
```

## Usage

### Basic Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  name     = "my-app"
  vpc_cidr = "10.0.0.0/16"
  az_count = 3

  tags = {
    Environment = "prod"
    Project     = "MyApp"
  }
}
```

### Cost-Optimized (Single NAT Gateway)

```hcl
module "vpc" {
  source = "./modules/vpc"

  name               = "my-app"
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 3
  single_nat_gateway = true

  tags = {
    Environment = "dev"
  }
}
```

### Minimal (No NAT Gateway)

```hcl
module "vpc" {
  source = "./modules/vpc"

  name               = "my-app"
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = false
  enable_flow_logs   = false

  tags = {
    Environment = "test"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name prefix for resources | string | n/a | yes |
| vpc_cidr | VPC CIDR block | string | "10.0.0.0/16" | no |
| az_count | Number of AZs (2-6) | number | 3 | no |
| enable_nat_gateway | Enable NAT Gateway | bool | true | no |
| single_nat_gateway | Use single NAT | bool | false | no |
| create_database_subnets | Create DB subnets | bool | true | no |
| enable_flow_logs | Enable VPC Flow Logs | bool | true | no |
| flow_logs_retention_days | Log retention | number | 30 | no |
| enable_s3_endpoint | Create S3 endpoint | bool | true | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| vpc_cidr | CIDR block of the VPC |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| database_subnet_ids | List of database subnet IDs |
| nat_gateway_ips | NAT Gateway public IPs |
| availability_zones | AZs used |

## Cost Considerations

| Configuration | Monthly Cost (approx) |
|---------------|----------------------|
| 3 NAT Gateways | ~$100/month |
| 1 NAT Gateway | ~$33/month |
| No NAT Gateway | $0 |

## Best Practices

1. Use 3 AZs for production workloads
2. Use single NAT gateway only for dev/test
3. Enable flow logs for security compliance
4. Use S3 endpoint to reduce data transfer costs
