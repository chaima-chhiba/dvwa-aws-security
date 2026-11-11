terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Learner Lab region (us-east-1 or us-west-2)"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "dvwa-cloud-security"
      Stage   = "layer2"
    }
  }
}

# Learner Lab permits certificate upload but denies iam:TagServerCertificate.
# Keep the normal provider's default tags on all other resources.
provider "aws" {
  alias  = "certificate"
  region = var.region
}
