# Figures 2 and 3 (Results, section 3.2), January 2020 - December 2025, rows with include_main == 1.
# Fig 2: mean monthly rainfall by calendar month and rainfall regime (line = mean over the six years, band = range over years).
# Fig 3: snakebite incidence relative to the district mean by months since rainy-season onset
#        (mean and 95% CI over district-years). Onset: first month from February with mean rainfall >= 2 mm/day (section 2.3).
# No title or source note on the images: these are given in the figure captions in the manuscript.
# Usage: python3 analysis/fig2_fig3_seasonality.py data/snakebite_unified_district_month.csv figures
import sys
import numpy as np, pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

data_csv, out_dir = sys.argv[1:3]
d = pd.read_csv(data_csv)
d = d[d.include_main == 1].copy()

SURFACE, INK, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
COL = {"unimodal": "#eb6834", "transition": "#1baf7a", "bimodal": "#2a78d6"}
LAB = {"unimodal": "Unimodal (47 districts)", "transition": "Transition (22 districts)", "bimodal": "Bimodal (192 districts)"}
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9, "text.color": INK, "axes.labelcolor": INK,
                     "xtick.color": MUTED, "ytick.color": MUTED, "axes.edgecolor": MUTED})
LINE = dict(lw=1.8, solid_capstyle="round", solid_joinstyle="round", marker="o", ms=4.2, mec=SURFACE, mew=1.0)

def new_axes():
    fig, ax = plt.subplots(figsize=(6.5, 4.0), facecolor=SURFACE)
    ax.set_facecolor(SURFACE)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.spines["left"].set_linewidth(0.6); ax.spines["bottom"].set_linewidth(0.6)
    ax.grid(axis="y", color=GRID, linewidth=0.6); ax.set_axisbelow(True)
    return fig, ax

def finish(fig, ax, name):
    handles = [Line2D([], [], color=COL[k], label=LAB[k], **LINE) for k in COL]
    ax.legend(handles=handles, loc="upper left", frameon=False, fontsize=8.5)
    fig.tight_layout()
    for ext in ("png", "pdf"):
        fig.savefig(f"{out_dir}/{name}.{ext}", dpi=300, facecolor=SURFACE)
    print("saved", f"{out_dir}/{name}.png")

# Fig 2: rainfall by calendar month
g = d.groupby(["regime", "year", "month"]).rainfall.mean().reset_index()
s = g.groupby(["regime", "month"]).rainfall.agg(["mean", "min", "max"]).reset_index()
fig, ax = new_axes()
for reg in COL:
    r = s[s.regime == reg]
    ax.fill_between(r.month, r["min"], r["max"], color=COL[reg], alpha=0.12, linewidth=0)
    ax.plot(r.month, r["mean"], color=COL[reg], **LINE)
ax.set_xticks(range(1, 13))
ax.set_xticklabels(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"])
ax.set_xlim(0.6, 12.4); ax.set_ylim(0, 13.5)
ax.set_ylabel("Rainfall (mm/day)")
finish(fig, ax, "Fig2")

# Fig 3: relative incidence by months since onset
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
fig, ax = new_axes()
ax.axhline(1, color=MUTED, lw=0.8)
ax.axvline(0, color=MUTED, lw=0.8, ls=(0, (2, 2)))
for reg in COL:
    r = on[on.regime == reg]
    ax.fill_between(r.k, r.m - 1.96 * r.se, r.m + 1.96 * r.se, color=COL[reg], alpha=0.12, linewidth=0)
    ax.plot(r.k, r.m, color=COL[reg], **LINE)
ax.set_xticks(range(-3, 7)); ax.set_xlim(-3.4, 6.4); ax.set_ylim(0.3, 2.4)
ax.set_xlabel("Months since rainy-season onset"); ax.set_ylabel("Incidence relative to district mean")
finish(fig, ax, "Fig3")
