# Baden-Württemberg EV Charging Infrastructure: SQL Analysis

**Where is Baden-Württemberg's public charging network strong, where is it thin, and who runs it?**
An end-to-end SQL project on the official German charging station register (BNetzA Ladesäulenregister, data as of 30.09.2026): loading, profiling, cleaning, normalising and analysing 117,662 charging stations in PostgreSQL.

**Tools:** PostgreSQL 18 · pgAdmin 4 · Excel (file conversion only)
**SQL used:** CTEs · window functions (`RANK`, `NTILE`, `LAG`, `ROW_NUMBER`, `SUM() OVER`, `PARTITION BY`) · `FILTER` · `CASE` · `CROSS JOIN LATERAL` · `UNNEST … WITH ORDINALITY` · type casting · primary keys

---

## Key findings

| # | Finding |
|---|---|
| 1 | **BW has Germany's #3 charging network:** 19,018 stations and 35,437 charge points, 16.8% of the national total, behind NRW and Bayern. |
| 2 | **The build-out peaked in 2023 and has slowed since:** 7,201 new charge points in 2023, then 5,453 (2024, −24%) and 4,954 (2025, −9%). 2026 is on track for about 3,700 (annualised from Jan–Sep). |
| 3 | **The network is concentrated:** Stuttgart alone holds 12.4% of BW's charge points; half the network sits in 12 of 44 districts. |
| 4 | **Stuttgart leads in quantity but lags in fast charging:** 19.1% of BW's charge points are fast (DC); Stuttgart has the lowest share of all 44 districts (5.4%), Rhein-Neckar-Kreis the highest (39.7%). |
| 5 | **Capacity per charge point varies three-fold:** from 20.4 kW (Stuttgart) to 61.6 kW (Heidenheim); BW average 34.2 kW, 1.21 GW installed in total. |
| 6 | **Fragmented overall, dominated locally:** 1,874 operators; the largest (EnBW mobility+) has only 7.6%. But in Emmendingen and Calw one operator runs over half the network, and Mercedes-Benz runs 43% of Böblingen's charge points. |
| 7 | **The network is mostly AC; new fast charging is high-power CCS:** 82.5% of 38,169 connectors are AC. CCS outnumbers CHAdeMO 18 to 1, and 71% of CCS connectors deliver 150 kW or more. |
| 8 | **Fast chargers are far more driver-friendly:** 57.8% of fast stations accept debit/credit card vs 12.4% of normal stations. At least 41% of fast stations are confirmed open 24/7 (opening hours are unspecified for most stations). |

---

## Business questions

1. How big is BW's charging network, and how does it rank among the 16 federal states?
2. How has BW's network grown each year?
3. Which districts have the most and the fewest charge points, and how concentrated is the network?
4. What share of each district's charge points is fast charging?
5. How do districts rank by installed power, and which tier does each fall into?
6. Who runs the network, and does any operator dominate a district?
7. What is the mix of connector types and power classes?
8. What share of stations is open 24/7 and accepts card payment?

---

## Data

