# District multidimensional poverty from the Ghana Statistical Service 2021 Population and Housing Census (GSS MPI tables).
# Inputs (data/, downloaded from the GSS StatsBank; left unchanged):
#   MPI1_*.xlsx  Multidimensional poverty by geographic area: incidence (H), intensity (A), MPI (M0)        [optional]
#   MPI2_*.xlsx  ... by sex of household head
#   MPI3_*.xlsx  ... by education of household head
#   MPI4_*.xlsx  ... by industry of household head
#   MPI5_*.xlsx  Contributors (%) of the 13 indicators to the MPI
# Output: data/district_poverty.csv, one row per district of the snakebite data (261), matched within region.
# The build script analysis/build_unified_dataset.py merges it into the unified datasets.
# Usage: python3 analysis/build_poverty.py
import glob, re, sys
import numpy as np, pandas as pd

REGIONS = ["Western", "Central", "Greater Accra", "Volta", "Eastern", "Ashanti", "Western North", "Ahafo", "Bono",
           "Bono East", "Oti", "Northern", "Savannah", "North East", "Upper East", "Upper West"]
# snakebite district name -> GSS area name, where spelling or naming differs
CROSSWALK = {
    "adansi akrofuom": "Akrofuom", "afadjato south": "Afadzato South", "asante mampong": "Mampong Municipal",
    "assin foso": "Assin Fosu Municipal", "atebubu amanten": "Atebubu Amantin Municipal",
    "atwima nwabiagya": "Atwima Nwabiagya South Municipal", "berekum": "Berekum East Municipal", "bosomtwe": "Bosomtwi",
    "cape coast": "Cape Cape Metropolitan Area (CCMA)", "denkyembour": "Denkyembuor", "dormaa": "Dormaa Central Municipal",
    "efutu": "Effutu Municipal", "gushiegu": "Gushegu Municipal",
    "komenda edna eguafo abirem": "Komenda Edina Eguafo Abirem Municipal", "lambussie": "Lambussie Karni",
    "mfantseman": "Mfantsiman Municipal", "okai koi north": "Okaikoi North Municipal", "pru": "Pru East",
    "tatale sangule": "Tatale Sanguli", "twifo hemang lower denkyira": "Twifo Heman Lower Denkyira",
}

def norm(s):
    s = str(s).lower().replace("-", " ").replace("'", "").replace("/", " ")
    s = re.sub(r"\(.*?\)", "", s)
    s = re.sub(r"\b(municipal|metropolitan|metro|district|assembly|municipality|area)\b", "", s)
    return re.sub(r"\s+", " ", s).strip()

def area_rows(df):
    """Yield (region, area, row) for the data rows of a GSS table, tracking the current region."""
    region, area = None, None
    for i in range(3, len(df)):
        a = df.iat[i, 0]
        if isinstance(a, str) and (a.startswith("Internal") or a.startswith("Source") or a.startswith("Units")):
            break
        if isinstance(a, str) and a.strip():
            area = a.strip()
            if area in REGIONS:
                region = area
        if pd.isna(df.iat[i, 1]) and pd.isna(df.iat[i, 2]):
            continue
        yield region, area, df.iloc[i]

def by_category(path, cats):
    """Long table: region, area, category, H, A, M0, for tables with a category column."""
    df = pd.read_excel(path, header=None)
    out = [(r, a, str(row.iat[1]).strip(), row.iat[2], row.iat[3], row.iat[4]) for r, a, row in area_rows(df)]
    t = pd.DataFrame(out, columns=["region", "area", "category", "H", "A", "M0"])
    t = t[t.category.isin(cats)]
    return t

found = {k: sorted(glob.glob(f"data/{k}_*.xlsx")) for k in ["MPI1", "MPI2", "MPI3", "MPI4", "MPI5"]}
log = []
tabs = []
if found["MPI1"]:
    df = pd.read_excel(found["MPI1"][0], header=None)
    num = lambda v: pd.to_numeric(v, errors="coerce")
    rows = []
    for r, a, row in area_rows(df):
        vals = [num(x) for x in row.iloc[1:].tolist()]
        vals = [v for v in vals if pd.notna(v)][:3]
        if len(vals) == 3:
            rows.append((r, a, *vals))
    t1 = pd.DataFrame(rows, columns=["region", "area", "poverty_H", "poverty_A", "poverty_M0"])
    tabs.append(t1); log.append(f"MPI1: {len(t1)} areas")
else:
    log.append("MPI1 (overall district poverty) not found: poverty_H, poverty_A and poverty_M0 are left empty.")
if found["MPI2"]:
    t = by_category(found["MPI2"][0], ["Male", "Female"])
    w = t.pivot_table(index=["region", "area"], columns="category", values="H", aggfunc="first").reset_index()
    w = w.rename(columns={"Male": "H_male_head", "Female": "H_female_head"}); tabs.append(w)
if found["MPI3"]:
    t = by_category(found["MPI3"][0], ["No Education"])
    tabs.append(t.rename(columns={"H": "H_head_no_education"})[["region", "area", "H_head_no_education"]])
if found["MPI4"]:
    t = by_category(found["MPI4"][0], ["Agriculture"])
    tabs.append(t.rename(columns={"H": "H_head_agriculture"})[["region", "area", "H_head_agriculture"]])
if found["MPI5"]:
    df = pd.read_excel(found["MPI5"][0], header=None)
    heads = [str(h).strip() for h in df.iloc[2, 1:].tolist()]
    rows = [(r, a, *row.iloc[1:].tolist()) for r, a, row in area_rows(df)]
    cols = ["region", "area"] + ["contrib_" + re.sub(r"\W+", "_", h.lower()).strip("_") for h in heads]
    tabs.append(pd.DataFrame(rows, columns=cols))

pov = tabs[0]
for t in tabs[1:]:
    pov = pov.merge(t, on=["region", "area"], how="outer")
pov = pov[~pov.area.isin(REGIONS)].copy()
pov["key"] = pov.area.map(norm)
for c in pov.columns.drop(["region", "area", "key"]):
    pov[c] = pd.to_numeric(pov[c], errors="coerce")

d = pd.read_csv("data/snakebite_unified_district_month.csv", usecols=["district", "region"]).drop_duplicates()
d["key"] = [norm(CROSSWALK.get(x, x)) for x in d.district]
m = d.merge(pov.drop(columns="area"), on=["region", "key"], how="left")
miss = m[m.drop(columns=["district", "region", "key"]).isna().all(axis=1)].district.tolist()
log.append(f"Districts matched to GSS areas: {len(d) - len(miss)} of {len(d)}; unmatched: {miss}")
dup = m.district.duplicated().sum()
assert dup == 0, f"{dup} districts matched more than one GSS area"
for c in ["poverty_H", "poverty_A", "poverty_M0"]:
    if c not in m:
        m[c] = np.nan
cols = ["district", "region", "poverty_H", "poverty_A", "poverty_M0", "H_male_head", "H_female_head",
        "H_head_no_education", "H_head_agriculture"] + [c for c in m.columns if c.startswith("contrib_")]
m = m[[c for c in cols if c in m]].sort_values("district")
m.to_csv("data/district_poverty.csv", index=False)
log.append(f"Written data/district_poverty.csv: {len(m)} districts, columns {list(m.columns[2:])}")
print("\n".join(log))
print(m.describe().T[["count", "mean", "min", "max"]].round(2).to_string())
