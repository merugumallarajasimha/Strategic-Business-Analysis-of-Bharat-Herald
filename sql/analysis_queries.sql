-- SQL Script to answer Business Requests and Primary Analysis Questions for Bharat Herald

-- =========================================================================
-- PART 1: BUSINESS REQUESTS FROM AD-HOC-REQUESTS.PDF
-- =========================================================================

-- Business Request 1: Monthly Circulation Drop Check
-- Generate a report showing the top 3 months (2019-2024) where any city recorded the sharpest MoM decline in net_circulation.
WITH monthly_circulation AS (
    SELECT
        c.city AS city_name,
        to_char(p.month, 'YYYY-MM') AS month_str,
        p.month,
        p.net_circulation,
        LAG(p.net_circulation) OVER (PARTITION BY p.city_id ORDER BY p.month) AS prev_net_circulation
    FROM cleaned_data.fact_print_sales p
    JOIN cleaned_data.dim_city c ON p.city_id = c.city_id
),
declines AS (
    SELECT
        city_name,
        month_str,
        net_circulation,
        prev_net_circulation,
        (net_circulation - prev_net_circulation) AS circulation_change
    FROM monthly_circulation
    WHERE prev_net_circulation IS NOT NULL
)
SELECT
    city_name,
    month_str AS month,
    net_circulation,
    circulation_change AS decline_value
FROM declines
ORDER BY circulation_change ASC
LIMIT 3;


-- Business Request 2: Yearly Revenue Concentration by Category
-- Identify ad categories that contributed > 50% of total yearly ad revenue.
WITH yearly_category_rev AS (
    SELECT
        substring(r.quarter from 1 for 4)::int AS year,
        cat.standard_ad_category AS category_name,
        SUM(r.ad_revenue_in_inr) AS category_revenue
    FROM cleaned_data.fact_ad_revenue r
    JOIN cleaned_data.dim_ad_category cat ON r.ad_category_id = cat.ad_category_id
    GROUP BY 1, 2
),
yearly_total_rev AS (
    SELECT
        substring(r.quarter from 1 for 4)::int AS year,
        SUM(r.ad_revenue_in_inr) AS total_revenue_year
    FROM cleaned_data.fact_ad_revenue r
    GROUP BY 1
)
SELECT
    cr.year,
    cr.category_name,
    cr.category_revenue,
    tr.total_revenue_year,
    ROUND(((cr.category_revenue / tr.total_revenue_year) * 100)::numeric, 2) AS pct_of_year_total
FROM yearly_category_rev cr
JOIN yearly_total_rev tr ON cr.year = tr.year
WHERE (cr.category_revenue / tr.total_revenue_year) > 0.50
ORDER BY cr.year ASC, pct_of_year_total DESC;


-- Business Request 3: 2024 Print Efficiency Leaderboard
-- Rank cities by print efficiency = net_circulation / copies_printed for 2024. Return top 5.
WITH city_2024_print AS (
    SELECT
        c.city AS city_name,
        SUM(p.copies_printed) AS copies_printed_2024,
        SUM(p.net_circulation) AS net_circulation_2024
    FROM cleaned_data.fact_print_sales p
    JOIN cleaned_data.dim_city c ON p.city_id = c.city_id
    WHERE extract(year from p.month) = 2024
    GROUP BY c.city
)
SELECT
    city_name,
    copies_printed_2024,
    net_circulation_2024,
    ROUND((net_circulation_2024::numeric / copies_printed_2024), 4) AS efficiency_ratio,
    RANK() OVER (ORDER BY (net_circulation_2024::numeric / copies_printed_2024) DESC) AS efficiency_rank_2024
FROM city_2024_print
ORDER BY efficiency_ratio DESC
LIMIT 5;


-- Business Request 4: Internet Readiness Growth (2021)
-- Compute the change in internet penetration from Q1-2021 to Q4-2021 for each city.
WITH q1_2021 AS (
    SELECT city_id, internet_penetration AS internet_rate_q1_2021
    FROM cleaned_data.fact_city_readiness
    WHERE quarter = '2021-Q1'
),
q4_2021 AS (
    SELECT city_id, internet_penetration AS internet_rate_q4_2021
    FROM cleaned_data.fact_city_readiness
    WHERE quarter = '2021-Q4'
)
SELECT
    c.city AS city_name,
    q1.internet_rate_q1_2021,
    q4.internet_rate_q4_2021,
    (q4.internet_rate_q4_2021 - q1.internet_rate_q1_2021) AS delta_internet_rate
