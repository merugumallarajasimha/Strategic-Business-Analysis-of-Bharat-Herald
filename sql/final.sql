-- SQL Script to answer Business Requests and Primary Analysis Questions for Bharat Herald
-- All queries have been updated to reference the new `cleaned` schema.

-- =========================================================================
-- PART 1: BUSINESS REQUESTS FROM AD-HOC-REQUESTS.PDF
-- =========================================================================

-- Business Request 1: Monthly Circulation Drop Check
-- Generate a report showing the top 3 months (2019 – 2024) where any city recorded the sharpest MoM decline in net_circulation.
WITH monthly_drop AS
(
    SELECT
        c.city AS city_name,
        to_char(p.month, 'YYYY-MM') AS month,
        p.net_circulation,
        LAG(p.net_circulation) OVER (
            PARTITION BY p.city_id
            ORDER BY p.month
        ) AS previous_month_circulation
    FROM cleaned.fact_print_sales p
    JOIN cleaned.dim_city c ON p.city_id = c.city_id
)
SELECT
    city_name,
    month,
    previous_month_circulation,
    net_circulation,
    (previous_month_circulation - net_circulation) AS circulation_drop
FROM monthly_drop
WHERE previous_month_circulation IS NOT NULL
  AND net_circulation < previous_month_circulation
ORDER BY circulation_drop DESC
LIMIT 3;


-- Business Request 2: Yearly Revenue Concentration by Category
-- Identify ad categories that contributed > 50% of total yearly ad revenue.
WITH category_revenue AS
(
    SELECT
        LEFT(quarter,4)::INT AS year,
        dac.standard_ad_category AS category_name,
        SUM(ar.ad_revenue_in_inr) AS category_revenue
    FROM cleaned.fact_ad_revenue ar
    JOIN cleaned.dim_ad_category dac
        ON ar.ad_category_id = dac.ad_category_id
    GROUP BY
        LEFT(quarter,4)::INT,
        dac.standard_ad_category
),

yearly_revenue AS
(
    SELECT
        LEFT(quarter,4)::INT AS year,
        SUM(ad_revenue_in_inr) AS total_revenue_year
    FROM cleaned.fact_ad_revenue
    GROUP BY LEFT(quarter,4)::INT
)

SELECT
    cr.year,
    cr.category_name,
    cr.category_revenue,
    yr.total_revenue_year,

    ROUND(
        (cr.category_revenue::NUMERIC /
        yr.total_revenue_year) * 100,
        2
    ) AS pct_of_year_total

FROM category_revenue cr

JOIN yearly_revenue yr
ON cr.year = yr.year

ORDER BY
    cr.year,
    pct_of_year_total DESC;


-- Business Request 3: 2024 Print Efficiency Leaderboard
-- Rank cities by print efficiency = net_circulation / copies_printed for 2024. Return top 5.
SELECT
    c.city AS city_name,
    SUM(p.copies_printed) AS copies_printed_2024,
    SUM(p.net_circulation) AS net_circulation_2024,
    ROUND(
        SUM(p.net_circulation)::NUMERIC /
        NULLIF(SUM(p.copies_printed),0),
        4
    ) AS efficiency_ratio,
    DENSE_RANK() OVER
    (
        ORDER BY
        ROUND(
            SUM(p.net_circulation)::NUMERIC /
            NULLIF(SUM(p.copies_printed),0),
            4
        ) DESC
    ) AS efficiency_rank_2024
FROM cleaned.fact_print_sales p
JOIN cleaned.dim_city c ON p.city_id = c.city_id
WHERE EXTRACT(YEAR FROM p.month)=2024
GROUP BY c.city
ORDER BY efficiency_rank_2024
LIMIT 5;


WITH quarterly_rates AS
(
    SELECT
        dc.city AS city_name,
        CASE
            WHEN fcr.quarter = '2021-Q1' THEN 'Q1'
            WHEN fcr.quarter = '2021-Q4' THEN 'Q4'
        END AS quarter,
        AVG(fcr.internet_penetration) AS avg_internet_rate
    FROM cleaned.fact_city_readiness fcr
    JOIN cleaned.dim_city dc
    ON fcr.city_id = dc.city_id
    WHERE fcr.quarter IN ('2021-Q1', '2021-Q4')
    GROUP BY
        dc.city,
        CASE
            WHEN fcr.quarter = '2021-Q1' THEN 'Q1'
            WHEN fcr.quarter = '2021-Q4' THEN 'Q4'
        END
)
SELECT
    q1.city_name,
    ROUND(q1.avg_internet_rate,2) AS internet_rate_q1_2021,
    ROUND(q4.avg_internet_rate,2) AS internet_rate_q4_2021,
    ROUND(
        q4.avg_internet_rate -
        q1.avg_internet_rate,
        2
    ) AS delta_internet_rate
