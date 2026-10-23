-- ====================================================================
-- PROJECT: Global ESG & Energy Transition Analytics
-- AUTHOR: Rejwana Akter
-- STACK: Databricks Lakehouse (Delta Lake, SQL Analytics) & Power BI
-- ARCHITECTURE: Medallion Architecture (Bronze -> Silver -> Gold)
-- ====================================================================

USE CATALOG workspace;
USE SCHEMA default;

-- --------------------------------------------------------------------
-- STEP 1: BRONZE LAYER (Raw Data Ingestion)
-- --------------------------------------------------------------------
SELECT COUNT(*) AS total_bronze_records FROM workspace.default.bronze_energy_raw;


-- --------------------------------------------------------------------
-- STEP 2: SILVER LAYER (Data Cleaning, Typing & Quality Validation)
-- --------------------------------------------------------------------
CREATE OR REPLACE TABLE silver_energy_cleaned
USING DELTA AS
SELECT 
    TRIM(iso_code) AS iso_code,
    TRIM(country) AS country,
    CAST(year AS INT) AS year,
    COALESCE(CAST(population AS BIGINT), 0) AS population,
    COALESCE(CAST(gdp AS DOUBLE), 0) AS gdp,
    -- Energy Generation Metrics (TWh)
    COALESCE(CAST(electricity_generation AS DOUBLE), 0) AS total_electricity_twh,
    COALESCE(CAST(fossil_electricity AS DOUBLE), 0) AS fossil_electricity_twh,
    COALESCE(CAST(renewables_electricity AS DOUBLE), 0) AS renewable_electricity_twh,
    COALESCE(CAST(solar_electricity AS DOUBLE), 0) AS solar_twh,
    COALESCE(CAST(wind_electricity AS DOUBLE), 0) AS wind_twh,
    COALESCE(CAST(hydro_electricity AS DOUBLE), 0) AS hydro_twh,
    -- Emissions (Million Tonnes CO2)
    COALESCE(CAST(greenhouse_gas_emissions AS DOUBLE), 0) AS co2_emissions_mt
FROM bronze_energy_raw
WHERE iso_code IS NOT NULL 
  AND LENGTH(TRIM(iso_code)) = 3
  AND CAST(year AS INT) >= 1990;


-- --------------------------------------------------------------------
-- STEP 3: GOLD LAYER (Dimensional Modeling - Star Schema for BI)
-- --------------------------------------------------------------------

-- Dimension: Country Table
CREATE OR REPLACE TABLE gold_dim_country
USING DELTA AS
SELECT DISTINCT
    iso_code,
    country
FROM silver_energy_cleaned;

-- Fact Table: Energy & Carbon Transition
CREATE OR REPLACE TABLE gold_fact_energy_transition
USING DELTA AS
SELECT 
    iso_code,
    country,
    year,
    population,
    gdp,
    total_electricity_twh,
    fossil_electricity_twh,
    renewable_electricity_twh,
    solar_twh,
    wind_twh,
    hydro_twh,
    co2_emissions_mt,
    -- Pre-calculated Analytical Metrics
    ROUND(
        CASE 
            WHEN total_electricity_twh > 0 THEN (renewable_electricity_twh / total_electricity_twh) * 100 
            ELSE 0 
        END, 2
    ) AS renewable_share_pct,
    ROUND(
        CASE 
            WHEN gdp > 0 THEN (co2_emissions_mt / (gdp / 1000000000))
            ELSE 0 
        END, 2
    ) AS carbon_intensity
FROM silver_energy_cleaned;

-- Validation check
SELECT COUNT(*) AS total_gold_records FROM gold_fact_energy_transition;
