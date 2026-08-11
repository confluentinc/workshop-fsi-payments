# Azure instructor-led: multi-cluster lifecycle ShadowTraffic

Thin root over [`../modules/lifecycle-shadowtraffic`](../modules/lifecycle-shadowtraffic/).
Does **not** create Kafka — only renders N Kafka connections × 4 generators and
deploys `shadowtraffic-lifecycle` on the shared Postgres VM.

```bash
# After wsa build:
./scripts/wsa-deploy-lifecycle-st.sh apply --run-id "$WSA_RUN_ID" --cloud azure --auto-approve
```

See [`docs/operator-instructor-led.md`](../../docs/operator-instructor-led.md).
