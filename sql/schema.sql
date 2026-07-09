-- Bharat Herald Strategic Business Analysis Database Schema (PostgreSQL)

-- -------------------------------------------------------------------------
-- SCHEMA CREATION & CLEANUP
-- -------------------------------------------------------------------------
DROP SCHEMA IF EXISTS raw CASCADE;
DROP SCHEMA IF EXISTS cleaned CASCADE;
DROP SCHEMA IF EXISTS analytics CASCADE;
DROP SCHEMA IF EXISTS cleaned_data CASCADE; -- Old schema cleanup

-- Drop redundant tables in public schema if they exist
DROP TABLE IF EXISTS public.fact_print_sales CASCADE;
DROP TABLE IF EXISTS public.fact_digital_pilot CASCADE;
DROP TABLE IF EXISTS public.fact_city_readiness CASCADE;
DROP TABLE IF EXISTS public.fact_ad_revenue CASCADE;
DROP TABLE IF EXISTS public.dim_ad_category CASCADE;
DROP TABLE IF EXISTS public.dim_city CASCADE;

CREATE SCHEMA raw;
CREATE SCHEMA cleaned;
CREATE SCHEMA analytics;

-- -------------------------------------------------------------------------
-- 1. RAW SCHEMA (Exact Copy of Raw Datasets)
-- -------------------------------------------------------------------------

CREATE TABLE raw.dim_city (
    city_id VARCHAR(255),
    city VARCHAR(255),
    state VARCHAR(255),
    tier VARCHAR(255)
);

CREATE TABLE raw.dim_ad_category (
    ad_category_id VARCHAR(255),
    standard_ad_category VARCHAR(255),
    category_group VARCHAR(255),
    example_brands VARCHAR(255)
);

CREATE TABLE raw.fact_ad_revenue (
    edition_id VARCHAR(255),
    ad_category VARCHAR(255),
    quarter VARCHAR(255),
    ad_revenue VARCHAR(255),
    currency VARCHAR(255),
    comments VARCHAR(255)
);

CREATE TABLE raw.fact_city_readiness (
    index INTEGER,
    city_id VARCHAR(255),
    quarter VARCHAR(255),
    literacy_rate VARCHAR(255),
    smartphone_penetration VARCHAR(255),
    internet_penetration VARCHAR(255)
);

CREATE TABLE raw.fact_digital_pilot (
    index INTEGER,
    platform VARCHAR(255),
    launch_month VARCHAR(255),
    ad_category_id VARCHAR(255),
    dev_cost VARCHAR(255),
    marketing_cost VARCHAR(255),
    users_reached VARCHAR(255),
    downloads_or_accesses VARCHAR(255),
    avg_bounce_rate VARCHAR(255),
    cumulative_feedback_from_customers TEXT,
    city_id VARCHAR(255)
);

CREATE TABLE raw.fact_print_sales (
    "edition_ID" VARCHAR(255),
    "City_ID" VARCHAR(255),
    "Language" VARCHAR(255),
    "State" VARCHAR(255),
    "Month" VARCHAR(255),
    "Copies Sold" VARCHAR(255),
    "copies_returned" VARCHAR(255),
    "Net_Circulation" VARCHAR(255)
);

-- -------------------------------------------------------------------------
-- 2. CLEANED SCHEMA (Standardized & Validated Datasets)
-- -------------------------------------------------------------------------

CREATE TABLE cleaned.dim_city (
    city_id VARCHAR(10) PRIMARY KEY,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    tier VARCHAR(10) NOT NULL CHECK (tier IN ('Tier 1', 'Tier 2', 'Tier 3'))
);

CREATE TABLE cleaned.dim_ad_category (
    ad_category_id VARCHAR(10) PRIMARY KEY,
    standard_ad_category VARCHAR(50) NOT NULL,
    category_group VARCHAR(50) NOT NULL,
    example_brands VARCHAR(255)
);

CREATE TABLE cleaned.fact_ad_revenue (
    id SERIAL PRIMARY KEY,
    edition_id VARCHAR(10) NOT NULL,
    city_id VARCHAR(10) NOT NULL REFERENCES cleaned.dim_city(city_id),
    ad_category_id VARCHAR(10) NOT NULL REFERENCES cleaned.dim_ad_category(ad_category_id),
    quarter VARCHAR(10) NOT NULL,
    raw_ad_revenue NUMERIC NOT NULL,
    currency VARCHAR(20) NOT NULL,
    ad_revenue_in_inr NUMERIC NOT NULL,
    comments TEXT
);

CREATE TABLE cleaned.fact_city_readiness (
    id SERIAL PRIMARY KEY,
    city_id VARCHAR(10) NOT NULL REFERENCES cleaned.dim_city(city_id),
    quarter VARCHAR(10) NOT NULL,
    literacy_rate NUMERIC NOT NULL CHECK (literacy_rate BETWEEN 0 AND 100),
    smartphone_penetration NUMERIC NOT NULL CHECK (smartphone_penetration BETWEEN 0 AND 100),
    internet_penetration NUMERIC NOT NULL CHECK (internet_penetration BETWEEN 0 AND 100)
);

CREATE TABLE cleaned.fact_digital_pilot (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    launch_month VARCHAR(10) NOT NULL,
    ad_category_id VARCHAR(10) NOT NULL REFERENCES cleaned.dim_ad_category(ad_category_id),
    dev_cost NUMERIC NOT NULL,
    marketing_cost NUMERIC NOT NULL,
    users_reached INTEGER NOT NULL CHECK (users_reached >= 0),
    downloads_or_accesses INTEGER NOT NULL CHECK (downloads_or_accesses >= 0),
    avg_bounce_rate NUMERIC CHECK (avg_bounce_rate BETWEEN 0 AND 1),
    cumulative_feedback_from_customers TEXT,
    city_id VARCHAR(10) NOT NULL REFERENCES cleaned.dim_city(city_id)
);

CREATE TABLE cleaned.fact_print_sales (
    id SERIAL PRIMARY KEY,
    edition_id VARCHAR(10) NOT NULL,
    city_id VARCHAR(10) NOT NULL REFERENCES cleaned.dim_city(city_id),
    language VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    month DATE NOT NULL,
    copies_sold INTEGER NOT NULL CHECK (copies_sold >= 0),
    copies_printed INTEGER NOT NULL CHECK (copies_printed >= 0),
    copies_returned INTEGER NOT NULL CHECK (copies_returned >= 0),
    net_circulation INTEGER NOT NULL CHECK (net_circulation >= 0),
    CONSTRAINT check_net_circulation CHECK (net_circulation = copies_printed - copies_returned)
);