FROM q1_2021 q1
JOIN q4_2021 q4 ON q1.city_id = q4.city_id
JOIN cleaned_data.dim_city c ON q1.city_id = c.city_id
ORDER BY delta_internet_rate DESC;


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
        FROM cleaned_data.fact_print_sales
        UNION ALL
        SELECT city_id, substring(quarter from 1 for 4)::int AS year_val, 0 AS net_circulation, ad_revenue_in_inr AS ad_revenue
        FROM cleaned_data.fact_ad_revenue
    ) t
    JOIN cleaned_data.dim_city c ON t.city_id = c.city_id
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
ORDER BY cs.is_declining_print DESC, cs.is_declining_ad_revenue DESC, m.city_name, m.year_val;


-- Business Request 6: 2021 Readiness vs Pilot Engagement Outlier
-- Identify city with highest digital readiness score but bottom 3 in digital pilot engagement for 2021.
WITH readiness_2021 AS (
    SELECT
        city_id,
        AVG((literacy_rate + smartphone_penetration + internet_penetration) / 3.0) AS readiness_score_2021
    FROM cleaned_data.fact_city_readiness
    WHERE quarter LIKE '2021%'
    GROUP BY city_id
),
pilot_engagement_2021 AS (
    SELECT
        city_id,
        SUM(downloads_or_accesses)::numeric / SUM(users_reached) AS engagement_metric_2021
    FROM cleaned_data.fact_digital_pilot
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
    JOIN cleaned_data.dim_city c ON r.city_id = c.city_id
)
SELECT
    city_name,
    ROUND(readiness_score_2021::numeric, 2) AS readiness_score_2021,
    ROUND(engagement_metric_2021::numeric, 4) AS engagement_metric_2021,
    readiness_rank_desc,
    engagement_rank_asc,
    (CASE WHEN readiness_rank_desc = 1 AND engagement_rank_asc <= 3 THEN 'Yes' ELSE 'No' END) AS is_outlier
FROM ranks
ORDER BY readiness_score_2021 DESC;


-- =========================================================================
-- PART 2: PRIMARY ANALYSIS QUESTIONS FROM PRIMARY_AND_SECONDARY_ANALYSIS.PDF
-- =========================================================================

-- Q1: Print Circulation Trends
-- Yearly totals and YoY percentage change across all editions.
WITH yearly_circulation AS (
    SELECT
        extract(year from month)::int AS year,
        SUM(copies_printed) AS total_copies_printed,
        SUM(copies_returned) AS total_copies_returned,
        SUM(net_circulation) AS total_net_circulation
    FROM cleaned_data.fact_print_sales
    GROUP BY 1
),
yoy_changes AS (
    SELECT
        year,
        total_copies_printed,
        total_copies_returned,
        total_net_circulation,
        LAG(total_copies_printed) OVER (ORDER BY year) AS prev_printed,
        LAG(total_net_circulation) OVER (ORDER BY year) AS prev_net
    FROM yearly_circulation
)
SELECT
    year,
    total_copies_printed,
    total_copies_returned,
    total_net_circulation,
    ROUND(((total_copies_printed - prev_printed)::numeric / prev_printed) * 100, 2) AS pct_change_printed,
    ROUND(((total_net_circulation - prev_net)::numeric / prev_net) * 100, 2) AS pct_change_net
FROM yoy_changes
ORDER BY year;


-- Q2: Top Performing Cities (2024)
-- Cities contributing the highest net circulation and copies printed in 2024.
SELECT
    c.city AS city_name,
    SUM(p.copies_printed) AS copies_printed_2024,
    SUM(p.net_circulation) AS net_circulation_2024,
    ROUND((SUM(p.net_circulation)::numeric / SUM(SUM(p.net_circulation)) OVER ()) * 100, 2) AS circulation_contribution_pct
FROM cleaned_data.fact_print_sales p
JOIN cleaned_data.dim_city c ON p.city_id = c.city_id
WHERE extract(year from p.month) = 2024
GROUP BY c.city
ORDER BY net_circulation_2024 DESC;


-- Q3: Print Waste Analysis
-- Gap between copies printed and net circulation (which is copies_returned) over time.
SELECT
    c.city AS city_name,
    extract(year from p.month)::int AS year,
    SUM(p.copies_printed) AS total_copies_printed,
    SUM(p.copies_returned) AS total_copies_returned,
    ROUND((SUM(p.copies_returned)::numeric / SUM(p.copies_printed)) * 100, 2) AS return_waste_pct
