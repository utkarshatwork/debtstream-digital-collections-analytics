-- ============================================================
-- DebtStream Digital Collections Funnel & Payment Journey Optimisation
-- FILE: 01_Setup_and_Base_Tables.sql
-- DESCRIPTION:
--   This file validates the successful ingestion of the six core
--   DebtStream project tables into BigQuery. It checks row counts,
--   table previews, date ranges, duplicate IDs, relationship integrity,
--   numeric field sanity, and key categorical distributions.
--
--   This is the foundation step before building the funnel analysis,
--   SMS A/B testing analysis, repayment/recovery analysis, and Power BI
--   reporting views.
--
-- PLATFORM: BigQuery
-- DATASET: debtstream_analytics
-- PROJECT: debtstream-analytics-project
-- ============================================================


-- ============================================================
-- SECTION 1: TABLE ROW COUNT CHECKS
-- Purpose:
--   Confirm that all six project CSV files have been uploaded
--   successfully into BigQuery and the row counts match the expected
--   dataset validation summary.
-- ============================================================

SELECT 'clients' AS table_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.clients`

UNION ALL

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.customers`

UNION ALL

SELECT 'communication_events' AS table_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.communication_events`

UNION ALL

SELECT 'journey_events' AS table_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.journey_events`

UNION ALL

SELECT 'payments' AS table_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.payments`

UNION ALL

SELECT 'repayment_plans' AS table_name, COUNT(*) AS row_count
FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`;


-- ============================================================
-- SECTION 2: TABLE PREVIEW CHECKS
-- Purpose:
--   Preview a small sample of each table to understand structure,
--   column names, and example values before writing analytical queries.
-- ============================================================

-- 2.1 Preview clients table
SELECT *
FROM `debtstream-analytics-project.debtstream_analytics.clients`
LIMIT 10;


-- 2.2 Preview customers table
SELECT *
FROM `debtstream-analytics-project.debtstream_analytics.customers`
LIMIT 10;


-- 2.3 Preview communication events table
SELECT *
FROM `debtstream-analytics-project.debtstream_analytics.communication_events`
LIMIT 10;


-- 2.4 Preview journey events table
SELECT *
FROM `debtstream-analytics-project.debtstream_analytics.journey_events`
LIMIT 10;


-- 2.5 Preview payments table
SELECT *
FROM `debtstream-analytics-project.debtstream_analytics.payments`
LIMIT 10;


-- 2.6 Preview repayment plans table
SELECT *
FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
LIMIT 10;


-- ============================================================
-- SECTION 3: DATE RANGE CHECKS
-- Purpose:
--   Validate that the dataset reflects the intended DebtStream work
--   period from June 2022 to May 2023, while allowing journey events
--   and payments to occur shortly after upload/invite dates.
-- ============================================================

-- 3.1 Customer account upload date range
SELECT
  MIN(account_upload_date) AS earliest_upload_date,
  MAX(account_upload_date) AS latest_upload_date
FROM `debtstream-analytics-project.debtstream_analytics.customers`;


-- 3.2 Communication sent date range
SELECT
  MIN(sent_date) AS earliest_sent_date,
  MAX(sent_date) AS latest_sent_date
FROM `debtstream-analytics-project.debtstream_analytics.communication_events`;


-- 3.3 Journey event date range
SELECT
  MIN(event_date) AS earliest_event_date,
  MAX(event_date) AS latest_event_date
FROM `debtstream-analytics-project.debtstream_analytics.journey_events`;


-- 3.4 Payment date range
SELECT
  MIN(payment_date) AS earliest_payment_date,
  MAX(payment_date) AS latest_payment_date
FROM `debtstream-analytics-project.debtstream_analytics.payments`;


-- 3.5 Repayment plan creation date range
SELECT
  MIN(plan_created_date) AS earliest_plan_date,
  MAX(plan_created_date) AS latest_plan_date
FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`;


-- ============================================================
-- SECTION 4: DUPLICATE ID CHECKS
-- Purpose:
--   Check whether supposedly unique IDs are duplicated.
--   A count above 1 means the ID appears more than once.
-- ============================================================

-- 4.1 Duplicate client IDs
SELECT
  client_id,
  COUNT(*) AS duplicate_count
FROM `debtstream-analytics-project.debtstream_analytics.clients`
GROUP BY client_id
HAVING COUNT(*) > 1;


-- 4.2 Duplicate customer IDs
SELECT
  customer_id,
  COUNT(*) AS duplicate_count
FROM `debtstream-analytics-project.debtstream_analytics.customers`
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- 4.3 Duplicate communication IDs
SELECT
  communication_id,
  COUNT(*) AS duplicate_count
FROM `debtstream-analytics-project.debtstream_analytics.communication_events`
GROUP BY communication_id
HAVING COUNT(*) > 1;


-- 4.4 Duplicate journey event IDs
SELECT
  event_id,
  COUNT(*) AS duplicate_count
FROM `debtstream-analytics-project.debtstream_analytics.journey_events`
GROUP BY event_id
HAVING COUNT(*) > 1;


-- 4.5 Duplicate payment IDs
SELECT
  payment_id,
  COUNT(*) AS duplicate_count
FROM `debtstream-analytics-project.debtstream_analytics.payments`
GROUP BY payment_id
HAVING COUNT(*) > 1;


-- 4.6 Duplicate repayment plan IDs
SELECT
  plan_id,
  COUNT(*) AS duplicate_count
FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
GROUP BY plan_id
HAVING COUNT(*) > 1;


-- ============================================================
-- SECTION 5: RELATIONSHIP INTEGRITY CHECKS
-- Purpose:
--   Confirm that child tables only contain customer_id and client_id
--   values that exist in the base customers and clients tables.
-- ============================================================

-- 5.1 Communication events with customer IDs not found in customers
SELECT
  COUNT(*) AS unmatched_communication_customer_ids
FROM `debtstream-analytics-project.debtstream_analytics.communication_events` ce
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.customers` c
  ON ce.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 5.2 Journey events with customer IDs not found in customers
