# LAB 6: Wrap-up & Cleanup

**Previous:** [LAB 5: RiverPulse Analytics](../LAB5_riverpulse_analytics/LAB5.md)

## Overview

Recap what you built, then destroy cloud resources so free-trial spend stops.

## Recap

You:

1. Signed up for BYO accounts and deployed RiverPay infra
2. Built Flink data products (completed payments + FX + operational risk UDF)
3. Enabled Tableflow with a TTL / right-to-forget talking point
4. Answered the three RiverPulse questions in Genie

Compare modes anytime: [`labs/self-service/README.md`](../README.md).

## Cleanup

Disable Tableflow on `riverflow_payments` and `riverflow_payments_risk_score` in the Confluent UI (avoids provider-integration **409** on destroy), then:

**AWS:**

```sh
cd terraform/aws
docker-compose run --rm terraform -c "terraform destroy -auto-approve"
```

**Azure:**

```sh
cd terraform/azure
terraform destroy
```

If destroy fails with Tableflow integration **409**, see [`labs/shared/troubleshooting.md`](../../shared/troubleshooting.md).

## Feedback

Optional: share feedback with your facilitator / workshop owner.

## Done

Self-service path complete. For a guided instructor-led session, see [`labs/instructor-led/`](../../instructor-led/README.md). For a one-click demo, see [`labs/demo/`](../../demo/README.md).
