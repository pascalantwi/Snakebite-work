# Figure 1 (Study setting, section 2.1): study area and rainfall regimes of Ghana.
# Main map: 261 districts shaded by rainfall regime (unimodal / transition / bimodal, from district rainfall), 16 regions outlined and named; locator of Ghana in West Africa.
# No title or source note on the image: these are given in the figure caption in the manuscript.
# Sources: district/region boundaries geoBoundaries gbOpen GHA ADM2/ADM1 (Runfola et al. 2020; CC BY 4.0;
# USAID Ghana HPNO / Ghana Statistical Service); country outlines Natural Earth 1:50m (public domain).
# Usage: python3 analysis/fig1_map.py data_snake.csv data/geo figures
import sys, json, re, textwrap
import numpy as np, pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patheffects as pe
from matplotlib.patches import Polygon as MplPolygon, Patch, Rectangle
from matplotlib.collections import PatchCollection
from shapely.geometry import shape

data_csv, geo_dir, out_dir = sys.argv[1:4]
NORTH = ["Northern", "Upper East", "Upper West", "Savannah", "North East"]
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

def polys(geom):
    return [MplPolygon(np.asarray(g.exterior.coords), closed=True) for g in getattr(geom, "geoms", [geom])]

adm2 = json.load(open(f"{geo_dir}/geoBoundaries-GHA-ADM2_simplified.geojson"))["features"]
adm1 = json.load(open(f"{geo_dir}/geoBoundaries-GHA-ADM1_simplified.geojson"))["features"]
world = json.load(open(f"{geo_dir}/ne_50m_admin_0_countries.geojson"))["features"]
geo = {f["properties"]["shapeName"]: shape(f["geometry"]) for f in adm2}
by_norm = {norm(k): k for k in geo}

d = pd.read_csv(data_csv)
dist = d.groupby("district").agg(region=("region", "first")).reset_index()
# rainfall regime from each district's own rainfall (see analysis/build_unified_dataset.py)
reg = pd.read_csv("data/snakebite_unified_district_month.csv", usecols=["district", "regime", "n_bimodal_years"]).drop_duplicates("district")
LAB = {"unimodal": "Unimodal", "transition": "Transition", "bimodal": "Bimodal"}
dist = dist.merge(reg, on="district", how="left")
dist["regime"] = dist.regime.map(LAB)
dist["shapeName"] = [CROSSWALK.get(n, by_norm.get(norm(n))) for n in dist.district]
dist.to_csv(f"{out_dir}/../analysis/district_crosswalk.csv", index=False)
unmatched = dist[dist.shapeName.isna()].district.tolist()
print("districts:", len(dist), "| mapped to a polygon:", dist.shapeName.notna().sum(), "| no polygon:", unmatched)

SURFACE, INK, MUTED = "#fcfcfb", "#0b0b0b", "#52514e"
COL = {"Unimodal": "#D55E00", "Transition": "#009E73", "Bimodal": "#0072B2"}  # Okabe-Ito
halo = [pe.withStroke(linewidth=2.4, foreground="white")]
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 8.5, "text.color": INK})
fig = plt.figure(figsize=(9.0, 7.0), facecolor=SURFACE)

# main map
ax = fig.add_axes([0.0, 0.01, 0.66, 0.98])
pp, cc = [], []
for _, r in dist.dropna(subset=["shapeName"]).iterrows():
    for pg in polys(geo[r.shapeName]):
        pp.append(pg); cc.append(COL[r.regime])
ax.add_collection(PatchCollection(pp, facecolor=cc, edgecolor="white", linewidth=0.25, alpha=0.9))
ax.add_collection(PatchCollection([pg for f in adm1 for pg in polys(shape(f["geometry"]))],
                                  facecolor="none", edgecolor=INK, linewidth=0.8))
NUDGE = {"Greater Accra": (0.25, -0.12), "Central": (0.0, -0.1), "Western": (-0.1, -0.15), "Ahafo": (0.0, 0.0)}
for f in adm1:
    nm = f["properties"]["shapeName"].replace(" Region", "")
    pt = shape(f["geometry"]).representative_point(); dx, dy = NUDGE.get(nm, (0, 0))
    ax.text(pt.x + dx, pt.y + dy, nm, fontsize=7.4, fontweight="bold", ha="center", va="center", color=INK, path_effects=halo)
ax.set_xlim(-3.45, 1.35); ax.set_ylim(4.6, 11.25); ax.set_aspect("equal"); ax.axis("off")
# scale bar (100 km at ~6°N) and north arrow
km_per_deg = 111.32 * np.cos(np.radians(6.0))
x0, y0 = 0.15, 4.85
ax.add_patch(Rectangle((x0, y0), 100 / km_per_deg, 0.05, facecolor=INK, edgecolor=INK))
ax.text(x0 + 50 / km_per_deg, y0 + 0.12, "100 km", ha="center", fontsize=7.5)
ax.annotate("N", xy=(1.05, 10.95), xytext=(1.05, 10.55), ha="center", fontsize=9, fontweight="bold",
            arrowprops=dict(arrowstyle="-|>", color=INK, lw=1.2))
n = dist.regime.value_counts()
fig.legend(handles=[Patch(facecolor=COL[k], edgecolor="none", label=f"{k}: {n[k]} districts") for k in COL],
           loc="upper left", bbox_to_anchor=(0.63, 0.62), frameon=False, fontsize=9, title="Rainfall regime",
           title_fontsize=9.5, alignment="left")

# locator
lx = fig.add_axes([0.62, 0.68, 0.36, 0.27])
for f in world:
    g = shape(f["geometry"])
    if not g.intersects(shape({"type": "Polygon", "coordinates": [[(-20, 0), (16, 0), (16, 24), (-20, 24), (-20, 0)]]})):
        continue
    is_gh = f["properties"].get("ADM0_A3") == "GHA"
    lx.add_collection(PatchCollection(polys(g), facecolor=INK if is_gh else "#e4e3df", edgecolor="#9a9893", linewidth=0.4))
    if f["properties"].get("ADM0_A3") in ("CIV", "BFA", "NGA", "MLI"):
        c = g.representative_point(); dx = -2.2 if f["properties"].get("ADM0_A3") == "CIV" else 0
        lx.text(c.x + dx, c.y, f["properties"]["NAME"], fontsize=6.2, ha="center", va="center", color=MUTED)
lx.annotate("GHANA", xy=(-1.2, 7.6), xytext=(-4.5, 3.2), fontsize=7, fontweight="bold", ha="center", color=INK,
            arrowprops=dict(arrowstyle="-", color=INK, lw=0.8))
lx.set_xlim(-18, 15); lx.set_ylim(1, 21); lx.set_aspect("equal"); lx.set_xticks([]); lx.set_yticks([])
lx.set_facecolor("#ffffff")
for sp in lx.spines.values(): sp.set_edgecolor(MUTED); sp.set_linewidth(0.6)
lx.set_title("Location in West Africa", loc="left", fontsize=8.5, fontweight="bold")

for ext in ("png", "pdf"):
    fig.savefig(f"{out_dir}/Fig1.{ext}", dpi=300, facecolor=SURFACE)
print("saved", f"{out_dir}/Fig1.png")
