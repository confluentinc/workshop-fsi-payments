-- RiverPulse Genie / Databricks SQL views (created by Terraform after Tableflow sync)
-- Tableflow publishes only Flink data products:
--   riverflow_payments (append — completed)
--   riverflow_payments_risk_score (upsert)

CREATE OR REPLACE VIEW riverpulse_high_risk_payments AS
SELECT payment_id, customer_id, segment, account_tier, amount, currency,
       risk_score, risk_reason, enrichment_timestamp
FROM riverflow_payments_risk_score
WHERE risk_score >= 0.5
ORDER BY risk_score DESC;

CREATE OR REPLACE VIEW riverpulse_customer_risk_7d AS
SELECT customer_id, segment, account_tier,
       COUNT(*) AS payment_count,
       AVG(risk_score) AS avg_risk_score,
       MAX(risk_score) AS max_risk_score
FROM riverflow_payments_risk_score
WHERE enrichment_timestamp >= current_timestamp() - INTERVAL 7 DAYS
GROUP BY customer_id, segment, account_tier
ORDER BY avg_risk_score DESC;

-- Phase 1 completion proxy (stall drill-down is Phase 2 backlog):
-- risk_score ≈ initiated+enriched; riverflow_payments ≈ fully completed (4-way inner join).
CREATE OR REPLACE VIEW riverpulse_lifecycle_completion AS
SELECT
  (SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments_risk_score) AS initiated_enriched,
  (SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments) AS completed,
  CASE
    WHEN (SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments_risk_score) = 0 THEN NULL
    ELSE CAST((SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments) AS DOUBLE)
         / CAST((SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments_risk_score) AS DOUBLE)
  END AS completion_rate;
