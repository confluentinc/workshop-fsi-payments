# Stage 1: ROSA HCP

Provisions a public ROSA Hosted Control Plane cluster plus VPC, STS account/operator roles, managed OIDC, cluster-admin, and an HTPasswd IDP user (`riverpay-demo`).

## Prerequisites

1. [Enable ROSA](https://console.redhat.com/openshift/create/rosa/getstarted) on your AWS account (service-linked roles / getting started).
2. Create an [OCM offline token](https://console.redhat.com/openshift/token/rosa) and export it:

   ```sh
   export RHCS_TOKEN="<token>"
   ```

3. AWS credentials configured for the target account/region (`aws sts get-caller-identity`).
4. Terraform `>= 1.6` on the host (preferred over Docker for this long apply).

## Apply

```sh
cd terraform/cp-rosa/stage1-rosa
cp sample-tfvars terraform.tfvars
# edit terraform.tfvars

terraform init
terraform apply
```

**Expected duration:** often 30–45+ minutes.

## After apply

```sh
terraform output next_steps
terraform output -raw cluster_api_url
terraform output -raw cluster_admin_password
```

Log in with `oc`, then continue to [`../stage2-cfk/`](../stage2-cfk/).

## Destroy

Destroy Stage 2 first, then:

```sh
terraform destroy
```
