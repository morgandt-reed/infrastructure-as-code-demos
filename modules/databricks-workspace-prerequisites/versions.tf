terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# No databricks provider here on purpose. This module creates AWS resources
# only; the databricks_mws_* resources that register them as a workspace live
# in whatever configuration calls this module.
