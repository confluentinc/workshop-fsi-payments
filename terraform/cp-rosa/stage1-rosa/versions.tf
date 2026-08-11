# ===============================
# Stage 1 — Terraform / provider versions (ROSA HCP)
# ===============================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.35.0"
    }
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = ">= 1.6.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}
