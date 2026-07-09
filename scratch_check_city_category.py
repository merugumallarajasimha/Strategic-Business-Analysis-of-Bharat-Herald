import psycopg2
import pandas as pd

conn = psycopg2.connect(host="localhost", port=5432, database="bharat_herald", user="postgres", password="postgresql")

query = """
WITH city_category_revenue AS (
    SELECT
        LEFT(r.quarter, 4)::int AS year,
        c.city AS city_name,
        cat.standard_ad_category AS category_name,
        SUM(r.ad_revenue_in_inr) AS category_revenue
    FROM cleaned.fact_ad_revenue r
    JOIN cleaned.dim_city c ON r.city_id = c.city_id
    JOIN cleaned.dim_ad_category cat ON r.ad_category_id = cat.ad_category_id
    GROUP BY 1, 2, 3
),
city_yearly_total AS (
    SELECT
        LEFT(r.quarter, 4)::int AS year,
        c.city AS city_name,
        SUM(r.ad_revenue_in_inr) AS total_revenue_year
    FROM cleaned.fact_ad_revenue r
    JOIN cleaned.dim_city c ON r.city_id = c.city_id
    GROUP BY 1, 2
)
SELECT
    cr.year,
    cr.city_name,
    cr.category_name,
    cr.category_revenue,
    yr.total_revenue_year,
    ROUND(((cr.category_revenue / yr.total_revenue_year) * 100)::numeric, 2) AS pct_of_year_total
FROM city_category_revenue cr
JOIN city_yearly_total yr ON cr.year = yr.year AND cr.city_name = yr.city_name
WHERE (cr.category_revenue / yr.total_revenue_year) > 0.50
ORDER BY cr.year ASC, pct_of_year_total DESC;
"""

df = pd.read_sql_query(query, conn)
pd.set_option('display.max_columns', None)
pd.set_option('display.width', 1000)
print(df)
conn.close()
