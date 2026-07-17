# Manifests for cp-rosa Stage 2

| File | Purpose |
|------|---------|
| [`confluent-platform.yaml`](confluent-platform.yaml) | KRaft + Kafka + Connect + Schema Registry + ksqlDB + REST Proxy + Control Center (CFK CRs) |
| [`riverpay-producer.yaml`](riverpay-producer.yaml) | KafkaTopic CRs + RiverPay-lite JSON producer Deployment |
| [`controlcenter-route-patch.yaml`](controlcenter-route-patch.yaml) | Optional Control Center OpenShift route (replace `APPS_DOMAIN`) |

Applied by [`../stage2-cfk/`](../stage2-cfk/) via `kubectl apply` after CFK Helm install.
