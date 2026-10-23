# Unified snakebite dataset

These files are built by `analysis/build_unified_dataset.py` from three source files, which are left unchanged:

* `Snake Bite Data 2020 - 2025.xlsx`: monthly DHIMS-2 snakebite cases by district and sex, January 2020 to December 2025.
* `data_snake.csv`: district-month cases, population and climate, January 2020 to November 2025.
* `Snake Bite Data.xlsx`: annual totals by region, district and facility for 2023, 2024 and January–June 2025. It is used only to cross-check the monthly counts.

Case counts come from the monthly sex-disaggregated file, which is the later and more complete extraction. Population and climate come from `data_snake.csv`. The checks are listed in `data_quality_checks.txt`.

## Files

**`snakebite_unified_district_month.csv`** has one row per district and month: 261 districts × 72 months = 18,792 rows. Use it for models of total cases, with sex shares available as a district-month covariate if needed.

**`snakebite_unified_district_month_sex.csv`** has one row per district, month and sex: 37,584 rows. Use it for models with sex as a covariate, for example `cases ~ sex + climate terms + (1 | region/district) + offset(log(population_sex))`.

**`district_points.csv`** gives one point per district, inside its boundary polygon, for extracting climate. Guan has no polygon and uses the point of Afadjato South, which shares Guan's NASA POWER grid cell.

## Variables

| Variable | Meaning |
|---|---|
| `district`, `region` | District (lower case, harmonised to `data_snake.csv` spelling) and region |
| `regime` | Rainfall regime: `north_unimodal` (Northern, Savannah, North East, Upper East, Upper West) or `south_bimodal` |
| `year`, `month`, `date`, `t` | Calendar year and month, `YYYY-MM`, and a time index from 1 (Jan 2020) to 72 (Dec 2025) |
| `cases_total`, `cases_male`, `cases_female` | Reported snakebite cases (district-month file) |
| `sex`, `cases` | Sex and the sex-specific case count (district-month-sex file) |
| `population` | Annual district population from `data_snake.csv`; for rows absent from that file, carried from the latest available district-year (see `population_source`) |
| `population_sex` | Approximate sex-specific population: `population` × 0.493 for males and × 0.507 for females, the national shares in the 2021 Population and Housing Census provisional results. Replace with district census counts by sex when available |
| `rainfall` | NASA POWER precipitation, monthly mean, mm/day |
| `rel_humidity` | Relative humidity at 2 m, % |
| `t2m`, `tmax`, `tmin` | Mean, maximum and minimum air temperature at 2 m, °C |
| `ndvi` | District mean NDVI |
| `climate_available` | 1 if all climate variables are present. December 2025 is filled by running `Rscript analysis/extract_dec2025_climate.R` |
| `in_original_csv` | 1 if the district-month was in `data_snake.csv` |
| `cases_revised_nov2025` | 1 for the 146 November 2025 district-months whose counts rose in the later extraction (late reports, +556 cases) |
| `all_zero_district` | 1 for Ayawaso East, which reports no cases in any month |
| `possible_nonreporting_year` | 1 for district-years with zero cases where the district averages at least 10 cases a year otherwise: Accra 2025, Ada West 2020, Jasikan 2025, Saboba 2024 and Sagnarigu 2021 |
| `include_main` | 1 for rows recommended for the main analysis. It excludes the all-zero district, the flagged non-reporting district-years, and Ledzokuku and Ayawaso East in 2024–2025, which are zero throughout and absent from `data_snake.csv` |

## Age

Age is not included. The age-group export (`data/Snake Bite Data-1.xlsx`, kept unchanged) covers January 2024 to October 2025 only. Age data for 2020–2023 are not available, and the export stops partway through November 2025 at Excel's 256-column limit. A complete age export for all of 2020–2025, with months as rows, would allow age to be added in the same way as sex.
