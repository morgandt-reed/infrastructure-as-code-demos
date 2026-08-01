# Complete setup: composes the modules in this repository into one stack.
#
#   modules/vpc                                -> network
#   modules/docker-host                        -> one EC2 host in a public subnet
#   modules/databricks-workspace-prerequisites -> optional, off by default
#
# Everything here is real: `terraform apply` creates billable resources
# (NAT Gateway, EIP, EC2 instance). Run `terraform destroy` when you are done.

locals {
  common_tags = merge(
    {
      Project     = var.name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Example     = "complete-setup"
    },
    var.tags
  )
}

module "vpc" {
  source = "../../modules/vpc"

  name     = var.name
  vpc_cidr = var.vpc_cidr
  az_count = var.az_count

  enable_nat_gateway      = true
  single_nat_gateway      = var.single_nat_gateway
  create_database_subnets = var.enable_databricks_prerequisites
  enable_flow_logs        = true
  enable_s3_endpoint      = true

  tags = local.common_tags
}

module "docker_host" {
  source = "../../modules/docker-host"

  instance_name = "${var.name}-docker-host"
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]

  allowed_ssh_cidrs  = var.allowed_ssh_cidrs
  allowed_http_cidrs = var.allowed_http_cidrs

  # Ports open only to the VPC, demonstrating per-port CIDR scoping
  additional_ports = [
    {
      port        = 8080
      cidr_blocks = [var.vpc_cidr]
      description = "Application port, VPC-internal only"
    }
  ]

  enable_elastic_ip        = true
  enable_cloudwatch_alarms = true
  alarm_actions            = var.alarm_actions

  tags = local.common_tags
}

module "databricks_prerequisites" {
  source = "../../modules/databricks-workspace-prerequisites"
  count  = var.enable_databricks_prerequisites ? 1 : 0

  workspace_name        = "${var.name}-databricks"
  environment           = var.environment
  databricks_account_id = var.databricks_account_id

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  tags = local.common_tags
}
