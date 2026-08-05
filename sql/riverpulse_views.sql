-- RiverPulse Genie / Databricks SQL views (created by Terraform after Tableflow sync)
-- Tableflow publishes only Flink data products:
--   riverflow_payments (append — completed)
--   riverflow_payments_risk_score (upsert — per payment)
--   riverflow_customer_risk_exposure_24h (upsert — per customer, trailing 24h)

CREATE OR REPLACE VIEW riverpulse_high_risk_payments AS
SELECT payment_id, customer_id, segment, account_tier, amount, currency,
       risk_score, risk_reason, enrichment_timestamp
FROM riverflow_payments_risk_score
WHERE risk_score >= 0.5
ORDER BY risk_score DESC;

CREATE OR REPLACE VIEW riverpulse_customer_risk_24h AS
SELECT customer_id, segment, account_tier,
       payment_count, avg_risk_score, max_risk_score, updated_at
FROM riverflow_customer_risk_exposure_24h
ORDER BY avg_risk_score DESC;

-- Phase 1 completion proxy (stall drill-down is Phase 2 backlog):
-- risk_score ≈ initiated+enriched; riverflow_payments ≈ fully completed
-- (4-way inner join + FX temporal join).
CREATE OR REPLACE VIEW riverpulse_lifecycle_completion AS
SELECT
  (SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments_risk_score) AS initiated_enriched,
  (SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments) AS completed,
  CASE
    WHEN (SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments_risk_score) = 0 THEN NULL
    ELSE CAST((SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments) AS DOUBLE)
         / CAST((SELECT COUNT(DISTINCT payment_id) FROM riverflow_payments_risk_score) AS DOUBLE)
  END AS completion_rate;
