# ===============================
# Stage 1 — Providers
# ===============================
# RHCS_TOKEN (OCM offline token) can be set in the environment instead of
# passing token in the provider block. Never commit tokens.

provider "aws" {
  region = var.aws_region
}

provider "rhcs" {
  # token = var.rhcs_token  # optional; prefer RHCS_TOKEN env var
}
