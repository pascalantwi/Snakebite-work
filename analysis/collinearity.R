# Multicollinearity checks (Sections 2.4.3 and 3.5).
#   (1) between the lags of each exposure: correlations between lagged values (lags 0-9) and variance inflation factors
#       (VIF) if every lag were entered as a separate linear term (an unconstrained distributed-lag model);
#   (2) between exposures: correlations and VIFs at the same lag;
#   (3) in the fitted design: generalized VIFs (GVIF; Fox & Monette 1992) of each model term, including the cross-bases
#       (lag 9, natural splines with 2 df), the seasonal terms (regime and calendar month by regime, as one block, because
#       a main effect and its interaction cannot be assessed separately), the year effects and district poverty.
# Run from the repository root:  Rscript analysis/collinearity.R
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(dlnm) })
source("analysis/primary_common.R")
L <- 9; MAIN <- c("rainfall", "tmax", "tmin", "ndvi"); ALL <- c(MAIN, "rel_humidity")
d <- load_panel()
rows <- d$include_main == 1 & d$t > L
lagged <- function(v, k) ave(d[[v]], d$district, FUN = function(z) c(rep(NA, k), head(z, length(z) - k)))
vif <- function(X) { r <- cor(X, use = "complete.obs"); diag(solve(r)) }

# (1) lags of each exposure
lag_tab <- bind_rows(lapply(ALL, function(v) {
  X <- sapply(0:L, function(k) lagged(v, k))[rows, ]
  r <- cor(X, use = "complete.obs")
  tibble(variable = v, adjacent_lag_r_min = min(diag(r[-1, -ncol(r)])), adjacent_lag_r_max = max(diag(r[-1, -ncol(r)])),
         lag0_lag9_r = r[1, L + 1], VIF_unconstrained_max = max(vif(X)), VIF_unconstrained_median = median(vif(X)))
}))
print(lag_tab, width = 200); write_csv(lag_tab, "analysis/output/collinearity_lags.csv")

# (2) between exposures at the same lag
same <- bind_rows(lapply(0:L, function(k) {
  X <- sapply(ALL, function(v) lagged(v, k))[rows, ]; r <- cor(X, use = "complete.obs")
  v4 <- vif(X[, MAIN]); v5 <- vif(X)
  tibble(lag = k, max_abs_r_main = max(abs(r[MAIN, MAIN][upper.tri(diag(4))])), VIF_max_main = max(v4),
         r_rh_tmax = r["rel_humidity", "tmax"], VIF_max_with_rh = max(v5))
}))
print(same, n = 20); write_csv(same, "analysis/output/collinearity_between_exposures.csv")

# (3) generalized VIFs of the terms of the fitted design (fixed effects, without the intercept)
pov <- if ("poverty_H" %in% names(d) && any(!is.na(d$poverty_H))) "poverty_H" else "H_male_head"
d$poverty <- d[[pov]]
cb <- lapply(MAIN, function(v) crossbasis(d[[v]], lag = L, group = d$district, argvar = list(fun = "ns", df = 2),
                                          arglag = list(fun = "ns", df = 2)))
names(cb) <- paste0("cb_", MAIN)
dd <- d[rows, ]
blocks <- c(lapply(cb, function(m) unclass(m)[rows, , drop = FALSE]),
            list(year = model.matrix(~ year_f, dd)[, -1, drop = FALSE],
                 seasonal_regime = model.matrix(~ regime * month_f, dd)[, -1, drop = FALSE],
                 poverty = matrix(dd$poverty, ncol = 1)))
gvif <- function(blocks) {
  X <- do.call(cbind, blocks); id <- rep(names(blocks), sapply(blocks, ncol))
  keep <- apply(X, 2, sd) > 0; X <- X[, keep]; id <- id[keep]
  R <- cor(X); dR <- determinant(R)$modulus
  bind_rows(lapply(unique(id), function(b) {
    j <- id == b
    g <- exp(determinant(R[j, j, drop = FALSE])$modulus + determinant(R[!j, !j, drop = FALSE])$modulus - dR)
    tibble(term = b, df = sum(j), GVIF = as.numeric(g), GVIF_adj = as.numeric(g)^(1 / (2 * sum(j))))
  }))
}
g <- gvif(blocks) |> mutate(poverty_measure = pov)
print(g, width = 200); write_csv(g, "analysis/output/collinearity_gvif.csv")
cat("poverty measure used:", pov, "\n")
cat("correlation of district poverty with unimodal regime:",
    round(cor(dd$poverty, as.numeric(dd$regime == "unimodal")), 2), "\n")
cat("done\n")
