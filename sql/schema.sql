-- Bharat Herald Strategic Business Analysis Database Schema (PostgreSQL)

-- Drop existing tables if they exist to allow clean rebuilds
DROP TABLE IF EXISTS fact_print_sales CASCADE;
DROP TABLE IF EXISTS fact_digital_pilot CASCADE;
DROP TABLE IF EXISTS fact_city_readiness CASCADE;
DROP TABLE IF EXISTS fact_ad_revenue CASCADE;
DROP TABLE IF EXISTS dim_ad_category CASCADE;
DROP TABLE IF EXISTS dim_city CASCADE;

-- 1. Dimension Table: Cities
CREATE TABLE dim_city (
    city_id VARCHAR(10) PRIMARY KEY,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    tier VARCHAR(10) NOT NULL CHECK (tier IN ('Tier 1', 'Tier 2', 'Tier 3'))
);

-- 2. Dimension Table: Ad Categories
CREATE TABLE dim_ad_category (
    ad_category_id VARCHAR(10) PRIMARY KEY,
    standard_ad_category VARCHAR(50) NOT NULL,
    category_group VARCHAR(50) NOT NULL,
    example_brands VARCHAR(255)
);

-- 3. Fact Table: Ad Revenue (Quarterly)
CREATE TABLE fact_ad_revenue (
    id SERIAL PRIMARY KEY,
    edition_id VARCHAR(10) NOT NULL,            -- Original edition_id (e.g. ED1001)
    city_id VARCHAR(10) NOT NULL REFERENCES dim_city(city_id), -- Normalized city_id (e.g. C001)
    ad_category_id VARCHAR(10) NOT NULL REFERENCES dim_ad_category(ad_category_id),
    quarter VARCHAR(10) NOT NULL,               -- Standardized quarter (e.g. 2019-Q1)
    raw_ad_revenue NUMERIC NOT NULL,            -- Revenue in original currency
    currency VARCHAR(20) NOT NULL,              -- Original currency (USD, EUR, INR)
    ad_revenue_in_inr NUMERIC NOT NULL,         -- Standardized revenue in INR
    comments TEXT
);

-- 4. Fact Table: City Readiness (Quarterly)
CREATE TABLE fact_city_readiness (
    id SERIAL PRIMARY KEY,
    city_id VARCHAR(10) NOT NULL REFERENCES dim_city(city_id),
    quarter VARCHAR(10) NOT NULL,               -- Standardized quarter (e.g. 2019-Q1)
    literacy_rate NUMERIC NOT NULL CHECK (literacy_rate BETWEEN 0 AND 100),
    smartphone_penetration NUMERIC NOT NULL CHECK (smartphone_penetration BETWEEN 0 AND 100),
    internet_penetration NUMERIC NOT NULL CHECK (internet_penetration BETWEEN 0 AND 100)
);

-- 5. Fact Table: Digital Pilot (2021 Campaign Performance)
CREATE TABLE fact_digital_pilot (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    launch_month VARCHAR(10) NOT NULL,          -- Month of launch (e.g. Mar-2021)
    ad_category_id VARCHAR(10) NOT NULL REFERENCES dim_ad_category(ad_category_id),
    dev_cost NUMERIC NOT NULL,                  -- Development cost (INR)
    marketing_cost NUMERIC NOT NULL,            -- Marketing budget spend (INR)
    users_reached INTEGER NOT NULL CHECK (users_reached >= 0),
    downloads_or_accesses INTEGER NOT NULL CHECK (downloads_or_accesses >= 0),
    avg_bounce_rate NUMERIC CHECK (avg_bounce_rate BETWEEN 0 AND 1),
    cumulative_feedback_from_customers TEXT,
    city_id VARCHAR(10) NOT NULL REFERENCES dim_city(city_id)
);

-- 6. Fact Table: Print Sales (Monthly Operational Metrics)
CREATE TABLE fact_print_sales (
    id SERIAL PRIMARY KEY,
    edition_id VARCHAR(10) NOT NULL,            -- edition_ID from Excel (e.g. ED1005)
    city_id VARCHAR(10) NOT NULL REFERENCES dim_city(city_id), -- City_ID from Excel (e.g. C005)
    language VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    month DATE NOT NULL,                        -- First day of the month (e.g. 2019-01-01)
    copies_printed INTEGER NOT NULL CHECK (copies_printed >= 0),     -- Mapped from Copies Sold
    copies_returned INTEGER NOT NULL CHECK (copies_returned >= 0),   -- Mapped from copies_returned
    net_circulation INTEGER NOT NULL CHECK (net_circulation >= 0),   -- Mapped from Net_Circulation
    CONSTRAINT check_net_circulation CHECK (net_circulation = copies_printed - copies_returned)
);