FROM quarterly_rates q1
JOIN quarterly_rates q4
ON q1.city_name = q4.city_name
WHERE
q1.quarter='Q1'
AND q4.quarter='Q4'
ORDER BY
delta_internet_rate DESC;


-- Business Request 5: Consistent Multi-Year Decline (2019-2024)
-- Find cities where both net_circulation and ad_revenue decreased every year from 2019 through 2024.
WITH yearly_metrics AS (
    SELECT
        c.city_id,
        c.city AS city_name,
        year_val,
        SUM(net_circulation) AS yearly_net_circulation,
        SUM(ad_revenue) AS yearly_ad_revenue
    FROM (
        SELECT city_id, extract(year from month)::int AS year_val, net_circulation, 0::numeric AS ad_revenue
        FROM cleaned.fact_print_sales
        UNION ALL
        SELECT city_id, substring(quarter from 1 for 4)::int AS year_val, 0 AS net_circulation, ad_revenue_in_inr AS ad_revenue
        FROM cleaned.fact_ad_revenue
    ) t
    JOIN cleaned.dim_city c ON t.city_id = c.city_id
    WHERE year_val BETWEEN 2019 AND 2024
    GROUP BY c.city_id, c.city, year_val
),
yoy_diffs AS (
    SELECT
        city_id,
        city_name,
        year_val,
        yearly_net_circulation,
        yearly_ad_revenue,
        LAG(yearly_net_circulation) OVER (PARTITION BY city_id ORDER BY year_val) AS prev_circ,
        LAG(yearly_ad_revenue) OVER (PARTITION BY city_id ORDER BY year_val) AS prev_rev
    FROM yearly_metrics
),
decreases AS (
    SELECT
        city_id,
        city_name,
        year_val,
        yearly_net_circulation,
        yearly_ad_revenue,
        (CASE WHEN year_val = 2019 THEN TRUE ELSE yearly_net_circulation < prev_circ END) AS circ_decreased,
        (CASE WHEN year_val = 2019 THEN TRUE ELSE yearly_ad_revenue < prev_rev END) AS rev_decreased
    FROM yoy_diffs
),
city_summary AS (
    SELECT
        city_id,
        city_name,
        (COUNT(CASE WHEN year_val > 2019 AND circ_decreased THEN 1 END) = 5) AS is_declining_print,
        (COUNT(CASE WHEN year_val > 2019 AND rev_decreased THEN 1 END) = 5) AS is_declining_ad_revenue
    FROM decreases
    GROUP BY city_id, city_name
)
SELECT
    m.city_name,
    m.year_val AS year,
    m.yearly_net_circulation,
    m.yearly_ad_revenue,
    (CASE WHEN cs.is_declining_print THEN 'Yes' ELSE 'No' END) AS is_declining_print,
    (CASE WHEN cs.is_declining_ad_revenue THEN 'Yes' ELSE 'No' END) AS is_declining_ad_revenue,
    (CASE WHEN cs.is_declining_print AND cs.is_declining_ad_revenue THEN 'Yes' ELSE 'No' END) AS is_declining_both
FROM yearly_metrics m
JOIN city_summary cs ON m.city_id = cs.city_id
WHERE cs.is_declining_print = TRUE AND cs.is_declining_ad_revenue = TRUE
ORDER BY m.city_name, m.year_val;


