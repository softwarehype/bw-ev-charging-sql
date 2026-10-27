-- =========================================================
-- 08_analysis.sql
-- Project: Baden-Württemberg EV charging infrastructure
-- Source:  BNetzA Ladesäulenregister, data as of 30.09.2026
-- Purpose: answer business questions Q1-Q8 on the clean layer
--          (clean.charging_stations, clean.connectors)
-- Run:     highlight one query at a time and press F5
-- Findings: see README.md
-- =========================================================


-- ---------------------------------------------------------
-- Q1: How big is BW's charging network, and how does it
--     rank among the 16 federal states?
-- ---------------------------------------------------------
WITH by_state AS (                                     -- Step 1: one row per state
    SELECT federal_state,
           COUNT(*)                AS stations,        -- each row = one station
           SUM(num_charge_points)  AS charge_points    -- a station can have 1–6 points
    FROM clean.charging_stations
    GROUP BY federal_state
)
SELECT federal_state,
       stations,
       charge_points,
       RANK() OVER (ORDER BY stations      DESC) AS rank_by_stations,  -- window function: rank WITHOUT collapsing rows
       RANK() OVER (ORDER BY charge_points DESC) AS rank_by_points,
       ROUND(100.0 * charge_points / SUM(charge_points) OVER (), 1)
                                                 AS pct_of_germany_points  -- share of the national total
FROM by_state
ORDER BY charge_points DESC;


-- ---------------------------------------------------------
-- Q2: How has BW's charging network grown each year?
--     (charge points by year of commissioning, BW only)
-- ---------------------------------------------------------
WITH yearly AS (                                            -- Step 1: one row per year
    SELECT EXTRACT(YEAR FROM commissioning_date)::INTEGER AS year,  -- EXTRACT pulls the year out of a date
           COUNT(*)                                       AS new_stations,
           SUM(num_charge_points)                         AS new_charge_points
    FROM clean.charging_stations
    WHERE federal_state = 'Baden-Württemberg'
      AND NOT date_suspicious                               -- exclude the 1992 station (our flag)
    GROUP BY 1                                              -- 1 = the first column in the SELECT (year)
),
with_windows AS (                                           -- Step 2: add the window calculations
    SELECT year,
           new_stations,
           new_charge_points,
           LAG(new_charge_points) OVER (ORDER BY year)      AS prev_year_points,      -- value from the row before
           SUM(new_charge_points) OVER (ORDER BY year)      AS cumulative_points      -- running total up to this year
    FROM yearly
)
SELECT year,
       new_stations,
       new_charge_points,
       ROUND(100.0 * (new_charge_points - prev_year_points) / prev_year_points, 1)
                                                            AS yoy_growth_pct,        -- (this year - last year) / last year
       cumulative_points                                    -- check: 2026 row = 35436
FROM with_windows
WHERE year >= 2010                                          -- filter AFTER the windows, so the running total keeps 2001-2008
ORDER BY year;


-- ---------------------------------------------------------
-- Q3: Which BW districts have the most and the fewest
--     charge points? How concentrated is the network?
-- ---------------------------------------------------------
WITH by_district AS (                                       -- Step 1: one row per district
    SELECT district,
           CASE WHEN district LIKE 'Stadtkreis%' THEN 'City'   -- independent city
                ELSE 'Rural district'                          -- Landkreis
           END                                  AS district_type,
           COUNT(*)                             AS stations,
           SUM(num_charge_points)               AS charge_points
    FROM clean.charging_stations
    WHERE federal_state = 'Baden-Württemberg'
    GROUP BY district
)
SELECT district,
       district_type,
       stations,
       charge_points,
       RANK() OVER (ORDER BY charge_points DESC)                    AS rank_in_bw,
       ROUND(100.0 * charge_points / SUM(charge_points) OVER (), 1) AS pct_of_bw,         -- share of BW total
       ROUND(100.0 * SUM(charge_points) OVER (ORDER BY charge_points DESC)
                   / SUM(charge_points) OVER (), 1)                 AS cumulative_pct     -- running share: top N together
