-- Reference Flink SQL for RiverPay data products (also embedded in Terraform).

-- =============================================================================
-- 1) Completed payments — 4-way inner join + FX temporal join → riverflow_payments
-- Only emits when initiation, authorization, balance_update, and status all match,
-- and an FX rate exists for the payment currency at initiation time.
-- Progressive / stall-aware state is Phase 2 backlog.
-- See also: flink/fx_conversion.sql
-- =============================================================================

-- Watermarks / changelog (demo Terraform applies equivalents):
-- Lifecycle Kafka sources: append + event-time watermark on the stage timestamp
--   (initiated_at / authorized_at / updated_at / completed_at), OR use $rowtime
--   if you prefer broker ingestion time — keep the choice consistent across joins.
-- FX rates CDC: upsert + $rowtime watermark (see fx_conversion.sql).
-- Profiles CDC: upsert + $rowtime for the risk temporal join (see risk_udf.sql).
-- Prefer $rowtime for CDC upsert sources; lifecycle append topics commonly use
-- the business timestamp column with a small skew interval.

-- CREATE MATERIALIZED TABLE riverflow_payments AS
SELECT
  i.`payment_id`,
  i.`customer_id`,
  i.`source_account`,
  i.`destination_account`,
  i.`amount`,
  i.`currency`,
  fx.`rate_to_usd`,
  ROUND(i.`amount` * fx.`rate_to_usd`, 2) AS `amount_usd`,
  i.`payment_type`,
  i.`channel`,
  i.`initiated_at`,
  a.`authorization_code`,
  a.`authorized_at`,
  b.`source_balance_after`,
  b.`destination_balance_after`,
  b.`updated_at` AS `balance_updated_at`,
  s.`status`,
  s.`status_reason`,
  s.`completed_at`
FROM `riverflow.payments.initiation` i
  INNER JOIN `riverflow.payments.authorization` a
    ON i.`payment_id` = a.`payment_id`
  INNER JOIN `riverflow.payments.balance_update` b
    ON i.`payment_id` = b.`payment_id`
  INNER JOIN `riverflow.payments.status` s
    ON i.`payment_id` = s.`payment_id`
  JOIN `riverflow.riverpay.fx_rates` FOR SYSTEM_TIME AS OF i.`$rowtime` AS fx
    ON fx.`currency_code` = i.`currency`;

-- =============================================================================
-- 2) Operational risk — temporal join → riverflow_payments_risk_score (upsert)
-- Inputs: initiation + customer_profiles. CASE heuristics are interim;
-- Elevate replaces scoring with an external risk UDF (shared workshop API).
-- risk_score ≠ fraud.
-- =============================================================================

-- ALTER TABLE `riverflow.riverpay.customer_profiles`
--   SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact');
-- ALTER TABLE `riverflow.riverpay.customer_profiles`
--   MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;

-- CREATE MATERIALIZED TABLE riverflow_payments_risk_score AS
SELECT
  p.`payment_id`,
  p.`customer_id`,
  c.`segment`,
  c.`account_tier`,
  p.`amount`,
  p.`currency`,
  p.`payment_type`,
  p.`initiated_at`,
  CASE
    WHEN p.`amount` >= 10000 THEN 0.85
    WHEN p.`amount` >= 5000 AND c.`account_tier` = 'standard' THEN 0.72
    WHEN c.`segment` = 'new_partner' THEN 0.65
    WHEN p.`amount` >= 2500 THEN 0.48
    WHEN c.`account_tier` = 'premium' THEN 0.12
    ELSE 0.28
  END AS `risk_score`,
  CASE
    WHEN p.`amount` >= 10000 THEN 'amount_significantly_above_customer_baseline'
    WHEN p.`amount` >= 5000 AND c.`account_tier` = 'standard' THEN 'high_value_standard_tier'
    WHEN c.`segment` = 'new_partner' THEN 'new_partner_bank_customer'
    WHEN p.`amount` >= 2500 THEN 'elevated_amount_review_recommended'
    WHEN c.`account_tier` = 'premium' THEN 'low_value_established_recipient'
    ELSE 'routine_instant_credit_transfer'
  END AS `risk_reason`,
  CURRENT_TIMESTAMP AS `enrichment_timestamp`
FROM `riverflow.payments.initiation` p
  JOIN `riverflow.riverpay.customer_profiles` FOR SYSTEM_TIME AS OF p.`$rowtime` AS c
    ON c.`customer_id` = p.`customer_id`;
