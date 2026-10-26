# Section 3.10: out-of-sample predictive validation (Section 2.4.10), version 2.
# One-month-ahead forecasts. All models: calendar month by regime, a linear time trend (extrapolated to the predicted
# year), recent case history (log of last month's cases + 1; log incidence over the previous 12 months), region and
# district random intercepts and a log(population) offset.
#   A = seasonal terms and case history;
#   B = A + cross-bases of standardized climate anomalies (rainfall, maximum and minimum temperature, NDVI) at lags 1-9,
#       with the climatology estimated from the training years only;
#   C = B + months 1-6 after rainy-season onset (known one month ahead).
# High-incidence months (above the district's training 75th percentile) are flagged when the predicted probability of
# exceeding that value passes a cut-off chosen on the training data (Youden index); AUC is reported.
# Hold-out 2025 and rolling origin (each year 2022-2025 predicted from all earlier months).
# Run from the repository root:  Rscript analysis/prediction.R      (about 15 minutes on 4 cores)
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(dlnm); library(glmmTMB); library(parallel) })
source("analysis/primary_common.R")
L <- 9; MAIN <- c("rainfall", "tmax", "tmin", "ndvi")
set.seed(20251231)
d <- load_panel() |> group_by(district) |>
  mutate(hist1 = log1p(lag(cases_total, 1)),
         hist12 = log((as.numeric(stats::filter(lag(cases_total, 1), rep(1, 12), sides = 1)) + 0.5) / population)) |>
  ungroup() |> mutate(trend = (t - 36) / 12)
on <- d |> group_by(district, year) |> summarise(onset = { m <- month[month >= 2 & rainfall >= 2]; if (length(m)) min(m) else NA_integer_ }, .groups = "drop")
d <- d |> left_join(on, by = c("district", "year")) |>
  mutate(k = month - onset, ev_rt = factor(ifelse(!is.na(k) & k >= 1 & k <= 6, as.character(k), "ref"), levels = c("ref", 1:6)))
rows <- d$include_main == 1 & d$t > 12            # a full 12-month case history (January 2021 onwards)
RE <- "+ offset(log(population)) + (1 | region) + (1 | region:district)"
BASE <- "cases_total ~ trend + regime * month_f + hist1 + hist12"
CB <- paste(paste0("an_", MAIN), collapse = " + ")
FORMS <- c(A = paste(BASE, RE), B = paste(BASE, "+", CB, RE), C = paste(BASE, "+", CB, "+ ev_rt", RE))