FROM cleaned_data.fact_print_sales p
JOIN cleaned_data.dim_city c ON p.city_id = c.city_id
GROUP BY c.city, year
ORDER BY return_waste_pct DESC, year;


-- Q4: Ad Revenue Trends by Category
-- Yearly ad revenue by category from 2019 to 2024.
SELECT
    cat.standard_ad_category AS category_name,
    SUM(CASE WHEN substring(r.quarter from 1 for 4) = '2019' THEN r.ad_revenue_in_inr ELSE 0 END) AS rev_2019,
    SUM(CASE WHEN substring(r.quarter from 1 for 4) = '2020' THEN r.ad_revenue_in_inr ELSE 0 END) AS rev_2020,
    SUM(CASE WHEN substring(r.quarter from 1 for 4) = '2021' THEN r.ad_revenue_in_inr ELSE 0 END) AS rev_2021,
    SUM(CASE WHEN substring(r.quarter from 1 for 4) = '2022' THEN r.ad_revenue_in_inr ELSE 0 END) AS rev_2022,
    SUM(CASE WHEN substring(r.quarter from 1 for 4) = '2023' THEN r.ad_revenue_in_inr ELSE 0 END) AS rev_2023,
    SUM(CASE WHEN substring(r.quarter from 1 for 4) = '2024' THEN r.ad_revenue_in_inr ELSE 0 END) AS rev_2024,
    ROUND((((SUM(CASE WHEN substring(r.quarter from 1 for 4) = '2024' THEN r.ad_revenue_in_inr ELSE 0 END) - 
            SUM(CASE WHEN substring(r.quarter from 1 for 4) = '2019' THEN r.ad_revenue_in_inr ELSE 0 END))::numeric / 
            NULLIF(SUM(CASE WHEN substring(r.quarter from 1 for 4) = '2019' THEN r.ad_revenue_in_inr ELSE 0 END), 0)) * 100)::numeric, 2) AS total_growth_pct
FROM cleaned_data.fact_ad_revenue r
JOIN cleaned_data.dim_ad_category cat ON r.ad_category_id = cat.ad_category_id
GROUP BY cat.standard_ad_category
ORDER BY total_growth_pct DESC;


-- Q5: City-Level Ad Revenue Performance vs Print Circulation (2024)
WITH city_2024_ad AS (
    SELECT city_id, SUM(ad_revenue_in_inr) AS ad_revenue_2024
    FROM cleaned_data.fact_ad_revenue
    WHERE quarter LIKE '2024%'
    GROUP BY city_id
),
city_2024_circ AS (
    SELECT city_id, SUM(net_circulation) AS net_circulation_2024
    FROM cleaned_data.fact_print_sales
    WHERE extract(year from month) = 2024
    GROUP BY city_id
)
SELECT
    c.city AS city_name,
    COALESCE(ad.ad_revenue_2024, 0) AS ad_revenue_2024,
    COALESCE(circ.net_circulation_2024, 0) AS net_circulation_2024,
    ROUND((COALESCE(ad.ad_revenue_2024, 0) / NULLIF(COALESCE(circ.net_circulation_2024, 0), 0))::numeric, 2) AS revenue_per_net_copy_2024
FROM cleaned_data.dim_city c
LEFT JOIN city_2024_ad ad ON c.city_id = ad.city_id
LEFT JOIN city_2024_circ circ ON c.city_id = circ.city_id
ORDER BY ad_revenue_2024 DESC;


-- Q6: Digital Readiness vs Pilot Performance (2021)
-- Comparing average digital readiness with digital pilot downloads for 2021.
WITH readiness_2021 AS (
    SELECT
        city_id,
        AVG((literacy_rate + smartphone_penetration + internet_penetration) / 3.0) AS readiness_score_2021
    FROM cleaned_data.fact_city_readiness
    WHERE quarter LIKE '2021%'
    GROUP BY city_id
),
pilot_2021 AS (
    SELECT
        city_id,
        SUM(downloads_or_accesses) AS total_pilot_downloads,
        SUM(users_reached) AS total_users_reached,
        ROUND(SUM(downloads_or_accesses)::numeric / SUM(users_reached) * 100, 2) AS pilot_engagement_pct
    FROM cleaned_data.fact_digital_pilot
    WHERE launch_month LIKE '2021%'
    GROUP BY city_id
)
SELECT
    c.city AS city_name,
    ROUND(r.readiness_score_2021::numeric, 2) AS digital_readiness_score_2021,
    COALESCE(p.total_pilot_downloads, 0) AS total_pilot_downloads,
    COALESCE(p.pilot_engagement_pct, 0.0) AS pilot_engagement_pct
