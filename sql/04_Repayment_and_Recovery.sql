-- ============================================================
-- DebtStream Digital Collections Funnel & Payment Journey Optimisation
-- FILE: 04_Repayment_and_Recovery.sql
-- DESCRIPTION:
--   This file analyses DebtStream's repayment, payment, plan, and
--   recovery outcomes across customer accounts, debt balance segments,
--   debt age bands, client portfolio types, and affordability assessment
--   behaviour.
--
--   The analysis focuses on:
--     1. Overall repayment and recovery performance
--     2. Payment conversion and amount collected
--     3. Recovery by balance band
--     4. Recovery by debt age band
--     5. Recovery by client type
--     6. Payment method performance
--     7. Repayment plan sustainability
--     8. Affordability assessment impact
--     9. Recovery priority segments
--
-- BUSINESS CONTEXT:
--   DebtStream's product value is not only measured by customer
--   engagement. The more important business question is whether
--   digital self-service journeys result in successful payments,
--   sustainable repayment plans, and higher recovery rates for clients.
--
-- IMPORTANT:
--   Recovery Rate = Successful Amount Collected / Total Outstanding Balance
--
--   Only successful payments are included in amount collected.
--   Failed or reversed payments are excluded from recovery calculations.
--
-- PLATFORM: BigQuery
-- DATASET: debtstream_analytics
-- PROJECT: debtstream-analytics-project
-- DEPENDS ON:
--   01_Setup_and_Base_Tables.sql
--   02_Funnel_and_Channel_Analysis.sql
--   03_SMS_AB_Testing.sql
-- ============================================================


-- ============================================================
-- SECTION 1: OVERALL REPAYMENT AND RECOVERY SUMMARY
-- Purpose:
--   Establish the overall commercial baseline for the project:
--   total outstanding balance, successful amount collected,
--   payment conversion, plan setup, and recovery rate.
--
-- Business Question:
--   What is the overall repayment and recovery performance across
--   all customer accounts?
-- ============================================================

WITH payment_summary AS (
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
    ) AS one_off_payment_flag

  FROM `debtstream-analytics-project.debtstream_analytics.payments`
  GROUP BY customer_id
),

plan_summary AS (
  SELECT
    customer_id,
    1 AS repayment_plan_created_flag,
    MAX(CASE WHEN first_instalment_paid_flag = 1 THEN 1 ELSE 0 END) AS first_instalment_paid_flag,
    MAX(CASE WHEN plan_status = 'Broken' THEN 1 ELSE 0 END) AS broken_plan_flag
  FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
  GROUP BY customer_id
)