FROM by_district
ORDER BY charge_points DESC;


-- ---------------------------------------------------------
-- Q4: What share of each BW district's charge points is
--     fast charging, compared with the BW average?
-- ---------------------------------------------------------
WITH by_district AS (                                       -- Step 1: one row per district
    SELECT district,
           SUM(num_charge_points)                                        AS charge_points,
           SUM(num_charge_points) FILTER
               (WHERE station_type = 'Schnellladeeinrichtung')           AS fast_points   -- only fast stations' points
    FROM clean.charging_stations
    WHERE federal_state = 'Baden-Württemberg'
    GROUP BY district
)
SELECT district,
       charge_points,
       fast_points,
       ROUND(100.0 * fast_points / charge_points, 1)                     AS fast_pct,       -- district's own share
       ROUND(100.0 * SUM(fast_points) OVER () / SUM(charge_points) OVER (), 1)
                                                                         AS bw_fast_pct,    -- BW average, same on every row
       ROUND(100.0 * fast_points / charge_points
           - 100.0 * SUM(fast_points) OVER () / SUM(charge_points) OVER (), 1)
                                                                         AS diff_vs_bw      -- percentage points: + above, - below
FROM by_district                                            -- read from the CTE, not from the big table
ORDER BY fast_pct DESC;                                     -- highest fast share first


-- ---------------------------------------------------------
-- Q5: How do BW districts rank by installed charging power,
--     and which tier (quartile) does each fall into?
-- ---------------------------------------------------------
WITH by_district AS (                                          -- Step 1: one row per district
    SELECT district,
           SUM(num_charge_points)     AS charge_points,
           SUM(rated_power_kw)        AS installed_kw          -- total capacity of all stations
    FROM clean.charging_stations
    WHERE federal_state = 'Baden-Württemberg'
    GROUP BY district
)
SELECT district,
       charge_points,
       ROUND(installed_kw)                                     AS installed_kw,
       ROUND(installed_kw / charge_points, 1)                  AS avg_kw_per_point,   -- capacity per point
       RANK()  OVER (ORDER BY installed_kw DESC)               AS rank_by_kw,
       RANK()  OVER (ORDER BY charge_points DESC)              AS rank_by_points,     -- from Q3, for comparison
       NTILE(4) OVER (ORDER BY installed_kw DESC)              AS kw_tier             -- 1 = top 25%, 4 = bottom 25%
FROM by_district
ORDER BY installed_kw DESC;


-- ---------------------------------------------------------
-- Q6A: Who are the biggest charging operators in BW,
--      and how concentrated is the market?
-- ---------------------------------------------------------
WITH by_operator AS (
    SELECT TRIM(operator)            AS operator,       -- TRIM: some names have hidden trailing spaces
           COUNT(*)                  AS stations,
           SUM(num_charge_points)    AS charge_points
    FROM clean.charging_stations
    WHERE federal_state = 'Baden-Württemberg'
    GROUP BY TRIM(operator)                             -- group on the trimmed name, so variants merge
),
ranked AS (
    SELECT operator,
           stations,
           charge_points,
           RANK() OVER (ORDER BY charge_points DESC)                         AS rank_in_bw,
           ROUND(100.0 * charge_points / SUM(charge_points) OVER (), 1)      AS market_share_pct,
           ROUND(100.0 * SUM(charge_points) OVER (ORDER BY charge_points DESC)
                       / SUM(charge_points) OVER (), 1)                      AS cumulative_pct,
           COUNT(*) OVER ()                                                  AS total_operators   -- how many operators in BW
    FROM by_operator
)
SELECT *
FROM ranked
WHERE rank_in_bw <= 10                                  -- show only the top 10
ORDER BY rank_in_bw;


