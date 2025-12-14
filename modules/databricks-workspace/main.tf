# Databricks Workspace Terraform Module
# Creates a Databricks workspace with associated AWS resources

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Bucket for Databricks Root Storage
resource "aws_s3_bucket" "databricks_root" {
  bucket = "${var.workspace_name}-${data.aws_caller_identity.current.account_id}-root"

  tags = merge(var.tags, {
    Name        = "${var.workspace_name}-root-storage"
    Purpose     = "Databricks workspace root storage"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.s3_kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.s3_kms_key_arn != "" ? var.s3_kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for Databricks Cross-Account Access
resource "aws_iam_role" "databricks_cross_account" {
  name = "${var.workspace_name}-cross-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"  # Databricks AWS account
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "databricks_cross_account" {
  name = "${var.workspace_name}-cross-account-policy"
  role = aws_iam_role.databricks_cross_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AllocateAddress",
          "ec2:AssociateIamInstanceProfile",
          "ec2:AttachInternetGateway",
          "ec2:AttachVolume",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateInternetGateway",
          "ec2:CreateKeyPair",
          "ec2:CreateNatGateway",
          "ec2:CreateRoute",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:CreateVpc",
          "ec2:CreateVpcEndpoint",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteKeyPair",
          "ec2:DeleteNatGateway",
          "ec2:DeleteRoute",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSubnet",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DeleteVpc",
          "ec2:DeleteVpcEndpoint",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeIamInstanceProfileAssociations",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstances",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribePrefixLists",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotInstanceRequests",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeVpcs",
          "ec2:DetachInternetGateway",
          "ec2:DisassociateIamInstanceProfile",
          "ec2:ModifyVpcAttribute",
          "ec2:ReleaseAddress",
          "ec2:ReplaceIamInstanceProfileAssociation",
          "ec2:RequestSpotInstances",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "iam:PutRolePolicy"
        ]
        Resource = "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = "spot.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.databricks_root.arn,
          "${aws_s3_bucket.databricks_root.arn}/*"
        ]
      }
    ]
  })
}

# IAM Instance Profile for Databricks Clusters
resource "aws_iam_role" "databricks_instance_profile" {
  name = "${var.workspace_name}-instance-profile-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "databricks_instance_profile" {
  name = "${var.workspace_name}-instance-profile-policy"
  role = aws_iam_role.databricks_instance_profile.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.databricks_root.arn,
          "${aws_s3_bucket.databricks_root.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "databricks" {
  name = "${var.workspace_name}-instance-profile"
  role = aws_iam_role.databricks_instance_profile.name

  tags = var.tags
}

# Security Group for Databricks
resource "aws_security_group" "databricks" {
  name        = "${var.workspace_name}-sg"
  description = "Security group for Databricks workspace"
  vpc_id      = var.vpc_id

  # Allow all traffic within the security group
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.workspace_name}-sg"
  })
}

# Outputs are defined in outputs.tf
