# Section 3.9: snakebite cases attributable to non-optimal climate (backward perspective; Gasparrini & Leone 2014).
# AF_it = 1 - exp(-sum_l [f.w(x_{i,t-l}, l) - f.w(x0, l)]), AN_it = AF_it * n_it, from the selected model.
# Main measure: exposures above the median, with the median as reference (values at or below the median set to it).
# Secondary measures: (i) minimum-risk reference, searched between the 5th and 95th percentiles (and, for comparison,
# between the 1st and 99th); (ii) positive weather anomalies (above the district's usual value for the calendar month),
# relative to no anomaly, from the climatology-anomaly model (Section 2.4.6).
# 95% empirical CIs from 1,000 Monte Carlo samples of the cross-basis coefficients.
# Run after analysis/exposure_response.R:  Rscript analysis/attributable.R
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(dlnm); library(glmmTMB); library(MASS) })
source("analysis/primary_common.R")
L <- 9; MAIN <- c("rainfall", "tmax", "tmin", "ndvi"); NSIM <- 1000
set.seed(20251231)
d <- load_panel()
rows <- d$include_main == 1 & d$t > L
m <- readRDS("analysis/output/exposure_response_fits.rds")$final
dd <- d[rows, ]
X <- list(); X95 <- list(); Xmed <- list(); eta <- list(); x0 <- c(); x095 <- c()
for (v in MAIN) {
  cb <- crossbasis(d[[v]], lag = L, group = d$district, argvar = list(fun = "ns", df = 2), arglag = list(fun = "ns", df = 2))
  i <- grep(paste0("^cb_", v), names(fixef(m)$cond)); b <- fixef(m)$cond[i]; V <- vcov(m)$cond[i, i]
  grid <- seq(quantile(d[[v]][rows], 0.01), quantile(d[[v]][rows], 0.99), length.out = 400)
  cp <- crosspred(cb, coef = b, vcov = V, model.link = "log", at = grid, cen = median(d[[v]][rows]))
  x0[v] <- grid[which.min(cp$allRRfit)]
  cb0 <- crossbasis(rep(x0[v], nrow(d)), lag = L, group = d$district, argvar = attr(cb, "argvar"), arglag = attr(cb, "arglag"))
  X[[v]] <- (unclass(cb) - unclass(cb0))[rows, , drop = FALSE]
  g95 <- grid >= quantile(d[[v]][rows], 0.05) & grid <= quantile(d[[v]][rows], 0.95)
  x095[v] <- grid[g95][which.min(cp$allRRfit[g95])]
  cb095 <- crossbasis(rep(x095[v], nrow(d)), lag = L, group = d$district, argvar = attr(cb, "argvar"), arglag = attr(cb, "arglag"))
  X95[[v]] <- (unclass(cb) - unclass(cb095))[rows, , drop = FALSE]
  # secondary measure: exposures above the median, relative to the median (values at or below the median set to it)
  med <- median(d[[v]][rows])
  cbh <- crossbasis(pmax(d[[v]], med), lag = L, group = d$district, argvar = attr(cb, "argvar"), arglag = attr(cb, "arglag"))
  cbm <- crossbasis(rep(med, nrow(d)), lag = L, group = d$district, argvar = attr(cb, "argvar"), arglag = attr(cb, "arglag"))
  Xmed[[v]] <- (unclass(cbh) - unclass(cbm))[rows, , drop = FALSE]
  eta[[v]] <- list(b = b, V = V)
}
print(round(x0, 3)); print(round(x095, 3))
sims <- lapply(MAIN, function(v) t(mvrnorm(NSIM, eta[[v]]$b, eta[[v]]$V))); names(sims) <- MAIN

# attributable numbers by group: point estimate and Monte Carlo interval, for each exposure and all exposures together
an_by <- function(group, XX = X, label = "minimum-risk reference", E = eta, SM = sims) {
  g <- if (group == "Ghana") rep("Ghana", nrow(dd)) else as.character(dd[[group]])
  out <- list()
  for (v in c(MAIN, "all")) {
    vs <- if (v == "all") MAIN else v
    lin  <- Reduce(`+`, lapply(vs, function(u) drop(XX[[u]] %*% E[[u]]$b)))
    linS <- Reduce(`+`, lapply(vs, function(u) XX[[u]] %*% SM[[u]]))
    an  <- dd$cases_total * (1 - exp(-lin)); anS <- dd$cases_total * (1 - exp(-linS))
    est <- tapply(an, g, sum); simt <- rowsum(anS, g); tot <- tapply(dd$cases_total, g, sum)
    out[[v]] <- tibble(measure = label, group_var = group, group = names(est), exposure = v, cases = as.numeric(tot[names(est)]),
      AN = as.numeric(est), AN_lo = apply(simt[names(est), , drop = FALSE], 1, quantile, 0.025),
      AN_hi = apply(simt[names(est), , drop = FALSE], 1, quantile, 0.975)) |>
      mutate(AF = 100 * AN / cases, AF_lo = 100 * AN_lo / cases, AF_hi = 100 * AN_hi / cases)
  }
  bind_rows(out)
}
# positive weather anomalies, from the climatology-anomaly model fitted in analysis/exposure_response.R
ca <- readRDS("analysis/output/exposure_response_fits.rds")$ca_full
Xan <- list(); Ean <- list()
for (v in MAIN) {
  clim <- ave(d[[v]], d$district, d$month); dev <- d[[v]] - clim; a <- dev / sd(dev)
  cba <- crossbasis(a, lag = L, group = d$district, argvar = list(fun = "ns", df = 2), arglag = list(fun = "ns", df = 2))
  cbp <- crossbasis(pmax(a, 0), lag = L, group = d$district, argvar = attr(cba, "argvar"), arglag = attr(cba, "arglag"))
  cb0 <- crossbasis(rep(0, nrow(d)), lag = L, group = d$district, argvar = attr(cba, "argvar"), arglag = attr(cba, "arglag"))
  Xan[[v]] <- (unclass(cbp) - unclass(cb0))[rows, , drop = FALSE]
  i <- grep(paste0("^an_", v), names(fixef(ca)$cond)); Ean[[v]] <- list(b = fixef(ca)$cond[i], V = vcov(ca)$cond[i, i])
}
San <- lapply(MAIN, function(v) t(mvrnorm(NSIM, Ean[[v]]$b, Ean[[v]]$V))); names(San) <- MAIN
G4 <- c("Ghana", "regime", "region", "year")
res <- bind_rows(lapply(G4, an_by, XX = Xmed, label = "above the median"),
                 lapply(G4, an_by, XX = X95, label = "minimum-risk reference (5th-95th percentile)"),
                 lapply(G4, an_by, XX = X, label = "minimum-risk reference (1st-99th percentile)"),
                 lapply(G4, an_by, XX = Xan, label = "positive anomalies", E = Ean, SM = San))
print(res |> filter(group_var %in% c("Ghana", "regime")) |> dplyr::select(-group_var) |> mutate(across(where(is.numeric), \(x) round(x, 1))), n = 40)
print(res |> filter(exposure == "all", group_var %in% c("region", "year")) |> dplyr::select(-group_var) |> mutate(across(where(is.numeric), \(x) round(x, 1))), n = 40)
write_csv(res, "analysis/output/attributable.csv")
write_csv(tibble(exposure = names(x0), x0_1_99 = x0, x0_5_95 = x095), "analysis/output/attributable_reference.csv")
cat("rows", nrow(dd), "cases", sum(dd$cases_total), "\ndone\n")
