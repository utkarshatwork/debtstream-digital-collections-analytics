-- ============================================================
-- DebtStream Digital Collections Funnel & Payment Journey Optimisation
-- FILE: 03_SMS_AB_Testing.sql
-- DESCRIPTION:
--   This file prepares and analyses the SMS A/B test used to compare
--   direct payment reminders against supportive repayment-option
--   messaging.
--
--   The analysis focuses on:
--     1. Identifying the SMS A/B test population
--     2. Creating a customer-level A/B test outcome view
--     3. Comparing Control vs Variant engagement outcomes
--     4. Comparing payment and repayment plan outcomes
--     5. Segmenting A/B performance by balance band
--     6. Preparing clean outputs for Python statistical testing
--
-- BUSINESS CONTEXT:
--   DebtStream wanted to understand whether supportive repayment
--   messaging improved customer engagement and repayment plan setup
--   compared with a direct payment reminder.
--
-- A/B TEST DESIGN:
--   Control  = Direct payment reminder
--   Variant  = Supportive repayment-options message
--
-- IMPORTANT:
--   The test is analysed at customer level, not communication-event
--   level, to avoid double-counting customers who received reminders.
--
-- PLATFORM: BigQuery
-- DATASET: debtstream_analytics
-- PROJECT: debtstream-analytics-project
-- DEPENDS ON:
--   01_Setup_and_Base_Tables.sql
--   02_Funnel_and_Channel_Analysis.sql
-- ============================================================


-- ============================================================
-- SECTION 1: A/B TEST POPULATION CHECK
-- Purpose:
--   Identify customers included in the SMS A/B test and confirm
--   that Control and Variant group sizes are reasonably balanced.
--
-- Business Question:
--   How many customers were included in each SMS test group?
-- ============================================================

WITH ab_test_customers AS (
  SELECT
    customer_id,
    ab_test_group,
    message_tone,
    sent_date,
    ROW_NUMBER() OVER (
      PARTITION BY customer_id
      ORDER BY sent_date ASC, communication_id ASC
    ) AS rn
  FROM `debtstream-analytics-project.debtstream_analytics.communication_events`
  WHERE channel = 'SMS'
    AND ab_test_group IN ('Control', 'Variant')
    AND sent_date BETWEEN DATE '2023-01-01' AND DATE '2023-03-31'
)

SELECT
  ab_test_group,
  message_tone,
  COUNT(DISTINCT customer_id) AS test_customers,
  ROUND(
    COUNT(DISTINCT customer_id) * 100.0 /
    SUM(COUNT(DISTINCT customer_id)) OVER (),
    2
  ) AS customer_share_percent
FROM ab_test_customers
WHERE rn = 1
GROUP BY ab_test_group, message_tone
ORDER BY ab_test_group;


-- ============================================================
-- SECTION 2: CREATE CUSTOMER-LEVEL A/B TEST OUTCOME VIEW
-- Purpose:
--   Create one clean customer-level table/view for Python statistical
--   testing and downstream analysis.
--
-- Why this matters:
--   The raw communication table can contain multiple communications
--   per customer. For A/B testing, each customer should appear once,
--   assigned to their first eligible SMS test message.
--
-- Output:
--   vw_ab_test_customer_outcomes
-- ============================================================

CREATE OR REPLACE VIEW `debtstream-analytics-project.debtstream_analytics.vw_ab_test_customer_outcomes` AS

WITH first_ab_sms AS (
  SELECT
    communication_id,
    customer_id,
    client_id,
    sent_date AS sms_sent_date,
    ab_test_group,
    message_tone,
    delivered_flag,
    opened_or_clicked_flag,

    ROW_NUMBER() OVER (
      PARTITION BY customer_id
      ORDER BY sent_date ASC, communication_id ASC
    ) AS rn

  FROM `debtstream-analytics-project.debtstream_analytics.communication_events`
  WHERE channel = 'SMS'
    AND ab_test_group IN ('Control', 'Variant')
    AND sent_date BETWEEN DATE '2023-01-01' AND DATE '2023-03-31'
),

ab_customers AS (
  SELECT
    communication_id,
    customer_id,
    client_id,
    sms_sent_date,
    ab_test_group,
    message_tone,
    delivered_flag,
    opened_or_clicked_flag
  FROM first_ab_sms
  WHERE rn = 1
),