-- Business Request 6: 2021 Readiness vs Pilot Engagement Outlier
-- Identify city with highest digital readiness score but bottom 3 in digital pilot engagement for 2021.
WITH readiness_2021 AS (
    SELECT
        city_id,
        AVG((literacy_rate + smartphone_penetration + internet_penetration) / 3.0) AS readiness_score_2021
    FROM cleaned.fact_city_readiness
    WHERE quarter LIKE '2021%'
    GROUP BY city_id
),
pilot_engagement_2021 AS (
    SELECT
        city_id,
        SUM(downloads_or_accesses)::numeric / SUM(users_reached) AS engagement_metric_2021
    FROM cleaned.fact_digital_pilot
    WHERE launch_month LIKE '2021%'
    GROUP BY city_id
),
ranks AS (
    SELECT
        c.city AS city_name,
        r.readiness_score_2021,
        pe.engagement_metric_2021,
        RANK() OVER (ORDER BY r.readiness_score_2021 DESC) AS readiness_rank_desc,
        RANK() OVER (ORDER BY pe.engagement_metric_2021 ASC) AS engagement_rank_asc
    FROM readiness_2021 r
    JOIN pilot_engagement_2021 pe ON r.city_id = pe.city_id
    JOIN cleaned.dim_city c ON r.city_id = c.city_id
)
SELECT
    city_name,
    ROUND(readiness_score_2021::numeric, 2) AS readiness_score_2021,
    ROUND(engagement_metric_2021::numeric, 4) AS engagement_metric_2021,
    readiness_rank_desc,
    engagement_rank_asc,
    (CASE WHEN readiness_rank_desc = 1 AND engagement_rank_asc <= 3 THEN 'Yes' ELSE 'No' END) AS is_outlier
FROM ranks
WHERE readiness_rank_desc = 1 AND engagement_rank_asc <= 3
ORDER BY readiness_score_2021 DESC;


-- =========================================================================
-- PART 2: PRIMARY ANALYSIS QUESTIONS FROM PRIMARY_AND_SECONDARY_ANALYSIS.PDF
-- =========================================================================

-- Q1: Print Circulation Trends
-- Yearly totals and YoY percentage change across all editions.
DROP TABLE IF EXISTS analytics.primary_analysis_q1;

CREATE TABLE analytics.primary_analysis_q1 AS

WITH yearly_summary AS
(
    SELECT
        EXTRACT(YEAR FROM month) AS year,

        SUM(copies_printed) AS total_copies_printed,

        SUM(copies_sold) AS total_copies_sold,

        SUM(net_circulation) AS total_net_circulation

    FROM cleaned.fact_print_sales

    GROUP BY EXTRACT(YEAR FROM month)
),

yoy AS
(
    SELECT
        year,
        total_copies_printed,
        total_copies_sold,
        total_net_circulation,

        LAG(total_copies_printed) OVER (ORDER BY year) AS prev_printed,
        LAG(total_copies_sold) OVER (ORDER BY year) AS prev_sold,
        LAG(total_net_circulation) OVER (ORDER BY year) AS prev_net

    FROM yearly_summary
)

SELECT

    year,

    total_copies_printed,

    total_copies_sold,

    total_net_circulation,

    ROUND(
        ((total_copies_printed - prev_printed)::NUMERIC
        / NULLIF(prev_printed,0))*100,
        2
    ) AS pct_change_printed,

    ROUND(
        ((total_copies_sold - prev_sold)::NUMERIC
        / NULLIF(prev_sold,0))*100,
        2
    ) AS pct_change_sold,

    ROUND(
        ((total_net_circulation - prev_net)::NUMERIC
        / NULLIF(prev_net,0))*100,
        2
    ) AS pct_change_net

FROM yoy

ORDER BY year;


-- Q2: Top Performing Cities (2024)
-- Cities contributing the highest net circulation and copies sold in 2024.
DROP TABLE IF EXISTS analytics.primary_analysis_q2;

CREATE TABLE analytics.primary_analysis_q2 AS

WITH city_summary AS
(
    SELECT
        c.city,
        SUM(p.copies_printed) AS copies_printed_2024,
        SUM(p.copies_sold) AS copies_sold_2024,
        SUM(p.net_circulation) AS net_circulation_2024

    FROM cleaned.fact_print_sales p
    JOIN cleaned.dim_city c ON p.city_id = c.city_id

    WHERE EXTRACT(YEAR FROM p.month) = 2024

    GROUP BY c.city
)

SELECT
    city AS city_name,
    copies_printed_2024,
    copies_sold_2024,
    net_circulation_2024,

    ROUND(
        (net_circulation_2024::NUMERIC / NULLIF(copies_printed_2024,0)) * 100,
        2
    ) AS print_efficiency_pct,

    ROUND(
        (net_circulation_2024::NUMERIC /
        SUM(net_circulation_2024) OVER ()) * 100,
        2
    ) AS circulation_contribution_pct,

    CASE
        WHEN (net_circulation_2024::NUMERIC / NULLIF(copies_printed_2024,0)) >= 0.95
            THEN 'Highly Profitable'

        WHEN (net_circulation_2024::NUMERIC / NULLIF(copies_printed_2024,0)) >= 0.90
            THEN 'Profitable'

        WHEN (net_circulation_2024::NUMERIC / NULLIF(copies_printed_2024,0)) >= 0.80
            THEN 'Moderate'

        ELSE 'Needs Attention'
    END AS profitability_status