FROM cleaned_data.dim_city c
JOIN readiness_2021 r ON c.city_id = r.city_id
LEFT JOIN pilot_2021 p ON c.city_id = p.city_id
ORDER BY digital_readiness_score_2021 DESC;


-- Q7: Ad Revenue vs. Circulation ROI
-- How does ad revenue per net circulated copy change over time (2019 vs 2024)?
WITH yearly_ad_rev AS (
    SELECT
        city_id,
        substring(quarter from 1 for 4)::int AS year,
        SUM(ad_revenue_in_inr) AS ad_revenue
    FROM cleaned_data.fact_ad_revenue
    GROUP BY city_id, year
),
yearly_circ AS (
    SELECT
        city_id,
        extract(year from month)::int AS year,
        SUM(net_circulation) AS net_circulation
    FROM cleaned_data.fact_print_sales
    GROUP BY city_id, year
)
SELECT
    c.city AS city_name,
    ad19.year AS year_2019,
    ROUND((ad19.ad_revenue / circ19.net_circulation)::numeric, 2) AS revenue_per_copy_2019,
    ad24.year AS year_2024,
    ROUND((ad24.ad_revenue / circ24.net_circulation)::numeric, 2) AS revenue_per_copy_2024,
    ROUND(((((ad24.ad_revenue / circ24.net_circulation) - (ad19.ad_revenue / circ19.net_circulation)) / (ad19.ad_revenue / circ19.net_circulation)) * 100)::numeric, 2) AS roi_growth_pct
FROM cleaned_data.dim_city c
JOIN yearly_ad_rev ad19 ON c.city_id = ad19.city_id AND ad19.year = 2019
JOIN yearly_circ circ19 ON c.city_id = circ19.city_id AND circ19.year = 2019
JOIN yearly_ad_rev ad24 ON c.city_id = ad24.city_id AND ad24.year = 2024
JOIN yearly_circ circ24 ON c.city_id = circ24.city_id AND circ24.year = 2024
ORDER BY revenue_per_copy_2024 DESC;


-- Q8: Digital Relaunch City Prioritization Matrix
-- Ranks cities by composite digital index (digital readiness * pilot engagement) and print decline rate.
WITH digital_readiness AS (
    SELECT
        city_id,
        AVG((literacy_rate + smartphone_penetration + internet_penetration) / 3.0) AS readiness_score
    FROM cleaned_data.fact_city_readiness
    WHERE quarter LIKE '2024%' -- Use latest 2024 readiness scores
    GROUP BY city_id
),
pilot_performance AS (
    SELECT
        city_id,
        SUM(downloads_or_accesses)::numeric / SUM(users_reached) AS engagement_rate
    FROM cleaned_data.fact_digital_pilot
    GROUP BY city_id
),
print_decline AS (
    SELECT
        city_id,
        -- Decline from 2019 to 2024
        ROUND((SUM(CASE WHEN extract(year from month) = 2024 THEN net_circulation ELSE 0 END) - 
               SUM(CASE WHEN extract(year from month) = 2019 THEN net_circulation ELSE 0 END))::numeric / 
               NULLIF(SUM(CASE WHEN extract(year from month) = 2019 THEN net_circulation ELSE 0 END), 0) * 100, 2) AS decline_pct
    FROM cleaned_data.fact_print_sales
    GROUP BY city_id
)
SELECT
    c.city AS city_name,
    c.tier,
    ROUND(dr.readiness_score::numeric, 2) AS digital_readiness_2024_pct,
    ROUND((pp.engagement_rate * 100)::numeric, 2) AS pilot_engagement_pct,
    pd.decline_pct AS print_decline_2019_2024_pct,
    -- Composite Relaunch Priority Score = Readiness * Engagement * Absolute Print Decline
    ROUND((dr.readiness_score * pp.engagement_rate * ABS(pd.decline_pct))::numeric, 2) AS composite_relaunch_score,
    RANK() OVER (ORDER BY (dr.readiness_score * pp.engagement_rate * ABS(pd.decline_pct)) DESC) AS relaunch_rank
FROM cleaned_data.dim_city c
JOIN digital_readiness dr ON c.city_id = dr.city_id
JOIN pilot_performance pp ON c.city_id = pp.city_id
JOIN print_decline pd ON c.city_id = pd.city_id
ORDER BY composite_relaunch_score DESC;
