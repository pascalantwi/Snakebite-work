# Figure 2 (Results, section 3.2): seasonal profiles by rainfall regime, January 2020 - December 2025.
# A-F: monthly incidence and climate by calendar month (line = mean over the six years, band = range over years).
# G: incidence relative to the district mean by months since rainy-season onset (mean and 95% CI over district-years).
# Onset: first month from February with mean rainfall >= 2 mm/day (section 2.3). Rows with include_main == 1.
# No title or source note on the image: these are given in the figure caption in the manuscript.
# Usage: python3 analysis/fig2_seasonality.py data/snakebite_unified_district_month.csv figures
import sys
import numpy as np, pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

data_csv, out_dir = sys.argv[1:3]
d = pd.read_csv(data_csv)
d = d[d.include_main == 1].copy()

# A-F: regime x year x month summaries, then mean and range over years
g = d.groupby(["regime", "year", "month"]).agg(
    cases=("cases_total", "sum"), pop=("population", "sum"), rainfall=("rainfall", "mean"),
    rel_humidity=("rel_humidity", "mean"), tmax=("tmax", "mean"), tmin=("tmin", "mean"), ndvi=("ndvi", "mean")).reset_index()
g["incidence"] = g.cases / g["pop"] * 1e5

# G: incidence relative to the district mean, aligned to onset
d["rr"] = (d.cases_total / d.population) / (d.cases_total / d.population).groupby(d.district).transform("mean")
idx = d.set_index(["district", "t"])["rr"]
rows = []
for (dist, yr), h in d.groupby(["district", "year"]):
    w = h[(h.month >= 2) & (h.rainfall >= 2)].sort_values("month")
    if w.empty:
        continue
    t0 = int(w.t.iloc[0])
    for k in range(-3, 7):
        if (dist, t0 + k) in idx.index:
            rows.append((h.regime.iloc[0], k, idx[(dist, t0 + k)]))
on = pd.DataFrame(rows, columns=["regime", "k", "rr"])
on = on.groupby(["regime", "k"]).rr.agg(m="mean", se=lambda v: v.std(ddof=1) / np.sqrt(len(v))).reset_index()

SURFACE, INK, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
COL = {"unimodal": "#eb6834", "transition": "#1baf7a", "bimodal": "#2a78d6"}
LAB = {"unimodal": "Unimodal (47 districts)", "transition": "Transition (22 districts)", "bimodal": "Bimodal (192 districts)"}
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 8.5, "text.color": INK, "axes.labelcolor": INK,
                     "xtick.color": MUTED, "ytick.color": MUTED, "axes.edgecolor": MUTED})
fig, axes = plt.subplots(4, 2, figsize=(7.5, 9.6), facecolor=SURFACE)
axes = axes.ravel()
panels = [("incidence", "Cases per 100,000 per month"), ("rainfall", "Rainfall (mm/day)"),
          ("rel_humidity", "Relative humidity (%)"), ("tmax", "Maximum temperature (°C)"),
          ("tmin", "Minimum temperature (°C)"), ("ndvi", "NDVI")]
months = np.arange(1, 13)

def style(ax, letter):
    ax.set_facecolor(SURFACE)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.spines["left"].set_linewidth(0.6); ax.spines["bottom"].set_linewidth(0.6)
    ax.grid(axis="y", color=GRID, linewidth=0.6); ax.set_axisbelow(True)
    ax.text(-0.16, 1.04, letter, transform=ax.transAxes, fontsize=11, fontweight="bold", va="bottom")

for ax, (var, ylab), letter in zip(axes, panels, "ABCDEF"):
    s = g.groupby(["regime", "month"])[var].agg(["mean", "min", "max"]).reset_index()
    for reg in COL:
        r = s[s.regime == reg]
        ax.fill_between(r.month, r["min"], r["max"], color=COL[reg], alpha=0.12, linewidth=0)
        ax.plot(r.month, r["mean"], color=COL[reg], lw=1.6, solid_capstyle="round", solid_joinstyle="round",
                marker="o", ms=3.6, mec=SURFACE, mew=0.9)
    ax.set_xticks(months); ax.set_xticklabels(list("JFMAMJJASOND")); ax.set_xlim(0.6, 12.4)
    ax.set_ylabel(ylab); style(ax, letter)
    if var == "incidence":
        ax.set_ylim(0, None)

ax = axes[6]
ax.axhline(1, color=MUTED, lw=0.8)
ax.axvline(0, color=MUTED, lw=0.8, ls=(0, (2, 2)))
for reg in COL:
    r = on[on.regime == reg]
    ax.fill_between(r.k, r.m - 1.96 * r.se, r.m + 1.96 * r.se, color=COL[reg], alpha=0.12, linewidth=0)
    ax.plot(r.k, r.m, color=COL[reg], lw=1.6, marker="o", ms=3.6, mec=SURFACE, mew=0.9)
ax.set_xticks(range(-3, 7)); ax.set_xlim(-3.4, 6.4)
ax.set_xlabel("Months since rainy-season onset"); ax.set_ylabel("Relative incidence")
style(ax, "G")

axes[7].axis("off")
handles = [Line2D([], [], color=COL[k], lw=1.6, marker="o", ms=3.6, mec=SURFACE, label=LAB[k]) for k in COL]
axes[7].legend(handles=handles, loc="center left", frameon=False, fontsize=9, title="Rainfall regime",
               title_fontsize=9.5, alignment="left")

fig.tight_layout(h_pad=1.6, w_pad=2.0)
for ext in ("png", "pdf"):
    fig.savefig(f"{out_dir}/Fig2.{ext}", dpi=300, facecolor=SURFACE)
print("saved", f"{out_dir}/Fig2.png")