SELECT
  COUNT(DISTINCT c.customer_id) AS total_customer_accounts,
  ROUND(SUM(c.debt_balance), 2) AS total_outstanding_balance,
  ROUND(SUM(COALESCE(ps.amount_collected, 0)), 2) AS total_amount_collected,

  ROUND(
    SUM(COALESCE(ps.amount_collected, 0)) * 100.0 /
    NULLIF(SUM(c.debt_balance), 0),
    2
  ) AS overall_recovery_rate,

  COUNT(DISTINCT CASE WHEN COALESCE(ps.payment_made_flag, 0) = 1 THEN c.customer_id END) AS customers_with_successful_payment,
  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(ps.payment_made_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS payment_conversion_rate,

  COUNT(DISTINCT CASE WHEN COALESCE(ps.one_off_payment_flag, 0) = 1 THEN c.customer_id END) AS one_off_payment_customers,
  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(ps.one_off_payment_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS one_off_payment_rate,

  COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END) AS repayment_plan_customers,
  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS plan_setup_rate,

  COUNT(DISTINCT CASE WHEN COALESCE(pl.first_instalment_paid_flag, 0) = 1 THEN c.customer_id END) AS first_instalment_paid_customers,

  COUNT(DISTINCT CASE WHEN COALESCE(pl.broken_plan_flag, 0) = 1 THEN c.customer_id END) AS broken_plan_customers

FROM `debtstream-analytics-project.debtstream_analytics.customers` c
LEFT JOIN payment_summary ps
  ON c.customer_id = ps.customer_id
LEFT JOIN plan_summary pl
  ON c.customer_id = pl.customer_id;


-- ============================================================
-- SECTION 2: RECOVERY PERFORMANCE BY BALANCE BAND
-- Purpose:
--   Compare repayment and recovery outcomes across Low, Medium,
--   High, and Very High balance accounts.
--
-- Business Question:
--   Are low-balance customers more likely to pay, and are medium-
--   balance customers more likely to set up repayment plans?
-- ============================================================

WITH payment_summary AS (
  SELECT
    customer_id,
    SUM(CASE WHEN payment_status = 'Successful' THEN payment_amount ELSE 0 END) AS amount_collected,
    MAX(CASE WHEN payment_status = 'Successful' THEN 1 ELSE 0 END) AS payment_made_flag,
    MAX(CASE WHEN payment_status = 'Successful' AND payment_type = 'One-off' THEN 1 ELSE 0 END) AS one_off_payment_flag
  FROM `debtstream-analytics-project.debtstream_analytics.payments`
  GROUP BY customer_id
),

plan_summary AS (
  SELECT
    customer_id,
    1 AS repayment_plan_created_flag,
    MAX(CASE WHEN plan_status = 'Broken' THEN 1 ELSE 0 END) AS broken_plan_flag
  FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
  GROUP BY customer_id
)

SELECT
  c.balance_band,
  COUNT(DISTINCT c.customer_id) AS total_customers,
  ROUND(AVG(c.debt_balance), 2) AS avg_debt_balance,
  ROUND(SUM(c.debt_balance), 2) AS total_outstanding_balance,
  ROUND(SUM(COALESCE(ps.amount_collected, 0)), 2) AS total_amount_collected,

  ROUND(
    SUM(COALESCE(ps.amount_collected, 0)) * 100.0 /
    NULLIF(SUM(c.debt_balance), 0),
    2
  ) AS recovery_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(ps.payment_made_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS payment_conversion_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(ps.one_off_payment_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS one_off_payment_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS plan_setup_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(pl.broken_plan_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END), 0),
    2
  ) AS broken_plan_rate

FROM `debtstream-analytics-project.debtstream_analytics.customers` c
LEFT JOIN payment_summary ps
  ON c.customer_id = ps.customer_id
LEFT JOIN plan_summary pl
  ON c.customer_id = pl.customer_id
GROUP BY c.balance_band
ORDER BY
  CASE c.balance_band
    WHEN 'Low' THEN 1
    WHEN 'Medium' THEN 2
    WHEN 'High' THEN 3
    WHEN 'Very High' THEN 4
    ELSE 5
  END;


-- ============================================================
-- SECTION 3: RECOVERY PERFORMANCE BY DEBT AGE BAND
-- Purpose:
--   Compare repayment and recovery outcomes across newer and older
--   debt accounts.
--
-- Business Question:
--   Do newer debts recover more effectively through digital journeys
--   than older debts?
-- ============================================================

WITH payment_summary AS (
  SELECT
    customer_id,
    SUM(CASE WHEN payment_status = 'Successful' THEN payment_amount ELSE 0 END) AS amount_collected,
    MAX(CASE WHEN payment_status = 'Successful' THEN 1 ELSE 0 END) AS payment_made_flag
  FROM `debtstream-analytics-project.debtstream_analytics.payments`
  GROUP BY customer_id
),

plan_summary AS (
  SELECT
    customer_id,
    1 AS repayment_plan_created_flag,
    MAX(CASE WHEN plan_status = 'Broken' THEN 1 ELSE 0 END) AS broken_plan_flag
  FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
  GROUP BY customer_id
)

SELECT
  c.debt_age_band,
  COUNT(DISTINCT c.customer_id) AS total_customers,
  ROUND(AVG(c.debt_age_days), 2) AS avg_debt_age_days,
  ROUND(SUM(c.debt_balance), 2) AS total_outstanding_balance,
  ROUND(SUM(COALESCE(ps.amount_collected, 0)), 2) AS total_amount_collected,

  ROUND(
    SUM(COALESCE(ps.amount_collected, 0)) * 100.0 /
    NULLIF(SUM(c.debt_balance), 0),
    2
  ) AS recovery_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(ps.payment_made_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS payment_conversion_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS plan_setup_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(pl.broken_plan_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END), 0),
    2
  ) AS broken_plan_rate

FROM `debtstream-analytics-project.debtstream_analytics.customers` c
LEFT JOIN payment_summary ps
  ON c.customer_id = ps.customer_id
LEFT JOIN plan_summary pl
  ON c.customer_id = pl.customer_id
