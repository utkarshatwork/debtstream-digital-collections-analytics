-- ============================================================
-- DebtStream Digital Collections Funnel & Payment Journey Optimisation
-- FILE: 05_PowerBI_Views.sql
-- DESCRIPTION:
--   This file creates clean BigQuery reporting views for the final
--   Power BI dashboard.
--
--   These views are designed to support a dynamic and interactive
--   three-page Power BI report:
--
--     Page 1: Digital Collections Funnel & Channel Performance
--     Page 2: A/B Test, Repayment Performance & Recovery Outcomes
--
--   The views simplify the Power BI model by preparing customer-level,
--   funnel-level, A/B test, recovery, client portfolio, and repayment
--   plan performance datasets inside BigQuery.
--
-- BUSINESS CONTEXT:
--   Instead of connecting Power BI directly to every raw table and
--   rebuilding all joins/measures from scratch, this file creates a
--   reporting layer that keeps the dashboard cleaner, easier to validate,
--   and closer to how analytics teams prepare BI-ready data.
--
-- IMPORTANT:
--   Funnel and outcome metrics are prepared at customer level wherever
--   possible to avoid double-counting repeated communication or journey
--   events.
--
-- PLATFORM: BigQuery
-- DATASET: debtstream_analytics
-- PROJECT: debtstream-analytics-project
-- DEPENDS ON:
--   01_Setup_and_Base_Tables.sql
--   02_Funnel_and_Channel_Analysis.sql
--   03_SMS_AB_Testing.sql
--   04_Repayment_and_Recovery.sql
-- ============================================================


-- ============================================================
-- VIEW 1: CUSTOMER SUMMARY VIEW
-- Purpose:
--   Create one customer-level summary table containing customer,
--   client, communication, journey, payment, repayment plan, and
--   recovery fields.
--
-- Power BI Use:
--   This will be the main fact table for dynamic KPI cards, slicers,
--   funnel metrics, repayment outcomes, and recovery analysis.
-- ============================================================

CREATE OR REPLACE VIEW `debtstream-analytics-project.debtstream_analytics.vw_customer_summary` AS

WITH first_channel AS (
  SELECT
    customer_id,
    channel AS primary_channel,
    sent_date AS first_communication_date
  FROM (
    SELECT
      customer_id,
      channel,
      sent_date,
      communication_id,
      ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY sent_date ASC, communication_id ASC
      ) AS rn
    FROM `debtstream-analytics-project.debtstream_analytics.communication_events`
  )
  WHERE rn = 1
),

