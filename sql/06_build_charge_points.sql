-- =========================================================
-- 06_build_charge_points.sql
-- Project: Baden-Württemberg EV charging infrastructure
-- Purpose: unpivot the 6 plug column groups (wide) into one
--          row per charge point (long)
-- Why:     profiling (02) showed plug group N = charge point N;
--          filled groups always equal num_charge_points
-- Run:     the whole file at once; safe to re-run (after 05)
-- =========================================================

DROP TABLE IF EXISTS clean.charge_points;     -- re-runnable

CREATE TABLE clean.charge_points AS
SELECT
    r.station_id::INTEGER  AS station_id,     -- link back to clean.charging_stations
    p.point_no,                               -- which charge point at the station (1–6)
    p.connector_types,                        -- still a list, e.g. 'AC Typ 2 Steckdose; AC Schuko'
    p.connector_power_kw                      -- matching list, e.g. '22; 3' (split in 07)
FROM raw.charging_stations AS r
CROSS JOIN LATERAL (                          -- for EACH station row, produce the rows below
    VALUES
        (1, r.plug_types_1, r.plug_power_kw_1),   -- each line = one plug group turned into one row
        (2, r.plug_types_2, r.plug_power_kw_2),
        (3, r.plug_types_3, r.plug_power_kw_3),
        (4, r.plug_types_4, r.plug_power_kw_4),
        (5, r.plug_types_5, r.plug_power_kw_5),
        (6, r.plug_types_6, r.plug_power_kw_6)
) AS p(point_no, connector_types, connector_power_kw)   -- name the 3 columns of these rows
WHERE p.connector_types IS NOT NULL;          -- drop empty groups (a 2-point station keeps 2 rows, not 6)


-- ---------------------------------------------------------
-- Check: charge point rows must equal the sum of
-- num_charge_points (BW expected: 35437 and 35437)
-- ---------------------------------------------------------
SELECT
    (SELECT COUNT(*)
     FROM clean.charge_points cp
     JOIN clean.charging_stations s USING (station_id)       -- USING = join on the same-named column
     WHERE s.federal_state = 'Baden-Württemberg')            AS bw_point_rows,
    (SELECT SUM(num_charge_points)
     FROM clean.charging_stations
     WHERE federal_state = 'Baden-Württemberg')              AS bw_points_declared;