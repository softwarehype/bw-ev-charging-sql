-- =========================================================
-- 01_load_raw.sql
-- Project: Baden-Württemberg EV charging infrastructure
-- Source:  BNetzA Ladesäulenregister, data as of 30.09.2026
-- Purpose: Create the raw layer and load the source CSV unchanged
-- Note:    Run once on an empty database. Re-running gives
--          "relation already exists" - that protects the loaded data.
-- =========================================================

-- 1. Schema for untouched source data
CREATE SCHEMA IF NOT EXISTS raw;              -- IF NOT EXISTS: no error if the schema is already there

-- 2. Raw table: all columns TEXT so no value is rejected on import.
--    Column order matches the CSV exactly (import is by position).
CREATE TABLE raw.charging_stations (
    -- General information (CSV columns 1–23)
    station_id          TEXT,  -- Ladeeinrichtungs-ID
    operator            TEXT,  -- Betreiber
    display_name        TEXT,  -- Anzeigename (Karte)
    status              TEXT,  -- Status
    station_type        TEXT,  -- Art der Ladeeinrichtung
    num_charge_points   TEXT,  -- Anzahl Ladepunkte
    rated_power_kw      TEXT,  -- Nennleistung Ladeeinrichtung [kW]
    commissioning_date  TEXT,  -- Inbetriebnahmedatum
    street              TEXT,  -- Straße
    house_number        TEXT,  -- Hausnummer
    address_suffix      TEXT,  -- Adresszusatz
    postcode            TEXT,  -- Postleitzahl
    city                TEXT,  -- Ort
    district            TEXT,  -- Kreis/kreisfreie Stadt
    federal_state       TEXT,  -- Bundesland
    latitude            TEXT,  -- Breitengrad
    longitude           TEXT,  -- Längengrad
    location_label      TEXT,  -- Standortbezeichnung
    parking_info        TEXT,  -- Informationen zum Parkraum
    payment_systems     TEXT,  -- Bezahlsysteme
    opening_hours       TEXT,  -- Öffnungszeiten
    opening_weekdays    TEXT,  -- Öffnungszeiten: Wochentage
    opening_times       TEXT,  -- Öffnungszeiten: Tageszeiten
    -- Plugs 1–6: same 4 columns repeated (CSV columns 24–47)
    plug_types_1 TEXT, plug_power_kw_1 TEXT, evse_id_1 TEXT, public_key_1 TEXT,
    plug_types_2 TEXT, plug_power_kw_2 TEXT, evse_id_2 TEXT, public_key_2 TEXT,
    plug_types_3 TEXT, plug_power_kw_3 TEXT, evse_id_3 TEXT, public_key_3 TEXT,
    plug_types_4 TEXT, plug_power_kw_4 TEXT, evse_id_4 TEXT, public_key_4 TEXT,
    plug_types_5 TEXT, plug_power_kw_5 TEXT, evse_id_5 TEXT, public_key_5 TEXT,
    plug_types_6 TEXT, plug_power_kw_6 TEXT, evse_id_6 TEXT, public_key_6 TEXT
);

-- 3. Import (done in pgAdmin: right-click table -> Import/Export Data)
--    File:     ladesaeulenregister_2026-09-30.csv (saved from the BNetzA .xlsx
--              as "CSV UTF-8", top 10 note rows removed)
--    Settings: Format csv | Encoding UTF8 | Header ON | Delimiter ; | Quote "

-- 4. Reconciliation check: must match the source file
--    Expected: 117662 total, 19018 Baden-Württemberg
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE federal_state = 'Baden-Württemberg') AS bw_rows
FROM raw.charging_stations;