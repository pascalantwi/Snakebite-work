# Section 3.11: sensitivity analyses (Section 2.4.11) and model diagnostics (Section 2.4.12).
# Each alternative refits the selected model (cross-bases of rainfall, maximum and minimum temperature and NDVI; maximum
# lag 9 months, natural splines with 2 df) and the seasonality models M0-M2 of the primary analysis, so that each gives
# the cumulative rate ratios at the 90th percentile compared with the median (reference values from the main analysis)
# and the share of seasonality reproduced by climate, S_clim = (D0 - D2) / (D0 - D1), with D the -2 log-likelihood.
# Alternatives: lag structure; NB1, zero-inflated and hurdle models; outlying district-months, 2020 and December 2025
# excluded; Fourier seasonality; grid-cell random intercept and standard errors clustered by grid cell; monthly
# (interpolated) population; regime thresholds 0.75 and 0.9 and the transition zone merged; first-order autoregressive
# district-month effects; a spatially structured district effect; alternative onset definitions (event study).
# Diagnostics: randomized quantile residuals of the selected model (uniformity, dispersion, zeros), residual
# autocorrelation within districts and Moran's I between neighbouring districts (data/district_neighbours.csv).
# Run from the repository root:  Rscript analysis/sensitivity.R      (about 1-2 hours on 4 cores)
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(dlnm); library(glmmTMB); library(parallel) })
source("analysis/primary_common.R")
set.seed(20251231)
MAIN <- c("rainfall", "tmax", "tmin", "ndvi")
d0 <- load_panel()
main_rows <- d0$include_main == 1 & d0$t > 9
Q <- lapply(setNames(MAIN, MAIN), function(v) quantile(d0[[v]][main_rows], c(0.5, 0.9)))
SEAS <- c(month = "regime * month_f", fourier = "regime * (s1 + c1 + s2 + c2)")
RE0 <- "(1 | region) + (1 | region:district)"
d0 <- d0 |> mutate(s1 = sin(2 * pi * month / 12), c1 = cos(2 * pi * month / 12), s2 = sin(4 * pi * month / 12), c2 = cos(4 * pi * month / 12))

# ---- alternative data ---------------------------------------------------------------------------------------------
# rainfall regime with another threshold for the July-August dip (Section 2.1; main threshold 0.8)
regime_thr <- function(thr) {
  m <- d0 |> filter(year <= 2024) |> group_by(district, year) |>
    summarise(bim = { r <- setNames(rainfall, month); min(r[c("7", "8")]) < thr * max(r[c("4", "5", "6")]) &
                      min(r[c("7", "8")]) < thr * max(r[c("9", "10")]) }, .groups = "drop") |>
    group_by(district) |> summarise(n = sum(bim))
  g <- setNames(ifelse(m$n >= 4, "bimodal", ifelse(m$n <= 1, "unimodal", "transition")), m$district)
  factor(g[as.character(d0$district)])
}
stopifnot(mean(as.character(regime_thr(0.8)) == as.character(d0$regime)) > 0.98)
reg75 <- regime_thr(0.75); reg90 <- regime_thr(0.9)
n_changed <- function(r) sum((r != d0$regime)[!duplicated(d0$district)])
# outlying district-months: more than 20 cases and more than ten times the district median
med <- ave(ifelse(d0$include_main == 1, d0$cases_total, NA), d0$district, FUN = function(z) median(z, na.rm = TRUE))
outlier <- d0$cases_total > 20 & d0$cases_total > 10 * med
# grid cells: districts with identical NASA POWER series
key <- d0 |> group_by(district) |> summarise(k = paste(round(c(rainfall, tmax, tmin, rel_humidity), 3), collapse = ","))
cell <- setNames(as.integer(factor(key$k)), key$district)
d0$cell <- factor(cell[as.character(d0$district)])
# monthly population: annual values placed at July and interpolated linearly (constant before July 2020 and after July 2025)
d0 <- d0 |> group_by(district) |> mutate(pop_month = { a <- tapply(population, year, first)
  approx((as.numeric(names(a)) - 2020) * 12 + 7, a, xout = t, rule = 2)$y }) |> ungroup()
