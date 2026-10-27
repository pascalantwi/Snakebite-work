#!/bin/sh
# Reruns the whole analysis, from the data to every Results figure and table (Sections 3.1-3.11), in order.
# Each step is logged with its time in analysis/output/pipeline.log; the run stops at the first failing step.
# Long steps (placebo permutations, lag grid) resume from their saved progress if the run is interrupted; pass --fresh
# to discard that progress, which is needed whenever the data or the models have changed.
# Run from anywhere:  sh analysis/run_all.sh --fresh        (about 5 hours on 4 cores)
cd "$(dirname "$0")/.." || exit 1
export LANG=C.UTF-8 LC_ALL=C.UTF-8
LOG=analysis/output/pipeline.log
if [ "$1" = "--fresh" ]; then
  rm -rf analysis/output/placebo_progress analysis/output/lag_grid_progress
  rm -f analysis/output/*.rds
fi
step() {
  echo "$(date -u '+%Y-%m-%d %H:%M:%S') start $*" >> "$LOG"
  "$@" > "analysis/output/$(basename "$2" | sed 's/\.[A-Za-z]*$//').log" 2>&1 || { echo "$(date -u '+%F %T') FAILED $*" >> "$LOG"; exit 1; }
  echo "$(date -u '+%Y-%m-%d %H:%M:%S') done  $*" >> "$LOG"
}
echo "==== pipeline started $(date -u '+%F %T') ====" >> "$LOG"
step python3 analysis/build_poverty.py
step python3 analysis/build_unified_dataset.py
step Rscript analysis/figures_descriptive.R          # 3.1-3.2: Figs 2-3, S1 Fig
step Rscript analysis/collinearity.R                 # multicollinearity, including between lags
step Rscript analysis/primary_models.R               # 3.3: M0-M3, temporal placebo, cross-validation
step Rscript analysis/primary_placebo.R              # 3.3: spatial placebo permutations
step Rscript analysis/fig4_primary.R                 # Fig 4
# 3.4: lag grid; two models at a time, then one at a time for any candidate that ran out of memory
echo "$(date -u '+%Y-%m-%d %H:%M:%S') start lag_selection.R" >> "$LOG"
NCORES=2 Rscript analysis/lag_selection.R > analysis/output/lag_selection.log 2>&1 || \
  NCORES=1 Rscript analysis/lag_selection.R > analysis/output/lag_selection.log 2>&1 || \
  { echo "$(date -u '+%F %T') FAILED lag_selection.R" >> "$LOG"; exit 1; }
echo "$(date -u '+%Y-%m-%d %H:%M:%S') done  lag_selection.R" >> "$LOG"
# the later steps use the specification selected before poverty was added (lag 9, 2/2 df); stop if it changed
grep -q '^9,2,2,.*selected$' analysis/output/lag_selected.csv || { echo "$(date -u '+%F %T') STOP selected specification changed; update L and df in the later scripts" >> "$LOG"; exit 1; }
step Rscript analysis/exposure_response.R            # 3.5-3.6
step Rscript analysis/overdispersion.R               # 3.5: Poisson vs negative binomial
step Rscript analysis/covariate_effects.R            # 3.5: all covariates, sex, poverty
step Rscript analysis/fig5_fig7.R                    # Figs 5-7
step Rscript analysis/falsification_region.R         # 3.4: falsification with month by region
step Rscript analysis/regime_onset.R                 # 3.7-3.8
step Rscript analysis/fig8_fig9.R                    # Figs 8-9
step Rscript analysis/attributable.R                 # 3.9
step Rscript analysis/prediction.R                   # 3.10
step Rscript analysis/fig10.R                        # Fig 10
step python3 analysis/build_neighbours.py           # district neighbours for the spatial checks
step Rscript analysis/sensitivity.R                  # 3.11: sensitivity analyses and diagnostics
step Rscript analysis/fig11_s2fig.R                  # Fig 11, S2 Fig
echo "==== pipeline finished $(date -u '+%F %T') ====" >> "$LOG"