GROUP BY c.debt_age_band
ORDER BY
  CASE c.debt_age_band
    WHEN '0-30' THEN 1
    WHEN '31-90' THEN 2
    WHEN '91-180' THEN 3
    WHEN '181-365' THEN 4
    WHEN '365+' THEN 5
    ELSE 6
  END;


-- ============================================================
-- SECTION 4: RECOVERY PERFORMANCE BY CLIENT TYPE
-- Purpose:
--   Compare repayment and recovery outcomes across DebtStream's
--   B2B client portfolio types.
--
-- Business Question:
--   Which client types perform best on digital repayment and recovery?
-- ============================================================

WITH payment_summary AS (
  SELECT
    customer_id,
    SUM(CASE WHEN payment_status = 'Successful' THEN payment_amount ELSE 0 END) AS amount_collected,
    MAX(CASE WHEN payment_status = 'Successful' THEN 1 ELSE 0 END) AS payment_made_flag
  FROM `debtstream-analytics-project.debtstream_analytics.payments`
  GROUP BY customer_id
),

plan_summary AS (
  SELECT
    customer_id,
    1 AS repayment_plan_created_flag,
    MAX(CASE WHEN plan_status = 'Broken' THEN 1 ELSE 0 END) AS broken_plan_flag
  FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
  GROUP BY customer_id
)

SELECT
  cl.client_type,
  COUNT(DISTINCT c.customer_id) AS total_customers,
  ROUND(SUM(c.debt_balance), 2) AS total_outstanding_balance,
  ROUND(SUM(COALESCE(ps.amount_collected, 0)), 2) AS total_amount_collected,

  ROUND(
    SUM(COALESCE(ps.amount_collected, 0)) * 100.0 /
    NULLIF(SUM(c.debt_balance), 0),
    2
  ) AS recovery_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(ps.payment_made_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS payment_conversion_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS plan_setup_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(pl.broken_plan_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END), 0),
    2
  ) AS broken_plan_rate

FROM `debtstream-analytics-project.debtstream_analytics.customers` c
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.clients` cl
  ON c.client_id = cl.client_id
LEFT JOIN payment_summary ps
  ON c.customer_id = ps.customer_id
LEFT JOIN plan_summary pl
  ON c.customer_id = pl.customer_id
GROUP BY cl.client_type
ORDER BY recovery_rate DESC;


-- ============================================================
-- SECTION 5: PAYMENT METHOD PERFORMANCE
-- Purpose:
--   Understand how different payment methods perform in terms of
--   successful payments, failed payments, and amount collected.
--
-- Business Question:
--   Which payment methods are associated with stronger successful
--   repayment outcomes?
-- ============================================================

SELECT
  payment_method,
  COUNT(*) AS total_payment_attempts,

  COUNT(CASE WHEN payment_status = 'Successful' THEN 1 END) AS successful_payments,
  COUNT(CASE WHEN payment_status = 'Failed' THEN 1 END) AS failed_payments,
  COUNT(CASE WHEN payment_status = 'Reversed' THEN 1 END) AS reversed_payments,

  ROUND(
    COUNT(CASE WHEN payment_status = 'Successful' THEN 1 END) * 100.0 /
    COUNT(*),
    2
  ) AS payment_success_rate,

  ROUND(SUM(CASE WHEN payment_status = 'Successful' THEN payment_amount ELSE 0 END), 2) AS successful_amount_collected,

  ROUND(AVG(CASE WHEN payment_status = 'Successful' THEN payment_amount ELSE NULL END), 2) AS avg_successful_payment_amount

FROM `debtstream-analytics-project.debtstream_analytics.payments`
GROUP BY payment_method
ORDER BY successful_amount_collected DESC;


-- ============================================================
-- SECTION 6: REPAYMENT PLAN SUSTAINABILITY SUMMARY
-- Purpose:
--   Analyse whether repayment plans are successfully starting and
--   remaining sustainable.
--
-- Business Question:
--   Are created repayment plans turning into meaningful repayment
--   behaviour, or are many plans breaking?
-- ============================================================

SELECT
  COUNT(DISTINCT plan_id) AS total_repayment_plans,

  COUNT(DISTINCT CASE WHEN first_instalment_paid_flag = 1 THEN plan_id END) AS first_instalment_paid_plans,

  ROUND(
    COUNT(DISTINCT CASE WHEN first_instalment_paid_flag = 1 THEN plan_id END) * 100.0 /
    COUNT(DISTINCT plan_id),
    2
  ) AS first_instalment_paid_rate,

  COUNT(DISTINCT CASE WHEN plan_status = 'Broken' THEN plan_id END) AS broken_plans,

  ROUND(
    COUNT(DISTINCT CASE WHEN plan_status = 'Broken' THEN plan_id END) * 100.0 /
    COUNT(DISTINCT plan_id),
    2
  ) AS broken_plan_rate,

  ROUND(AVG(plan_amount), 2) AS avg_plan_amount,
  ROUND(AVG(instalment_amount), 2) AS avg_instalment_amount,
  ROUND(AVG(plan_length_months), 2) AS avg_plan_length_months,
  ROUND(AVG(missed_payment_count), 2) AS avg_missed_payment_count

FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`;


