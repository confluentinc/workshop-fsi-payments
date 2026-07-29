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
    p.`payment_type`,
    p.`initiated_at`,
    lookup_operational_risk(p.`amount`, c.`segment`, c.`account_tier`) AS `risk_payload`
  FROM `riverflow.payments.initiation` p
    JOIN `riverflow.riverpay.customer_profiles` FOR SYSTEM_TIME AS OF p.`$rowtime` AS c
      ON c.`customer_id` = p.`customer_id`
) AS enriched;