-- ---------------------------------------------------------
-- Q6B: Which operator has the largest share in each BW district?
-- ---------------------------------------------------------
WITH by_district_operator AS (                                   -- one row per district + operator pair
    SELECT district,
           TRIM(operator)             AS operator,
           SUM(num_charge_points)     AS charge_points
    FROM clean.charging_stations
    WHERE federal_state = 'Baden-Württemberg'
    GROUP BY district, TRIM(operator)
),
ranked AS (
    SELECT district,
           operator,
           charge_points,
           ROUND(100.0 * charge_points
                 / SUM(charge_points) OVER (PARTITION BY district), 1)   AS share_in_district_pct,
           ROW_NUMBER() OVER (PARTITION BY district
                              ORDER BY charge_points DESC)               AS rn   -- 1 = biggest operator in that district
    FROM by_district_operator
)
SELECT district,
       operator               AS top_operator,
       charge_points,
       share_in_district_pct
FROM ranked
WHERE rn = 1                                                     -- keep only the #1 operator per district
ORDER BY share_in_district_pct DESC;


-- ---------------------------------------------------------
-- Q7: What is the mix of connector types and power classes
--     in BW? (one row per connector, from clean.connectors)
-- ---------------------------------------------------------
WITH bw_connectors AS (                                        -- Step 1: BW connectors + derived labels
    SELECT c.connector_type,
           c.power_kw,
           LEFT(c.connector_type, 2)                AS current_type,   -- 'AC' or 'DC': first 2 characters
           CASE WHEN c.power_kw <= 22  THEN '1 Normal (<=22 kW)'
                WHEN c.power_kw <  150 THEN '2 Fast (23-149 kW)'
                ELSE                        '3 High-power (>=150 kW)'
           END                                      AS power_class
    FROM clean.connectors c
    JOIN clean.charging_stations s USING (station_id)          -- the state is in the station table
    WHERE s.federal_state = 'Baden-Württemberg'
)
SELECT current_type,
       connector_type,
       power_class,
       COUNT(*)                                                AS connectors,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS pct_of_bw,
       ROUND(AVG(power_kw), 1)                                 AS avg_kw
FROM bw_connectors
GROUP BY current_type, connector_type, power_class
ORDER BY current_type, connector_type, power_class;


-- ---------------------------------------------------------
-- Q7 check: AC connectors above the physical AC limit (~43 kW)
--     (data quality, documented in docs/data_quality_decisions.xlsx)
-- ---------------------------------------------------------
SELECT COUNT(*) AS implausible_ac_connectors        -- expect 48
FROM clean.connectors c
JOIN clean.charging_stations s USING (station_id)
WHERE s.federal_state = 'Baden-Württemberg'
  AND c.connector_type LIKE 'AC%'                   -- AC connectors only
  AND c.power_kw > 43;                              -- above the AC maximum


-- ---------------------------------------------------------
-- Q8: What share of BW stations is open 24/7, and what share
--     accepts debit/credit card payment? (normal vs fast)
-- ---------------------------------------------------------
SELECT
    station_type,
    COUNT(*)                                                                 AS stations,

    -- Opening hours: three groups, because "not specified" is NOT the same as "no"
    ROUND(100.0 * COUNT(*) FILTER (WHERE opening_hours = '247')           / COUNT(*), 1) AS pct_confirmed_24_7,
    ROUND(100.0 * COUNT(*) FILTER (WHERE opening_hours = 'Eingeschränkt') / COUNT(*), 1) AS pct_restricted,
    ROUND(100.0 * COUNT(*) FILTER (WHERE opening_hours = 'Keine Angabe')  / COUNT(*), 1) AS pct_hours_unknown,

    -- Payment: card = debit or credit card, contactless (NFC) or card reader
    ROUND(100.0 * COUNT(*) FILTER (WHERE payment_systems LIKE '%Kreditkarte%'
                                      OR payment_systems LIKE '%Debitkarte%') / COUNT(*), 1) AS pct_card_payment,
    ROUND(100.0 * COUNT(*) FILTER (WHERE payment_systems IS NULL)         / COUNT(*), 1) AS pct_payment_unknown
FROM clean.charging_stations
WHERE federal_state = 'Baden-Württemberg'
GROUP BY station_type
ORDER BY station_type;