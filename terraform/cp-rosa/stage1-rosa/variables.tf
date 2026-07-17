# ===============================
# Stage 1 — Variables (ROSA HCP)
# ===============================

variable "cluster_name" {
  type        = string
  description = "ROSA HCP cluster name (max 54 chars). Immutable after create."

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 54
    error_message = "cluster_name must be 1–54 characters."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region for the VPC and ROSA cluster."
  default     = "us-east-1"
}

variable "openshift_version" {
  type        = string
  description = "OpenShift version for ROSA HCP (major.minor.patch)."
  default     = "4.16.3"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.openshift_version))
    error_message = "openshift_version must look like 4.16.3."
  }
}

variable "availability_zones_count" {
  type        = number
  description = "Number of AZs for the VPC / worker placement (2 is enough for a demo HCP)."
  default     = 2

  validation {
    condition     = var.availability_zones_count >= 2 && var.availability_zones_count <= 3
    error_message = "availability_zones_count must be 2 or 3."
  }
}

variable "private" {
  type        = bool
  description = "If true, API and app routes are private-only (not recommended for the default demo)."
  default     = false
}

variable "owner_email" {
  type        = string
  description = "Tag / contact email for resources created by this demo."
  default     = ""
}
