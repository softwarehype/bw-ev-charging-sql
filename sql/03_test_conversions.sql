-- =========================================================
-- 03_test_conversions.sql
-- Project: Baden-Württemberg EV charging infrastructure
-- Purpose: preview the TEXT -> number/date conversions side by side
--          (raw value next to converted value) BEFORE building anything.
--          A SELECT changes nothing, so this is a safe test.
-- Next:    04 tests the same conversions on ALL rows.
-- =========================================================

SELECT
    num_charge_points,
    num_charge_points::INTEGER                           AS num_charge_points_int,   -- ::INTEGER = cast text to whole number

    rated_power_kw,
    REPLACE(rated_power_kw, ',', '.')::NUMERIC           AS rated_power_kw_num,      -- swap decimal comma for dot, then cast: '3,6' -> 3.6

    commissioning_date,
    TO_DATE(commissioning_date, 'DD/MM/YYYY')            AS commissioning_date_dt,   -- explicit format: '11/01/2020' = 11 January

    latitude,
    REPLACE(latitude, ',', '.')::NUMERIC(9,6)            AS latitude_num             -- 9 digits total, 6 after the point
FROM raw.charging_stations
WHERE federal_state = 'Baden-Württemberg'
  AND rated_power_kw LIKE '%,%'      -- pick rows WITH decimals: test the hard case, not the easy one
LIMIT 10;                            -- a preview is enough here; 04 covers every row