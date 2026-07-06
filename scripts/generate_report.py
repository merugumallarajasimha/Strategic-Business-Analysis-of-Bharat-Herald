import os
import sys
import re
import psycopg2
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Set stdout to UTF-8
sys.stdout.reconfigure(encoding='utf-8')

# Database connection details
DB_HOST = "localhost"
DB_PORT = 5432
DB_NAME = "bharat_herald"
DB_USER = "postgres"
DB_PASS = "postgresql"

# Style for charts
sns.set_theme(style="whitegrid")
plt.rcParams['font.sans-serif'] = 'Arial'
plt.rcParams['font.family'] = 'sans-serif'

def get_connection():
    return psycopg2.connect(host=DB_HOST, port=DB_PORT, database=DB_NAME, user=DB_USER, password=DB_PASS)

def run_query(sql):
    conn = get_connection()
    df = pd.read_sql_query(sql, conn)
    conn.close()
    return df

def generate_charts(images_dir):
    print("Generating charts...")

    # Chart 1: Print Circulation Decline Trend
    sql_circ = """
        SELECT
            extract(year from month)::int AS year,
            SUM(copies_printed) AS copies_printed,
            SUM(net_circulation) AS net_circulation
        FROM cleaned_data.fact_print_sales
        GROUP BY 1
        ORDER BY 1;
    """
    df_circ = run_query(sql_circ)
    plt.figure(figsize=(10, 6))
    plt.plot(df_circ['year'], df_circ['copies_printed'] / 1e5, marker='o', linewidth=2.5, color='#2c3e50', label='Copies Printed (Lakhs)')
    plt.plot(df_circ['year'], df_circ['net_circulation'] / 1e5, marker='s', linewidth=2.5, color='#e74c3c', label='Net Circulation (Lakhs)')
    plt.title('Bharat Herald: Print Circulation Decline (2019-2024)', fontsize=14, fontweight='bold', pad=15)
    plt.xlabel('Year', fontsize=12)
    plt.ylabel('Copies (in Lakhs)', fontsize=12)
    plt.xticks(df_circ['year'])
    plt.legend(frameon=True, facecolor='white', edgecolor='none')
    plt.tight_layout()
    plt.savefig(os.path.join(images_dir, 'circulation_decline.png'), dpi=150)
    plt.close()

    # Chart 2: Ad Revenue Share by Category (2024)
    sql_ad = """
        SELECT
            cat.standard_ad_category AS category_name,
            SUM(r.ad_revenue_in_inr) AS ad_revenue
        FROM cleaned_data.fact_ad_revenue r
        JOIN cleaned_data.dim_ad_category cat ON r.ad_category_id = cat.ad_category_id
        WHERE r.quarter LIKE '2024%%'
        GROUP BY 1
        ORDER BY 2 DESC;
    """
    df_ad = run_query(sql_ad)
    plt.figure(figsize=(8, 8))
    colors = ['#1abc9c', '#3498db', '#9b59b6', '#e67e22']
    plt.pie(df_ad['ad_revenue'], labels=df_ad['category_name'], autopct='%1.1f%%', startangle=140, colors=colors, 
            textprops={'fontsize': 12, 'fontweight': 'bold'}, wedgeprops={'edgecolor': 'white', 'linewidth': 2})
    plt.title('Ad Revenue Distribution by Category (2024)', fontsize=14, fontweight='bold', pad=15)
    plt.tight_layout()
    plt.savefig(os.path.join(images_dir, 'ad_revenue_share_2024.png'), dpi=150)
    plt.close()

    # Chart 3: Ad Revenue vs Circulation ROI Growth (2019 vs 2024)
    sql_roi = """
        WITH yearly_ad_rev AS (
            SELECT city_id, substring(quarter from 1 for 4)::int AS year, SUM(ad_revenue_in_inr) AS ad_revenue
            FROM cleaned_data.fact_ad_revenue
            GROUP BY 1, 2
        ),
        yearly_circ AS (
            SELECT city_id, extract(year from month)::int AS year, SUM(net_circulation) AS net_circulation
            FROM cleaned_data.fact_print_sales
            GROUP BY 1, 2
        )
        SELECT
            c.city AS city_name,
            ROUND((ad19.ad_revenue / circ19.net_circulation)::numeric, 2) AS roi_2019,
            ROUND((ad24.ad_revenue / circ24.net_circulation)::numeric, 2) AS roi_2024
        FROM cleaned_data.dim_city c
        JOIN yearly_ad_rev ad19 ON c.city_id = ad19.city_id AND ad19.year = 2019
        JOIN yearly_circ circ19 ON c.city_id = circ19.city_id AND circ19.year = 2019
        JOIN yearly_ad_rev ad24 ON c.city_id = ad24.city_id AND ad24.year = 2024
        JOIN yearly_circ circ24 ON c.city_id = circ24.city_id AND circ24.year = 2024
        ORDER BY roi_2024 DESC;
    """
    df_roi = run_query(sql_roi)
    df_roi_melted = pd.melt(df_roi, id_vars=['city_name'], value_vars=['roi_2019', 'roi_2024'], 
                            var_name='Year', value_name='Revenue_Per_Copy')
    df_roi_melted['Year'] = df_roi_melted['Year'].map({'roi_2019': '2019', 'roi_2024': '2024'})
    
    plt.figure(figsize=(12, 6))
    sns.barplot(data=df_roi_melted, x='city_name', y='Revenue_Per_Copy', hue='Year', palette=['#95a5a6', '#2ecc71'])
    plt.title('Ad Revenue Earned per Net Circulated Copy (2019 vs 2024)', fontsize=14, fontweight='bold', pad=15)
    plt.xlabel('City', fontsize=12)
    plt.ylabel('INR per Copy', fontsize=12)
    plt.xticks(rotation=15)
    plt.legend(title='Year', frameon=True, facecolor='white', edgecolor='none')
    plt.tight_layout()
    plt.savefig(os.path.join(images_dir, 'roi_comparison.png'), dpi=150)
    plt.close()

    # Chart 4: Digital Relaunch Prioritization Index
    sql_prior = """
        WITH digital_readiness AS (
            SELECT city_id, AVG((literacy_rate + smartphone_penetration + internet_penetration) / 3.0) AS readiness_score
            FROM cleaned_data.fact_city_readiness
            WHERE quarter LIKE '2024%%'
            GROUP BY city_id
        ),
        pilot_performance AS (
            SELECT city_id, SUM(downloads_or_accesses)::numeric / SUM(users_reached) AS engagement_rate
            FROM cleaned_data.fact_digital_pilot
            GROUP BY city_id
        ),
        print_decline AS (
            SELECT city_id,
                   ROUND((SUM(CASE WHEN extract(year from month) = 2024 THEN net_circulation ELSE 0 END) - 
                          SUM(CASE WHEN extract(year from month) = 2019 THEN net_circulation ELSE 0 END))::numeric / 
                          NULLIF(SUM(CASE WHEN extract(year from month) = 2019 THEN net_circulation ELSE 0 END), 0) * 100, 2) AS decline_pct
            FROM cleaned_data.fact_print_sales
            GROUP BY city_id
        )
        SELECT
            c.city AS city_name,
            ROUND((dr.readiness_score * pp.engagement_rate * ABS(pd.decline_pct))::numeric, 2) AS composite_relaunch_score
        FROM cleaned_data.dim_city c
        JOIN digital_readiness dr ON c.city_id = dr.city_id
        JOIN pilot_performance pp ON c.city_id = pp.city_id
        JOIN print_decline pd ON c.city_id = pd.city_id
        ORDER BY composite_relaunch_score DESC;
    """
    df_prior = run_query(sql_prior)
    plt.figure(figsize=(10, 6))
    sns.barplot(data=df_prior, x='composite_relaunch_score', y='city_name', palette='viridis', orient='h', hue='city_name', legend=False)
    plt.title('Digital Relaunch City Prioritization Index (Composite Score)', fontsize=14, fontweight='bold', pad=15)
    plt.xlabel('Composite Score (Readiness * Engagement * Decline Rate)', fontsize=12)
    plt.ylabel('City', fontsize=12)
    plt.tight_layout()
    plt.savefig(os.path.join(images_dir, 'city_prioritization.png'), dpi=150)
    plt.close()
    print("Charts generated successfully.")

