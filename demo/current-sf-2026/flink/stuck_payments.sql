-- CURRENT SF 2026 DEMO VARIANT — "stuck" / stalled payments  (OPTIONAL)
-- Additive / demo-only. The workshop's riverflow_payments is a 4-way INNER JOIN = completed only
-- ("stuck at authorization" drill-down is the workshop's Phase 2 backlog).
--
-- Only needed if the video keeps a literal "stuck between stages" moment. The current Video 3
-- narrative uses exception-probability (exception_score_ci.sql) + segment, which needs NONE of this.
--
-- Requires the generator to emit partial lifecycles (payments that initiate/authorize but never
-- reach a terminal status) — see ../shadowtraffic/generator-demo-overlay.md.
--
-- TODO: confirm CP Flink event-time interval-join / timer syntax for the SLA window; set the SLA
--   (e.g. 15 min); prefer event-time over CURRENT_TIMESTAMP for the age calculation.

-- Sketch: a payment is "stuck" if it has an initiation but no terminal status past the SLA.
-- CREATE MATERIALIZED TABLE riverflow_payments_stuck AS
SELECT
  i.`payment_id`,
  i.`customer_id`,
  i.`amount`,
  i.`currency`,
  i.`initiated_at`,
  a.`authorized_at`,
  TIMESTAMPDIFF(MINUTE, i.`initiated_at`, CURRENT_TIMESTAMP) AS `age_minutes`,  -- TODO: event-time
  CASE
    WHEN a.`payment_id` IS NULL THEN 'stuck_before_authorization'
    ELSE 'stuck_before_settlement'
  END AS `stuck_stage`
FROM `riverflow.payments.initiation` i
  LEFT JOIN `riverflow.payments.authorization` a ON i.`payment_id` = a.`payment_id`
  LEFT JOIN `riverflow.payments.status`        s ON i.`payment_id` = s.`payment_id`
WHERE s.`payment_id` IS NULL
  AND TIMESTAMPDIFF(MINUTE, i.`initiated_at`, CURRENT_TIMESTAMP) >= 15;  -- TODO: event-time SLA window
