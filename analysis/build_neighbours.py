# District neighbours for the spatial checks (Sections 2.4.11-2.4.12): two districts are neighbours if their
# geoBoundaries ADM2 polygons share a boundary, taken as any pair of boundary vertices less than about 500 m apart
# (the simplified polygons do not always share identical vertices). Guan, created after the 2018 boundaries, has no
# polygon; it takes the neighbours of Afadjato South, from which it was carved, and Afadjato South itself.
# Output: data/district_neighbours.csv (one row per ordered pair of neighbouring districts).
# Usage: python3 analysis/build_neighbours.py
import json
import numpy as np, pandas as pd
from scipy.spatial import cKDTree

TOL = 0.005  # degrees
g = json.load(open("data/geo/geoBoundaries-GHA-ADM2_simplified.geojson"))
pts = pd.read_csv("data/district_points.csv")
name2d = dict(zip(pts.shapeName, pts.district))
xy, owner = [], []
for f in g["features"]:
    d = name2d.get(f["properties"]["shapeName"])
    if d is None:
        continue
    geom = f["geometry"]
    polys = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]
    for poly in polys:
        for ring in poly:
            xy.extend(ring); owner.extend([d] * len(ring))
xy = np.array(xy); owner = np.array(owner)
pairs = cKDTree(xy).query_pairs(TOL, output_type="ndarray")
a, b = owner[pairs[:, 0]], owner[pairs[:, 1]]
keep = a != b
nb = pd.DataFrame({"district": np.r_[a[keep], b[keep]], "neighbour": np.r_[b[keep], a[keep]]}).drop_duplicates()
src = "afadjato south"
add = [("guan", n) for n in nb[nb.district == src].neighbour] + [("guan", src)]
add = pd.DataFrame(add, columns=["district", "neighbour"])
nb = pd.concat([nb, add, add.rename(columns={"district": "neighbour", "neighbour": "district"})]).drop_duplicates()
nb = nb.sort_values(["district", "neighbour"])
nb.to_csv("data/district_neighbours.csv", index=False)
k = nb.groupby("district").size()
print(f"districts with neighbours: {k.size} of {pts.district.nunique()}; neighbours per district: "
      f"median {k.median():.0f}, range {k.min()}-{k.max()}; pairs {len(nb) // 2}")
