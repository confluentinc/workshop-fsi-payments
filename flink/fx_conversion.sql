-- Reference Flink SQL: FX rates temporal join (also embedded in Terraform).
-- CDC topic: riverflow.riverpay.fx_rates (upsert from Postgres riverpay.fx_rates)
-- Currencies: USD (1.0) + GBP, AUD, CAD, JPY, EUR (ShadowTraffic updates ~5s)
--
-- This is v1 of the completed-payments product, as built in LAB 3. LAB 5 Step 3
-- evolves it in place to add `segment` — see flink/payments_add_segment.sql.

-- ALTER TABLE `riverflow.riverpay.fx_rates`
--   SET ('changelog.mode' = 'upsert');
-- NOTE: do not compact this topic. Every currency is rewritten every few
-- seconds, so compaction discards the historical versions that
-- FOR SYSTEM_TIME AS OF needs, and foreign-currency payments silently drop
-- out of the inner join. The CDC connector creates the topic with
-- cleanup.policy=delete and retention.ms=-1 — leave it that way.
-- ALTER TABLE `riverflow.riverpay.fx_rates`
--   MODIFY WATERMARK FOR `$rowtime` AS `$rowtime` - INTERVAL '5' SECOND;

-- Completed payments with USD-normalized amount:
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