journey_flags AS (
  SELECT
    customer_id,

    MAX(CASE WHEN event_name = 'invite_sent' THEN 1 ELSE 0 END) AS invite_sent_flag,
    MAX(CASE WHEN event_name = 'invite_delivered' THEN 1 ELSE 0 END) AS invite_delivered_flag,
    MAX(CASE WHEN event_name = 'link_opened' THEN 1 ELSE 0 END) AS link_opened_flag,
    MAX(CASE WHEN event_name = 'identity_verified' THEN 1 ELSE 0 END) AS identity_verified_flag,
    MAX(CASE WHEN event_name = 'balance_viewed' THEN 1 ELSE 0 END) AS balance_viewed_flag,
    MAX(CASE WHEN event_name = 'affordability_started' THEN 1 ELSE 0 END) AS affordability_started_flag,
    MAX(CASE WHEN event_name = 'affordability_completed' THEN 1 ELSE 0 END) AS affordability_completed_flag,
    MAX(CASE WHEN event_name = 'payment_option_selected' THEN 1 ELSE 0 END) AS payment_option_selected_flag,
    MAX(CASE WHEN event_name = 'payment_made' THEN 1 ELSE 0 END) AS payment_made_journey_flag,
    MAX(CASE WHEN event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_journey_flag,

    MIN(CASE WHEN event_name = 'link_opened' THEN event_date ELSE NULL END) AS first_link_open_date,
    MIN(CASE WHEN event_name = 'identity_verified' THEN event_date ELSE NULL END) AS first_identity_verified_date,
    MIN(CASE WHEN event_name = 'payment_made' THEN event_date ELSE NULL END) AS first_payment_journey_date,
    MIN(CASE WHEN event_name = 'repayment_plan_created' THEN event_date ELSE NULL END) AS first_plan_journey_date

  FROM `debtstream-analytics-project.debtstream_analytics.journey_events`
  GROUP BY customer_id
),

payment_summary AS (
  SELECT
    customer_id,

    SUM(
      CASE
        WHEN payment_status = 'Successful'
        THEN payment_amount
        ELSE 0
      END
    ) AS amount_collected,

    MAX(
      CASE
        WHEN payment_status = 'Successful'
        THEN 1 ELSE 0
      END
    ) AS payment_made_flag,

    MAX(
      CASE
        WHEN payment_status = 'Successful'
         AND payment_type = 'One-off'
        THEN 1 ELSE 0
      END
    ) AS one_off_payment_flag,

    MIN(
      CASE
        WHEN payment_status = 'Successful'
        THEN payment_date
        ELSE NULL
      END
    ) AS first_successful_payment_date,

    AVG(
      CASE
        WHEN payment_status = 'Successful'
        THEN payment_amount
        ELSE NULL
      END
    ) AS avg_successful_payment_amount,

    COUNT(CASE WHEN payment_status = 'Successful' THEN payment_id END) AS successful_payment_count,
    COUNT(CASE WHEN payment_status = 'Failed' THEN payment_id END) AS failed_payment_count,
    COUNT(CASE WHEN payment_status = 'Reversed' THEN payment_id END) AS reversed_payment_count

  FROM `debtstream-analytics-project.debtstream_analytics.payments`
  GROUP BY customer_id
),

plan_summary AS (
  SELECT
    customer_id,

    1 AS repayment_plan_created_flag,

    MAX(CASE WHEN first_instalment_paid_flag = 1 THEN 1 ELSE 0 END) AS first_instalment_paid_flag,
    MAX(CASE WHEN plan_status = 'Broken' THEN 1 ELSE 0 END) AS broken_plan_flag,
    MAX(CASE WHEN plan_status = 'Active' THEN 1 ELSE 0 END) AS active_plan_flag,
    MAX(CASE WHEN plan_status = 'Completed' THEN 1 ELSE 0 END) AS completed_plan_flag,
    MAX(CASE WHEN plan_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_plan_flag,
    MAX(CASE WHEN affordability_completed_flag = 1 THEN 1 ELSE 0 END) AS affordability_completed_plan_flag,

    MAX(plan_status) AS plan_status,
    MIN(plan_created_date) AS first_plan_created_date,
    AVG(plan_amount) AS avg_plan_amount,
    AVG(instalment_amount) AS avg_instalment_amount,
    AVG(plan_length_months) AS avg_plan_length_months,
    MAX(missed_payment_count) AS max_missed_payment_count

  FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
  GROUP BY customer_id
),

ab_test_summary AS (
  SELECT
    customer_id,
    ab_test_group,
    message_tone
  FROM `debtstream-analytics-project.debtstream_analytics.vw_ab_test_customer_outcomes`
)

SELECT
  c.customer_id,
  c.client_id,
  cl.client_name,
  cl.client_type,
  cl.industry,
  cl.integration_type,
  cl.client_size,
  cl.region_focus,

  c.account_upload_date,
  DATE_TRUNC(c.account_upload_date, MONTH) AS upload_month,
  c.portfolio_type,
  c.debt_balance,
  c.balance_band,
  c.debt_age_days,
  c.debt_age_band,
  c.customer_age_band,
  c.region,
  c.vulnerability_flag,
  c.preferred_contact_channel,
  c.account_status,

  fc.primary_channel,
  fc.first_communication_date,

  COALESCE(jf.invite_sent_flag, 0) AS invite_sent_flag,
  COALESCE(jf.invite_delivered_flag, 0) AS invite_delivered_flag,
  COALESCE(jf.link_opened_flag, 0) AS link_opened_flag,
  COALESCE(jf.identity_verified_flag, 0) AS identity_verified_flag,
  COALESCE(jf.balance_viewed_flag, 0) AS balance_viewed_flag,
  COALESCE(jf.affordability_started_flag, 0) AS affordability_started_flag,
  COALESCE(jf.affordability_completed_flag, 0) AS affordability_completed_flag,
  COALESCE(jf.payment_option_selected_flag, 0) AS payment_option_selected_flag,

  COALESCE(ps.payment_made_flag, 0) AS payment_made_flag,
  COALESCE(ps.one_off_payment_flag, 0) AS one_off_payment_flag,
  COALESCE(ps.amount_collected, 0) AS amount_collected,
  COALESCE(ps.avg_successful_payment_amount, 0) AS avg_successful_payment_amount,
  COALESCE(ps.successful_payment_count, 0) AS successful_payment_count,
  COALESCE(ps.failed_payment_count, 0) AS failed_payment_count,
  COALESCE(ps.reversed_payment_count, 0) AS reversed_payment_count,

  COALESCE(pl.repayment_plan_created_flag, 0) AS repayment_plan_created_flag,
  COALESCE(pl.first_instalment_paid_flag, 0) AS first_instalment_paid_flag,
  COALESCE(pl.broken_plan_flag, 0) AS broken_plan_flag,
  COALESCE(pl.active_plan_flag, 0) AS active_plan_flag,
  COALESCE(pl.completed_plan_flag, 0) AS completed_plan_flag,
  COALESCE(pl.cancelled_plan_flag, 0) AS cancelled_plan_flag,
  COALESCE(pl.affordability_completed_plan_flag, 0) AS affordability_completed_plan_flag,
  COALESCE(pl.plan_status, 'No Plan') AS plan_status,
  COALESCE(pl.avg_plan_amount, 0) AS avg_plan_amount,
  COALESCE(pl.avg_instalment_amount, 0) AS avg_instalment_amount,
  COALESCE(pl.avg_plan_length_months, 0) AS avg_plan_length_months,
  COALESCE(pl.max_missed_payment_count, 0) AS max_missed_payment_count,

  ab.ab_test_group,
  ab.message_tone,

  ROUND(COALESCE(ps.amount_collected, 0) / NULLIF(c.debt_balance, 0), 4) AS customer_recovery_rate,

  DATE_DIFF(ps.first_successful_payment_date, c.account_upload_date, DAY) AS days_to_first_payment,
  DATE_DIFF(pl.first_plan_created_date, c.account_upload_date, DAY) AS days_to_first_plan

FROM `debtstream-analytics-project.debtstream_analytics.customers` c
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.clients` cl
  ON c.client_id = cl.client_id
LEFT JOIN first_channel fc
  ON c.customer_id = fc.customer_id
LEFT JOIN journey_flags jf
  ON c.customer_id = jf.customer_id
LEFT JOIN payment_summary ps
  ON c.customer_id = ps.customer_id
LEFT JOIN plan_summary pl
  ON c.customer_id = pl.customer_id
LEFT JOIN ab_test_summary ab
  ON c.customer_id = ab.customer_id;


-- ============================================================
-- VIEW 2: FUNNEL SUMMARY VIEW
-- Purpose:
--   Create an aggregated funnel summary by month, client type,
--   primary channel, balance band, and debt age band.
--
-- Power BI Use:
--   Use this view for Page 1 funnel charts, channel performance
--   visuals, and segment-level funnel comparisons.
-- ============================================================

CREATE OR REPLACE VIEW `debtstream-analytics-project.debtstream_analytics.vw_funnel_summary` AS

SELECT
  upload_month,
  client_type,
  primary_channel,
  balance_band,
  debt_age_band,
  portfolio_type,

  COUNT(DISTINCT customer_id) AS total_customers,

  COUNT(DISTINCT CASE WHEN invite_sent_flag = 1 THEN customer_id END) AS invite_sent_customers,
  COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END) AS invite_delivered_customers,
  COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) AS link_opened_customers,
  COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) AS identity_verified_customers,
  COUNT(DISTINCT CASE WHEN balance_viewed_flag = 1 THEN customer_id END) AS balance_viewed_customers,
  COUNT(DISTINCT CASE WHEN payment_option_selected_flag = 1 THEN customer_id END) AS payment_option_selected_customers,
  COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) AS payment_made_customers,
  COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) AS repayment_plan_created_customers,

  ROUND(
    COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0),
    2
  ) AS link_open_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END), 0),
    2
  ) AS verification_after_open_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0),
    2
  ) AS payment_conversion_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0),
    2
  ) AS plan_setup_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_customer_summary`
GROUP BY
  upload_month,
  client_type,
  primary_channel,
  balance_band,
  debt_age_band,
  portfolio_type;


-- ============================================================
-- VIEW 3: CHANNEL PERFORMANCE VIEW
-- Purpose:
--   Create a channel-level summary of engagement, payment, plan,
--   and recovery outcomes.
--
-- Power BI Use:
--   Use this view for channel comparison charts on Page 1.
-- ============================================================

CREATE OR REPLACE VIEW `debtstream-analytics-project.debtstream_analytics.vw_channel_performance` AS

SELECT
  primary_channel,

  COUNT(DISTINCT customer_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END) AS invite_delivered_customers,
  COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) AS link_opened_customers,
  COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) AS identity_verified_customers,
  COUNT(DISTINCT CASE WHEN payment_option_selected_flag = 1 THEN customer_id END) AS payment_option_selected_customers,
  COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) AS payment_made_customers,
  COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) AS repayment_plan_created_customers,

  ROUND(
    COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0),
    2
  ) AS link_open_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END), 0),
    2
  ) AS verification_after_open_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0),
    2
  ) AS payment_conversion_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0),
    2
  ) AS plan_setup_rate,

  ROUND(SUM(amount_collected), 2) AS total_amount_collected,
  ROUND(SUM(debt_balance), 2) AS total_outstanding_balance,

  ROUND(
    SUM(amount_collected) * 100.0 / NULLIF(SUM(debt_balance), 0),
    2
  ) AS recovery_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_customer_summary`
GROUP BY primary_channel;


-- ============================================================
-- VIEW 4: A/B TEST SUMMARY VIEW
-- Purpose:
--   Create an aggregated A/B test summary by group, balance band,
--   client type, and debt age band.
--
-- Power BI Use:
--   Use this view for Page 2 A/B test visuals.
-- ============================================================

CREATE OR REPLACE VIEW `debtstream-analytics-project.debtstream_analytics.vw_ab_test_summary` AS

SELECT
  ab_test_group,
  message_tone,
  balance_band,
  client_type,
  debt_age_band,
  portfolio_type,

  COUNT(DISTINCT customer_id) AS test_customers,

  ROUND(AVG(link_opened_flag) * 100, 2) AS link_open_rate,
  ROUND(AVG(identity_verified_flag) * 100, 2) AS identity_verification_rate,
  ROUND(AVG(payment_option_selected_flag) * 100, 2) AS payment_option_selection_rate,

  ROUND(AVG(payment_made_flag) * 100, 2) AS payment_rate,
  ROUND(AVG(one_off_payment_flag) * 100, 2) AS one_off_payment_rate,
  ROUND(AVG(repayment_plan_created_flag) * 100, 2) AS plan_setup_rate,
  ROUND(AVG(first_instalment_paid_flag) * 100, 2) AS first_instalment_paid_rate,
  ROUND(AVG(broken_plan_flag) * 100, 2) AS broken_plan_rate,

  ROUND(SUM(amount_collected), 2) AS total_amount_collected,
  ROUND(AVG(amount_collected), 2) AS avg_amount_collected_per_customer,
  ROUND(AVG(customer_recovery_rate) * 100, 2) AS avg_customer_recovery_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_customer_summary`