SELECT
  COUNT(*) AS unmatched_journey_customer_ids
FROM `debtstream-analytics-project.debtstream_analytics.journey_events` je
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.customers` c
  ON je.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 5.3 Payments with customer IDs not found in customers
SELECT
  COUNT(*) AS unmatched_payment_customer_ids
FROM `debtstream-analytics-project.debtstream_analytics.payments` p
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.customers` c
  ON p.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 5.4 Repayment plans with customer IDs not found in customers
SELECT
  COUNT(*) AS unmatched_plan_customer_ids
FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans` rp
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.customers` c
  ON rp.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 5.5 Customers with client IDs not found in clients
SELECT
  COUNT(*) AS unmatched_customer_client_ids
FROM `debtstream-analytics-project.debtstream_analytics.customers` c
LEFT JOIN `debtstream-analytics-project.debtstream_analytics.clients` cl
  ON c.client_id = cl.client_id
WHERE cl.client_id IS NULL;


-- ============================================================
-- SECTION 6: NUMERIC SANITY CHECKS
-- Purpose:
--   Validate that important numeric fields such as debt balance,
--   payment amount, and repayment plan amount have realistic values.
-- ============================================================

-- 6.1 Debt balance range
SELECT
  MIN(debt_balance) AS min_debt_balance,
  MAX(debt_balance) AS max_debt_balance,
  AVG(debt_balance) AS avg_debt_balance
FROM `debtstream-analytics-project.debtstream_analytics.customers`;


-- 6.2 Payment amount range
SELECT
  MIN(payment_amount) AS min_payment_amount,
  MAX(payment_amount) AS max_payment_amount,
  AVG(payment_amount) AS avg_payment_amount
FROM `debtstream-analytics-project.debtstream_analytics.payments`;


-- 6.3 Repayment plan amount range
SELECT
  MIN(plan_amount) AS min_plan_amount,
  MAX(plan_amount) AS max_plan_amount,
  AVG(plan_amount) AS avg_plan_amount
FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`;


-- 6.4 Check for negative or zero debt balances
SELECT
  COUNT(*) AS invalid_debt_balance_records
FROM `debtstream-analytics-project.debtstream_analytics.customers`
WHERE debt_balance <= 0;


-- 6.5 Check for negative payment amounts
SELECT
  COUNT(*) AS negative_payment_records
FROM `debtstream-analytics-project.debtstream_analytics.payments`
WHERE payment_amount < 0;


-- ============================================================
-- SECTION 7: CATEGORY DISTRIBUTION CHECKS
-- Purpose:
--   Review the distribution of key categorical variables that will
--   be used later in funnel, A/B testing, repayment, and recovery
--   analysis.
-- ============================================================

-- 7.1 Client type distribution
SELECT
  client_type,
  COUNT(*) AS client_count
FROM `debtstream-analytics-project.debtstream_analytics.clients`
GROUP BY client_type
ORDER BY client_count DESC;


-- 7.2 Customer balance band distribution
SELECT
  balance_band,
  COUNT(*) AS customer_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_share_percent
FROM `debtstream-analytics-project.debtstream_analytics.customers`
GROUP BY balance_band
ORDER BY customer_count DESC;


-- 7.3 Debt age band distribution
SELECT
  debt_age_band,
  COUNT(*) AS customer_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_share_percent
FROM `debtstream-analytics-project.debtstream_analytics.customers`
GROUP BY debt_age_band
ORDER BY customer_count DESC;


-- 7.4 Communication channel distribution
SELECT
  channel,
  COUNT(*) AS communication_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS communication_share_percent
FROM `debtstream-analytics-project.debtstream_analytics.communication_events`
GROUP BY channel
ORDER BY communication_count DESC;


-- 7.5 Journey event distribution
SELECT
  event_name,
  COUNT(*) AS event_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS event_share_percent
FROM `debtstream-analytics-project.debtstream_analytics.journey_events`
GROUP BY event_name
ORDER BY event_count DESC;


-- 7.6 Payment status distribution
SELECT
  payment_status,
  COUNT(*) AS payment_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS payment_share_percent
FROM `debtstream-analytics-project.debtstream_analytics.payments`
GROUP BY payment_status
ORDER BY payment_count DESC;


-- 7.7 Repayment plan status distribution
SELECT
  plan_status,
  COUNT(*) AS plan_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS plan_share_percent
FROM `debtstream-analytics-project.debtstream_analytics.repayment_plans`
GROUP BY plan_status
ORDER BY plan_count DESC;


-- ============================================================
-- NEXT STEPS
-- After completing these setup and validation checks, continue to:
--
--   02_Funnel_and_Channel_Analysis.sql
--
-- This next file will analyse:
--   1. Overall digital collections funnel
--   2. Stage-to-stage drop-off rates
--   3. Funnel performance by channel
--   4. Funnel performance by balance band
--   5. Funnel performance by debt age band
-- ============================================================