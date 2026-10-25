#!/bin/sh
# Runs the remaining analyses in order. Each step is skipped when its output exists; the placebo and lag-grid scripts
# also resume from their saved progress if interrupted.
cd "$(dirname "$0")/.." || exit 1
while pgrep -f "primary_placebo.R" > /dev/null; do sleep 30; done
[ -f analysis/output/placebo_median_fit.rds ] || Rscript analysis/primary_placebo.R > analysis/output/primary_placebo.log 2>&1
[ -f figures/Fig5.png ] || Rscript analysis/fig5_primary.R > analysis/output/fig5_primary.log 2>&1
Rscript analysis/lag_selection.R > analysis/output/lag_selection.log 2>&1
echo all-finished >> analysis/output/lag_selection.log
