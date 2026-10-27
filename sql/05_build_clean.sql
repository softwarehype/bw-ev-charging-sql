-- =========================================================
-- 05_build_clean.sql
-- Project: Baden-Württemberg EV charging infrastructure
-- Purpose: build the clean layer from raw, applying the tested
--          conversions (03, 04) and the data quality decisions
--          (see docs/data_quality_decisions.xlsx)
-- Run:     the whole file at once; safe to re-run
-- =========================================================

CREATE SCHEMA IF NOT EXISTS clean;            -- folder for cleaned data; IF NOT EXISTS = no error on re-run

DROP TABLE IF EXISTS clean.charging_stations; -- makes the script re-runnable: remove old version first
                                              -- (DROP also removes the old primary key)

CREATE TABLE clean.charging_stations AS       -- CREATE TABLE ... AS = create a table from a query's result
WITH converted AS (                           -- Stage 1: text -> proper data types
    SELECT
        station_id::INTEGER                                  AS station_id,         -- ID as whole number
        operator,                                                                    -- stays text
        status,
        station_type,                                                                -- Normal- / Schnellladeeinrichtung
        num_charge_points::INTEGER                           AS num_charge_points,
        REPLACE(rated_power_kw, ',', '.')::NUMERIC           AS rated_power_kw,     -- '3,6' -> 3.6
        TO_DATE(commissioning_date, 'DD/MM/YYYY')            AS commissioning_date, -- '11/01/2020' -> 2020-01-11
        postcode,                                                                    -- stays text: label, not a quantity
        city,
        district,
        federal_state,
        REPLACE(latitude,  ',', '.')::NUMERIC(9,6)           AS latitude,
        REPLACE(longitude, ',', '.')::NUMERIC(9,6)           AS longitude,
        payment_systems,                                                             -- for question 8
        opening_hours                                                                -- for question 8 ('247' = 24/7)
    FROM raw.charging_stations
)
SELECT                                        -- Stage 2: apply the quality decisions
    station_id, operator, status, station_type, num_charge_points,
    rated_power_kw, commissioning_date, postcode, city, district, federal_state,

    -- Flag: are the coordinates believable?
    CASE
        WHEN federal_state <> 'Baden-Württemberg'               THEN NULL   -- not checked (box only fits BW)
        WHEN latitude  BETWEEN 47.5 AND 49.8
         AND longitude BETWEEN 7.5  AND 10.5                    THEN TRUE   -- inside BW
        ELSE FALSE                                                          -- outside BW -> wrong
    END                                                         AS coords_valid,

    -- Decision: keep the station, but remove a coordinate we know is wrong
    CASE WHEN federal_state = 'Baden-Württemberg'
          AND NOT (latitude BETWEEN 47.5 AND 49.8 AND longitude BETWEEN 7.5 AND 10.5)
         THEN NULL ELSE latitude  END                           AS latitude,
    CASE WHEN federal_state = 'Baden-Württemberg'
          AND NOT (latitude BETWEEN 47.5 AND 49.8 AND longitude BETWEEN 7.5 AND 10.5)
         THEN NULL ELSE longitude END                           AS longitude,

    -- Flag: commissioning date before 2000 is not believable for public EV charging
    commissioning_date < DATE '2000-01-01'                      AS date_suspicious, -- a comparison gives TRUE/FALSE directly

    payment_systems,
    opening_hours
FROM converted;


-- ---------------------------------------------------------
-- Enforce one row per station: unique + not null.
-- If this fails, the source contains duplicate station IDs.
-- ---------------------------------------------------------
ALTER TABLE clean.charging_stations
    ADD PRIMARY KEY (station_id);


-- ---------------------------------------------------------
-- Reconciliation check: clean must match raw
-- ---------------------------------------------------------
SELECT COUNT(*)                                                    AS total_rows,      -- expect 117662 (no rows lost)
       COUNT(*) FILTER (WHERE federal_state = 'Baden-Württemberg') AS bw_rows,         -- expect 19018
       COUNT(*) FILTER (WHERE coords_valid = FALSE)                AS bad_coords,      -- expect 126
       COUNT(*) FILTER (WHERE date_suspicious)                     AS bad_dates        -- expect 1
FROM clean.charging_stations;