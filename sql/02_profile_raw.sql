-- =========================================================
-- 02_profile_raw.sql
-- Project: Baden-Württemberg EV charging infrastructure
-- Purpose: inspect raw values BEFORE deciding how to convert them
--          (profiling first, cleaning second)
-- =========================================================


-- ---------------------------------------------------------
-- 1. Sample the columns that will become numbers or dates (BW only)
--    Findings: decimal comma in latitude/longitude/power ('48,442398'),
--              dates as DD/MM/YYYY ('23/11/2022')
-- ---------------------------------------------------------
SELECT station_id,
       num_charge_points,
       rated_power_kw,
       commissioning_date,
       latitude,
       longitude,
       plug_power_kw_1
FROM raw.charging_stations
WHERE federal_state = 'Baden-Württemberg'
LIMIT 10;


-- ---------------------------------------------------------
-- 2. Plug columns hold LISTS, not single values
--    e.g. plug_types_1 = 'AC Typ 2 Steckdose; AC Schuko', plug_power_kw_1 = '22; 3'
--    -> cannot be cast to a number; handled later by reshaping (06, 07)
-- ---------------------------------------------------------
SELECT plug_types_1,
       plug_power_kw_1,
       COUNT(*) AS stations
FROM raw.charging_stations
WHERE federal_state = 'Baden-Württemberg'
  AND plug_power_kw_1 LIKE '%;%'          -- a semicolon = more than one value in the cell
GROUP BY plug_types_1, plug_power_kw_1
ORDER BY stations DESC
LIMIT 10;