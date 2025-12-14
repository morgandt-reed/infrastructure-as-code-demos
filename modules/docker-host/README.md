# Docker Host Module

Terraform module to create an EC2 instance with Docker and Docker Compose pre-installed.

## Features

- Ubuntu 22.04 LTS base image
- Docker and Docker Compose automatically installed
- Configurable security groups
- Optional Elastic IP
- CloudWatch monitoring and alarms
- Encrypted root volume
- IMDSv2 enforced for security

## Usage

```hcl
module "docker_host" {
  source = "./modules/docker-host"

  instance_name    = "my-docker-host"
  instance_type    = "t3.medium"
  key_name         = "my-key-pair"
  vpc_id           = "vpc-xxx"
  subnet_id        = "subnet-xxx"

  allowed_ssh_cidrs  = ["your.ip.address/32"]
  additional_ports   = [8080, 3000]
  enable_elastic_ip  = true

  tags = {
    Environment = "production"
    Project     = "microservices"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| instance_name | Name of the Docker host | `string` | n/a | yes |
| instance_type | EC2 instance type | `string` | `"t3.medium"` | no |
| key_name | SSH key pair name | `string` | n/a | yes |
| vpc_id | VPC ID | `string` | `null` | no |
| subnet_id | Subnet ID | `string` | `null` | no |
| allowed_ssh_cidrs | CIDRs allowed SSH access | `list(string)` | `[]` | no |
| additional_ports | Additional ports to open | `list(number)` | `[]` | no |
| enable_elastic_ip | Attach Elastic IP | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID |
| instance_public_ip | Public IP address |
| elastic_ip | Elastic IP (if enabled) |
| ssh_command | SSH command to connect |

## Examples

See [examples/docker-host/](../../examples/docker-host/) for complete example.
