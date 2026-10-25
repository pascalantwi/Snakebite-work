# Section 3.9: snakebite cases attributable to non-optimal climate (backward perspective; Gasparrini & Leone 2014).
# AF_it = 1 - exp(-sum_l [f.w(x_{i,t-l}, l) - f.w(x0, l)]), AN_it = AF_it * n_it, with x0 the minimum-risk value of the
# cumulative exposure-response curve (searched between the 1st and 99th percentiles), from the selected model.
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
X <- list(); Xmed <- list(); eta <- list(); x0 <- c()
for (v in MAIN) {
  cb <- crossbasis(d[[v]], lag = L, group = d$district, argvar = list(fun = "ns", df = 2), arglag = list(fun = "ns", df = 2))
  i <- grep(paste0("^cb_", v), names(fixef(m)$cond)); b <- fixef(m)$cond[i]; V <- vcov(m)$cond[i, i]
  grid <- seq(quantile(d[[v]][rows], 0.01), quantile(d[[v]][rows], 0.99), length.out = 400)
  cp <- crosspred(cb, coef = b, vcov = V, model.link = "log", at = grid, cen = median(d[[v]][rows]))
  x0[v] <- grid[which.min(cp$allRRfit)]
  cb0 <- crossbasis(rep(x0[v], nrow(d)), lag = L, group = d$district, argvar = attr(cb, "argvar"), arglag = attr(cb, "arglag"))
  X[[v]] <- (unclass(cb) - unclass(cb0))[rows, , drop = FALSE]
  # secondary measure: exposures above the median, relative to the median (values at or below the median set to it)
  med <- median(d[[v]][rows])
  cbh <- crossbasis(pmax(d[[v]], med), lag = L, group = d$district, argvar = attr(cb, "argvar"), arglag = attr(cb, "arglag"))
  cbm <- crossbasis(rep(med, nrow(d)), lag = L, group = d$district, argvar = attr(cb, "argvar"), arglag = attr(cb, "arglag"))
  Xmed[[v]] <- (unclass(cbh) - unclass(cbm))[rows, , drop = FALSE]
  eta[[v]] <- list(b = b, V = V)
}
print(round(x0, 3))
sims <- lapply(MAIN, function(v) t(mvrnorm(NSIM, eta[[v]]$b, eta[[v]]$V))); names(sims) <- MAIN

# attributable numbers by group: point estimate and Monte Carlo interval, for each exposure and all exposures together
an_by <- function(group, XX = X, label = "minimum-risk reference") {
  g <- if (group == "Ghana") rep("Ghana", nrow(dd)) else as.character(dd[[group]])
  out <- list()
  for (v in c(MAIN, "all")) {
    vs <- if (v == "all") MAIN else v
    lin  <- Reduce(`+`, lapply(vs, function(u) drop(XX[[u]] %*% eta[[u]]$b)))
    linS <- Reduce(`+`, lapply(vs, function(u) XX[[u]] %*% sims[[u]]))
    an  <- dd$cases_total * (1 - exp(-lin)); anS <- dd$cases_total * (1 - exp(-linS))
    est <- tapply(an, g, sum); simt <- rowsum(anS, g); tot <- tapply(dd$cases_total, g, sum)
    out[[v]] <- tibble(measure = label, group_var = group, group = names(est), exposure = v, cases = as.numeric(tot[names(est)]),
      AN = as.numeric(est), AN_lo = apply(simt[names(est), , drop = FALSE], 1, quantile, 0.025),
      AN_hi = apply(simt[names(est), , drop = FALSE], 1, quantile, 0.975)) |>
      mutate(AF = 100 * AN / cases, AF_lo = 100 * AN_lo / cases, AF_hi = 100 * AN_hi / cases)
  }
  bind_rows(out)
}
res <- bind_rows(an_by("Ghana"), an_by("regime"), an_by("region"), an_by("year"),
                 bind_rows(lapply(c("Ghana", "regime", "region", "year"), an_by, XX = Xmed, label = "above the median")))
print(res |> filter(group_var %in% c("Ghana", "regime")) |> select(-group_var) |> mutate(across(where(is.numeric), \(x) round(x, 1))), n = 40)
print(res |> filter(exposure == "all", group_var %in% c("region", "year")) |> select(-group_var) |> mutate(across(where(is.numeric), \(x) round(x, 1))), n = 40)
write_csv(res, "analysis/output/attributable.csv")
write_csv(tibble(exposure = names(x0), x0 = x0), "analysis/output/attributable_reference.csv")
cat("rows", nrow(dd), "cases", sum(dd$cases_total), "\ndone\n")