WHERE ab_test_group IN ('Control', 'Variant')
GROUP BY
  ab_test_group,
  message_tone,
  balance_band,
  client_type,
  debt_age_band,
  portfolio_type;


-- ============================================================
-- VIEW 5: RECOVERY SUMMARY VIEW
-- Purpose:
--   Create an aggregated recovery summary by key business segments.
--
-- Power BI Use:
--   Use this view for recovery by balance band, debt age, client type,
--   and portfolio type charts.
-- ============================================================

CREATE OR REPLACE VIEW `debtstream-analytics-project.debtstream_analytics.vw_recovery_summary` AS

SELECT
  client_type,
  balance_band,
  debt_age_band,
  portfolio_type,
  primary_channel,

  COUNT(DISTINCT customer_id) AS total_customers,
  ROUND(SUM(debt_balance), 2) AS total_outstanding_balance,
  ROUND(SUM(amount_collected), 2) AS total_amount_collected,

  ROUND(
    SUM(amount_collected) * 100.0 / NULLIF(SUM(debt_balance), 0),
    2
  ) AS recovery_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) * 100.0 /
    COUNT(DISTINCT customer_id),
    2
  ) AS payment_conversion_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN one_off_payment_flag = 1 THEN customer_id END) * 100.0 /
    COUNT(DISTINCT customer_id),
    2
  ) AS one_off_payment_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) * 100.0 /
    COUNT(DISTINCT customer_id),
    2
  ) AS plan_setup_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN broken_plan_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END), 0),
    2
  ) AS broken_plan_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_customer_summary`
GROUP BY
  client_type,
  balance_band,
  debt_age_band,
  portfolio_type,
  primary_channel;


-- ============================================================
-- VIEW 6: CLIENT PORTFOLIO SUMMARY VIEW
-- Purpose:
--   Create a client-level performance summary for B2B portfolio
--   reporting.
--
-- Power BI Use:
--   Use this view to compare performance across client names, client
--   types, industries, integration types, and client sizes.
-- ============================================================

CREATE OR REPLACE VIEW `debtstream-analytics-project.debtstream_analytics.vw_client_portfolio_summary` AS

SELECT
  client_id,
  client_name,
  client_type,
  industry,
  integration_type,
  client_size,
  region_focus,

  COUNT(DISTINCT customer_id) AS total_customers,
  ROUND(SUM(debt_balance), 2) AS total_outstanding_balance,
  ROUND(SUM(amount_collected), 2) AS total_amount_collected,

  ROUND(
    SUM(amount_collected) * 100.0 / NULLIF(SUM(debt_balance), 0),
    2
  ) AS recovery_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0),
    2
  ) AS link_open_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) * 100.0 /
    COUNT(DISTINCT customer_id),
    2
  ) AS payment_conversion_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) * 100.0 /
    COUNT(DISTINCT customer_id),
    2
  ) AS plan_setup_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN broken_plan_flag = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END), 0),
    2
  ) AS broken_plan_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_customer_summary`
