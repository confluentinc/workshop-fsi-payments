# AWS Support Roadmap

Status snapshot of the AWS path (`wsa-spec-aws.yaml`, `terraform/aws*`) relative to
the working Azure path (`wsa-spec-azure.yaml`, `terraform/azure*`).

## TODO

- [ ] **AWS Databricks workspace auto-provisioning.** Azure defaults
  `databricks_host = ""` and auto-provisions a workspace + Unity Catalog
  metastore (`modules/azure-databricks-workspace`,
  `azure-databricks-metastore`, `azure-databricks-access-connector`). AWS
  (`terraform/aws/variables.tf`) has no default and requires an existing
  `https://*.cloud.databricks.com` workspace URL — no `aws-databricks-workspace`
  equivalent exists. Note: Databricks is also structurally *unconditional* in
  `terraform/aws/main.tf` — `module.databricks`, `databricks_catalog.main`, and
  `module.catalog_integration` are always created (no `count`/enable flag), so
  every AWS apply currently requires a working Databricks workspace regardless
  of `enable_tableflow_topics`. Decide: build parity auto-provisioning, or
  formally document AWS as BYO-workspace-only and gate Databricks resources
  behind a variable so a Databricks-less apply is a supported first-class mode
  (not just a throwaway copy).
- [ ] **De-duplicate `terraform/aws-demo/` vs `terraform/aws/`.** The per-cloud
  modules (`aws-iam`, `aws-keypair`, `aws-networking`, `aws-postgres`,
  `aws-s3`) are structural copies between the two roots, so AWS fixes need to
  land twice. `terraform/aws-demo/` is also missing a `README.md` that
  `terraform/aws/` has.
- [ ] **(Optional/low)** Add a short AWS-specific operator note (EC2 Risk API /
  Docker specifics) parallel to `docs/operator-azure-elevate.md`, if operators
  want it split out of the shared `docs/operator-instructor-led.md`.

## Done

- [x] `scripts/validate-run.sh` supports `--cloud aws|azure` (terraform dir,
  region default, Databricks SP env-var prefix all cloud-aware now).
