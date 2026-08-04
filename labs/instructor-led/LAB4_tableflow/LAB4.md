# LAB 4: Tableflow

**Previous:** [LAB 3: Stream Processing](../LAB3_stream_processing/LAB3.md)

## Overview

Publish the Flink data products to Databricks Unity Catalog with Tableflow (Delta). Discuss **data TTL / right-to-forget** as a governance talking point for payment ops.

<img src="./assets/lab4.png" alt="Pipeline diagram highlighting Tableflow syncing Risk Score and Completed Payments to Delta Lake and Databricks" width="800">

### What you'll accomplish

1. Create the Unity Catalog integration for Tableflow
2. Enable Tableflow on `riverflow_payments` (append) and `riverflow_payments_risk_score` (upsert)
3. Configure **data TTL** (right-to-forget) on both Tableflow topics
4. Verify Delta tables in Databricks

### Prerequisites

Completed **[LAB 3](../LAB3_stream_processing/LAB3.md)** with both MTs populated.

## Steps

### Step 1: Catalog integration

Create the Tableflow → Unity Catalog integration yourself:

1. Open **[Tableflow](https://confluent.cloud/go/tableflow)** → **External Catalog Integrations** → **+ Add integration**

   <img src="./assets/lab4_step1_1.png" alt="Tableflow environment page with External Catalog Integrations section and Add integration button" width="550">

2. Select integration type **Databricks Unity**, then fill in the integration details:

   | Field | Value |
   |-------|-------|
   | Name | A name for this integration, e.g. `tableflow-databricks-workshop` |
   | Supported format | `Delta` (fixed) |
   | Namespace | Pre-populated with your Kafka cluster ID — leave as is |

   <img src="./assets/lab4_step1_2.png" alt="Select integration type Databricks Unity and fill in name, supported format, and namespace" width="400">

3. Fill in the service principal fields using the values from the email you received:

   | Field | Value |
   |-------|-------|
   | Workspace URL | Your Databricks host |
   | Client ID | Databricks service principal client ID |
   | Client secret | Databricks service principal client secret |

   <img src="./assets/lab4_step1_3.png" alt="Create a service principal form with Workspace URL, Client ID, and Client secret fields" width="550">

4. Copy your **Unity Catalog name** (from the email you received) and paste it into the Confluent Cloud form.

   > [!TIP]
   > The service principal's Unity Catalog permissions — Data editor + EXTERNAL USE SCHEMA — are pre-granted for instructor-led, so you don't need to set those up yourself.

   <img src="./assets/lab4_step1_4.png" alt="Grant Unity Catalog permissions form with Data editor privilege preset and Unity Catalog name field" width="550">

5. Follow the wizard to launch the integration

> [!NOTE]
> The integration shows **Pending** until Tableflow is enabled on at least one topic — that happens in Step 2.

### Step 2: Enable Tableflow on real-time data products only

Enable Tableflow for:

| Topic / table | Mode |
|---------------|------|
| `riverflow_payments` | append |
| `riverflow_payments_risk_score` | upsert |

> [!WARNING]
> Do **not** Tableflow-enable raw lifecycle CDC topics in this workshop.

#### 🧩 Enable Tableflow Challenge

In the **[Topic UI](https://confluent.cloud/go/topics)**, find where to enable Tableflow on one of the two topics above, choose **Delta** as the table format, and point it at your catalog integration. Repeat for the second topic.

<img src="./assets/lab4_step2_1.png" alt="Enable Tableflow modal with Iceberg/Delta format choice and storage configuration options" width="400">

<details>
<summary>Hint</summary>

If you choose custom storage, you'll need:

- **Azure storage account name**
- **Container name**

Both are in the email you received.

</details>

> [!TIP]
> Tableflow will start syncing in a few minutes, and the tables will appear in your Databricks catalog.

### Step 3: Set Tableflow data TTL (right-to-forget)

For each of the two Tableflow-enabled topics, configure **data TTL** so old rows expire automatically (GDPR / right-to-forget talking point).

1. Open the topic → **Tableflow** → **Configuration** (or Edit settings)
2. Find **Data retention** / **Data TTL** (`data_retention_ms`)
3. Set retention to at least **30 days** (Confluent Cloud minimum today — `2592000000` ms). For the workshop, use **30 days** unless the instructor specifies otherwise.
4. Optionally note **Snapshot / version retention** (`retention_ms`) — this expires old Delta versions for time-travel, and is separate from deleting table rows.
5. Save

> [!NOTE]
> **Data TTL vs snapshot retention**
>
> - **Data TTL** (`data_retention_ms`) — deletes rows older than the retention window.
> - **Snapshot retention** (`retention_ms`) — expires old Delta snapshots/versions used for time-travel; does not by itself delete current table rows.
>
> In demo mode, Terraform sets both on `riverflow_payments` and `riverflow_payments_risk_score` (default TTL = 30 days). Here you set them in the UI so you see the control ops would use.

**Talking point:** RiverPay needs operational visibility *and* bounded retention of payment/risk history. TTL is how Tableflow encodes “we don’t keep this forever.”

### Step 4: Verify in Databricks

In SQL editor (replace catalog/schema):

```sql
SHOW TABLES IN <catalog>.<schema>;
SELECT * FROM <catalog>.<schema>.riverflow_payments LIMIT 10;
SELECT * FROM <catalog>.<schema>.riverflow_payments_risk_score LIMIT 10;
```

#### Checkpoint

- [ ] Catalog integration created and healthy
- [ ] Both real-time data products enabled for Tableflow
- [ ] Data TTL configured (≥ 30 days) on both topics
- [ ] Rows visible in Databricks
- [ ] You can explain data TTL vs snapshot retention for payments ops

## Conclusion

Governed Delta tables are ready for RiverPulse / Genie.

## What's next

**[LAB 5: RiverPulse Analytics](../LAB5_riverpulse_analytics/LAB5.md)**
