# RiverPay Risk Scoring API

Shared workshop service for Flink UDF external connectivity. Returns operational
exception probability (`risk_score`) and a human-readable `risk_reason` — **not** fraud.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Liveness |
| GET | `/v1/risk?amount=&segment=&account_tier=` | Lookup (UDF-friendly) |
| POST | `/v1/risk` | Lookup (JSON body) |

## Local run

```bash
cd services/risk-api
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
PORT=8089 python app.py
# curl "http://127.0.0.1:8089/v1/risk?amount=12000&segment=retail&account_tier=standard"
```

## Docker

```bash
docker build -t riverpay-risk-api .
docker run --rm -p 8089:8089 riverpay-risk-api
```

## Elevate / instructor-led

Operators deploy **one** public HTTPS URL via Azure Container Apps
(`terraform/azure-shared`, `enable_risk_api=true`). Per-attendee Flink
environments register a `CREATE CONNECTION` pointing at that URL and a Java UDF
(`udf/riverpay-risk`) that calls it.

Smoke after apply:

```bash
cd terraform/azure-shared
../../services/risk-api/smoke.sh "$(terraform output -raw risk_api_endpoint)" "$(terraform output -raw risk_api_key)"
```

Or from repo root:

```bash
./services/risk-api/smoke.sh "$RISK_API_URL" "$RISK_API_KEY"
```

### aws-demo

`terraform/aws-demo` can still run the API on the Postgres EC2 host (`:8089`)
for local demo convenience when `enable_risk_api=true`. Demo defaults
`enable_risk_udf=true` and expects the JAR at `udf/riverpay-risk/dist/`.

To score via UDF in demo mode:

1. Build the JAR (`udf/riverpay-risk/README.md`) — artifact also in `dist/`
2. Keep `enable_risk_udf = true` (default) or set explicitly
3. Apply

See `flink/risk_udf.sql` and `udf/riverpay-risk/README.md`.

> Flink UDF private networking is AWS-only; Azure Elevate uses the **public
> HTTPS** Container Apps endpoint.
