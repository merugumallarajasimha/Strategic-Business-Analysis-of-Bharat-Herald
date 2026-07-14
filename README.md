# 📊 Bharat Herald  Print-to-Digital Strategic Business Analysis

**End-to-end data analytics project**: ETL pipeline → PostgreSQL data warehouse → SQL analytics → Power BI dashboard, built to help a fictional regional news publisher decide where to launch its digital relaunch.

---

## 🧩 Business Context

Bharat Herald is a regional news publisher facing declining print circulation and volatile print ad revenue. The executive team needed a data-backed answer to one question:

> **Which cities should we prioritize for a digital relaunch  and why?**

This project answers that using 6 years of print sales, ad revenue, and digital pilot data (2019–2024) across multiple Indian cities.

---

## 🏗️ Architecture

```
Excel / CSV files  →  Python ETL (pandas)  →  PostgreSQL (3-schema design)  →  SQL Analytics  →  Power BI
   /Datasets            run_pipeline.py                                                          
```

**Three-schema PostgreSQL design:**

| Schema | Purpose |
|---|---|
| `raw` | Ingests source files exactly as-is (all columns as `VARCHAR`) — zero data loss |
| `cleaned` | Typed, standardized tables with primary keys, foreign keys, and check constraints |
| `analytics` | Query-ready output tables that power the Power BI dashboard and strategic report |

---

## 🧹 Data Cleaning Highlights

Raw data had real-world messiness, handled programmatically in `run_pipeline.py`:

- **Currency symbols in count fields** - stripped `₹` and commas from what should have been plain integers (`Copies Sold`)
- **Inconsistent casing** - `English` / `ENGLISH` / `hindi` collapsed into standardized values
- **Geographic naming chaos** - `Uttar-Pradesh`, `Madhya_Pradesh`, `maharashtra` etc. mapped to a single canonical state list
- **Mixed currencies** - ad revenue reported in `USD`, `EUR`, `INR`, and `IN RUPEES`; converted to INR using fixed exchange rates
- **Non-standard quarter formats** - `Q1-2019`, `4th Qtr 2020`, `2023-Q2` normalized to `YYYY-Q#`
- **Bounce rate scale mismatch** - stored as `65.76` instead of `0.6576`; divided by 100 to satisfy schema constraints
- **Swapped field logic** - some rows had `Copies Sold` and `Net Circulation` values reversed; corrected using the relationship `net_circulation = copies_printed − copies_returned`
- **Deduplication** - removed duplicate rows violating primary key constraints before load

Full detail in [`DATA_CLEANING_REPORT.md`](./DATA_CLEANING_REPORT.md).

---

## ❓ Business Questions Answered

**6 Business Requests** (SQL, stored in `analytics` schema):
1. Top 3 sharpest month-over-month net circulation drops (2019–2024)
2. Ad categories contributing >50% of yearly ad revenue
3. 2024 print efficiency leaderboard (top 5 cities)
4. City with highest internet readiness growth in 2021
5. Cities with strictly declining circulation *and* ad revenue every year, 2019–2024
6. 2021 outlier: high digital readiness but bottom-3 pilot engagement

**8 Primary/Secondary Questions** (visualized in Power BI):
- YoY print circulation trends
- Top-performing cities by net circulation/copies sold in 2024
- Print waste analysis (printed vs. net circulation gap)
- Ad revenue trends by category
- City-level ad revenue vs. circulation correlation
- Digital readiness vs. pilot engagement
- Ad revenue ROI per net circulated copy over time
- Final digital relaunch city prioritization (weighted scoring model)

---

## 🎯 Key Insights

- **Circulation**: Every city declined YoY from 2019–2024; total copies printed fell from 44.1M to 33.0M (**-25%** cumulative)
- **Ad revenue mix shift**: Government-led revenue (2019–20) gave way to Real Estate as the top category from 2021 onward
- **Efficiency ≠ size**: Smaller cities (Ranchi, Patna) post the highest print efficiency, not the biggest metros
- **Kanpur is the standout opportunity**: highest digital readiness score but low pilot engagement —a market ready for digital but underserved by it
- **ROI is rising in "declining" cities**: Patna and Lucknow show falling circulation but *rising* ad revenue per copy  still highly profitable per unit

## 📈 Digital Relaunch Priority Score

A weighted model combining readiness, engagement gap, and print decline:

```
Priority Score = (Readiness × 0.4) + ((100 − Engagement Rate) × 0.3) + (Print Decline % × 0.3)
```

**Phase 1 rollout recommendation:** Kanpur, Jaipur
**Phase 2 rollout recommendation:** Varanasi, Bhopal

---

## 🛠️ Tech Stack

- **Python** (pandas, re, SQLAlchemy) - ETL and data cleaning
- **PostgreSQL** - relational schema design, constraints, analytical SQL
- **Power BI** - 5-page interactive dashboard, connected via Direct Query to the `analytics` schema and cleaned datasets

---

## 📂 Repository Structure

```
├── Datasets/                    # Raw source files (Excel/CSV)
├── Datasets_Cleaned/            # Cleaned, exported datasets
├── scripts/
│   └── run_pipeline.py          # Python ETL pipeline
├── schema.sql                   # PostgreSQL schema (raw/cleaned/analytics)
├── analysis_queries.sql         # All analytical SQL queries
├── STRATEGIC_REPORT.md          # Final markdown strategic report
├── DATA_CLEANING_REPORT.md      # Detailed data cleaning documentation
├── final_report.pbix            # Power BI dashboard
└── visuals/
    ├── circulation_decline.png
    ├── ad_revenue_share_2024.png
    ├── roi_comparison.png
    └── city_prioritization.png
```

---

## 🚀 How to Run

1. Set up a PostgreSQL instance and update connection credentials in `run_pipeline.py`
2. Place raw files in `/Datasets`
3. Run the ETL pipeline:
   ```bash
   python scripts/run_pipeline.py
   ```
4. Execute `analysis_queries.sql` against the `cleaned` schema to populate `analytics` tables
5. Open `final_report.pbix` in Power BI Desktop and refresh the Direct Query connection

---

## 📌 About This Project

This project was built as part of the **Codebasics Resume Project Challenge (RP-16)** to practice end-to-end data analytics: from messy raw data to a decision-ready executive report.
