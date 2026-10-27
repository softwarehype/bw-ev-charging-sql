-- =========================================================
-- 07_build_connectors.sql
-- Project: Baden-Württemberg EV charging infrastructure
-- Purpose: split each charge point's connector lists
--          ('AC Typ 2 Steckdose; AC Schuko' / '22; 3')
--          into one row per connector with numeric power
-- Run:     the whole file at once; safe to re-run (after 06)
-- =========================================================

DROP TABLE IF EXISTS clean.connectors;        -- re-runnable

CREATE TABLE clean.connectors AS
SELECT
    cp.station_id,
    cp.point_no,
    c.connector_no,                                                -- position in the list (1, 2, ...)
    TRIM(c.connector_type)                        AS connector_type, -- TRIM removes the space after ';'
    REPLACE(TRIM(c.power_txt), ',', '.')::NUMERIC AS power_kw        -- '7,2' -> 7.2, same fix as before
FROM clean.charge_points AS cp
CROSS JOIN LATERAL
    UNNEST(
        STRING_TO_ARRAY(cp.connector_types,    ';'),               -- 'A; B' -> {'A',' B'}
        STRING_TO_ARRAY(cp.connector_power_kw, ';')                -- '22; 3' -> {'22',' 3'}
    ) WITH ORDINALITY AS c(connector_type, power_txt, connector_no);
    -- UNNEST with TWO arrays walks them side by side: 1st with 1st, 2nd with 2nd
    -- WITH ORDINALITY adds the position number as an extra column


-- ---------------------------------------------------------
-- Check 1: connector count per type in BW
-- Expect 6 types, 38,169 connectors in total:
-- AC Typ 2 Steckdose 25641 | DC Combo 2 (CCS) 6338 | AC Typ 2 Fahrzeugkupplung 3835
-- AC Schuko 1997 | DC CHAdeMO 356 | AC Typ 1 Steckdose 2
-- ---------------------------------------------------------
SELECT c.connector_type,
       COUNT(*) AS connectors
FROM clean.connectors c
JOIN clean.charging_stations s USING (station_id)
WHERE s.federal_state = 'Baden-Württemberg'
GROUP BY c.connector_type
ORDER BY connectors DESC;


-- ---------------------------------------------------------
-- Check 2: no connector without a type or a power value
-- (UNNEST pads a shorter list with NULL silently, no error)
-- Result (all of Germany): missing_type 1, missing_power 109 -> see Check 3
-- ---------------------------------------------------------
SELECT COUNT(*) FILTER (WHERE connector_type IS NULL) AS missing_type,
       COUNT(*) FILTER (WHERE power_kw       IS NULL) AS missing_power
FROM clean.connectors;


-- ---------------------------------------------------------
-- Check 3: where are the incomplete connectors? (by state)
-- Result: 6 states (Hessen 35, NRW 29, Bayern 15, Berlin 12,
--         Rheinland-Pfalz 10, Niedersachsen 9), NONE in BW.
-- Decision: keep as NULL; true value unknown, no data invented.
-- ---------------------------------------------------------
SELECT s.federal_state,
       COUNT(*) FILTER (WHERE c.connector_type IS NULL) AS missing_type,
       COUNT(*) FILTER (WHERE c.power_kw       IS NULL) AS missing_power
FROM clean.connectors c
JOIN clean.charging_stations s USING (station_id)   -- bring in the state from the station table
WHERE c.connector_type IS NULL
   OR c.power_kw IS NULL                            -- only the problem rows
GROUP BY s.federal_state
ORDER BY missing_power DESC;