GROUP BY
  client_id,
  client_name,
  client_type,
  industry,
  integration_type,
  client_size,
  region_focus;


-- ============================================================
-- VIEW 7: REPAYMENT PLAN PERFORMANCE VIEW
-- Purpose:
--   Create a repayment-plan-level view for plan sustainability,
--   affordability, first instalment, and broken-plan analysis.
--
-- Power BI Use:
--   Use this view for Page 2 visuals around repayment plan quality,
--   affordability assessment impact, and plan sustainability.
-- ============================================================

CREATE OR REPLACE VIEW `debtstream-analytics-project.debtstream_analytics.vw_plan_performance` AS

SELECT
  rp.plan_id,
  rp.customer_id,
  rp.client_id,

  cl.client_type,
  cl.industry,
  cl.integration_type,

  c.balance_band,
  c.debt_age_band,
  c.portfolio_type,
  c.vulnerability_flag,

  rp.plan_created_date,
  DATE_TRUNC(rp.plan_created_date, MONTH) AS plan_created_month,
  rp.plan_amount,
  rp.instalment_amount,
  rp.plan_length_months,
  rp.first_instalment_paid_flag,
  rp.missed_payment_count,
  rp.plan_status,
  rp.affordability_completed_flag,

  CASE
    WHEN rp.affordability_completed_flag = 1 THEN 'Affordability Completed'
    ELSE 'No Affordability Completed'
  END AS affordability_status,

  CASE
    WHEN rp.plan_status = 'Broken' THEN 1
    ELSE 0
  END AS broken_plan_flag

FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans` rp
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.customers` c
  ON rp.customer_id = c.customer_id
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.clients` cl
  ON rp.client_id = cl.client_id;


-- ============================================================
-- SECTION 8: VALIDATE CREATED POWER BI VIEWS
-- Purpose:
--   Confirm that all reporting views have been created and return
--   the expected number of rows.
-- ============================================================

SELECT 'vw_customer_summary' AS view_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.vw_customer_summary`

UNION ALL

SELECT 'vw_funnel_summary' AS view_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.vw_funnel_summary`

UNION ALL

SELECT 'vw_channel_performance' AS view_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.vw_channel_performance`

UNION ALL

SELECT 'vw_ab_test_summary' AS view_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.vw_ab_test_summary`

UNION ALL

SELECT 'vw_recovery_summary' AS view_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.vw_recovery_summary`

UNION ALL

SELECT 'vw_client_portfolio_summary' AS view_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.vw_client_portfolio_summary`

UNION ALL

SELECT 'vw_plan_performance' AS view_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.vw_plan_performance`;


-- ============================================================
-- SECTION 9: QUICK DASHBOARD KPI VALIDATION
-- Purpose:
--   Validate that the main dashboard metrics can be recreated from
--   the customer summary view.
--
-- These numbers should align with earlier SQL validation:
--   Customers: 10,000
--   Link Opened: 3,695
--   Identity Verified: 2,458
--   Payment Made: 1,136
--   Repayment Plan Created: 743
-- ============================================================

