-- Reference: per-customer trailing-24h risk exposure, built on top of the
-- existing per-payment risk table. Every new payment immediately updates
-- that customer's row (OVER window, no window-close delay like HOP/TUMBLE).
-- The declared PRIMARY KEY is what makes Flink upsert by customer_id instead
-- of appending one row per payment -- this is the genuine-upsert data product.
--
-- KNOWN LIMITATION: a customer's row only refreshes when they have a NEW
-- payment. A quiet customer's numbers stay frozen at their last computed
-- value rather than decaying as their old payments age out of the real
-- last-24-hours -- there is no background clock forcing recomputation.

-- CREATE OR ALTER MATERIALIZED TABLE riverflow_customer_risk_exposure_24h (
--   PRIMARY KEY (customer_id) NOT ENFORCED
-- )
-- WITH (
--   'changelog.mode' = 'upsert',
--   'kafka.cleanup-policy' = 'compact'
-- ) AS
WITH risk_last_24h AS (
  SELECT
    customer_id,
    segment,
    account_tier,
    COUNT(*) OVER w AS payment_count,
    AVG(risk_score) OVER w AS avg_risk_score,
    MAX(risk_score) OVER w AS max_risk_score,
    `$rowtime` AS updated_at
  FROM riverflow_payments_risk_score
  WINDOW w AS (
    PARTITION BY customer_id
    ORDER BY `$rowtime`
    RANGE BETWEEN INTERVAL '24' HOUR PRECEDING AND CURRENT ROW
  )
)
SELECT * FROM risk_last_24h;