# anomaly cross-bases for a test year: climatology and SD of deviations from the training years only
anom_cb <- function(Y) {
  dd <- d
  for (v in MAIN) {
    tr <- dd$year < Y
    clim <- ave(ifelse(tr, dd[[v]], NA), dd$district, dd$month, FUN = function(z) mean(z, na.rm = TRUE))
    dev <- dd[[v]] - clim
    a <- dev / sd(dev[tr])
    dd[[paste0("an_", v)]] <- unclass(crossbasis(a, lag = c(1, L), group = dd$district,
                                                 argvar = list(fun = "ns", df = 2), arglag = list(fun = "ns", df = 2)))
  }
  dd
}
crps_nb <- function(y, mu, size) {
  K <- max(qnbinom(0.99999, size = size, mu = max(mu)), max(y)); k <- 0:K
  vapply(seq_along(y), function(i) { F <- pnbinom(k, size = size, mu = mu[i]); sum((F - (y[i] <= k))^2) }, 0)
}
auc <- function(score, case) { r <- rank(score); n1 <- sum(case); n0 <- sum(!case); (sum(r[case]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
one <- function(job) {
  Y <- job$year; mdl <- job$model; dd <- anom_cb(Y)
  tr <- dd[rows & dd$year < Y, ]; te <- dd[rows & dd$year == Y, ]
  m <- glmmTMB(as.formula(FORMS[[mdl]]), data = tr, family = nbinom2, control = glmmTMBControl(profile = TRUE))
  th <- sigma(m)
  thr <- tr |> group_by(district) |> summarise(thr = quantile(cases_total, 0.75), .groups = "drop")
  # probability of exceeding the threshold; cut-off from the training data (maximum Youden index)
  trp <- tr |> left_join(thr, by = "district") |> mutate(mu = fitted(m), pr = pnbinom(thr, size = th, mu = mu, lower.tail = FALSE))
  cuts <- seq(0.05, 0.95, 0.01)
  you <- sapply(cuts, function(c) mean(trp$pr[trp$cases_total > trp$thr] > c) + mean(trp$pr[trp$cases_total <= trp$thr] <= c) - 1)
  cut <- cuts[which.max(you)]
  te |> select(district, region, regime, year, month, date, cases_total, climate_imputed) |>
    mutate(model = mdl, test_year = Y, mu = predict(m, newdata = te, type = "response", allow.new.levels = FALSE), theta = th) |>
    left_join(thr, by = "district") |>
    mutate(lo90 = qnbinom(0.05, size = th, mu = mu), hi90 = qnbinom(0.95, size = th, mu = mu),
           F = pnbinom(cases_total, size = th, mu = mu), Fm1 = pnbinom(cases_total - 1, size = th, mu = mu),
           crps = crps_nb(cases_total, mu, th), pr = pnbinom(thr, size = th, mu = mu, lower.tail = FALSE), cut = cut)
}
jobs <- unlist(lapply(2022:2025, function(y) lapply(names(FORMS), function(mm) list(year = y, model = mm))), recursive = FALSE)
pred <- bind_rows(mclapply(jobs, one, mc.cores = 4, mc.preschedule = FALSE))
write_csv(pred, "analysis/output/predictions.csv")

summ <- function(p) p |> group_by(model) |> summarise(
  n = n(), MAE = mean(abs(cases_total - mu)), CRPS = mean(crps),
  coverage90 = mean(cases_total >= lo90 & cases_total <= hi90),
  AUC = auc(pr, cases_total > thr),
  sensitivity = mean(pr[cases_total > thr] > cut[cases_total > thr]),
  specificity = mean(pr[cases_total <= thr] <= cut[cases_total <= thr]), .groups = "drop")
h25 <- filter(pred, test_year == 2025)
tab <- bind_rows(mutate(summ(h25), set = "hold-out 2025"),
                 mutate(summ(filter(h25, climate_imputed == 0)), set = "hold-out 2025, excluding December"),
                 mutate(summ(pred), set = "rolling origin 2022-2025"))
print(tab, width = 200); write_csv(tab, "analysis/output/prediction_summary.csv")
by_year <- pred |> group_by(test_year, model) |> summarise(MAE = mean(abs(cases_total - mu)), CRPS = mean(crps), .groups = "drop")
print(by_year, n = 20); write_csv(by_year, "analysis/output/prediction_by_year.csv")
print(pred |> distinct(test_year, model, cut))

pit <- bind_rows(lapply(c("A", "B", "C"), function(mm) {
  p <- filter(h25, model == mm); u <- seq(0, 1, 0.1)
  Fbar <- sapply(u, function(x) mean(ifelse(x <= p$Fm1, 0, ifelse(x >= p$F, 1, (x - p$Fm1) / (p$F - p$Fm1)))))
  tibble(model = mm, bin = 1:10, lower = u[-11], upper = u[-1], density = 10 * diff(Fbar))
}))
write_csv(pit, "analysis/output/prediction_pit.csv"); print(pit |> group_by(model) |> summarise(min = min(density), max = max(density)))
nat <- bind_rows(lapply(c("A", "B", "C"), function(mm) {
  p <- filter(h25, model == mm)
  sims <- sapply(1:1000, function(s) tapply(rnbinom(nrow(p), size = p$theta[1], mu = p$mu), p$month, sum))
  tibble(model = mm, month = 1:12, observed = as.numeric(tapply(p$cases_total, p$month, sum)),
         predicted = as.numeric(tapply(p$mu, p$month, sum)), lo = apply(sims, 1, quantile, 0.05), hi = apply(sims, 1, quantile, 0.95))
}))
print(nat, n = 40); write_csv(nat, "analysis/output/prediction_national_2025.csv")
dist <- h25 |> group_by(model, district, regime) |> summarise(observed = sum(cases_total), predicted = sum(mu), .groups = "drop")
write_csv(dist, "analysis/output/prediction_district_2025.csv")
print(dist |> group_by(model) |> summarise(cor = cor(observed, predicted), cor_log = cor(log1p(observed), log1p(predicted))))
# version-1 summary on the same rows (January 2021 onwards are all v1 test rows), for the comparison in Table 8
v1 <- read_csv("analysis/output/predictions_v1.csv", show_col_types = FALSE) |>
  mutate(AUC = NA_real_, pr = NA_real_, cut = NA_real_)
v1s <- bind_rows(mutate(summ(filter(v1, test_year == 2025) |> mutate(pr = as.numeric(mu > thr), cut = 0.5)), set = "hold-out 2025"),
                 mutate(summ(v1 |> mutate(pr = as.numeric(mu > thr), cut = 0.5)), set = "rolling origin 2022-2025")) |>
  mutate(model = paste0(model, " (version 1)"), AUC = NA_real_)
print(v1s, width = 200); write_csv(v1s, "analysis/output/prediction_summary_v1_compare.csv")
cat("done\n")