-- ============================================================
-- SECTION 7: PLAN SUSTAINABILITY BY BALANCE BAND
-- Purpose:
--   Compare repayment plan quality across debt balance bands.
--
-- Business Question:
--   Are high and very high balance customers more likely to break
--   repayment plans?
-- ============================================================

SELECT
  c.balance_band,
  COUNT(DISTINCT rp.plan_id) AS total_repayment_plans,

  ROUND(AVG(rp.plan_amount), 2) AS avg_plan_amount,
  ROUND(AVG(rp.instalment_amount), 2) AS avg_instalment_amount,
  ROUND(AVG(rp.plan_length_months), 2) AS avg_plan_length_months,

  ROUND(
    COUNT(DISTINCT CASE WHEN rp.first_instalment_paid_flag = 1 THEN rp.plan_id END) * 100.0 /
    COUNT(DISTINCT rp.plan_id),
    2
  ) AS first_instalment_paid_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN rp.plan_status = 'Broken' THEN rp.plan_id END) * 100.0 /
    COUNT(DISTINCT rp.plan_id),
    2
  ) AS broken_plan_rate,

  ROUND(AVG(rp.missed_payment_count), 2) AS avg_missed_payment_count

FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans` rp
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.customers` c
  ON rp.customer_id = c.customer_id
GROUP BY c.balance_band
ORDER BY
  CASE c.balance_band
    WHEN 'Low' THEN 1
    WHEN 'Medium' THEN 2
    WHEN 'High' THEN 3
    WHEN 'Very High' THEN 4
    ELSE 5
  END;


-- ============================================================
-- SECTION 8: AFFORDABILITY ASSESSMENT IMPACT ON PLAN SUSTAINABILITY
-- Purpose:
--   Compare repayment plan performance between customers who completed
--   affordability assessment and those who did not.
--
-- Business Question:
--   Does affordability assessment completion improve repayment plan
--   sustainability?
-- ============================================================

SELECT
  CASE
    WHEN affordability_completed_flag = 1 THEN 'Affordability Completed'
    ELSE 'No Affordability Completed'
  END AS affordability_status,

  COUNT(DISTINCT plan_id) AS total_repayment_plans,

  ROUND(
    COUNT(DISTINCT CASE WHEN first_instalment_paid_flag = 1 THEN plan_id END) * 100.0 /
    COUNT(DISTINCT plan_id),
    2
  ) AS first_instalment_paid_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN plan_status = 'Broken' THEN plan_id END) * 100.0 /
    COUNT(DISTINCT plan_id),
    2
  ) AS broken_plan_rate,

  ROUND(AVG(missed_payment_count), 2) AS avg_missed_payment_count,
  ROUND(AVG(plan_amount), 2) AS avg_plan_amount,
  ROUND(AVG(instalment_amount), 2) AS avg_instalment_amount

FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
GROUP BY affordability_status
ORDER BY affordability_status;


-- ============================================================
-- SECTION 9: RECOVERY PRIORITY SEGMENTS
-- Purpose:
--   Identify the balance-band and debt-age combinations with the
--   weakest recovery performance.
--
-- Business Question:
--   Which customer segments should be prioritised for improved
--   repayment journeys, targeted nudges, or affordability-led support?
-- ============================================================

WITH payment_summary AS (
  SELECT
    customer_id,
    SUM(CASE WHEN payment_status = 'Successful' THEN payment_amount ELSE 0 END) AS amount_collected,
    MAX(CASE WHEN payment_status = 'Successful' THEN 1 ELSE 0 END) AS payment_made_flag
  FROM `debtstream-analytics-project.debtstream_analytics.payments`
  GROUP BY customer_id
),