FROM city_summary

ORDER BY net_circulation_2024 DESC;



-- Q3: Print Waste Analysis
-- Gap between copies printed and net circulation (which is copies_returned) over time.
DROP TABLE IF EXISTS analytics.primary_analysis_q3;

CREATE TABLE analytics.primary_analysis_q3 AS

SELECT
    c.city AS city_name,

    EXTRACT(YEAR FROM p.month) AS year,

    SUM(p.copies_printed) AS total_copies_printed,

    SUM(p.net_circulation) AS total_net_circulation,

    SUM(p.copies_printed) - SUM(p.net_circulation) AS print_waste,

    ROUND(
        (
            (SUM(p.copies_printed) - SUM(p.net_circulation))::NUMERIC
            / NULLIF(SUM(p.copies_printed), 0)
        ) * 100,
        2
    ) AS print_waste_pct

FROM cleaned.fact_print_sales p
JOIN cleaned.dim_city c ON p.city_id = c.city_id

GROUP BY
    c.city,
    EXTRACT(YEAR FROM p.month)

ORDER BY
    city_name,
    year;


-- Q4: Ad Revenue Trends by Category
-- Yearly ad revenue by category from 2019 to 2024.
DROP TABLE IF EXISTS analytics.primary_analysis_q4;

CREATE TABLE analytics.primary_analysis_q4 AS

SELECT
    SUBSTRING(ar.quarter FROM 1 FOR 4)::INT AS year,
    dac.standard_ad_category AS category_name,
    SUM(ar.ad_revenue_in_inr) AS total_ad_revenue
FROM cleaned.fact_ad_revenue ar
JOIN cleaned.dim_ad_category dac
ON ar.ad_category_id = dac.ad_category_id
GROUP BY
    SUBSTRING(ar.quarter FROM 1 FOR 4)::INT,
    dac.standard_ad_category
ORDER BY
    year,
    total_ad_revenue DESC;


-- Q5: City-Level Ad Revenue Performance vs Print Circulation (2024)
DROP TABLE IF EXISTS analytics.primary_analysis_q5;

CREATE TABLE analytics.primary_analysis_q5 AS

WITH ad_revenue AS
(
    SELECT
        c.city AS city_name,
        SUBSTRING(ar.quarter FROM 1 FOR 4)::INT AS year,
        SUM(ar.ad_revenue_in_inr) AS total_ad_revenue
    FROM cleaned.fact_ad_revenue ar
    JOIN cleaned.dim_city c ON ar.city_id = c.city_id
    GROUP BY c.city, SUBSTRING(ar.quarter FROM 1 FOR 4)::INT
),
print_sales AS
(
    SELECT
        c.city AS city_name,
        EXTRACT(YEAR FROM p.month)::INT AS year,
        SUM(p.net_circulation) AS total_net_circulation
    FROM cleaned.fact_print_sales p
    JOIN cleaned.dim_city c ON p.city_id = c.city_id
    GROUP BY c.city, EXTRACT(YEAR FROM p.month)::INT
)
SELECT
    ar.city_name,
    ar.year,
    ar.total_ad_revenue,
    ps.total_net_circulation,
    ROUND(
        (ar.total_ad_revenue / NULLIF(ps.total_net_circulation, 0))::NUMERIC,
        2
    ) AS revenue_per_copy
FROM ad_revenue ar
JOIN print_sales ps
ON ar.city_name = ps.city_name
AND ar.year = ps.year
ORDER BY
    ar.year,
    ar.total_ad_revenue DESC;


-- Q6: Digital Readiness vs Pilot Performance (2021)
DROP TABLE IF EXISTS analytics.primary_analysis_q6;

CREATE TABLE analytics.primary_analysis_q6 AS
SELECT
    dc.city AS city_name,

    ROUND(
        (fcr.smartphone_penetration +
         fcr.internet_penetration +
         fcr.literacy_rate) / 3.0,
        2
    ) AS readiness_score,

    ROUND(
        AVG(fdp.downloads_or_accesses::numeric / NULLIF(fdp.users_reached, 0) * 100),
        2
    ) AS engagement_rate,

    CASE
        WHEN
            ((fcr.smartphone_penetration +
              fcr.internet_penetration +
              fcr.literacy_rate) / 3.0) >= 75
            AND AVG(fdp.downloads_or_accesses::numeric / NULLIF(fdp.users_reached, 0) * 100) < 3
        THEN 'High Readiness - Low Engagement'

        WHEN
            ((fcr.smartphone_penetration +
              fcr.internet_penetration +
              fcr.literacy_rate) / 3.0) >= 75
            AND AVG(fdp.downloads_or_accesses::numeric / NULLIF(fdp.users_reached, 0) * 100) >= 3
        THEN 'High Readiness - High Engagement'

        ELSE 'Needs Improvement'
    END AS city_status

