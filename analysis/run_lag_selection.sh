#!/bin/sh
# Runs the lag-selection analysis one model at a time (the largest candidates need about 7 GB of memory each).
cd "$(dirname "$0")/.." || exit 1
NCORES=1 Rscript analysis/lag_selection.R > analysis/output/lag_selection.log 2>&1
echo all-finished >> analysis/output/lag_selection.log
