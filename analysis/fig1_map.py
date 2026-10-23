# Figure 1: (A) districts by rainfall regime; (B) district snakebite incidence, 2020-2024.
# Boundaries: geoBoundaries gbOpen GHA ADM2/ADM1 (CC BY 4.0; source USAID Ghana HPNO, Ghana Statistical Service).
# Usage: python3 analysis/fig1_map.py data_snake.csv data/geo figures
import sys, json, re
import numpy as np, pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MplPolygon, Patch
from matplotlib.collections import PatchCollection
from shapely.geometry import shape

data_csv, geo_dir, out_dir = sys.argv[1:4]
NORTH = ["Northern", "Upper East", "Upper West", "Savannah", "North East"]
# dataset name -> geoBoundaries shapeName where normalised names differ
CROSSWALK = {
    "accra": "Accra Metropolis", "adentan": "Adenta Municipal", "afadjato south": "Afadzato South",
    "agortime ziope": "Agotime Ziope", "akwapim north": "Akwapem North", "akwapim south": "Akwapem South",
    "akyemansa": "Akyem Mansa", "asante mampong": "Mampong Municipal", "asene manso akroso": "Asene Akroso Manso",
    "assin foso": "Assin Fosu", "atebubu amanten": "Atebubu Amantin", "atwima nwabiagya": "Atwima Nwabiagya South",
    "berekum": "Berekum East Municipal", "bolgatanga east": "Bolga  East", "efutu": "Effutu Municipal",
    "gushiegu": "Gushegu", "kasena nankana": "Kasena Nankana East",
    "komenda edna eguafo abirem": "Komenda-edina-eguafo-abirem Municipal", "lambussie": "Lambussie-karni",
    "lower manya krobo": "Lower Manya", "ningo prampram": "Ningo/prampram", "okai koi north": "Okaikwei North Municipal",
    "prestea huni valley": "Prestea/huni Valley", "pru": "Pru East", "sagnarigu": "Sagnerigu",
    "sekondi takoradi": "Sekondi Takoradi Metropolis", "sekyere afram plains": "Sekyere Afram Plains North",
    "tatale sangule": "Tatale Sanguli", "twifo ati morkwa": "Twifo Atti-morkwa", "upper manya krobo": "Upper Manya",
}

def norm(s):
    s = s.lower().replace("-", " ").replace("'", "")
    s = re.sub(r"\b(municipal|metropolitan|metro|district|assembly|municipality)\b", "", s)
    return re.sub(r"\s+", " ", s).strip()

adm2 = json.load(open(f"{geo_dir}/geoBoundaries-GHA-ADM2_simplified.geojson"))["features"]
adm1 = json.load(open(f"{geo_dir}/geoBoundaries-GHA-ADM1_simplified.geojson"))["features"]
geo = {f["properties"]["shapeName"]: shape(f["geometry"]) for f in adm2}
by_norm = {norm(k): k for k in geo}

d = pd.read_csv(data_csv)
dist = d.groupby("district").agg(region=("region", "first")).reset_index()
dist["regime"] = np.where(dist.region.isin(NORTH), "Unimodal (north)", "Bimodal (south)")
dy = d[d.year < 2025].groupby(["district", "year"]).agg(c=("cases", "sum"), p=("population", "first")).reset_index()
rate = dy.groupby("district").apply(lambda g: g.c.sum() / g.p.sum() * 1e5, include_groups=False).rename("rate")
dist = dist.merge(rate, left_on="district", right_index=True)
dist["shapeName"] = [CROSSWALK.get(n, by_norm.get(norm(n))) for n in dist.district]
dist.to_csv(f"{out_dir}/../analysis/district_crosswalk.csv", index=False)
unmatched = dist[dist.shapeName.isna()].district.tolist()
print("districts:", len(dist), "| mapped to a polygon:", dist.shapeName.notna().sum(), "| no polygon:", unmatched)

SURFACE, INK, MUTED, EDGE = "#fcfcfb", "#0b0b0b", "#52514e", "#ffffff"
REGIME_COL = {"Unimodal (north)": "#eb6834", "Bimodal (south)": "#2a78d6"}
SEQ = ["#cde2fb", "#86b6ef", "#3987e5", "#256abf", "#104281"]
bins = [0, 10, 25, 50, 100, np.inf]
labels = ["<10", "10–25", "25–50", "50–100", "≥100"]
dist["rbin"] = pd.cut(dist.rate, bins, labels=False, right=False)

def polys(geom):
    gs = getattr(geom, "geoms", [geom])
    return [MplPolygon(np.asarray(g.exterior.coords), closed=True) for g in gs]

def draw(ax, colour_of):
    patches, cols = [], []
    for _, r in dist.dropna(subset=["shapeName"]).iterrows():
        for pg in polys(geo[r.shapeName]):
            patches.append(pg); cols.append(colour_of(r))
    ax.add_collection(PatchCollection(patches, facecolor=cols, edgecolor=EDGE, linewidth=0.3))
    rp = [pg for f in adm1 for pg in polys(shape(f["geometry"]))]
    ax.add_collection(PatchCollection(rp, facecolor="none", edgecolor=MUTED, linewidth=0.8))
    ax.set_xlim(-3.4, 1.3); ax.set_ylim(4.6, 11.25); ax.set_aspect("equal"); ax.axis("off")

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9, "text.color": INK})
fig, axes = plt.subplots(1, 2, figsize=(9.2, 7.4), facecolor=SURFACE)
draw(axes[0], lambda r: REGIME_COL[r.regime])
axes[0].set_title("A  Rainfall regime", loc="left", fontsize=11, fontweight="bold")
n = dist.regime.value_counts()
axes[0].legend(handles=[Patch(facecolor=REGIME_COL[k], edgecolor="none", label=f"{k}, {n[k]} districts") for k in REGIME_COL],
               loc="upper left", bbox_to_anchor=(0.0, 0.0), frameon=False, fontsize=8.5)
draw(axes[1], lambda r: SEQ[int(r.rbin)])
axes[1].set_title("B  Snakebite incidence, 2020–2024", loc="left", fontsize=11, fontweight="bold")
cnt = dist.rbin.value_counts().sort_index()
axes[1].legend(handles=[Patch(facecolor=SEQ[i], edgecolor="none", label=f"{labels[i]} ({cnt.get(i,0)})") for i in range(5)],
               title="Cases per 100,000 per year\n(number of districts)", title_fontsize=8.5,
               loc="upper left", bbox_to_anchor=(0.0, 0.0), ncol=3, frameon=False, fontsize=8.5, alignment="left")
note = ("Thin white lines: district boundaries; grey lines: regional boundaries. "
        f"{len(unmatched)} district ({', '.join(u.title() for u in unmatched)}) has no polygon in the 260-district boundary file. "
        "Boundaries: geoBoundaries (CC BY 4.0), source USAID Ghana HPNO / Ghana Statistical Service.")
fig.text(0.02, 0.015, note, fontsize=7, color=MUTED, wrap=True)
fig.subplots_adjust(left=0.01, right=0.99, top=0.95, bottom=0.2, wspace=0.04)
for ext in ("png", "pdf"):
    fig.savefig(f"{out_dir}/Fig1.{ext}", dpi=300, facecolor=SURFACE)
print("saved", f"{out_dir}/Fig1.png")
