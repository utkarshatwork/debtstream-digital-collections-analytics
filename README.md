<p align="center">
  <img src="assets/DebtStream Logo" alt="DebtStream Digital Collections Analytics" width="180"/>
</p>

<h1 align="center" style="color:#111A33;">DebtStream: Digital Collections Analytics</h1>
<h3 align="center" style="color:#F47B20;">Digital Collections Funnel and Payment Journey Optimisation</h3>

<p align="center">
  <img src="https://img.shields.io/badge/BigQuery-4285F4?style=flat&logo=googlebigquery&logoColor=white"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black"/>
  &nbsp;
  <img src="https://img.shields.io/badge/Status-Complete-2E7D32?style=flat"/>
</p>

---

<p align="center">
  📄 <a href="docs/DebtStream_Analysis_Report.pdf"><strong>Download Full Project Report (PDF)</strong></a>
</p>

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Business Context and Problem Statement](#business-context-and-problem-statement)
3. [Data Overview](#data-overview)
4. [Project Structure](#project-structure)
5. [Tools and Technologies](#tools-and-technologies)
6. [Methods](#methods)
7. [Key Insights](#key-insights)
8. [Results and Conclusion](#results-and-conclusion)
9. [Dashboard Preview](#dashboard-preview)
10. [How to Run the Project](#how-to-run-the-project)
11. [Author](#author)

---

## Project Overview

An end-to-end digital collections analytics project for **DebtStream**, a B2B SaaS fintech platform that moves customer repayment journeys into a digital self-service flow. The project analyses **10,000 customer accounts** uploaded between June 2022 and May 2023 across the full analytical pipeline: data engineering and analytical view construction in BigQuery SQL, exploratory data analysis and statistical testing in Python, and a compact three-page interactive stakeholder dashboard built in Power BI.

---

## Business Context and Problem Statement

DebtStream helps lenders, utility providers, telecoms companies, debt purchasers, debt collection agencies and legal collections firms move customers into a digital self-service repayment journey. The platform's commercial value depends not on delivering reminders alone, but on whether customers open the journey, verify their identity, view their balance, select a repayment option, make a payment, and sustain a repayment plan over time.

This project analyses the full collections journey to answer:

- Where do customers drop off in the digital collections funnel, and which stage creates the biggest customer loss?
- Which primary communication channels drive customers into the self-service journey most effectively?
- Does supportive SMS repayment messaging outperform a direct payment reminder, and for which customer segments?
- Which balance bands and debt age bands recover better or worse through the digital collections process?
- Does completing the affordability assessment improve repayment plan sustainability and reduce broken-plan rates?
- Which customer segments combine weak recovery rates with high outstanding balance exposure?
- What should DebtStream prioritise to improve payment conversion, plan sustainability, and overall portfolio recovery?

---

## Data Overview

- **6 raw source tables:** `clients`, `customers`, `communication_events`, `journey_events`, `payments`, `repayment_plans`
- **7 analytical views built in BigQuery:** `vw_customer_summary`, `vw_ab_test_customer_outcomes`, `vw_funnel_summary`, `vw_channel_performance`, `vw_ab_test_summary`, `vw_recovery_summary`, `vw_plan_performance`
- **3 views imported into Power BI** as the primary reporting layer
- **Analysis period:** June 2022 to May 2023
- **Scale:** 10,000 customers · 19,244 communication events · 50,699 journey events · 2,362 payments · 743 repayment plans · 1,936 A/B test customers

---

## Project Structure

```
DebtStream_Digital_Collections_Project/
│
├── README.md
├── .gitignore
│
├── assets/
│   ├── DebtStream Logo                         # Project logo
│   ├── Overview & Funnel Performance           # Power BI Page 1 screenshot
│   ├── SMS AB Test                             # Power BI Page 2 screenshot
│   └── Risk & Recovery                         # Power BI Page 3 screenshot
│
├── data/
│   └── raw/
│       ├── clients.csv
│       ├── customers.csv
│       ├── communication_events.csv
│       ├── journey_events.csv
│       ├── payments.csv
│       └── repayment_plans.csv
│
├── docs/
│   ├── DebtStream Analysis Report.pdf          # Full project analytics report
│   ├── debtstream_data_dictionary              # Field definitions and data types
│   └── debtstream_validation_summary           # SQL validation results summary
│
├── notebooks/
│   ├── 01_Data_Validation_and_EDA.ipynb        # Data validation, EDA, funnel and channel analysis
│   ├── 02_SMS_AB_Testing_Analysis.ipynb        # A/B test comparison and statistical significance testing
│   └── 03_Repayment_and_Recovery_Insights.ipynb # Recovery analysis, segmentation and affordability impact
│
├── outputs/
│   ├── charts/                                 # Exported Python chart PNGs
│   └── summary_tables/                         # Exported SQL summary CSVs
│
├── powerbi/
│   └── DebtStream_Analytics.pbix               # Interactive three-page Power BI dashboard
│
└── sql/
    ├── 01_Setup_and_Base_Tables.sql            # Table validation, row counts, integrity checks
    ├── 02_Funnel_and_Channel_Analysis.sql      # Funnel, drop-off, channel and monthly trend
    ├── 03_SMS_AB_Testing.sql                   # A/B test population, outcomes and lift summary
    ├── 04_Repayment_and_Recovery.sql           # Recovery by segment, plan sustainability, affordability
    └── 05_PowerBI_Views.sql                    # All 7 BigQuery reporting views
```

---

## Tools and Technologies

| Tool | Purpose |
|---|---|
| **BigQuery SQL** | Raw table ingestion and validation, funnel analysis, SMS A/B test outputs, recovery analysis and Power BI reporting views |
| **Python** (Pandas, Matplotlib, Seaborn) | Data validation, EDA, statistical significance testing (z-tests and Welch t-test), recovery insights and chart exports |
| **Power BI Desktop** | Three-page interactive dashboard with DAX measures, dynamic SWITCH visuals and conditional formatting |

---

## Methods

- **Customer-Level Funnel Analysis:** digital collections journey measured across nine stages using distinct `customer_id` counts to prevent inflation from repeated communications or journey events. Stage-to-stage drop-off rates calculated at each transition to identify the highest-friction points in the customer journey.

- **SMS A/B Test Analysis:** two-group comparison of a direct payment reminder (Control, 929 customers) against a supportive repayment-options message (Variant, 1,007 customers). Analysis conducted at customer level to avoid double-counting. Two-proportion z-tests applied to all five binary outcome metrics and a Welch t-test used for average amount collected to confirm statistical significance.

- **Recovery and Segment Analysis:** recovery rate calculated at individual customer level as successful amount collected divided by outstanding balance. Segmented by balance band, debt age band, client type and portfolio type. A balance band by debt age band recovery matrix produced to identify highest-risk segment combinations.

- **Affordability Impact Analysis:** repayment plan quality compared between customers who completed and did not complete the affordability assessment, measuring first instalment paid rate and broken-plan rate as the two primary plan sustainability indicators.

- **Power BI Data Modelling:** three BigQuery views imported as Fact Customer (10,000 rows), Fact AB Test (1,936 rows) and Monthly Funnel Trend (4,360 rows). Three disconnected DAX DATATABLE helper tables created for dynamic funnel and A/B test visuals via SWITCH measures. 60 DAX measures built across seven groups and validated against SQL benchmark outputs.

---

## Key Insights

- **62.19% of customers who received a digital invite never clicked through to the journey.** The Invite Delivered to Link Opened transition is the single largest drop-off in the entire funnel, representing a far greater opportunity than optimising any later stage.

- **SMS drives the highest digital engagement at scale** with a 41.11% journey start rate, ahead of Email (35.14%) and Letter (26.70%). SMS also leads on payment conversion rate, making it the strongest end-to-end digital collections channel.

- **Variant (supportive) SMS outperformed Control (direct reminder) on four of five outcome metrics.** Plan setup rate: 10.53% vs 6.14% (+4.39pp). Average amount collected: £36.35 vs £29.95 (+£6.40 per customer). Statistically significant on plan setup and first instalment paid rate (p < 0.05).

- **One-off payment rate was the only metric where Control outperformed Variant** (6.78% vs 4.77%), confirming that supportive messaging deliberately shifts customers toward structured repayment plans rather than single payments. This is a commercially superior outcome for long-term recovery.

- **Overall recovery rate is 3.31% on £9,996,602 of outstanding balance.** Recovery declines sharply by balance band: Low (10.57%), Medium (5.00%), High (3.22%), Very High (0.89%). Very High balance accounts carry £3,192,271 of outstanding debt and a 72.22% broken-plan rate, the highest combined commercial risk in the portfolio.

- **Recovery declines 4x as debt ages.** Accounts aged 0-30 days recover at 6.10%, while accounts older than 365 days recover at just 1.48%. Early intervention is the single most effective lever for improving portfolio-level recovery.

- **Telecoms clients recover at 6.00%, Legal Collections at 0.84%.** Client type has a material impact on recovery outcomes. A single portfolio-wide benchmark masks significant performance differences across client types.

- **Only 2.03% of customers completed the affordability assessment**, yet those who did paid their first instalment at 86.21% vs 75.19% and broke their plans at 31.53% vs 43.89%. The vast majority of the available plan sustainability benefit is currently unrealised.

---

## Results and Conclusion

The project confirms that DebtStream's digital collections performance is structurally constrained by a single dominant problem: the transition from delivered invite to digital journey start. Fixing this one step, through better message content, timing and channel sequencing, creates more opportunity than any other intervention available.

The SMS A/B test provides statistically validated evidence that supportive repayment-options messaging outperforms the direct payment reminder for plan setup and long-term recovery quality. This is not a marginal finding. Variant customers generated £6.40 more per customer on average with a plan setup rate nearly double that of Control. The recommended approach is a segmented messaging strategy: supportive messaging for Medium and higher-balance customers who need flexibility, and direct reminders retained for customers with higher immediate payment readiness.

Recovery analysis confirms that balance band and debt age must be treated as the two core segmentation variables for collections strategy. Low-balance, newly uploaded accounts are well-suited to direct payment journeys. Medium-balance accounts respond strongly to plan setup nudges. High and Very High balance accounts require affordability-led support, closer plan monitoring, and likely specialist intervention given their 48-72% broken-plan rates.

Affordability completion stands out as the most underutilised lever in the dataset. An 11pp improvement in first instalment paid rate and a 12pp reduction in broken-plan rate from completing a single assessment step represents substantial value currently left unrealised for 97.97% of customers.

---

## Dashboard Preview

**Page 1: Overview and Funnel Performance**

![Overview and Funnel Performance](assets/Overview%20%26%20Funnel%20Performance)

**Page 2: SMS A/B Test and Messaging Strategy**

![SMS AB Test](assets/SMS%20AB%20Test)

**Page 3: Segment Recovery and Risk**

![Risk and Recovery](assets/Risk%20%26%20Recovery)

---

## How to Run the Project

### BigQuery SQL

1. Create a BigQuery project and dataset (e.g. `debtstream-analytics-project.debtstream_analytics`)
2. Upload the six raw CSV files from `data/raw/` as tables using the following names:
   `clients`, `customers`, `communication_events`, `journey_events`, `payments`, `repayment_plans`
3. Run SQL files in order from `sql/`:
   - `01_Setup_and_Base_Tables.sql` validates ingestion, checks row counts, duplicates, date ranges and referential integrity
   - `02_Funnel_and_Channel_Analysis.sql` builds the customer-level funnel and channel performance analysis
   - `03_SMS_AB_Testing.sql` creates `vw_ab_test_customer_outcomes` and compares Control vs Variant outcomes
   - `04_Repayment_and_Recovery.sql` analyses recovery performance by segment and plan sustainability
   - `05_PowerBI_Views.sql` creates all 7 BigQuery reporting views
4. Export summary outputs as CSVs to `outputs/summary_tables/` as specified in each file's NEXT STEPS comment

### Python

1. Clone the repository
2. Install dependencies:
   ```
   pip install pandas numpy matplotlib seaborn scipy google-cloud-bigquery jupyter
   ```
3. Open Jupyter Notebook or JupyterLab
4. Run notebooks in order from `notebooks/`:
   - `01_Data_Validation_and_EDA.ipynb` covers data validation, EDA, funnel visualisation and channel analysis
   - `02_SMS_AB_Testing_Analysis.ipynb` covers A/B test comparison and statistical significance testing
   - `03_Repayment_and_Recovery_Insights.ipynb` covers recovery analysis, segmentation and affordability impact
5. Charts are saved automatically to `outputs/charts/`

### Power BI

1. Install Power BI Desktop (free from Microsoft)
2. Open `powerbi/DebtStream_Analytics.pbix` in Power BI Desktop
3. Sign in with the Google account that has access to the BigQuery project
4. In Home, click Transform Data to open Power Query, then Close and Apply
5. Click Refresh to reload all three tables from BigQuery
6. All 60 DAX measures and three helper tables are pre-built and ready to use

---

## Author

**Utkarsh Pandey**
Data Analyst

[![GitHub](https://img.shields.io/badge/GitHub-Profile-181717?style=flat&logo=github&logoColor=white)](https://github.com/utkarshisatwork)
