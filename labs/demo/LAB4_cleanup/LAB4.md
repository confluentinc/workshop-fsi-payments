# LAB 4: Resource Cleanup

## Overview

Destroy all demo resources. Demo mode provisioned Tableflow topics and Flink statements via Terraform, so cleanup is mostly a single destroy.

### Prerequisites

Completed LAB 2 (resources exist).

## Steps

### Step 1: Stop ShadowTraffic (optional soft stop)

If you want to halt generation before destroy, run SSH from the **host** (not inside the Terraform container). The key file is written under `terraform/aws-demo/` and mounted into the container — use the host path:

```sh
cd terraform/aws-demo
HOST=$(docker-compose run --rm terraform -c "terraform output -raw postgres_public_dns")
# Prefer the local key file (host path). Do not use terraform output ssh_key_path —
# that path is container-internal (/workspace/...) and will fail with host ssh.
SSH_KEY=$(ls -1 sshkey-*.pem | head -n 1)
chmod 400 "$SSH_KEY"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@"$HOST" \
  "sudo docker rm -f shadowtraffic-riverpay"
```

### Step 2: Destroy Infrastructure

```sh
cd terraform/aws-demo
docker-compose run --rm terraform -c "terraform destroy -auto-approve"
```

> [!NOTE]
> **Expected Result**
>
> AWS, Confluent, and Databricks resources created by this workshop are removed. Destroy may take 10–20 minutes.

### Step 3: Verify cloud cleanup

1. Confluent Cloud: workshop environment/cluster gone (or empty if you reused an env ID)
2. AWS: EC2 / S3 / IAM workshop resources gone
3. Databricks: workshop catalog removed (`force_destroy` was enabled)

### Step 4: Local leftovers (optional)

From `terraform/aws-demo`, remove local artifacts that are gitignored but may still hold secrets or confuse a re-apply:

```sh
cd terraform/aws-demo
# SSH keys written by Terraform
rm -f sshkey-*.pem
# Local AWS config if you ran `aws configure` inside the container
rm -f aws-config/credentials aws-config/config
# Generated ShadowTraffic connection files (if present)
rm -rf generated/connections/*
# Terraform state (only if you are done and do not need to re-destroy)
# rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
# rm -rf .terraform
```

> [!WARNING]
> Do **not** delete `terraform.tfstate` until destroy has succeeded. Keep `terraform.tfvars` out of git; delete it locally when you no longer need the credentials file.

#### Checkpoint

- [ ] `terraform destroy` completed successfully
- [ ] No unexpected leftover billable workshop resources
- [ ] Local SSH keys / aws-config cleaned up (optional)

## Conclusion

Demo environment cleaned up. Thanks for building with RiverPay / RiverFlow / RiverPulse.

## What's Next

Read the [recap](../../shared/recap.md) for talking points and Phase 2 ideas.

## Troubleshooting

If destroy fails with **409** on the provider integration (`cspi-…` / “integration is being used”), follow [Provider integration 409 on destroy](../../shared/troubleshooting.md#provider-integration-409-on-destroy) (`terraform state rm` of the integration, then re-destroy). Same pattern as the Tableflow+Databricks workshop.
