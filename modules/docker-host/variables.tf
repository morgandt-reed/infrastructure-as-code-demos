variable "instance_name" {
  description = "Name of the Docker host instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"

  validation {
    condition     = can(regex("^t3\\.", var.instance_type)) || can(regex("^t2\\.", var.instance_type))
    error_message = "Instance type must be from t2 or t3 family for cost optimization."
  }
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the instance will be created"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be placed"
  type        = string
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the instance. Empty (the default) creates no SSH rule at all — use Session Manager."
  type        = list(string)
  default     = []
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed HTTP/HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_ports" {
  description = <<-EOT
    Additional TCP ports to open. Each entry carries its own CIDR list; the
    module never falls back to 0.0.0.0/0 for an extra port.
  EOT
  type = list(object({
    port        = number
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []

  validation {
    condition     = alltrue([for p in var.additional_ports : p.port > 0 && p.port <= 65535])
    error_message = "Each additional port must be between 1 and 65535."
  }

  validation {
    condition     = alltrue([for p in var.additional_ports : length(p.cidr_blocks) > 0])
    error_message = "Each additional port must list at least one CIDR block."
  }

  validation {
    condition     = length(distinct([for p in var.additional_ports : p.port])) == length(var.additional_ports)
    error_message = "Additional ports must be unique."
  }
}

variable "egress_cidr_blocks" {
  description = "CIDR blocks the instance may send traffic to. Defaults to the whole internet because apt and image pulls need it."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.egress_cidr_blocks) > 0
    error_message = "At least one egress CIDR block is required."
  }
}

variable "enable_ssm" {
  description = "Attach AmazonSSMManagedInstanceCore so the host is reachable via Session Manager without opening SSH"
  type        = bool
  default     = true
}

variable "install_cloudwatch_agent" {
  description = "Install the CloudWatch agent in user-data. The instance profile always carries the policy it needs."
  type        = bool
  default     = true
}

variable "docker_compose_version" {
  description = "Version tag of the standalone docker-compose binary to install"
  type        = string
  default     = "v2.32.4"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.docker_compose_version))
    error_message = "Docker Compose version must be a vMAJOR.MINOR.PATCH tag, e.g. v2.32.4."
  }
}

variable "alarm_actions" {
  description = "SNS topic ARNs notified when the CloudWatch alarms change state. Empty means the alarms fire silently."
  type        = list(string)
  default     = []
}

variable "root_volume_type" {
  description = "Type of root volume"
  type        = string
  default     = "gp3"
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 30
}

variable "enable_elastic_ip" {
  description = "Whether to attach an Elastic IP"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
