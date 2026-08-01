# Terraform and provider constraints live in versions.tf

# Data sources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
#
# Unrestricted egress is intentional and configurable: this host runs
# `apt-get update` and pulls images from arbitrary registries during boot. Narrow
# it by setting egress_cidr_blocks, or replace it with VPC endpoints plus a
# registry allowlist if your environment can support that.
#trivy:ignore:AVD-AWS-0104
resource "aws_security_group" "docker_host" {
  name        = "${var.instance_name}-sg"
  description = "Security group for Docker host"
  vpc_id      = var.vpc_id

  # SSH access. Rendered only when allowed_ssh_cidrs is non-empty; an ingress
  # block with no sources is rejected by the EC2 API.
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  # HTTP
  dynamic "ingress" {
    for_each = length(var.allowed_http_cidrs) > 0 ? [1] : []
    content {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.allowed_http_cidrs
    }
  }

  # HTTPS
  dynamic "ingress" {
    for_each = length(var.allowed_http_cidrs) > 0 ? [1] : []
    content {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.allowed_http_cidrs
    }
  }

  # Custom ports. Each entry carries its own CIDR list — the module never
  # defaults an extra port to 0.0.0.0/0.
  dynamic "ingress" {
    for_each = { for p in var.additional_ports : tostring(p.port) => p }
    content {
      description = coalesce(ingress.value.description, "Custom port ${ingress.value.port}")
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # Outbound internet access
  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.egress_cidr_blocks
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.instance_name}-sg"
    }
  )
}

# IAM role for the instance. Required for the CloudWatch agent to publish
# metrics and logs — without it the agent installs and then silently fails.
resource "aws_iam_role" "docker_host" {
  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.docker_host.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Lets Session Manager replace SSH entirely, which is why allowed_ssh_cidrs
# defaults to an empty list.
resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.docker_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "docker_host" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.docker_host.name

  tags = var.tags
}

# EC2 Instance
resource "aws_instance" "docker_host" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.docker_host.id]
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.docker_host.name

  user_data = templatefile("${path.module}/user-data.sh", {
    install_cloudwatch_agent = var.install_cloudwatch_agent
    compose_version          = var.docker_compose_version
  })

  # Root volume configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  # Monitoring
  monitoring = var.enable_detailed_monitoring

  # Instance metadata service v2
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = var.instance_name
    }
  )

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP (optional)
resource "aws_eip" "docker_host" {
  count    = var.enable_elastic_ip ? 1 : 0
  instance = aws_instance.docker_host.id
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.instance_name}-eip"
    }
  )
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.instance_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"

  # An alarm with no actions changes state and notifies nobody. Pass SNS topic
  # ARNs in alarm_actions to make it mean something.
  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.docker_host.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.instance_name}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors instance status checks"

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.docker_host.id
  }

  tags = var.tags
}
