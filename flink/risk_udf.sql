-- Reference: register shared risk CONNECTION + UDF, then score via external lookup.
-- Demo mode Terraform can automate this when enable_risk_udf=true and the JAR exists.
-- Instructor-led: CONNECTION + FUNCTION are pre-created; attendees write the MT SQL.

-- CREATE CONNECTION IF NOT EXISTS riverpay_risk_api
-- WITH (
--   'type' = 'rest',
--   'endpoint' = 'https://risk.example.workshop',
--   'token' = '<workshop-api-key>'
-- );

-- CREATE FUNCTION IF NOT EXISTS lookup_operational_risk
--   AS 'io.confluent.riverpay.udf.LookupOperationalRisk'
--   USING JAR 'confluent-artifact://<artifact-id>'
--   USING CONNECTIONS (`riverpay_risk_api`);

-- CREATE MATERIALIZED TABLE riverflow_payments_risk_score AS
SELECT
  enriched.`payment_id`,
  enriched.`customer_id`,
  enriched.`segment`,
  enriched.`account_tier`,
  enriched.`amount`,
  enriched.`currency`,
  enriched.`rate_to_usd`,
  enriched.`amount_usd`,
  enriched.`payment_type`,
  enriched.`initiated_at`,
  CAST(SPLIT_INDEX(enriched.`risk_payload`, '|', 0) AS DOUBLE) AS `risk_score`,
  SPLIT_INDEX(enriched.`risk_payload`, '|', 1) AS `risk_reason`,
  CURRENT_TIMESTAMP AS `enrichment_timestamp`
FROM (
  SELECT
    p.`payment_id`,
    p.`customer_id`,
    c.`segment`,
    c.`account_tier`,
    p.`amount`,
    p.`currency`,
    fx.`rate_to_usd`,
    ROUND(p.`amount` * fx.`rate_to_usd`, 2) AS `amount_usd`,
    p.`payment_type`,
    p.`initiated_at`,
    -- Score the USD-normalized amount. The API's thresholds (2500 / 5000 /
    -- 10000) are absolute, so passing the raw amount would score a ¥6,000
    -- payment (~$40) as if it were $6,000.
    lookup_operational_risk(
      ROUND(p.`amount` * fx.`rate_to_usd`, 2),
      c.`segment`,
      c.`account_tier`
    ) AS `risk_payload`
  FROM `riverflow.payments.initiation` p
    JOIN `riverflow.riverpay.customer_profiles` FOR SYSTEM_TIME AS OF p.`$rowtime` AS c
      ON c.`customer_id` = p.`customer_id`
    JOIN `riverflow.riverpay.fx_rates` FOR SYSTEM_TIME AS OF p.`$rowtime` AS fx
      ON fx.`currency_code` = p.`currency`
) AS enriched;
