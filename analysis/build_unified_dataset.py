# Build the unified analysis dataset from:
#   "Snake Bite Data 2020 - 2025.xlsx"  monthly DHIMS-2 snakebite cases by district and sex, Jan 2020 - Dec 2025
#   data_snake.csv                      district-month cases, population and climate (NASA POWER, NDVI), Jan 2020 - Nov 2025
#   "Snake Bite Data.xlsx"              annual totals by region/district/facility (2023, 2024, Jan-Jun 2025), used for cross-checks only
# Outputs (in data/):
#   snakebite_unified_district_month.csv      one row per district x month (cases_male, cases_female, cases_total + covariates)
#   snakebite_unified_district_month_sex.csv  one row per district x month x sex (for sex as a covariate)
#   data_quality_checks.txt
# Usage: python3 analysis/build_unified_dataset.py
import re
import numpy as np, pandas as pd, openpyxl

MONTHLY_XLSX, ANNUAL_XLSX, CSV = "Snake Bite Data 2020 - 2025.xlsx", "Snake Bite Data.xlsx", "data_snake.csv"
REGIONS = ["Ahafo", "Ashanti", "Bono", "Bono East", "Central", "Eastern", "Greater Accra", "North East", "Northern",
           "Oti", "Savannah", "Upper East", "Upper West", "Volta", "Western", "Western North"]
NORTH = ["Northern", "Upper East", "Upper West", "Savannah", "North East"]
MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
          "November", "December"]
# Ghana 2021 PHC provisional results: 49.3% male, 50.7% female (national); replace with district census counts when available
MALE_SHARE = 0.493
NAME_FIX = {"accra metro": "accra", "bawku municipal": "bawku", "bolgatanga municipal": "bolgatanga",
            "dormaa municipal": "dormaa", "sunyani municipal": "sunyani", "techiman municipal": "techiman",
            "wa municipal": "wa"}
CLIMATE = ["Rainfall", "Relative Humidity", "T2M", "Maximum Temperature", "Minimum Temperature", "ndvi"]
log = []

def norm(v):
    return re.sub(r"\s+", " ", str(v).lower().replace("-", " ").replace("'", "")).strip()

# 1. Monthly cases by sex (district rows only; region rows are subtotals)
rows = list(openpyxl.load_workbook(MONTHLY_XLSX, read_only=True).worksheets[0].iter_rows(values_only=True))
header, body = rows[1], rows[2:]
cols = []
for c in header[1:]:
    m = re.match(r"Snake Bite (\w+) (\d{4}) (Male|Female)", str(c).strip())
    cols.append((int(m.group(2)), MONTHS.index(m.group(1)) + 1, m.group(3).lower()))
recs, region = [], None
for r in body:
    name = str(r[0]).strip()
    if name in REGIONS:
        region = name
        continue
    for (y, mo, sx), v in zip(cols, r[1:]):
        recs.append((norm(name), region, y, mo, sx, 0 if v in ("", None) else int(v)))
sexlong = pd.DataFrame(recs, columns=["district", "region", "year", "month", "sex", "cases"])
sexlong["district"] = sexlong.district.replace(NAME_FIX)
wide = sexlong.pivot_table(index=["district", "region", "year", "month"], columns="sex", values="cases").reset_index()
wide.columns.name = None
wide = wide.rename(columns={"male": "cases_male", "female": "cases_female"})
wide[["cases_male", "cases_female"]] = wide[["cases_male", "cases_female"]].astype(int)
wide["cases_total"] = wide.cases_male + wide.cases_female
log.append(f"Monthly sex file: {wide.district.nunique()} districts, {len(wide)} district-months, "
           f"{wide.cases_total.sum()} cases ({wide.cases_male.sum()} male, {wide.cases_female.sum()} female)")

# 2. Covariates from data_snake.csv
s = pd.read_csv(CSV)
s["district"] = s.district.map(norm)
cov = s[["district", "year", "month", "cases", "population"] + CLIMATE].rename(columns={"cases": "cases_csv"})
u = wide.merge(cov, on=["district", "year", "month"], how="left", indicator=True)
assert not set(cov.district) - set(wide.district), "district in csv not found in xlsx"

# 3. Consistency checks between sources
both = u[u._merge == "both"]
diff = both[both.cases_total != both.cases_csv]
log.append(f"District-months in both sources: {len(both)}; totals differ in {len(diff)} "
           f"(all in {sorted(set(zip(diff.year, diff.month)))}; xlsx minus csv = {int((diff.cases_total - diff.cases_csv).sum())}). "
           "The xlsx (later extraction) is used, since late reports were added for November 2025.")
ann = list(openpyxl.load_workbook(ANNUAL_XLSX, read_only=True).worksheets[0].iter_rows(values_only=True))[2:-1]
ann = pd.DataFrame(ann, columns=["name", "y2023", "y2024", "h1_2025", "total"])
ann["district"] = ann.name.map(norm).replace(NAME_FIX)
ann = ann[ann.district.isin(wide.district)].set_index("district")
chk = pd.DataFrame({
    "y2023": wide[wide.year == 2023].groupby("district").cases_total.sum(),
    "y2024": wide[wide.year == 2024].groupby("district").cases_total.sum(),
    "h1_2025": wide[(wide.year == 2025) & (wide.month <= 6)].groupby("district").cases_total.sum()})
