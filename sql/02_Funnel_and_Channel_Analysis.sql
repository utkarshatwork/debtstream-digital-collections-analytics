-- ============================================================
-- DebtStream Digital Collections Funnel & Payment Journey Optimisation
-- FILE: 02_Funnel_and_Channel_Analysis.sql
-- DESCRIPTION:
--   This file analyses how customers move through DebtStream's
--   digital self-service collections journey.
--
--   The analysis focuses on:
--     1. Overall digital collections funnel
--     2. Stage-to-stage conversion and drop-off rates
--     3. Affordability assessment sub-funnel
--     4. Funnel performance by primary communication channel
--     5. Funnel performance by balance band
--     6. Funnel performance by debt age band
--     7. Funnel performance by client type
--     8. Monthly funnel trend
--
--   IMPORTANT:
--   Funnel counts are calculated using DISTINCT customer_id.
--   This avoids inflating funnel numbers because customers can
--   receive multiple reminders and may have repeated journey events.
--
-- PLATFORM: BigQuery
-- DATASET: debtstream_analytics
-- PROJECT: debtstream-analytics-project
-- DEPENDS ON:
--   01_Setup_and_Base_Tables.sql
-- ============================================================


-- ============================================================
-- SECTION 1: OVERALL DIGITAL COLLECTIONS FUNNEL
-- Purpose:
--   Understand how customers move from account upload/invite
--   to link open, identity verification, balance view, payment
--   option selection, payment, and repayment plan setup.
--
-- Business Question:
--   Where do customers drop off in the self-service collections
--   journey?
-- ============================================================

