-- Reference Flink SQL: schema evolution on the completed-payments data product.
-- v1 (the original statement) lives in flink/fx_conversion.sql — keep both to show
-- the before/after. Used by LAB 5 Step 3 (bonus).
--
-- The ask: break completed payments down by customer segment. `riverflow_payments`
-- has no `segment` column, so the product is evolved in place rather than rebuilt.
--
-- What changes from v1:
--   1. `c.segment` is APPENDED to the end of the SELECT list. Adding a column keeps
--      existing field positions intact, so the schema change stays backward
--      compatible and current consumers are unaffected.
--   2. A LEFT temporal join to customer_profiles supplies it. LEFT (not INNER) keeps
--      every completed payment in the table even if the profile lookup misses, so the
--      product's meaning is unchanged — and it keeps the new column nullable.
--
-- CREATE OR ALTER migrates the materialized table in place: no stopping the statement,
-- no drop/recreate, no offset or consumer coordination. Tableflow then propagates the
-- new column to Delta / Unity Catalog on its own.
--
-- Note: rows written before this runs keep NULL for `segment`. Adding a column is not
-- a backfill.

SET 'client.statement-name' = 'riverflow-payments-completed-v2';
CREATE OR ALTER MATERIALIZED TABLE `riverflow_payments` AS
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
  s.`completed_at`,
  c.`segment`
FROM `riverflow.payments.initiation` i
  INNER JOIN `riverflow.payments.authorization` a
    ON i.`payment_id` = a.`payment_id`
  INNER JOIN `riverflow.payments.balance_update` b
    ON i.`payment_id` = b.`payment_id`
  INNER JOIN `riverflow.payments.status` s
    ON i.`payment_id` = s.`payment_id`
  JOIN `riverflow.riverpay.fx_rates` FOR SYSTEM_TIME AS OF i.`$rowtime` AS fx
    ON fx.`currency_code` = i.`currency`
  LEFT JOIN `riverflow.riverpay.customer_profiles` FOR SYSTEM_TIME AS OF i.`$rowtime` AS c
    ON c.`customer_id` = i.`customer_id`;

-- Verify in Databricks (Tableflow-published Delta table):
-- SELECT `payment_id`, `customer_id`, `segment`
-- FROM `<catalog>`.`<schema>`.`riverflow_payments`
-- ORDER BY `completed_at` DESC
-- LIMIT 50;
