# AWS instructor-led: multi-cluster lifecycle ShadowTraffic

Thin root over [`../modules/lifecycle-shadowtraffic`](../modules/lifecycle-shadowtraffic/).
Does **not** create Kafka — only renders N Kafka connections × 4 generators and
deploys `shadowtraffic-lifecycle` on the shared Postgres EC2.

```bash
# After wsa build (this is the lifecycle-st phase, enabled: false by default):
op run --env-file=.env.tpl -- wsa build -w /path/to/workshop-fsi-payments/wsa-spec-aws.yaml \
  --run-id "$WSA_RUN_ID" --phases lifecycle-st
```

See [`docs/operator-instructor-led.md`](../../docs/operator-instructor-led.md).