WITH customer_stage_flags AS (
  SELECT
    c.customer_id,

    -- Base customer/account stage
    1 AS account_uploaded_flag,

    -- Communication/journey stage flags
    MAX(CASE WHEN je.event_name = 'invite_sent' THEN 1 ELSE 0 END) AS invite_sent_flag,
    MAX(CASE WHEN je.event_name = 'invite_delivered' THEN 1 ELSE 0 END) AS invite_delivered_flag,
    MAX(CASE WHEN je.event_name = 'link_opened' THEN 1 ELSE 0 END) AS link_opened_flag,
    MAX(CASE WHEN je.event_name = 'identity_verified' THEN 1 ELSE 0 END) AS identity_verified_flag,
    MAX(CASE WHEN je.event_name = 'balance_viewed' THEN 1 ELSE 0 END) AS balance_viewed_flag,
    MAX(CASE WHEN je.event_name = 'payment_option_selected' THEN 1 ELSE 0 END) AS payment_option_selected_flag,
    MAX(CASE WHEN je.event_name = 'payment_made' THEN 1 ELSE 0 END) AS payment_made_flag,
    MAX(CASE WHEN je.event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_created_flag

  FROM `debtstream-analytics-project.debtstream_analytics.customers` c
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.journey_events` je
    ON c.customer_id = je.customer_id
  GROUP BY c.customer_id
),

funnel_counts AS (
  SELECT 1 AS stage_order, 'Account Uploaded' AS funnel_stage, COUNT(DISTINCT customer_id) AS customers
  FROM customer_stage_flags
  WHERE account_uploaded_flag = 1

  UNION ALL

  SELECT 2, 'Invite Sent', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE invite_sent_flag = 1

  UNION ALL

  SELECT 3, 'Invite Delivered', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE invite_delivered_flag = 1

  UNION ALL

  SELECT 4, 'Link Opened', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE link_opened_flag = 1

  UNION ALL

  SELECT 5, 'Identity Verified', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE identity_verified_flag = 1

  UNION ALL

  SELECT 6, 'Balance Viewed', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE balance_viewed_flag = 1

  UNION ALL

  SELECT 7, 'Payment Option Selected', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE payment_option_selected_flag = 1

  UNION ALL

  SELECT 8, 'Payment Made', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE payment_made_flag = 1

  UNION ALL

  SELECT 9, 'Repayment Plan Created', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE repayment_plan_created_flag = 1
)

SELECT
  stage_order,
  funnel_stage,
  customers,
  ROUND(customers * 100.0 / FIRST_VALUE(customers) OVER (ORDER BY stage_order), 2) AS percent_of_uploaded_accounts
FROM funnel_counts
ORDER BY stage_order;


-- ============================================================
-- SECTION 2: STAGE-TO-STAGE CONVERSION AND DROP-OFF
-- Purpose:
--   Calculate conversion from each funnel stage to the next stage.
--   This highlights where the biggest product or communication
--   friction occurs.
--
-- Business Question:
--   Which stage has the highest drop-off?
-- ============================================================

WITH customer_stage_flags AS (
  SELECT
    c.customer_id,
    1 AS account_uploaded_flag,
    MAX(CASE WHEN je.event_name = 'invite_sent' THEN 1 ELSE 0 END) AS invite_sent_flag,
    MAX(CASE WHEN je.event_name = 'invite_delivered' THEN 1 ELSE 0 END) AS invite_delivered_flag,
    MAX(CASE WHEN je.event_name = 'link_opened' THEN 1 ELSE 0 END) AS link_opened_flag,
    MAX(CASE WHEN je.event_name = 'identity_verified' THEN 1 ELSE 0 END) AS identity_verified_flag,
    MAX(CASE WHEN je.event_name = 'balance_viewed' THEN 1 ELSE 0 END) AS balance_viewed_flag,
    MAX(CASE WHEN je.event_name = 'payment_option_selected' THEN 1 ELSE 0 END) AS payment_option_selected_flag,
    MAX(CASE WHEN je.event_name = 'payment_made' THEN 1 ELSE 0 END) AS payment_made_flag,
    MAX(CASE WHEN je.event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_created_flag
  FROM `debtstream-analytics-project.debtstream_analytics.customers` c
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.journey_events` je
    ON c.customer_id = je.customer_id
  GROUP BY c.customer_id
),

funnel_counts AS (
  SELECT 1 AS stage_order, 'Account Uploaded' AS funnel_stage, COUNT(DISTINCT customer_id) AS customers
  FROM customer_stage_flags
  WHERE account_uploaded_flag = 1

  UNION ALL

  SELECT 2, 'Invite Sent', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE invite_sent_flag = 1

  UNION ALL

  SELECT 3, 'Invite Delivered', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE invite_delivered_flag = 1

  UNION ALL

  SELECT 4, 'Link Opened', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE link_opened_flag = 1

  UNION ALL

  SELECT 5, 'Identity Verified', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE identity_verified_flag = 1

  UNION ALL

  SELECT 6, 'Balance Viewed', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE balance_viewed_flag = 1

  UNION ALL

  SELECT 7, 'Payment Option Selected', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE payment_option_selected_flag = 1

  UNION ALL

  SELECT 8, 'Payment Made', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE payment_made_flag = 1

  UNION ALL

  SELECT 9, 'Repayment Plan Created', COUNT(DISTINCT customer_id)
  FROM customer_stage_flags
  WHERE repayment_plan_created_flag = 1
),

stage_comparison AS (
  SELECT
    stage_order,
    funnel_stage,
    customers,
    LAG(customers) OVER (ORDER BY stage_order) AS previous_stage_customers
  FROM funnel_counts
)

SELECT
  stage_order,
  funnel_stage,
  customers,
  previous_stage_customers,
  ROUND(customers * 100.0 / previous_stage_customers, 2) AS stage_to_stage_conversion_percent,
  ROUND((previous_stage_customers - customers) * 100.0 / previous_stage_customers, 2) AS stage_drop_off_percent
FROM stage_comparison
WHERE previous_stage_customers IS NOT NULL
ORDER BY stage_order;


-- ============================================================
-- SECTION 3: AFFORDABILITY ASSESSMENT SUB-FUNNEL
-- Purpose:
--   Affordability assessment is an optional branch, not a mandatory
--   funnel step. Therefore, it should be analysed separately from
--   the main funnel.
--
-- Business Question:
--   How many customers start and complete affordability assessment,
--   and how does that connect to repayment plan creation?
-- ============================================================

WITH affordability_flags AS (
  SELECT
    c.customer_id,
    MAX(CASE WHEN je.event_name = 'balance_viewed' THEN 1 ELSE 0 END) AS balance_viewed_flag,
    MAX(CASE WHEN je.event_name = 'affordability_started' THEN 1 ELSE 0 END) AS affordability_started_flag,
    MAX(CASE WHEN je.event_name = 'affordability_completed' THEN 1 ELSE 0 END) AS affordability_completed_flag,
    MAX(CASE WHEN je.event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_created_flag,
    MAX(CASE WHEN rp.first_instalment_paid_flag = 1 THEN 1 ELSE 0 END) AS first_instalment_paid_flag
  FROM `debtstream-analytics-project.debtstream_analytics.customers` c
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.journey_events` je
    ON c.customer_id = je.customer_id
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.repayment_plans` rp
    ON c.customer_id = rp.customer_id
  GROUP BY c.customer_id
),

affordability_funnel AS (
  SELECT 1 AS stage_order, 'Balance Viewed' AS funnel_stage, COUNT(DISTINCT customer_id) AS customers
  FROM affordability_flags
  WHERE balance_viewed_flag = 1

  UNION ALL

  SELECT 2, 'Affordability Started', COUNT(DISTINCT customer_id)
  FROM affordability_flags
  WHERE affordability_started_flag = 1

  UNION ALL

  SELECT 3, 'Affordability Completed', COUNT(DISTINCT customer_id)
  FROM affordability_flags
  WHERE affordability_completed_flag = 1

  UNION ALL

  SELECT 4, 'Repayment Plan Created', COUNT(DISTINCT customer_id)
  FROM affordability_flags
  WHERE repayment_plan_created_flag = 1

  UNION ALL

  SELECT 5, 'First Instalment Paid', COUNT(DISTINCT customer_id)
  FROM affordability_flags
  WHERE first_instalment_paid_flag = 1
)

SELECT
  stage_order,
  funnel_stage,
  customers,
  ROUND(customers * 100.0 / FIRST_VALUE(customers) OVER (ORDER BY stage_order), 2) AS percent_of_balance_viewers
FROM affordability_funnel
ORDER BY stage_order;


-- ============================================================
-- SECTION 4: FUNNEL PERFORMANCE BY PRIMARY COMMUNICATION CHANNEL
-- Purpose:
--   Compare funnel performance by the first communication channel
--   used for each customer.
--
-- Business Question:
--   Which channel drives stronger engagement and repayment outcomes?
--
-- Note:
--   A customer can receive multiple communications. To avoid double
--   counting, this query assigns each customer to their first recorded
--   communication channel.
-- ============================================================

WITH first_channel AS (
  SELECT
    customer_id,
    channel AS primary_channel
  FROM (
    SELECT
      customer_id,
      channel,
      sent_date,
      ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY sent_date ASC, communication_id ASC
      ) AS rn
    FROM `debtstream-analytics-project.debtstream_analytics.communication_events`
  )
  WHERE rn = 1
),

customer_stage_flags AS (
  SELECT
    c.customer_id,
    fc.primary_channel,
    MAX(CASE WHEN je.event_name = 'invite_delivered' THEN 1 ELSE 0 END) AS invite_delivered_flag,
    MAX(CASE WHEN je.event_name = 'link_opened' THEN 1 ELSE 0 END) AS link_opened_flag,
    MAX(CASE WHEN je.event_name = 'identity_verified' THEN 1 ELSE 0 END) AS identity_verified_flag,
    MAX(CASE WHEN je.event_name = 'balance_viewed' THEN 1 ELSE 0 END) AS balance_viewed_flag,
    MAX(CASE WHEN je.event_name = 'payment_option_selected' THEN 1 ELSE 0 END) AS payment_option_selected_flag,
    MAX(CASE WHEN je.event_name = 'payment_made' THEN 1 ELSE 0 END) AS payment_made_flag,
    MAX(CASE WHEN je.event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_created_flag
  FROM `debtstream-analytics-project.debtstream_analytics.customers` c
  LEFT JOIN first_channel fc
    ON c.customer_id = fc.customer_id
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.journey_events` je
    ON c.customer_id = je.customer_id
  GROUP BY c.customer_id, fc.primary_channel
)

SELECT
  primary_channel,
  COUNT(DISTINCT customer_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END) AS invite_delivered_customers,
  COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) AS link_opened_customers,
  COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) AS identity_verified_customers,
  COUNT(DISTINCT CASE WHEN balance_viewed_flag = 1 THEN customer_id END) AS balance_viewed_customers,
  COUNT(DISTINCT CASE WHEN payment_option_selected_flag = 1 THEN customer_id END) AS payment_option_selected_customers,
  COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) AS payment_made_customers,
  COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) AS repayment_plan_created_customers,

  ROUND(COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS link_open_rate,

  ROUND(COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END), 0), 2) AS verification_after_open_rate,

  ROUND(COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS payment_conversion_rate,

  ROUND(COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS plan_setup_rate

FROM customer_stage_flags
GROUP BY primary_channel
ORDER BY total_customers DESC;


-- ============================================================
-- SECTION 5: FUNNEL PERFORMANCE BY BALANCE BAND
-- Purpose:
--   Compare how customers with different debt balances move through
--   the digital self-service journey.
--
-- Business Question:
--   Are low-balance customers more likely to pay, and are medium-
--   balance customers more likely to set up repayment plans?
-- ============================================================

WITH customer_stage_flags AS (
  SELECT
    c.customer_id,
    c.balance_band,
    MAX(CASE WHEN je.event_name = 'invite_delivered' THEN 1 ELSE 0 END) AS invite_delivered_flag,
    MAX(CASE WHEN je.event_name = 'link_opened' THEN 1 ELSE 0 END) AS link_opened_flag,
    MAX(CASE WHEN je.event_name = 'identity_verified' THEN 1 ELSE 0 END) AS identity_verified_flag,
    MAX(CASE WHEN je.event_name = 'balance_viewed' THEN 1 ELSE 0 END) AS balance_viewed_flag,
    MAX(CASE WHEN je.event_name = 'payment_option_selected' THEN 1 ELSE 0 END) AS payment_option_selected_flag,
    MAX(CASE WHEN je.event_name = 'payment_made' THEN 1 ELSE 0 END) AS payment_made_flag,
    MAX(CASE WHEN je.event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_created_flag
  FROM `debtstream-analytics-project.debtstream_analytics.customers` c
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.journey_events` je
    ON c.customer_id = je.customer_id
  GROUP BY c.customer_id, c.balance_band
)

SELECT
  balance_band,
  COUNT(DISTINCT customer_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END) AS invite_delivered_customers,
  COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) AS link_opened_customers,
  COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) AS identity_verified_customers,
  COUNT(DISTINCT CASE WHEN payment_option_selected_flag = 1 THEN customer_id END) AS payment_option_selected_customers,
  COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) AS payment_made_customers,
  COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) AS repayment_plan_created_customers,

  ROUND(COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS link_open_rate,

  ROUND(COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS payment_conversion_rate,

  ROUND(COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS plan_setup_rate

FROM customer_stage_flags
GROUP BY balance_band
ORDER BY
  CASE balance_band
    WHEN 'Low' THEN 1
    WHEN 'Medium' THEN 2
    WHEN 'High' THEN 3
    WHEN 'Very High' THEN 4
    ELSE 5
  END;


-- ============================================================
-- SECTION 6: FUNNEL PERFORMANCE BY DEBT AGE BAND
-- Purpose:
--   Compare funnel performance across newer and older debts.
--
-- Business Question:
--   Do newer debts perform better through the digital collections
--   journey than older debts?
-- ============================================================

WITH customer_stage_flags AS (
  SELECT
    c.customer_id,
    c.debt_age_band,
    MAX(CASE WHEN je.event_name = 'invite_delivered' THEN 1 ELSE 0 END) AS invite_delivered_flag,
    MAX(CASE WHEN je.event_name = 'link_opened' THEN 1 ELSE 0 END) AS link_opened_flag,
    MAX(CASE WHEN je.event_name = 'identity_verified' THEN 1 ELSE 0 END) AS identity_verified_flag,
    MAX(CASE WHEN je.event_name = 'payment_option_selected' THEN 1 ELSE 0 END) AS payment_option_selected_flag,
    MAX(CASE WHEN je.event_name = 'payment_made' THEN 1 ELSE 0 END) AS payment_made_flag,
    MAX(CASE WHEN je.event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_created_flag
  FROM `debtstream-analytics-project.debtstream_analytics.customers` c
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.journey_events` je
    ON c.customer_id = je.customer_id
  GROUP BY c.customer_id, c.debt_age_band
)

SELECT
  debt_age_band,
  COUNT(DISTINCT customer_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END) AS invite_delivered_customers,
  COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) AS link_opened_customers,
  COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) AS identity_verified_customers,
  COUNT(DISTINCT CASE WHEN payment_option_selected_flag = 1 THEN customer_id END) AS payment_option_selected_customers,
  COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) AS payment_made_customers,
  COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) AS repayment_plan_created_customers,

  ROUND(COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS link_open_rate,

  ROUND(COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS payment_conversion_rate,

  ROUND(COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS plan_setup_rate

FROM customer_stage_flags
GROUP BY debt_age_band
ORDER BY
  CASE debt_age_band
    WHEN '0-30 days' THEN 1
    WHEN '31-90 days' THEN 2
    WHEN '91-180 days' THEN 3
    WHEN '181-365 days' THEN 4
    WHEN '365+ days' THEN 5
    ELSE 6
  END;


-- ============================================================
-- SECTION 7: FUNNEL PERFORMANCE BY CLIENT TYPE
-- Purpose:
--   Analyse whether different client portfolios perform differently
--   through the digital collections journey.
--
-- Business Question:
--   Which client types see stronger self-service engagement and
--   repayment outcomes?
-- ============================================================

WITH customer_stage_flags AS (
  SELECT
    c.customer_id,
    cl.client_type,
    MAX(CASE WHEN je.event_name = 'invite_delivered' THEN 1 ELSE 0 END) AS invite_delivered_flag,
    MAX(CASE WHEN je.event_name = 'link_opened' THEN 1 ELSE 0 END) AS link_opened_flag,
    MAX(CASE WHEN je.event_name = 'identity_verified' THEN 1 ELSE 0 END) AS identity_verified_flag,
    MAX(CASE WHEN je.event_name = 'payment_option_selected' THEN 1 ELSE 0 END) AS payment_option_selected_flag,
    MAX(CASE WHEN je.event_name = 'payment_made' THEN 1 ELSE 0 END) AS payment_made_flag,
    MAX(CASE WHEN je.event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_created_flag
  FROM `debtstream-analytics-project.debtstream_analytics.customers` c
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.clients` cl
    ON c.client_id = cl.client_id
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.journey_events` je
    ON c.customer_id = je.customer_id
  GROUP BY c.customer_id, cl.client_type
)

SELECT
  client_type,
  COUNT(DISTINCT customer_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END) AS invite_delivered_customers,
  COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) AS link_opened_customers,
  COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) AS identity_verified_customers,
  COUNT(DISTINCT CASE WHEN payment_option_selected_flag = 1 THEN customer_id END) AS payment_option_selected_customers,
  COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) AS payment_made_customers,
  COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) AS repayment_plan_created_customers,

  ROUND(COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS link_open_rate,

  ROUND(COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS payment_conversion_rate,

  ROUND(COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS plan_setup_rate

FROM customer_stage_flags
GROUP BY client_type
ORDER BY payment_conversion_rate DESC;


-- ============================================================
-- SECTION 8: MONTHLY FUNNEL TREND
-- Purpose:
--   Track how digital engagement and repayment outcomes changed
--   over time during the project period.
--
-- Business Question:
--   Did digital collections performance vary month by month?
-- ============================================================

WITH customer_stage_flags AS (
  SELECT
    c.customer_id,
    DATE_TRUNC(c.account_upload_date, MONTH) AS upload_month,
    MAX(CASE WHEN je.event_name = 'invite_delivered' THEN 1 ELSE 0 END) AS invite_delivered_flag,
    MAX(CASE WHEN je.event_name = 'link_opened' THEN 1 ELSE 0 END) AS link_opened_flag,
    MAX(CASE WHEN je.event_name = 'identity_verified' THEN 1 ELSE 0 END) AS identity_verified_flag,
    MAX(CASE WHEN je.event_name = 'payment_made' THEN 1 ELSE 0 END) AS payment_made_flag,
    MAX(CASE WHEN je.event_name = 'repayment_plan_created' THEN 1 ELSE 0 END) AS repayment_plan_created_flag
  FROM `debtstream-analytics-project.debtstream_analytics.customers` c
  LEFT JOIN `debtstream-analytics-project.debtstream_analytics.journey_events` je
    ON c.customer_id = je.customer_id
  GROUP BY c.customer_id, upload_month
)

SELECT
  upload_month,
  COUNT(DISTINCT customer_id) AS uploaded_customers,
  COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END) AS invite_delivered_customers,
  COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) AS link_opened_customers,
  COUNT(DISTINCT CASE WHEN identity_verified_flag = 1 THEN customer_id END) AS identity_verified_customers,
  COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) AS payment_made_customers,
  COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) AS repayment_plan_created_customers,

  ROUND(COUNT(DISTINCT CASE WHEN link_opened_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS link_open_rate,

  ROUND(COUNT(DISTINCT CASE WHEN payment_made_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS payment_conversion_rate,

  ROUND(COUNT(DISTINCT CASE WHEN repayment_plan_created_flag = 1 THEN customer_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN invite_delivered_flag = 1 THEN customer_id END), 0), 2) AS plan_setup_rate

FROM customer_stage_flags
GROUP BY upload_month
ORDER BY upload_month;


-- ============================================================
-- NEXT STEPS
-- After completing this funnel and channel analysis, continue to:
--
--   03_SMS_AB_Testing.sql
--
-- This next file will:
--   1. Prepare the SMS A/B test customer-level dataset
--   2. Compare Control vs Variant engagement outcomes
--   3. Compare payment and repayment plan outcomes
--   4. Segment A/B test performance by balance band
--   5. Prepare outputs for Python statistical testing
--
-- Recommended exports from this file:
--   1. overall_funnel.csv
--   2. stage_drop_off.csv
--   3. funnel_by_channel.csv
--   4. funnel_by_balance_band.csv
--   5. monthly_funnel_trend.csv
-- ============================================================