SELECT
  COUNT(DISTINCT customer_id) AS total_customers,

  COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END) AS invite_delivered_customers,
  COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) AS link_opened_customers,
  COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) AS identity_verified_customers,
  COUNT(DISTINCT CASE WHEN balance_viewed_flag = 1 THEN customer_id END) AS balance_viewed_customers,
  COUNT(DISTINCT CASE WHEN payment_option_selected_flag = 1 THEN customer_id END) AS payment_option_selected_customers,
  COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) AS payment_made_customers,
  COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) AS repayment_plan_created_customers,

  ROUND(SUM(debt_balance), 2) AS total_outstanding_balance,
  ROUND(SUM(amount_collected), 2) AS total_amount_collected,

  ROUND(
    SUM(amount_collected) * 100.0 / NULLIF(SUM(debt_balance), 0),
    2
  ) AS overall_recovery_rate

FROM `debtstream-analytics-project.debtstream_analytics.vw_customer_summary`;


-- ============================================================
-- NEXT STEPS
-- SQL phase is now complete.
--
-- After this file:
--
--   1. Confirm all views are visible in BigQuery.
--   2. Validate Section 8 and Section 9 results.
--   3. Move to Python/Jupyter Notebook phase:
--
--      01_Data_Validation_and_EDA.ipynb
--      02_SMS_AB_Testing_Analysis.ipynb
--      03_Repayment_and_Recovery_Insights.ipynb

-- ============================================================