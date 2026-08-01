# Complete Setup Example

Composes every module in this repository into one stack:

```
modules/vpc                                 →  VPC, subnets, NAT, flow logs, S3 endpoint
modules/docker-host                         →  EC2 Docker host in a public subnet
modules/databricks-workspace-prerequisites  →  optional, disabled by default
```

## What gets created

| Module | Always | Notes |
|---|---|---|
| vpc | yes | Public + private subnets across `az_count` AZs, one NAT Gateway (or one per AZ), VPC Flow Logs to CloudWatch, S3 gateway endpoint. Database subnets only when the Databricks prerequisites are enabled. |
| docker-host | yes | One `t3.small` with Docker and Compose installed via user-data, an Elastic IP, an instance profile carrying `CloudWatchAgentServerPolicy` and `AmazonSSMManagedInstanceCore`, and two CloudWatch alarms. |
| databricks-workspace-prerequisites | no | Set `enable_databricks_prerequisites = true` and supply `databricks_account_id`. Creates IAM roles and an S3 bucket; it does **not** create a Databricks workspace. |

## Usage

```bash
cd examples/complete-setup

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars

terraform init
terraform plan
terraform apply
```

Connect to the host without opening SSH:

```bash
aws ssm start-session --target "$(terraform output -raw docker_host_instance_id)"
```

Tear it down:

```bash
terraform destroy
```

## Cost

This applies real, billable resources. At us-west-2 on-demand pricing the
recurring cost is dominated by:

- **NAT Gateway** — roughly $32/month per gateway plus data processing.
  `single_nat_gateway = true` (the default here) keeps this to one.
- **EC2 t3.small** — roughly $15/month running continuously.
- **Elastic IP** — charged while the instance is stopped, free while attached to
  a running instance.
- **VPC Flow Logs** — CloudWatch Logs ingestion, proportional to traffic.

Run `terraform destroy` when you are finished. Use `infracost breakdown --path .`
for a real estimate against current pricing rather than trusting these figures.

## Notes

- State is local by default so the example runs without pre-creating a bucket.
  An S3 backend is commented out in `versions.tf`.
- The Docker host sits in a **public** subnet with an Elastic IP so it is
  reachable. Move it to `module.vpc.private_subnet_ids[0]` and drop
  `enable_elastic_ip` for a private host reachable only through Session Manager.
- `additional_ports` opens 8080 to the VPC CIDR only, demonstrating the
  per-port CIDR scoping the module requires.