plan_summary AS (
  SELECT
    customer_id,
    1 AS repayment_plan_created_flag,
    MAX(CASE WHEN plan_status = 'Broken' THEN 1 ELSE 0 END) AS broken_plan_flag
  FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
  GROUP BY customer_id
)

SELECT
  c.balance_band,
  c.debt_age_band,
  COUNT(DISTINCT c.customer_id) AS total_customers,
  ROUND(SUM(c.debt_balance), 2) AS total_outstanding_balance,
  ROUND(SUM(COALESCE(ps.amount_collected, 0)), 2) AS total_amount_collected,

  ROUND(
    SUM(COALESCE(ps.amount_collected, 0)) * 100.0 /
    NULLIF(SUM(c.debt_balance), 0),
    2
  ) AS recovery_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(ps.payment_made_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS payment_conversion_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    COUNT(DISTINCT c.customer_id),
    2
  ) AS plan_setup_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN COALESCE(pl.broken_plan_flag, 0) = 1 THEN c.customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT CASE WHEN COALESCE(pl.repayment_plan_created_flag, 0) = 1 THEN c.customer_id END), 0),
    2
  ) AS broken_plan_rate

FROM `debtstream-analytics-project.debtstream_analytics.customers` c
LEFT JOIN payment_summary ps
  ON c.customer_id = ps.customer_id
LEFT JOIN plan_summary pl
  ON c.customer_id = pl.customer_id
GROUP BY c.balance_band, c.debt_age_band
ORDER BY recovery_rate ASC;


-- ============================================================
-- SECTION 10: EXPORT-READY CUSTOMER RECOVERY SUMMARY
-- Purpose:
--   Create a customer-level recovery table that can be exported
--   for Python analysis or used to validate Power BI calculations.
--
-- Recommended export name:
--   customer_recovery_summary.csv
-- ============================================================

WITH payment_summary AS (
  SELECT
    customer_id,
    SUM(CASE WHEN payment_status = 'Successful' THEN payment_amount ELSE 0 END) AS amount_collected,
    MAX(CASE WHEN payment_status = 'Successful' THEN 1 ELSE 0 END) AS payment_made_flag,
    MAX(CASE WHEN payment_status = 'Successful' AND payment_type = 'One-off' THEN 1 ELSE 0 END) AS one_off_payment_flag
  FROM `debtstream-analytics-project.debtstream_analytics.payments`
  GROUP BY customer_id
),

plan_summary AS (
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
  c.customer_id,
  c.client_id,
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
  c.preferred_contact_channel,
  c.account_status,

  COALESCE(ps.payment_made_flag, 0) AS payment_made_flag,
  COALESCE(ps.one_off_payment_flag, 0) AS one_off_payment_flag,
  COALESCE(ps.amount_collected, 0) AS amount_collected,

  COALESCE(pl.repayment_plan_created_flag, 0) AS repayment_plan_created_flag,
  COALESCE(pl.first_instalment_paid_flag, 0) AS first_instalment_paid_flag,
  COALESCE(pl.broken_plan_flag, 0) AS broken_plan_flag,
  COALESCE(pl.affordability_completed_flag, 0) AS affordability_completed_flag,
  COALESCE(pl.max_missed_payment_count, 0) AS max_missed_payment_count,

  ROUND(COALESCE(ps.amount_collected, 0) / NULLIF(c.debt_balance, 0), 4) AS customer_recovery_rate

FROM `debtstream-analytics-project.debtstream_analytics.customers` c
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.clients` cl
  ON c.client_id = cl.client_id
LEFT JOIN payment_summary ps
  ON c.customer_id = ps.customer_id
LEFT JOIN plan_summary pl
  ON c.customer_id = pl.customer_id
ORDER BY c.customer_id;


-- ============================================================
-- NEXT STEPS
-- After completing this repayment and recovery analysis, continue to:
--
--   05_PowerBI_Views.sql
--
-- This next file will create clean reporting views for Power BI,
-- including:
--   1. Customer-level summary view
--   2. Funnel summary view
--   3. A/B testing summary view
--   4. Recovery summary view
--   5. Repayment plan performance view
--
-- Essential exports from this file:
--   1. recovery_by_balance_band.csv
--   2. recovery_by_debt_age.csv
--   3. recovery_by_client_type.csv
--   4. plan_sustainability_by_affordability.csv
--   5. recovery_priority_segments.csv
--   6. customer_recovery_summary.csv
-- ============================================================