for c in ["y2023", "y2024", "h1_2025"]:
    bad = chk.index[chk[c] != ann.loc[chk.index, c]]
    log.append(f"Annual facility file vs monthly file, {c}: {len(bad)} district mismatches {list(bad)}")

# 4. Fill population for rows absent from the csv (Dec 2025; two districts 2024-25) from the same/last district-year
pop_y = s.groupby(["district", "year"]).population.first()
def pop_for(d, y):
    ys = [yy for (dd, yy) in pop_y.index if dd == d and yy <= y]
    return pop_y[(d, max(ys))] if ys else np.nan
miss = u.population.isna()
u.loc[miss, "population"] = [pop_for(d, y) for d, y in zip(u.loc[miss, "district"], u.loc[miss, "year"])]
u["population_source"] = np.where(miss, "carried from latest available district-year", "data_snake.csv")

# 5. Flags and derived fields
u["regime"] = np.where(u.region.isin(NORTH), "north_unimodal", "south_bimodal")
u["date"] = pd.to_datetime(dict(year=u.year, month=u.month, day=1)).dt.strftime("%Y-%m")
u["t"] = (u.year - 2020) * 12 + u.month
u["climate_available"] = u[CLIMATE].notna().all(axis=1).astype(int)
u["cases_revised_nov2025"] = ((u.year == 2025) & (u.month == 11) & (u._merge == "both") & (u.cases_total != u.cases_csv)).astype(int)
u["all_zero_district"] = (u.groupby("district").cases_total.transform("sum") == 0).astype(int)
# possible non-reporting: a calendar year with zero cases in a district averaging >= 10 cases/year in the other years
yr = u.groupby(["district", "year"]).cases_total.sum().rename("yr_total").reset_index()
yr["other_mean"] = yr.groupby("district").yr_total.transform(lambda v: (v.sum() - v) / (len(v) - 1))
yr["possible_nonreporting_year"] = ((yr.yr_total == 0) & (yr.other_mean >= 10)).astype(int)
u = u.merge(yr[["district", "year", "possible_nonreporting_year"]], on=["district", "year"])
u["in_original_csv"] = (u._merge == "both").astype(int)
u["include_main"] = ((u.all_zero_district == 0) & (u.possible_nonreporting_year == 0) &
                     ~(u.district.isin(["ledzokuku", "ayawaso east"]) & (u.year >= 2024))).astype(int)
flagged = yr[yr.possible_nonreporting_year == 1][["district", "year", "other_mean"]]
log.append(f"Possible non-reporting district-years (zero cases, other years mean >= 10): {flagged.to_dict('records')}")
log.append("Ledzokuku and Ayawaso East: absent from data_snake.csv for 2024-2025 and zero in every 2024-2025 month "
           "of the xlsx; set include_main = 0 for those years (likely non-reporting after boundary changes).")

u = u.rename(columns={"Relative Humidity": "rel_humidity", "Maximum Temperature": "tmax", "Minimum Temperature": "tmin",
                      "Rainfall": "rainfall", "T2M": "t2m"})
order = ["district", "region", "regime", "year", "month", "date", "t", "cases_total", "cases_male", "cases_female",
         "population", "population_source", "rainfall", "rel_humidity", "t2m", "tmax", "tmin", "ndvi",
         "climate_available", "in_original_csv", "cases_revised_nov2025", "all_zero_district",
         "possible_nonreporting_year", "include_main"]
u = u[order].sort_values(["district", "year", "month"]).reset_index(drop=True)
u.to_csv("data/snakebite_unified_district_month.csv", index=False)

# Long format by sex, with an approximate sex-specific population offset
lg = u.melt(id_vars=[c for c in order if c not in ("cases_male", "cases_female")],
            value_vars=["cases_male", "cases_female"], var_name="sex", value_name="cases")
lg["sex"] = lg.sex.str.replace("cases_", "")
lg["population_sex"] = np.where(lg.sex == "male", lg.population * MALE_SHARE, lg.population * (1 - MALE_SHARE))
lg = lg.drop(columns="cases_total")
cols_long = ["district", "region", "regime", "year", "month", "date", "t", "sex", "cases", "population", "population_sex"] + \
            [c for c in order if c not in ("district", "region", "regime", "year", "month", "date", "t", "cases_total",
                                           "cases_male", "cases_female", "population")]
lg = lg[cols_long].sort_values(["district", "year", "month", "sex"]).reset_index(drop=True)
lg.to_csv("data/snakebite_unified_district_month_sex.csv", index=False)

log.append(f"Output district-month: {len(u)} rows ({u.include_main.sum()} with include_main = 1); "
           f"climate available for {u.climate_available.sum()} rows (December 2025 climate not yet extracted).")
log.append(f"Output district-month-sex: {len(lg)} rows. population_sex uses the national 2021 PHC share "
           f"({MALE_SHARE:.1%} male); replace with district census counts by sex when available.")
log.append("Age is not present in either source file; it cannot be added as a covariate from these data.")
open("data/data_quality_checks.txt", "w").write("\n".join(log) + "\n")
print("\n".join(log))
