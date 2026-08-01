# Docker Host Module

Creates an EC2 instance with Docker Engine and a `docker-compose` shim installed
by user-data.

## Features

- Ubuntu 22.04 LTS, latest Canonical AMI, with `ignore_changes = [ami]` so a new
  AMI release does not replace a running instance on the next apply
- Docker Engine via `get.docker.com` (which also installs the Compose v2 plugin),
  plus a pinned standalone `docker-compose` binary for tooling that still calls
  the v1 command name
- Instance profile carrying `CloudWatchAgentServerPolicy` and, by default,
  `AmazonSSMManagedInstanceCore` — so Session Manager replaces SSH and
  `allowed_ssh_cidrs` can stay empty
- Per-port CIDR scoping on `additional_ports`; the module never defaults an extra
  port to `0.0.0.0/0`
- Encrypted gp3 root volume, IMDSv2 required
- Optional Elastic IP, and two CloudWatch alarms that accept `alarm_actions`

## Usage

```hcl
module "docker_host" {
  source = "../../modules/docker-host"

  instance_name = "my-docker-host"
  instance_type = "t3.medium"

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]

  # Optional. With enable_ssm (the default) you can leave both of these out and
  # reach the host with `aws ssm start-session`.
  key_name          = "my-key-pair"
  allowed_ssh_cidrs = ["203.0.113.10/32"]

  additional_ports = [
    {
      port        = 8080
      cidr_blocks = ["10.0.0.0/16"]
      description = "Application port, VPC-internal only"
    },
    {
      port        = 3000
      cidr_blocks = ["10.0.0.0/16"]
    }
  ]

  enable_elastic_ip = true
  alarm_actions     = [aws_sns_topic.ops.arn]

  tags = {
    Environment = "production"
    Project     = "microservices"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| instance_name | Name prefix for every resource | `string` | n/a | yes |
| instance_type | EC2 instance type (t2/t3 families only) | `string` | `"t3.medium"` | no |
| key_name | SSH key pair name. Omit to rely on Session Manager. | `string` | n/a | yes |
| vpc_id | VPC the security group is created in | `string` | `null` | no |
| subnet_id | Subnet the instance is placed in | `string` | `null` | no |
| allowed_ssh_cidrs | CIDRs allowed SSH. **Empty creates no SSH rule at all.** | `list(string)` | `[]` | no |
| allowed_http_cidrs | CIDRs allowed HTTP/HTTPS | `list(string)` | `["0.0.0.0/0"]` | no |
| additional_ports | Extra TCP ports, each with its own CIDR list | `list(object({port, cidr_blocks, description}))` | `[]` | no |
| egress_cidr_blocks | Destinations the host may reach | `list(string)` | `["0.0.0.0/0"]` | no |
| enable_ssm | Attach `AmazonSSMManagedInstanceCore` | `bool` | `true` | no |
| install_cloudwatch_agent | Install the CloudWatch agent in user-data | `bool` | `true` | no |
| docker_compose_version | Standalone `docker-compose` version tag | `string` | `"v2.32.4"` | no |
| root_volume_type | Root volume type | `string` | `"gp3"` | no |
| root_volume_size | Root volume size in GB | `number` | `30` | no |
| enable_elastic_ip | Attach an Elastic IP | `bool` | `false` | no |
| enable_detailed_monitoring | Enable 1-minute EC2 metrics | `bool` | `false` | no |
| enable_cloudwatch_alarms | Create the CPU and status-check alarms | `bool` | `true` | no |
| alarm_actions | SNS topics notified by the alarms. **Empty means they notify nobody.** | `list(string)` | `[]` | no |
| tags | Tags applied to all resources | `map(string)` | `{}` | no |

`additional_ports` used to be a `list(number)` whose rules were all opened to
`0.0.0.0/0`. Callers upgrading need to rewrite it as a list of objects.

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID — pass to `aws ssm start-session --target` |
| instance_public_ip | Public IP address |
| instance_private_ip | Private IP address |
| elastic_ip | Elastic IP, or `null` when `enable_elastic_ip` is false |
| security_group_id | Security group ID |
| ssh_command | Ready-made SSH command |

## Notes

- User-data lives in [`user-data.sh`](user-data.sh) and is rendered with
  `templatefile()`. It runs under `set -euo pipefail` and logs to
  `/var/log/user-data.log`, so a failed download aborts the boot script instead
  of leaving a half-configured host.
- The security group allows unrestricted egress by default, because `apt-get`
  and image pulls need it. That exception is annotated inline in `main.tf` with
  `#trivy:ignore:AVD-AWS-0104`; narrow it with `egress_cidr_blocks`.

## Example

See [`examples/complete-setup/`](../../examples/complete-setup/), which uses this
module together with `modules/vpc`.
