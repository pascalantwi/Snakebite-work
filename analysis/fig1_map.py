# Figure 1: (A) districts by rainfall regime; (B) district snakebite incidence, 2020-2024.
# Boundaries: geoBoundaries gbOpen GHA ADM2/ADM1 (CC BY 4.0; source USAID Ghana HPNO, Ghana Statistical Service).
# Usage: python3 analysis/fig1_map.py data_snake.csv data/geo figures
import sys, json, re, textwrap
import numpy as np, pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patheffects as pe
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
halo = [pe.withStroke(linewidth=2.2, foreground="white")]
for _, r in dist.dropna(subset=["shapeName"]).nlargest(10, "rate").iterrows():
    pt = geo[r.shapeName].representative_point()
    axes[1].annotate(f"{r.district.title()} ({r.rate:.0f})", (pt.x, pt.y), fontsize=6.2, ha="center", va="center",
                     color=INK, path_effects=halo)
cnt = dist.rbin.value_counts().sort_index()
axes[1].legend(handles=[Patch(facecolor=SEQ[i], edgecolor="none", label=f"{labels[i]} ({cnt.get(i,0)})") for i in range(5)],
               title="Cases per 100,000 per year\n(number of districts)", title_fontsize=8.5,
               loc="upper left", bbox_to_anchor=(0.0, 0.0), ncol=3, frameon=False, fontsize=8.5, alignment="left")
note = ("Panel B names the ten districts with the highest incidence (rate in brackets). "
        "Thin white lines: district boundaries; grey lines: regional boundaries. "
        f"{len(unmatched)} district ({', '.join(u.title() for u in unmatched)}) has no polygon in the 260-district boundary file. "
        "Boundaries: geoBoundaries gbOpen GHA ADM1/ADM2 (Runfola et al. 2020; CC BY 4.0), source USAID Ghana HPNO / Ghana Statistical Service. "
        "Map drawn in Python with matplotlib and shapely (analysis/fig1_map.py).")
fig.text(0.02, 0.012, textwrap.fill(note, 175), fontsize=7, color=MUTED)
fig.subplots_adjust(left=0.01, right=0.99, top=0.95, bottom=0.2, wspace=0.04)
for ext in ("png", "pdf"):
    fig.savefig(f"{out_dir}/Fig1.{ext}", dpi=300, facecolor=SURFACE)
print("saved", f"{out_dir}/Fig1.png")


# ---- District reference map: every district numbered, with insets for Accra and Kumasi and a name index ----
ref = dist.sort_values(["region", "district"]).reset_index(drop=True)
ref["no"] = np.arange(1, len(ref) + 1)
TINT = {"Unimodal (north)": "#fbe0d6", "Bimodal (south)": "#e1edfc"}
INSETS = {"Central Accra": (-0.265, -0.155, 5.53, 5.635), "Greater Accra": (-0.40, 0.12, 5.52, 5.82), "Kumasi": (-1.78, -1.47, 6.58, 6.82)}
def in_box(pt, b): return b[0] <= pt.x <= b[1] and b[2] <= pt.y <= b[3]
def base(ax):
    pp, cc = [], []
    for _, r in ref.dropna(subset=["shapeName"]).iterrows():
        for pg in polys(geo[r.shapeName]):
            pp.append(pg); cc.append(TINT[r.regime])
    ax.add_collection(PatchCollection(pp, facecolor=cc, edgecolor="#9a9893", linewidth=0.25))
    ax.add_collection(PatchCollection([pg for f in adm1 for pg in polys(shape(f["geometry"]))],
                                      facecolor="none", edgecolor=INK, linewidth=0.7))
    ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
fig2 = plt.figure(figsize=(16, 12), facecolor=SURFACE)
axm = fig2.add_axes([0.0, 0.03, 0.42, 0.94]); base(axm)
axm.set_xlim(-3.4, 1.3); axm.set_ylim(4.6, 11.25); axm.axis("off")
axm.set_title("District reference map", loc="left", fontsize=12, fontweight="bold")
ins_axes = {"Kumasi": fig2.add_axes([0.425, 0.64, 0.125, 0.25]), "Greater Accra": fig2.add_axes([0.425, 0.38, 0.125, 0.22]),
            "Central Accra": fig2.add_axes([0.425, 0.08, 0.125, 0.25])}
for nm, a in ins_axes.items():
    base(a); b = INSETS[nm]; a.set_xlim(b[0], b[1]); a.set_ylim(b[2], b[3]); a.set_title(nm, fontsize=8, loc="left")
    axm.add_patch(matplotlib.patches.Rectangle((b[0], b[2]), b[1] - b[0], b[3] - b[2], fill=False, edgecolor=INK, linewidth=0.8))
    for sp in a.spines.values(): sp.set_edgecolor(INK); sp.set_linewidth(0.8)
small_halo = [pe.withStroke(linewidth=1.4, foreground="white")]
for _, r in ref.dropna(subset=["shapeName"]).iterrows():
    pt = geo[r.shapeName].representative_point()
    boxed = [nm for nm, b in INSETS.items() if in_box(pt, b)]  # first match wins: Central Accra before Greater Accra
    if boxed:
        ins_axes[boxed[0]].text(pt.x, pt.y, str(r.no), fontsize=5.5, ha="center", va="center", color=INK, path_effects=small_halo)
    else:
        axm.text(pt.x, pt.y, str(r.no), fontsize=4.6, ha="center", va="center", color=INK, path_effects=small_halo)
# index
lines = []
for reg, g in ref.groupby("region", sort=True):
    lines.append((f"{reg}", True))
    lines += [(f"{r.no:>3}  {r.district.title()}" + ("  (no polygon)" if pd.isna(r.shapeName) else ""), False) for _, r in g.iterrows()]
ncol = 4; per = int(np.ceil(len(lines) / ncol))
for c in range(ncol):
    y = 0.965
    for txt, hdr in lines[c * per:(c + 1) * per]:
        fig2.text(0.565 + c * 0.11, y, txt, fontsize=5.9 if not hdr else 6.4, fontweight="bold" if hdr else "normal",
                  family="DejaVu Sans Mono" if not hdr else "DejaVu Sans", color=INK, va="top")
        y -= 0.0128
fig2.legend(handles=[Patch(facecolor=TINT[k], edgecolor="#9a9893", label=k) for k in TINT], loc="lower left",
            bbox_to_anchor=(0.01, 0.06), frameon=False, fontsize=8, title="Rainfall regime", title_fontsize=8)
fig2.text(0.01, 0.012, "Districts are numbered alphabetically within region. Boundaries: geoBoundaries gbOpen GHA ADM1/ADM2 "
          "(Runfola et al. 2020; CC BY 4.0), source USAID Ghana HPNO / Ghana Statistical Service; Guan district is not in the "
          "260-district boundary file. Drawn in Python with matplotlib and shapely (analysis/fig1_map.py).", fontsize=7, color=MUTED, wrap=True)
for ext in ("png", "pdf"):
    fig2.savefig(f"{out_dir}/Fig1C_district_reference_map.{ext}", dpi=300, facecolor=SURFACE)
ref[["no", "district", "region", "regime", "shapeName", "rate"]].to_csv(f"{out_dir}/../analysis/district_reference_index.csv", index=False)
print("saved", f"{out_dir}/Fig1C_district_reference_map.png")
