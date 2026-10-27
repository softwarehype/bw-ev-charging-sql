-- =========================================================
-- 04_test_all_rows.sql
-- Project: Baden-Württemberg EV charging infrastructure
-- Purpose: 1) prove the type conversions work on EVERY row
--          2) range check: find impossible values (sanity check)
--          3) investigate the wrong coordinates found in 2)
-- Decisions: see docs/data_quality_decisions.xlsx
-- =========================================================


-- ---------------------------------------------------------
-- Part A: conversion test on all 117,662 rows (all of Germany)
-- MIN() and MAX() must convert every row to find the smallest/
-- largest value, so if this runs without an error, no row will
-- break the conversion when we build the clean table.
-- Result: 117662 rows, points 1-6, kW 1-1800, dates 1992-10-01 to 2026-09-30
--         -> 1992 suspicious (flagged in 05); 1800 kW plausible (multi-point station)
-- ---------------------------------------------------------
SELECT
    COUNT(*)                                          AS rows_converted, -- total rows checked; expect 117662

    MIN(num_charge_points::INTEGER)                   AS min_points,     -- ::INTEGER = convert text to whole number; MIN = smallest
    MAX(num_charge_points::INTEGER)                   AS max_points,     -- MAX = largest number of charge points at one station

    MIN(REPLACE(rated_power_kw, ',', '.')::NUMERIC)   AS min_kw,         -- REPLACE swaps German decimal comma for a dot ('3,6' -> '3.6'),
                                                                         -- then ::NUMERIC turns the text into a decimal number
    MAX(REPLACE(rated_power_kw, ',', '.')::NUMERIC)   AS max_kw,         -- highest station power: is it realistic?

    MIN(TO_DATE(commissioning_date, 'DD/MM/YYYY'))    AS first_date,     -- TO_DATE reads text as a date, with the format given
                                                                         -- explicitly (day/month/year); MIN = oldest station
    MAX(TO_DATE(commissioning_date, 'DD/MM/YYYY'))    AS last_date       -- newest station: should be on/before 30.09.2026 (data date)

FROM raw.charging_stations;                                              -- no WHERE: test every row in Germany


-- ---------------------------------------------------------
-- Part B: range check on Baden-Württemberg coordinates
-- BW lies roughly between latitude 47.5–49.8 (north–south)
-- and longitude 7.5–10.5 (west–east).
-- Any min/max outside that box = a station placed outside BW.
-- Result: max_lat 54.32459 / min_lon 7.36405 -> one point in the North Sea
-- ---------------------------------------------------------
SELECT
    MIN(REPLACE(latitude,  ',', '.')::NUMERIC)  AS min_lat,  -- southernmost station (expect ~47.5, Lake Constance)
    MAX(REPLACE(latitude,  ',', '.')::NUMERIC)  AS max_lat,  -- northernmost station (expect ~49.8)
    MIN(REPLACE(longitude, ',', '.')::NUMERIC)  AS min_lon,  -- westernmost station (expect ~7.5, the Rhine)
    MAX(REPLACE(longitude, ',', '.')::NUMERIC)  AS max_lon   -- easternmost station (expect ~10.5, Bavarian border)
FROM raw.charging_stations
WHERE federal_state = 'Baden-Württemberg';                   -- only BW rows, because the box only applies to BW


-- ---------------------------------------------------------
-- Part C: which BW stations lie outside the BW box, and is there a pattern?
-- Result: 126 stations at 6 coordinates; 116 share ONE point
--         (54,32459 / 7,36405, amba operations GmbH) -> a system
--         default value, not random typos. Handled in 05:
--         coordinates set to NULL, flag coords_valid = FALSE.
-- ---------------------------------------------------------
SELECT
    latitude,                                          -- the raw coordinate text
    longitude,
    COUNT(*)                             AS stations,  -- how many stations share this exact coordinate
    STRING_AGG(DISTINCT operator, ' | ') AS operators  -- STRING_AGG joins text from many rows into one cell;
                                                       -- DISTINCT lists each operator only once
FROM raw.charging_stations
WHERE federal_state = 'Baden-Württemberg'
  AND (   REPLACE(latitude,  ',', '.')::NUMERIC NOT BETWEEN 47.5 AND 49.8   -- outside north–south range
       OR REPLACE(longitude, ',', '.')::NUMERIC NOT BETWEEN 7.5  AND 10.5 ) -- OR outside west–east range
GROUP BY latitude, longitude                           -- one result row per distinct coordinate
ORDER BY stations DESC;                                -- biggest cluster first