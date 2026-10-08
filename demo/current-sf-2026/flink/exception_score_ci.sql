-- CURRENT SF 2026 DEMO VARIANT — exception scoring via on-prem CI model (KServe / IBM Granite)
-- Additive / demo-only. Does NOT replace workshop main (flink/risk_score.sql, flink/risk_udf.sql).
--
-- Swaps the workshop's CASE heuristic / external REST UDF for Confluent Intelligence on-prem:
-- a curated time-series model served in-cluster via KServe, called as a Flink SQL model function
-- (CREATE MODEL + ML_PREDICT per RFC #79 / CI-on-prem PRFAQ). Data + model never leave the cluster.
--
-- Output columns are kept identical to riverflow_payments_risk_score so the RiverPulse views
-- (sql/riverpulse_views.sql) and the Confluent Assistant queries work unchanged.
--
-- TODO(Robert / Julian): confirm CREATE MODEL + ML_PREDICT syntax and the model name/endpoint
--   in the demo env (us-central-dev). Preview models = forecasting + anomaly detection only (no PII).

-- 1) Register the on-prem model (served by KServe / IBM Granite, in-cluster).
-- CREATE MODEL anomaly_detector
--   INPUT  (amount_usd DOUBLE, segment STRING, account_tier STRING)   -- TODO confirm input schema
--   OUTPUT (exception_score DOUBLE, reason STRING)                    -- TODO confirm output schema
--   WITH (
--     'provider' = 'kserve',                                          -- TODO confirm provider id
--     'endpoint' = 'http://<kserve-svc>.<namespace>.svc.cluster.local/v2/models/<model>/infer', -- TODO
--     'task'     = 'anomaly_detection'                                -- or 'forecasting'
--   );

-- 2) Score every payment in-stream → RiverPulse exceptions product.
-- CREATE MATERIALIZED TABLE riverflow_payments_risk_score AS   -- same name/shape as workshop
SELECT
  enriched.`payment_id`,
  enriched.`customer_id`,
  enriched.`segment`,
  enriched.`account_tier`,
  enriched.`amount`,
  enriched.`currency`,
  enriched.`amount_usd`,
  enriched.`payment_type`,
  enriched.`initiated_at`,
  pred.`exception_score` AS `risk_score`,
  pred.`reason`          AS `risk_reason`,
  CURRENT_TIMESTAMP      AS `enrichment_timestamp`
FROM (
  SELECT
    p.`payment_id`, p.`customer_id`, c.`segment`, c.`account_tier`,
    p.`amount`, p.`currency`,
    ROUND(p.`amount` * fx.`rate_to_usd`, 2) AS `amount_usd`,   -- score the USD-normalized amount
    p.`payment_type`, p.`initiated_at`
  FROM `riverflow.payments.initiation` p
    JOIN `riverflow.riverpay.customer_profiles` FOR SYSTEM_TIME AS OF p.`$rowtime` AS c
      ON c.`customer_id` = p.`customer_id`
    JOIN `riverflow.riverpay.fx_rates` FOR SYSTEM_TIME AS OF p.`$rowtime` AS fx
      ON fx.`currency_code` = p.`currency`
) AS enriched
-- TODO(Robert / Julian): confirm ML_PREDICT / AI_FORECAST invocation + lateral syntax.
CROSS JOIN LATERAL TABLE(
  ML_PREDICT('anomaly_detector', enriched.`amount_usd`, enriched.`segment`, enriched.`account_tier`)
) AS pred;

-- Fallback: if the CI model is not demo-stable, use the stock workshop SQL unchanged
-- (../../flink/risk_score.sql CASE, or ../../flink/risk_udf.sql REST UDF). Same output columns.