| | |
|---|---|
| **Source** | Bundesnetzagentur, *Liste der Ladesäulen* ([bundesnetzagentur.de/ladeinfrastruktur](https://www.bundesnetzagentur.de/ladeinfrastruktur)) |
| **Data as of** | 30.09.2026 |
| **Coverage** | All public charging stations in Germany whose registration with BNetzA is complete (117,662 stations; BW: 19,018) |
| **Not in this repo** | The source files (~30–55 MB) exceed GitHub's limits. Download the xlsx from the link above to reproduce. |

---

## Method

```
raw.charging_stations      117,662 rows   source data, unchanged (47 TEXT columns)
        │  05: convert types, null wrong coordinates, add 2 quality flags, primary key
        ▼
clean.charging_stations    117,662 rows   one row per station
        │  06: unpivot 6 plug column groups (wide → long)
        ▼
clean.charge_points        BW: 35,437     one row per charge point
        │  07: split connector lists ('AC Typ 2; AC Schuko' / '22; 3')
        ▼
clean.connectors           BW: 38,169     one row per connector
```

| File | What it does |
|---|---|
| [`01_load_raw.sql`](sql/01_load_raw.sql) | Raw schema and table (all TEXT), import settings, reconciliation against the source |
| [`02_profile_raw.sql`](sql/02_profile_raw.sql) | Inspect raw values before converting (decimal commas, DD/MM/YYYY dates, list-valued plug columns) |
| [`03_test_conversions.sql`](sql/03_test_conversions.sql) | Preview conversions side by side on the hardest rows |
| [`04_test_all_rows.sql`](sql/04_test_all_rows.sql) | Test conversions on every row; range checks; investigate wrong coordinates |
| [`05_build_clean.sql`](sql/05_build_clean.sql) | Build the clean station table with quality decisions applied |
| [`06_build_charge_points.sql`](sql/06_build_charge_points.sql) | Unpivot plug groups into one row per charge point |
| [`07_build_connectors.sql`](sql/07_build_connectors.sql) | Split connector lists into one row per connector, with NULL checks |
| [`08_analysis.sql`](sql/08_analysis.sql) | Business questions Q1–Q8 |

**Every build step ends with a reconciliation check** (row counts against the previous layer). The clean layer (05–07) was rebuilt from scratch and reproduced all counts.

---

## Data quality

Issues were found by profiling and range checks, then handled with one rule: **does it affect the questions being answered?** Rows are never deleted to fix a single bad value, issues are flagged rather than hidden, and no values are invented. Full log: [`docs/data_quality_decisions.xlsx`](docs/data_quality_decisions.xlsx).

| Issue | Evidence | Decision |
|---|---|---|
| Wrong coordinates | 126 BW stations outside BW; **116 share one point in the North Sea** (one operator's default value) | Keep stations; set coordinates to NULL; flag `coords_valid = FALSE` |
| Implausible date | One station commissioned in 1992 (next oldest: 2001) | Keep; flag `date_suspicious`; excluded from the growth analysis |
| Decimal commas, DD/MM/YYYY dates | `48,442398`, `11/01/2020` | Convert with `REPLACE` + cast and `TO_DATE`, tested on all rows |
| Hidden spaces in operator names | 28 BW names with leading/trailing spaces (1,452 stations) | `TRIM` before grouping |
| Incomplete connector lists | 110 charge points outside BW with unequal type/power lists | Keep as NULL; 0 affected in BW |
| Implausible connector power | 48 AC connectors (0.1%) report more than the AC maximum of ~43 kW | Keep as reported; documented |

---

## Limitations

- **Absolute counts favour large districts.** A per-resident or per-EV comparison needs population and vehicle-stock data (planned as Part 2, using KBA data).
- **Survivorship:** the register lists stations operating today, so year-by-year growth shows today's network by year of commissioning, not the network size in past years.
- **2026 is a partial year** (January–September).
- **Installed power is capacity, not usage.**
- **Opening hours are unspecified for 69% of BW stations,** so 24/7 shares are minimums.
- Hypotheses mentioned (company chargers in Böblingen/Stuttgart, motorway corridors, end of the EV subsidy in Dec 2023) are **not tested** with this data.

---

## How to reproduce

1. Download the xlsx from [bundesnetzagentur.de/ladeinfrastruktur](https://www.bundesnetzagentur.de/ladeinfrastruktur).
2. Delete the 10 note rows above the header and save as **CSV UTF-8**.
3. In PostgreSQL, run `01_load_raw.sql` up to the CREATE TABLE, then import the CSV into `raw.charging_stations` (pgAdmin Import/Export: csv, UTF8, header on, delimiter `;`, quote `"`).
4. Run the reconciliation check in `01`, then files `05` → `06` → `07`, each as a whole file.
5. Run the queries in `08_analysis.sql` one at a time.

---

## About

I'm Matthew Okeke, a career changer moving into data analytics after 16 years in hospitality,
most recently in corporate catering. My background in psychology (Diplom, University of Nigeria,
Nsukka) and years of running service operations taught me to start from the people behind the
numbers: what a stakeholder needs to decide, and what the data can and can't honestly tell them.

This project is part of my portfolio for Junior Data Analyst / BI Analyst roles in the Stuttgart
region. It shows the full workflow in SQL: loading, profiling, cleaning, normalising, reconciling
and answering business questions on real public data.

- Project 1: [Stuttgart population dashboard (Power BI)](https://github.com/softwarehype/stuttgart-population-dashboard)