FROM cleaned.fact_city_readiness fcr
JOIN cleaned.fact_digital_pilot fdp
    ON fcr.city_id = fdp.city_id
JOIN cleaned.dim_city dc
    ON dc.city_id = fcr.city_id

GROUP BY
    dc.city,
    fcr.smartphone_penetration,
    fcr.internet_penetration,
    fcr.literacy_rate

ORDER BY
    readiness_score DESC,
    engagement_rate ASC;


-- Q7: Ad Revenue vs. Circulation ROI
-- How does ad revenue per net circulated copy change over time (2019 vs 2024)?
DROP TABLE IF EXISTS analytics.primary_analysis_q7;

CREATE TABLE analytics.primary_analysis_q7 AS

WITH ad_revenue AS
(
    SELECT
        city_id,
        SUBSTRING(quarter FROM 1 FOR 4)::INT AS year,
        SUM(ad_revenue_in_inr) AS total_ad_revenue
    FROM cleaned.fact_ad_revenue
    GROUP BY city_id, SUBSTRING(quarter FROM 1 FOR 4)::INT
),
print_sales AS
(
    SELECT
        city_id,
        EXTRACT(YEAR FROM month)::INT AS year,
        SUM(net_circulation) AS total_net_circulation
    FROM cleaned.fact_print_sales
    GROUP BY city_id, EXTRACT(YEAR FROM month)::INT
)
SELECT
    dc.city AS city_name,
    ar.year,
    ar.total_ad_revenue,
    ps.total_net_circulation,
    ROUND(
        (ar.total_ad_revenue / NULLIF(ps.total_net_circulation, 0))::NUMERIC,
        2
    ) AS revenue_per_copy
FROM ad_revenue ar
JOIN print_sales ps
  ON ar.city_id = ps.city_id
  AND ar.year = ps.year
JOIN cleaned.dim_city dc
  ON dc.city_id = ar.city_id
ORDER BY
    city_name,
    year;


-- Q8: Digital Relaunch City Prioritization Matrix
DROP TABLE IF EXISTS analytics.primary_analysis_q8;

CREATE TABLE analytics.primary_analysis_q8 AS

WITH readiness AS
(
    SELECT
        city_id,
        ROUND(
            AVG(
                (smartphone_penetration +
                 internet_penetration +
                 literacy_rate) / 3.0
            ),
            2
        ) AS readiness_score
    FROM cleaned.fact_city_readiness
    GROUP BY city_id
),
engagement AS
(
    SELECT
        city_id,
        ROUND(
            AVG(downloads_or_accesses::numeric / NULLIF(users_reached, 0) * 100),
            2
        ) AS engagement_rate
    FROM cleaned.fact_digital_pilot
    GROUP BY city_id
),
print_sales AS
(
    SELECT
        city_id,
        ROUND(
            (
                SUM(copies_printed) -
                SUM(net_circulation)
            ) * 100.0 /
            NULLIF(SUM(copies_printed),0),
            2
        ) AS print_decline_pct
    FROM cleaned.fact_print_sales
    GROUP BY city_id
)
SELECT
    dc.city AS city_name,
    r.readiness_score,
    e.engagement_rate,
    ps.print_decline_pct,
    ROUND(
        (r.readiness_score * 0.4) +
        ((100.0 - e.engagement_rate) * 0.3) +
        (ps.print_decline_pct * 0.3),
        2
    ) AS priority_score,
    DENSE_RANK() OVER (
        ORDER BY ROUND(
            (r.readiness_score * 0.4) +
            ((100.0 - e.engagement_rate) * 0.3) +
            (ps.print_decline_pct * 0.3),
            2
        ) DESC
    ) AS priority_rank
FROM cleaned.dim_city dc
JOIN readiness r ON dc.city_id = r.city_id
JOIN engagement e ON dc.city_id = e.city_id
JOIN print_sales ps ON dc.city_id = ps.city_id
ORDER BY
    priority_score DESC;