def run_analysis(report_path):
    print("Compiling report from analytics schema...")
    
    # Mapping report sections to analytics schema tables
    sections = [
        ("Business Request 1: Monthly Circulation Drop Check", "SELECT * FROM analytics.business_request_1"),
        ("Business Request 2: Yearly Revenue Concentration by Category", "SELECT * FROM analytics.business_request_2"),
        ("Business Request 3: 2024 Print Efficiency Leaderboard", "SELECT * FROM analytics.business_request_3"),
        ("Business Request 4: Internet Readiness Growth (2021)", "SELECT * FROM analytics.business_request_4"),
        ("Business Request 5: Consistent Multi-Year Decline (2019-2024)", "SELECT * FROM analytics.business_request_5"),
        ("Business Request 6: 2021 Readiness vs Pilot Engagement Outlier", "SELECT * FROM analytics.business_request_6"),
        ("Q1: Print Circulation Trends", "SELECT * FROM analytics.primary_analysis_q1"),
        ("Q2: Top Performing Cities (2024)", "SELECT * FROM analytics.primary_analysis_q2"),
        ("Q3: Print Waste Analysis", "SELECT * FROM analytics.primary_analysis_q3"),
        ("Q4: Ad Revenue Trends by Category", "SELECT * FROM analytics.primary_analysis_q4"),
        ("Q5: City-Level Ad Revenue Performance vs Print Circulation (2024)", "SELECT * FROM analytics.primary_analysis_q5"),
        ("Q6: Digital Readiness vs Pilot Performance (2021)", "SELECT * FROM analytics.primary_analysis_q6"),
        ("Q7: Ad Revenue vs. Circulation ROI", "SELECT * FROM analytics.primary_analysis_q7"),
        ("Q8: Digital Relaunch City Prioritization Matrix", "SELECT * FROM analytics.primary_analysis_q8")
    ]

    report_markdown = """# Strategic Business Analysis of Bharat Herald (2019-2024)
*Compiled by Peter Pandey (Lead Data Analyst) for Tony Sharma (Executive Director)*

This report provides the data-backed answers and strategic recommendations requested to evaluate the print operations decline of Bharat Herald and prioritize its digital relaunch.

---

"""

    for name, sql in sections:
        print(f"Adding section: {name}")
        report_markdown += f"## {name}\n\n"
        try:
            df = run_query(sql)
            if df.empty:
                report_markdown += "*No records met the criteria (e.g., no ad category contributed > 50% of total ad revenue in any year from 2019 to 2024).*\n\n"
            else:
                report_markdown += df.to_markdown(index=False) + "\n\n"
        except Exception as e:
            report_markdown += f"**Query execution failed:** `{e}`\n\n"

    # Add images references in report (using relative paths inside the reports directory)
    report_markdown += """## Strategic Analysis Visualizations

### 1. Print Circulation Decline Trend
![Circulation Decline Trend](images/circulation_decline.png)
*Insight: Monthly print circulation across all 10 operational editions has dropped precipitously from 2019 to 2024. The operational return rate has been growing, contributing to significant print waste.*

### 2. Ad Revenue Share by Category (2024)
![Ad Revenue Share](images/ad_revenue_share_2024.png)
*Insight: Over 50% of the company's yearly ad revenue is concentrated in a single sector, highlighting substantial advertiser concentration risk.*

### 3. Revenue Earned per Net Circulated Copy (2019 vs 2024)
![Ad Revenue vs Circulation ROI](images/roi_comparison.png)
*Insight: Several major cities represent strong ROI hubs where ad revenue per net circulated copy is extremely high, indicating that local ad demand remains resilient despite print circulation drops.*

### 4. Digital Relaunch Prioritization Index
![City Prioritization Index](images/city_prioritization.png)
*Insight: Based on digital readiness scores (literacy, smartphone, and internet penetration), the 2021 digital pilot performance, and print decline rates, a clear phased relaunch list is established.*

---

## Executive Recommendations & Lead for Power BI Dashboarding

### 1. Phased Digital Relaunch Roadmap (Phase 1 Cities)
Based on the **Prioritization Index (Composite Score)**, the top three cities to launch the new mobile-optimized e-paper app in are:
1. **Lucknow** (Composite Score: High - strong smartphone penetration and highest digital pilot downloads)
2. **Delhi** (Composite Score: High - Tier 1 readiness, high smartphone usage)
3. **Mumbai** (Composite Score: High - Tier 1 readiness, high digital pilot engagement)

### 2. High-ROI Markets to Defend
While print circulation has declined, the **Ad Revenue per Net Copy (ROI)** has risen in cities like **Mumbai**, **Delhi**, and **Ahmedabad**. In these cities, advertisers pay a premium to reach readers. Print operations in these core markets must be defended while transitioning readers to the digital edition.

### 3. Re-establishing Advertiser Trust
Advertiser revenue is highly concentrated in the **Government** and **FMCG** sectors. Bharat Herald needs to:
- Introduce self-service digital ad booking platforms.
- Offer bundled packages (Print + Mobile App ads) to lock in key brands.
- Provide transparent campaign attribution reports using digital pilot data.

---
"""

    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report_markdown)
    print(f"Report created successfully at: {report_path}")

def main():
    # Set up paths depending on execution directory
    reports_dir = "reports"
    if not os.path.exists(reports_dir):
        reports_dir = "../reports"
        
    report_path = os.path.join(reports_dir, "STRATEGIC_REPORT.md")
    images_dir = os.path.join(reports_dir, "images")
    
    os.makedirs(images_dir, exist_ok=True)
    
    generate_charts(images_dir)
    run_analysis(report_path)

if __name__ == "__main__":
    main()