# coordinates (km) for the spatially structured district effect
pts <- read_csv("data/district_points.csv", show_col_types = FALSE)
lat0 <- mean(pts$lat)
xy <- pts |> mutate(x = (lon - mean(lon)) * 111.32 * cos(lat0 * pi / 180), y = (lat - lat0) * 110.57)
d0 <- d0 |> left_join(select(xy, district, x, y), by = "district") |>
  mutate(pos = numFactor(round(x, 1), round(y, 1)), sp = factor(1), tf = factor(t), district = factor(district))
cat("outliers:", sum(outlier & d0$include_main == 1), "| grid cells:", nlevels(d0$cell),
    "| reclassified at 0.75:", n_changed(reg75), "at 0.9:", n_changed(reg90), "\n")

# ---- one alternative ------------------------------------------------------------------------------------------------
cbs <- function(d, vars, L, dfv, dfl, knots = FALSE) setNames(lapply(vars, function(v)
  crossbasis(d[[v]], lag = L, group = d$district, argvar = list(fun = "ns", df = dfv),
             arglag = if (knots) list(fun = "ns", knots = logknots(L, nk = 1)) else list(fun = "ns", df = dfl))), paste0("cb_", vars))
attach_cb <- function(d, cb, rows) { dd <- d[rows, ]; for (n in names(cb)) dd[[n]] <- unclass(cb[[n]])[rows, , drop = FALSE]; droplevels(dd) }
fitm <- function(f, dd, family, zi) {
  a <- list(formula = as.formula(f), data = dd, family = family, ziformula = zi)
  tryCatch(do.call(glmmTMB, c(a, list(control = glmmTMBControl(profile = TRUE)))),
           error = function(e) do.call(glmmTMB, a))
}
ok <- function(m) m$fit$convergence == 0 && isTRUE(m$sdr$pdHess)
run <- function(j) {
  t0 <- Sys.time()
  d <- d0; if (!is.null(j$regime)) d$regime <- j$regime
  if (!is.null(j$pop)) d$population <- d[[j$pop]]
  extra <- if (is.null(j$keep)) rep(TRUE, nrow(d)) else j$keep
  fam <- if (is.null(j$family)) nbinom2 else j$family; zi <- if (is.null(j$zi)) ~0 else j$zi
  re <- paste("+ offset(log(population)) +", if (is.null(j$re)) RE0 else j$re)
  seas <- SEAS[[if (is.null(j$seas)) "month" else j$seas]]
  L <- if (is.null(j$L)) 9 else j$L; dfv <- if (is.null(j$dfv)) 2 else j$dfv; dfl <- if (is.null(j$dfl)) 2 else j$dfl
  # selected model
  cb <- cbs(d, MAIN, L, dfv, dfl); rows <- d$include_main == 1 & d$t > L & extra
  dd <- attach_cb(d, cb, rows)
  m <- fitm(paste("cases_total ~ year_f + pov_z +", seas, "+", paste(names(cb), collapse = " + "), re), dd, fam, zi)
  b <- fixef(m)$cond; V <- vcov(m)$cond
  rr <- bind_rows(lapply(MAIN, function(v) {
    i <- grep(paste0("^cb_", v), names(b))
    p <- crosspred(cb[[paste0("cb_", v)]], coef = b[i], vcov = V[i, i], model.link = "log", at = Q[[v]][["90%"]], cen = Q[[v]][["50%"]])
    tibble(variable = v, cumRR = p$allRRfit, lo = p$allRRlow, hi = p$allRRhigh)
  }))
  out <- rr |> mutate(id = j$id, group = j$group, label = j$label, n = nrow(dd), cases = sum(dd$cases_total), converged = ok(m))
  # seasonality models
  if (!isFALSE(j$sclim)) {
    if (is.null(j$L)) { cbp <- cbs(d, VARS, 6, 3, NA, knots = TRUE); Lp <- 6 } else { cbp <- cbs(d, VARS, L, dfv, dfl); Lp <- L }
    rp <- d$include_main == 1 & d$t > Lp & extra; dp <- attach_cb(d, cbp, rp)
    f0 <- paste("cases_total ~ year_f + regime + pov_z", re)
    f1 <- paste("cases_total ~ year_f + pov_z +", seas, re)
    f2 <- paste("cases_total ~ year_f + regime + pov_z +", paste(names(cbp), collapse = " + "), re)
    ms <- lapply(list(f0, f1, f2), fitm, dd = dp, family = fam, zi = zi)
    D <- sapply(ms, function(x) -2 * as.numeric(logLik(x)))
    out <- out |> mutate(S_clim = (D[1] - D[3]) / (D[1] - D[2]), n_seas = nrow(dp), converged_seas = all(sapply(ms, ok)))
  }
  res <- list(summary = out)
  if (isTRUE(j$diag)) res$diag <- list(rows = which(rows), mu = as.numeric(fitted(m)), theta = sigma(m), y = dd$cases_total,
                                       district = as.character(dd$district), t = dd$t)
  if (!is.null(j$extra)) res$summary <- res$summary |> mutate(extra = j$extra(m))
  cat(format(Sys.time()), j$id, "done in", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min\n")
  res
}

spatial_share <- function(m) { v <- VarCorr(m)$cond
  sp <- attr(v[["sp"]], "stddev")[1]^2; sp / (sp + attr(v[["region:district"]], "stddev")^2) }
jobs <- list(
  list(id = "main", group = "Main analysis", label = "Selected model (lag 9 months, 2/2 df)", diag = TRUE),
  list(id = "L3", group = "Lag structure", label = "Maximum lag 3 months, 2/2 df", L = 3),
  list(id = "L6", group = "Lag structure", label = "Maximum lag 6 months, 2/2 df", L = 6),
  list(id = "L12", group = "Lag structure", label = "Maximum lag 12 months, 2/2 df", L = 12),
  list(id = "L9_23", group = "Lag structure", label = "Maximum lag 9 months, 2/3 df", L = 9, dfl = 3),
  list(id = "L9_32", group = "Lag structure", label = "Maximum lag 9 months, 3/2 df", L = 9, dfv = 3),
  list(id = "nb1", group = "Count distribution", label = "NB1 (linear variance)", family = nbinom1),
  list(id = "zinb", group = "Count distribution", label = "Zero-inflated NB2", zi = ~1),
  list(id = "hurdle", group = "Count distribution", label = "Hurdle NB2", family = truncated_nbinom2, zi = ~ year_f + regime + pov_z),
  list(id = "no_outliers", group = "Observations and periods", label = "Outlying district-months excluded", keep = !outlier),
  list(id = "no_2020", group = "Observations and periods", label = "2020 excluded", keep = d0$year >= 2021),
  list(id = "no_dec2025", group = "Observations and periods", label = "December 2025 excluded", keep = d0$climate_imputed == 0),
  list(id = "fourier", group = "Seasonal adjustment", label = "Fourier terms (two harmonics) by regime", seas = "fourier"),
  list(id = "cell_re", group = "Climate data", label = "Grid-cell random intercept", re = "(1 | region) + (1 | cell) + (1 | region:district)"),
  list(id = "pop_month", group = "Population and classification", label = "Monthly interpolated population", pop = "pop_month"),
  list(id = "thr75", group = "Population and classification", label = "Regime threshold 0.75", regime = reg75),
  list(id = "thr90", group = "Population and classification", label = "Regime threshold 0.9", regime = reg90),
  list(id = "tr_uni", group = "Population and classification", label = "Transition merged with unimodal",
       regime = factor(ifelse(d0$regime == "transition", "unimodal", as.character(d0$regime)))),
  list(id = "tr_bim", group = "Population and classification", label = "Transition merged with bimodal",
       regime = factor(ifelse(d0$regime == "transition", "bimodal", as.character(d0$regime)))),
  list(id = "ar1", group = "Dependence", label = "First-order autoregressive district-month effect", re = paste(RE0, "+ ar1(tf + 0 | district)"), diag = TRUE),
  list(id = "spatial", group = "Dependence", label = "Spatially structured district effect", re = paste(RE0, "+ exp(pos + 0 | sp)"), diag = TRUE, extra = spatial_share))
ord <- order(sapply(jobs, function(j) j$id %in% c("spatial", "ar1", "hurdle")), decreasing = TRUE)   # slow ones first
res <- mclapply(jobs[ord], function(j) tryCatch(run(j), error = function(e) { cat(j$id, "FAILED:", conditionMessage(e), "\n"); NULL }),
                mc.cores = 4, mc.preschedule = FALSE)
names(res) <- sapply(jobs[ord], `[[`, "id")
summ <- bind_rows(lapply(res, `[[`, "summary"))
print(summ |> select(id, variable, cumRR, lo, hi, S_clim, n, converged, converged_seas), n = 120, width = 200)
write_csv(summ, "analysis/output/sensitivity_summary.csv")

# ---- standard errors clustered by grid cell (fixed-district NB model, theta from the selected model) ------------------
dm <- res$main$diag; th <- dm$theta
cb <- cbs(d0, MAIN, 9, 2, 2); dd <- attach_cb(d0, cb, main_rows)
g <- glm(as.formula(paste("cases_total ~ district + year_f + regime:month_f +", paste(names(cb), collapse = " + "), "+ offset(log(population))")),
         data = dd, family = MASS::negative.binomial(th))
X <- model.matrix(g); keep <- !is.na(coef(g)); X <- X[, keep]; mu <- fitted(g)
s <- X * ((dd$cases_total - mu) / (1 + mu / th))
B <- vcov(g, dispersion = 1)[keep, keep]; G <- nlevels(droplevels(dd$cell))
M <- crossprod(rowsum(s, as.integer(droplevels(dd$cell)))) * G / (G - 1)
Vcl <- B %*% M %*% B
clus <- bind_rows(lapply(MAIN, function(v) {
  i <- grep(paste0("^cb_", v), names(coef(g))[keep])
  bind_rows(lapply(list(model = B, cluster = Vcl), function(VV) {
    p <- crosspred(cb[[paste0("cb_", v)]], coef = coef(g)[keep][i], vcov = VV[i, i], model.link = "log", at = Q[[v]][["90%"]], cen = Q[[v]][["50%"]])
    tibble(cumRR = p$allRRfit, lo = p$allRRlow, hi = p$allRRhigh)
  }), .id = "se") |> mutate(variable = v)
}))
print(clus); write_csv(clus |> mutate(clusters = G), "analysis/output/sensitivity_clustered_se.csv")

# ---- alternative onset definitions: event study by regime -------------------------------------------------------------
days <- c(31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
onset_def <- function(d, def) d |> group_by(district, year) |> arrange(month, .by_group = TRUE) |>
  summarise(onset = { r <- rainfall; mm <- cumsum(ifelse(month >= 2, r * days[month], 0))
    m <- switch(def, "2 mm/day" = month[month >= 2 & r >= 2], "1.5 mm/day" = month[month >= 2 & r >= 1.5],
                "3 mm/day" = month[month >= 2 & r >= 3], "120 mm from February" = month[month >= 2 & mm >= 120])
    if (length(m)) min(m) else NA_integer_ }, .groups = "drop")
REGS <- c("unimodal", "transition", "bimodal")
ojobs <- expand.grid(def = c("2 mm/day", "1.5 mm/day", "3 mm/day", "120 mm from February"), regime = REGS, stringsAsFactors = FALSE)
ons <- bind_rows(mclapply(seq_len(nrow(ojobs)), function(k) {
  def <- ojobs$def[k]; gg <- ojobs$regime[k]
  d2 <- d0 |> left_join(onset_def(d0, def), by = c("district", "year")) |>
    mutate(kk = month - onset, ev = factor(ifelse(!is.na(kk) & kk >= -2 & kk <= 6, as.character(kk), "ref"), levels = c("ref", -2:6)))
  r2 <- d2$include_main == 1 & !is.na(d2$onset) & d2$regime == gg
  m <- glmmTMB(as.formula(paste("cases_total ~ ev + year_f + pov_z + offset(log(population)) +", RE0)), data = droplevels(d2[r2, ]),
               family = nbinom2, control = glmmTMBControl(profile = TRUE))
  i <- grep("^ev", names(fixef(m)$cond)); b <- fixef(m)$cond[i]; se <- sqrt(diag(vcov(m)$cond))[i]
  on1 <- d2[r2 & !duplicated(paste(d2$district, d2$year)), ]
  tibble(definition = def, regime = gg, median_onset = median(on1$onset), district_years = nrow(on1),
         k = as.integer(sub("ev", "", names(b))), RR = exp(b), lo = exp(b - 1.96 * se), hi = exp(b + 1.96 * se), converged = ok(m))
}, mc.cores = 4, mc.preschedule = FALSE))
print(ons |> group_by(definition, regime) |> slice_max(RR, n = 1), n = 20)
write_csv(ons, "analysis/output/sensitivity_onset.csv")

# ---- diagnostics ------------------------------------------------------------------------------------------------------
nbr <- read_csv("data/district_neighbours.csv", show_col_types = FALSE)
moran <- function(z, ids) {
  W <- matrix(0, length(ids), length(ids), dimnames = list(ids, ids))
  e <- nbr |> filter(district %in% ids, neighbour %in% ids); W[cbind(e$district, e$neighbour)] <- 1
  I <- function(x) { x <- x - mean(x); length(x) / sum(W) * sum(W * outer(x, x)) / sum(x^2) }
  obs <- I(z); perm <- replicate(999, I(sample(z)))
  list(I = obs, p = (1 + sum(perm >= obs)) / 1000, perm = perm, E = -1 / (length(z) - 1))
}
diag_one <- function(x, name) {
  y <- x$y; mu <- x$mu; th <- x$theta
  Fm1 <- pnbinom(y - 1, size = th, mu = mu); F <- pnbinom(y, size = th, mu = mu)
  r <- Fm1 + runif(length(y)) * (F - Fm1); z <- qnorm(pmin(pmax(r, 1e-6), 1 - 1e-6))
  sims <- replicate(1000, rnbinom(length(y), size = th, mu = mu))
  disp_obs <- var(y - mu); disp_sim <- apply(sims, 2, function(s) var(s - mu))
  zero_obs <- sum(y == 0); zero_sim <- colSums(sims == 0)
  ks <- suppressWarnings(ks.test(r, "punif"))
  acf <- bind_rows(lapply(1:12, function(k) {
    i <- seq_along(z); j <- match(paste(x$district, x$t + k), paste(x$district, x$t)); keep <- !is.na(j)
    tibble(lag = k, acf = cor(z[keep], z[j[keep]]), n = sum(keep))
  }))
  zb <- tapply(z, x$district, mean); mo <- moran(as.numeric(zb), names(zb))
  list(tests = tibble(model = name, n = length(y), ks_D = unname(ks$statistic), ks_p = ks$p.value,
                      dispersion_ratio = disp_obs / mean(disp_sim), dispersion_p = 2 * min(mean(disp_sim >= disp_obs), mean(disp_sim <= disp_obs)),
                      zeros_obs = zero_obs, zeros_obs_share = zero_obs / length(y), zeros_sim_mean = mean(zero_sim),
                      zeros_ratio = zero_obs / mean(zero_sim), zeros_p = 2 * min(mean(zero_sim >= zero_obs), mean(zero_sim <= zero_obs)),
                      acf_lag1 = acf$acf[1], moran_I = mo$I, moran_E = mo$E, moran_p = mo$p),
       acf = mutate(acf, model = name), r = r, zero_sim = zero_sim, perm = mo$perm)
}
DN <- c(main = "Selected model", ar1 = "With autoregressive effect", spatial = "With spatial effect")
dg <- list()
for (k in names(DN)) if (!is.null(res[[k]]$diag)) dg[[k]] <- diag_one(res[[k]]$diag, DN[[k]])
tests <- bind_rows(lapply(dg, `[[`, "tests")); print(tests, width = 250)
write_csv(tests, "analysis/output/diagnostics.csv")
write_csv(bind_rows(lapply(dg, `[[`, "acf")), "analysis/output/diagnostics_acf.csv")
u <- sort(dg$main$r); write_csv(tibble(expected = (seq_along(u) - 0.5) / length(u), observed = u)[seq(1, length(u), by = 10), ], "analysis/output/diagnostics_qq.csv")
write_csv(tibble(zeros = dg$main$zero_sim), "analysis/output/diagnostics_zero_sims.csv")
write_csv(bind_rows(lapply(names(dg), function(k) tibble(model = dg[[k]]$tests$model, I = dg[[k]]$perm))), "analysis/output/diagnostics_moran_perm.csv")
cat("done\n")
