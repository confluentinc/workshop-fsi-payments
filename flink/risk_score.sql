-- Reference Flink SQL for RiverPay data products (also embedded in Terraform).

-- =============================================================================
-- 1) Completed payments — 4-way inner join → riverflow_payments (append)
-- Only emits when initiation, authorization, balance_update, and status all match.
-- Progressive / stall-aware state is Phase 2 backlog.
-- =============================================================================

-- ALTER TABLE `riverflow.payments.initiation` SET ('changelog.mode' = 'append');
-- ALTER TABLE `riverflow.payments.initiation`
--   MODIFY WATERMARK FOR `initiated_at` AS `initiated_at` - INTERVAL '5' SECOND;
-- (same append + watermark pattern for authorization, balance_update, status)

-- CREATE MATERIALIZED TABLE riverflow_payments AS
SELECT
  i.`payment_id`,
  i.`customer_id`,
  i.`source_account`,
  i.`destination_account`,
  i.`amount`,
  i.`currency`,
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
    ON i.`payment_id` = s.`payment_id`;

-- =============================================================================
-- 2) Operational risk — temporal join → riverflow_payments_risk_score (upsert)
-- Inputs: initiation + customer_profiles only. risk_score ≠ fraud.
-- =============================================================================

-- ALTER TABLE `riverflow.riverpay.customer_profiles`
--   SET ('changelog.mode' = 'upsert', 'kafka.cleanup-policy' = 'compact');
-- ALTER TABLE `riverflow.riverpay.customer_profiles`
--   MODIFY WATERMARK FOR `updated_at` AS `updated_at` - INTERVAL '5' SECOND;

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
  JOIN `riverflow.riverpay.customer_profiles` FOR SYSTEM_TIME AS OF p.`initiated_at` AS c
    ON c.`customer_id` = p.`customer_id`;