journey_flags AS (
  SELECT
    customer_id,
    MAX(CASE WHEN event_name = 'link_opened' THEN 1 ELSE 0 END) AS link_opened_flag,
    MAX(CASE WHEN event_name = 'identity_verified' THEN 1 ELSE 0 END) AS identity_verified_flag,
    MAX(CASE WHEN event_name = 'balance_viewed' THEN 1 ELSE 0 END) AS balance_viewed_flag,
    MAX(CASE WHEN event_name = 'payment_option_selected' THEN 1 ELSE 0 END) AS payment_option_selected_flag,
    MAX(CASE WHEN event_name = 'payment_made' THEN 1 ELSE 0 END) AS payment_made_journey_flag,
    MAX(CASE WHEN event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_journey_flag
  FROM `debtstream-analytics-project.debtstream_analytics.journey_events`
  GROUP BY customer_id
),

payment_outcomes AS (
  SELECT
    customer_id,

    MAX(CASE WHEN payment_status = 'Successful' THEN 1 ELSE 0 END) AS payment_made_flag,

    MAX(
      CASE
        WHEN payment_status = 'Successful'
         AND payment_type = 'One-off'
        THEN 1 ELSE 0
      END
    ) AS one_off_payment_flag,

    SUM(
      CASE
        WHEN payment_status = 'Successful'
        THEN payment_amount
        ELSE 0
      END
    ) AS amount_collected,

    AVG(
      CASE
        WHEN payment_status = 'Successful'
        THEN payment_amount
        ELSE NULL
      END
    ) AS avg_successful_payment_amount

  FROM `debtstream-analytics-project.debtstream_analytics.payments`
  GROUP BY customer_id
),

plan_outcomes AS (
  SELECT
    customer_id,

    1 AS repayment_plan_created_flag,

    MAX(CASE WHEN first_instalment_paid_flag = 1 THEN 1 ELSE 0 END) AS first_instalment_paid_flag,

    MAX(CASE WHEN plan_status = 'Broken' THEN 1 ELSE 0 END) AS broken_plan_flag,

    MAX(CASE WHEN affordability_completed_flag = 1 THEN 1 ELSE 0 END) AS affordability_completed_flag,

    MAX(missed_payment_count) AS max_missed_payment_count

  FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
  GROUP BY customer_id
)

SELECT
  ab.customer_id,
  ab.client_id,
  cl.client_type,
  cl.industry,
  cl.integration_type,

  c.portfolio_type,
  c.debt_balance,
  c.balance_band,
  c.debt_age_days,
  c.debt_age_band,
  c.customer_age_band,
  c.region,
  c.vulnerability_flag,
  c.account_status,

  ab.sms_sent_date,
  ab.ab_test_group,
  ab.message_tone,
  ab.delivered_flag,

  -- Engagement outcomes
  COALESCE(ab.opened_or_clicked_flag, 0) AS communication_opened_or_clicked_flag,
  COALESCE(jf.link_opened_flag, 0) AS link_opened_flag,
  COALESCE(jf.identity_verified_flag, 0) AS identity_verified_flag,
  COALESCE(jf.balance_viewed_flag, 0) AS balance_viewed_flag,
  COALESCE(jf.payment_option_selected_flag, 0) AS payment_option_selected_flag,

  -- Payment outcomes
  COALESCE(po.payment_made_flag, 0) AS payment_made_flag,
  COALESCE(po.one_off_payment_flag, 0) AS one_off_payment_flag,
  COALESCE(po.amount_collected, 0) AS amount_collected,
  COALESCE(po.avg_successful_payment_amount, 0) AS avg_successful_payment_amount,

  -- Repayment plan outcomes
  COALESCE(pl.repayment_plan_created_flag, 0) AS repayment_plan_created_flag,
  COALESCE(pl.first_instalment_paid_flag, 0) AS first_instalment_paid_flag,
  COALESCE(pl.broken_plan_flag, 0) AS broken_plan_flag,
  COALESCE(pl.affordability_completed_flag, 0) AS affordability_completed_flag,
  COALESCE(pl.max_missed_payment_count, 0) AS max_missed_payment_count,

  -- Recovery outcome
  ROUND(COALESCE(po.amount_collected, 0) / NULLIF(c.debt_balance, 0), 4) AS customer_recovery_rate

FROM ab_customers ab
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.customers` c
  ON ab.customer_id = c.customer_id
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.clients` cl
  ON ab.client_id = cl.client_id
LEFT JOIN journey_flags jf
  ON ab.customer_id = jf.customer_id
LEFT JOIN payment_outcomes po
  ON ab.customer_id = po.customer_id
LEFT JOIN plan_outcomes pl
  ON ab.customer_id = pl.customer_id;


-- ============================================================
-- SECTION 3: VALIDATE CUSTOMER-LEVEL A/B VIEW
-- Purpose:
--   Confirm that the A/B test view has one row per test customer
--   and contains only Control and Variant groups.
-- ============================================================

SELECT
  ab_test_group,
  COUNT(*) AS rows_in_view,
  COUNT(DISTINCT customer_id) AS distinct_customers
FROM `debtstream-analytics-project.debtstream_analytics.vw_ab_test_customer_outcomes`
GROUP BY ab_test_group
ORDER BY ab_test_group;


-- ============================================================
-- SECTION 4: CONTROL VS VARIANT — CORE PERFORMANCE SUMMARY
-- Purpose:
--   Compare the main customer-level engagement and repayment outcomes
--   between Control and Variant.
--
-- Business Question:
--   Did supportive SMS messaging improve engagement, payment, or
--   repayment plan setup compared with a direct payment reminder?
-- ============================================================

SELECT
  ab_test_group,
  COUNT(DISTINCT customer_id) AS test_customers,

  -- Engagement metrics
  ROUND(AVG(link_opened_flag) * 100, 2) AS link_open_rate,
  ROUND(AVG(identity_verified_flag) * 100, 2) AS identity_verification_rate,
  ROUND(AVG(balance_viewed_flag) * 100, 2) AS balance_view_rate,
  ROUND(AVG(payment_option_selected_flag) * 100, 2) AS payment_option_selection_rate,

  -- Payment and repayment outcomes
  ROUND(AVG(payment_made_flag) * 100, 2) AS payment_rate,
  ROUND(AVG(one_off_payment_flag) * 100, 2) AS one_off_payment_rate,
  ROUND(AVG(repayment_plan_created_flag) * 100, 2) AS plan_setup_rate,
  ROUND(AVG(first_instalment_paid_flag) * 100, 2) AS first_instalment_paid_rate,
  ROUND(AVG(broken_plan_flag) * 100, 2) AS broken_plan_rate,

  -- Commercial outcomes
  ROUND(SUM(amount_collected), 2) AS total_amount_collected,
  ROUND(AVG(amount_collected), 2) AS avg_amount_collected_per_customer,
  ROUND(AVG(customer_recovery_rate) * 100, 2) AS avg_customer_recovery_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_ab_test_customer_outcomes`
GROUP BY ab_test_group
ORDER BY ab_test_group;


-- ============================================================
-- SECTION 5: A/B TEST PERFORMANCE BY BALANCE BAND
-- Purpose:
--   Compare Control vs Variant performance across balance bands.
--
-- Business Question:
--   Does the supportive message work better for medium or high
--   balance customers who may need flexible repayment options?
-- ============================================================

SELECT
  balance_band,
  ab_test_group,
  COUNT(DISTINCT customer_id) AS test_customers,

  ROUND(AVG(link_opened_flag) * 100, 2) AS link_open_rate,
  ROUND(AVG(payment_made_flag) * 100, 2) AS payment_rate,
  ROUND(AVG(one_off_payment_flag) * 100, 2) AS one_off_payment_rate,
  ROUND(AVG(repayment_plan_created_flag) * 100, 2) AS plan_setup_rate,

  ROUND(SUM(amount_collected), 2) AS total_amount_collected,
  ROUND(AVG(customer_recovery_rate) * 100, 2) AS avg_customer_recovery_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_ab_test_customer_outcomes`
GROUP BY balance_band, ab_test_group
ORDER BY
  CASE balance_band
    WHEN 'Low' THEN 1
    WHEN 'Medium' THEN 2
    WHEN 'High' THEN 3
    WHEN 'Very High' THEN 4
    ELSE 5
  END,
  ab_test_group;


-- ============================================================
-- SECTION 6: A/B TEST PERFORMANCE BY CLIENT TYPE
-- Purpose:
--   Understand whether the experiment performs differently across
--   different B2B client portfolio types.
--
-- Business Question:
--   Do some client types respond better to supportive repayment
--   messaging than others?
-- ============================================================

SELECT
  client_type,
  ab_test_group,
  COUNT(DISTINCT customer_id) AS test_customers,

  ROUND(AVG(link_opened_flag) * 100, 2) AS link_open_rate,
  ROUND(AVG(payment_made_flag) * 100, 2) AS payment_rate,
  ROUND(AVG(repayment_plan_created_flag) * 100, 2) AS plan_setup_rate,
  ROUND(SUM(amount_collected), 2) AS total_amount_collected,
  ROUND(AVG(customer_recovery_rate) * 100, 2) AS avg_customer_recovery_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_ab_test_customer_outcomes`
GROUP BY client_type, ab_test_group
ORDER BY client_type, ab_test_group;


-- ============================================================
-- SECTION 7: A/B TEST PERFORMANCE BY DEBT AGE BAND
-- Purpose:
--   Compare experiment outcomes across newer and older debt accounts.
--
-- Business Question:
--   Is supportive messaging more effective for newer debts than older
--   debts, or does the effect remain consistent across debt age?
-- ============================================================

SELECT
  debt_age_band,
  ab_test_group,
  COUNT(DISTINCT customer_id) AS test_customers,

  ROUND(AVG(link_opened_flag) * 100, 2) AS link_open_rate,
  ROUND(AVG(payment_made_flag) * 100, 2) AS payment_rate,
  ROUND(AVG(repayment_plan_created_flag) * 100, 2) AS plan_setup_rate,
  ROUND(SUM(amount_collected), 2) AS total_amount_collected,
  ROUND(AVG(customer_recovery_rate) * 100, 2) AS avg_customer_recovery_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_ab_test_customer_outcomes`
GROUP BY debt_age_band, ab_test_group
ORDER BY
  CASE debt_age_band
    WHEN '0-30 days' THEN 1
    WHEN '31-90 days' THEN 2
    WHEN '91-180 days' THEN 3
    WHEN '181-365 days' THEN 4
    WHEN '365+ days' THEN 5
    ELSE 6
  END,
  ab_test_group;


-- ============================================================
-- SECTION 8: A/B TEST OUTCOME LIFT SUMMARY
-- Purpose:
--   Calculate the lift from Control to Variant for the most important
--   experiment metrics.
--
-- Business Question:
--   How much did the supportive SMS variant improve or reduce each
--   outcome compared with the direct payment reminder?
-- ============================================================

WITH group_summary AS (
  SELECT
    ab_test_group,

    COUNT(DISTINCT customer_id) AS test_customers,

    AVG(link_opened_flag) AS link_open_rate,
    AVG(payment_made_flag) AS payment_rate,
    AVG(one_off_payment_flag) AS one_off_payment_rate,
    AVG(repayment_plan_created_flag) AS plan_setup_rate,
    AVG(customer_recovery_rate) AS avg_customer_recovery_rate,
    AVG(amount_collected) AS avg_amount_collected_per_customer

  FROM `debtstream-analytics-project.debtstream_analytics.vw_ab_test_customer_outcomes`
  GROUP BY ab_test_group
),

control_values AS (
  SELECT *
  FROM group_summary
  WHERE ab_test_group = 'Control'
),

variant_values AS (
  SELECT *
  FROM group_summary
  WHERE ab_test_group = 'Variant'
)

SELECT
  'Variant vs Control' AS comparison,

  ROUND((v.link_open_rate - c.link_open_rate) * 100, 2) AS link_open_rate_point_lift,
  ROUND((v.payment_rate - c.payment_rate) * 100, 2) AS payment_rate_point_lift,
  ROUND((v.one_off_payment_rate - c.one_off_payment_rate) * 100, 2) AS one_off_payment_rate_point_lift,
  ROUND((v.plan_setup_rate - c.plan_setup_rate) * 100, 2) AS plan_setup_rate_point_lift,
  ROUND((v.avg_customer_recovery_rate - c.avg_customer_recovery_rate) * 100, 2) AS avg_recovery_rate_point_lift,
  ROUND(v.avg_amount_collected_per_customer - c.avg_amount_collected_per_customer, 2) AS avg_amount_collected_per_customer_lift

FROM control_values c
CROSS JOIN variant_values v;


-- ============================================================
-- SECTION 9: EXPORT-READY CUSTOMER-LEVEL A/B DATASET
-- Purpose:
--   This query produces the customer-level dataset that should be
--   exported for Python statistical testing.
--
-- Recommended export name:
--   ab_test_customer_outcomes.csv
-- ============================================================

SELECT *
FROM `debtstream-analytics-project.debtstream_analytics.vw_ab_test_customer_outcomes`
ORDER BY ab_test_group, customer_id;


-- ============================================================
-- NEXT STEPS
-- After completing this SQL A/B testing file, continue to:
--
--   04_Repayment_and_Recovery.sql
--
-- This next file will analyse:
--   1. Total outstanding balance
--   2. Total amount collected
--   3. Recovery rate
--   4. Payment conversion by balance band
--   5. Recovery by debt age
--   6. Repayment plan sustainability
--   7. Affordability completion impact
--
-- Recommended exports from this file:
--   1. ab_test_core_performance.csv
--   2. ab_test_by_balance_band.csv
--   3. ab_test_lift_summary.csv
--   4. ab_test_customer_outcomes.csv
-- ============================================================