# Section 3.10: out-of-sample predictive validation (Section 2.4.10).
# Models: A = year effects, calendar month by regime, region and district random intercepts, log(population) offset;
#         B = A + cross-bases of rainfall, maximum and minimum temperature and NDVI restricted to lags 1-9 (climate already
#             observed when the month is predicted); C = B + months since rainy-season onset for months 1-6 after onset
#             (known one month ahead; other months form the reference).
# Hold-out 2025 (trained on October 2020 - December 2024) and rolling origin (each year 2022-2025 from all earlier years).
# The year effect of a predicted year is unknown, so the linear predictor is averaged over the training-year effects.
# Run from the repository root:  Rscript analysis/prediction.R      (about 15 minutes on 4 cores)
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(dlnm); library(glmmTMB); library(parallel) })
source("analysis/primary_common.R")
L <- 9; MAIN <- c("rainfall", "tmax", "tmin", "ndvi")
set.seed(20251231)
d <- load_panel()
for (v in MAIN) d[[paste0("cbp_", v)]] <- unclass(crossbasis(d[[v]], lag = c(1, L), group = d$district,
                                         argvar = list(fun = "ns", df = 2), arglag = list(fun = "ns", df = 2)))
on <- d |> group_by(district, year) |> summarise(onset = { m <- month[month >= 2 & rainfall >= 2]; if (length(m)) min(m) else NA_integer_ }, .groups = "drop")
d <- d |> left_join(on, by = c("district", "year")) |>
  mutate(k = month - onset, ev_rt = factor(ifelse(!is.na(k) & k >= 1 & k <= 6, as.character(k), "ref"), levels = c("ref", 1:6)))
rows <- d$include_main == 1 & d$t > L
RE <- "+ offset(log(population)) + (1 | region) + (1 | region:district)"
CB <- paste(paste0("cbp_", MAIN), collapse = " + ")
FORMS <- c(A = paste("cases_total ~ year_f + regime * month_f", RE),
           B = paste("cases_total ~ year_f + regime * month_f +", CB, RE),
           C = paste("cases_total ~ year_f + regime * month_f +", CB, "+ ev_rt", RE))

crps_nb <- function(y, mu, size) {
  K <- max(qnbinom(0.99999, size = size, mu = max(mu)), max(y)); k <- 0:K
  vapply(seq_along(y), function(i) { F <- pnbinom(k, size = size, mu = mu[i]); sum((F - (y[i] <= k))^2) }, 0)
}
one <- function(job) {
  Y <- job$year; mdl <- job$model
  tr <- d[rows & d$year < Y, ] |> mutate(year_f = droplevels(year_f)); te <- d[rows & d$year == Y, ]
  m <- glmmTMB(as.formula(FORMS[[mdl]]), data = tr, family = nbinom2, control = glmmTMBControl(profile = TRUE))
  eta <- sapply(levels(tr$year_f), function(yy) { nd <- te; nd$year_f <- factor(yy, levels = levels(tr$year_f))
    log(predict(m, newdata = nd, type = "response")) })
  mu <- exp(rowMeans(eta)); th <- sigma(m)
  thr <- tr |> group_by(district) |> summarise(thr = quantile(cases_total, 0.75), .groups = "drop")
  te |> select(district, region, regime, year, month, date, cases_total, climate_imputed) |>
    mutate(model = mdl, test_year = Y, mu = mu, theta = th,
           lo90 = qnbinom(0.05, size = th, mu = mu), hi90 = qnbinom(0.95, size = th, mu = mu),
           F = pnbinom(cases_total, size = th, mu = mu), Fm1 = pnbinom(cases_total - 1, size = th, mu = mu),
           crps = crps_nb(cases_total, mu, th)) |>
    left_join(thr, by = "district")
}
jobs <- unlist(lapply(2022:2025, function(y) lapply(names(FORMS), function(mm) list(year = y, model = mm))), recursive = FALSE)
pred <- bind_rows(mclapply(jobs, one, mc.cores = 4, mc.preschedule = FALSE))
write_csv(pred, "analysis/output/predictions.csv")

summ <- function(p) p |> group_by(model) |> summarise(
  n = n(), MAE = mean(abs(cases_total - mu)), CRPS = mean(crps),
  coverage90 = mean(cases_total >= lo90 & cases_total <= hi90),
  sensitivity = sum(cases_total > thr & mu > thr) / sum(cases_total > thr),
  specificity = sum(cases_total <= thr & mu <= thr) / sum(cases_total <= thr), .groups = "drop")
h25 <- filter(pred, test_year == 2025)
tab <- bind_rows(mutate(summ(h25), set = "hold-out 2025"),
                 mutate(summ(filter(h25, climate_imputed == 0)), set = "hold-out 2025, excluding December"),
                 mutate(summ(pred), set = "rolling origin 2022-2025"))
print(tab, width = 200); write_csv(tab, "analysis/output/prediction_summary.csv")
by_year <- pred |> group_by(test_year, model) |> summarise(MAE = mean(abs(cases_total - mu)), CRPS = mean(crps), .groups = "drop")
print(by_year, n = 20); write_csv(by_year, "analysis/output/prediction_by_year.csv")

# non-randomised PIT histogram (Czado, Gneiting and Held 2009), 10 bins, hold-out 2025
pit <- bind_rows(lapply(c("A", "B", "C"), function(mm) {
  p <- filter(h25, model == mm); u <- seq(0, 1, 0.1)
  Fbar <- sapply(u, function(x) mean(ifelse(x <= p$Fm1, 0, ifelse(x >= p$F, 1, (x - p$Fm1) / (p$F - p$Fm1)))))
  tibble(model = mm, bin = 1:10, lower = u[-11], upper = u[-1], density = 10 * diff(Fbar))
}))
write_csv(pit, "analysis/output/prediction_pit.csv"); print(pit |> group_by(model) |> summarise(min = min(density), max = max(density)))

# national monthly totals in 2025 with 90% prediction intervals by simulation
nat <- bind_rows(lapply(c("A", "B", "C"), function(mm) {
  p <- filter(h25, model == mm)
  sims <- sapply(1:1000, function(s) tapply(rnbinom(nrow(p), size = p$theta[1], mu = p$mu), p$month, sum))
  tibble(model = mm, month = 1:12, observed = as.numeric(tapply(p$cases_total, p$month, sum)),
         predicted = as.numeric(tapply(p$mu, p$month, sum)), lo = apply(sims, 1, quantile, 0.05), hi = apply(sims, 1, quantile, 0.95))
}))
print(nat, n = 40); write_csv(nat, "analysis/output/prediction_national_2025.csv")
dist <- h25 |> group_by(model, district, regime) |> summarise(observed = sum(cases_total), predicted = sum(mu), .groups = "drop")
write_csv(dist, "analysis/output/prediction_district_2025.csv")
print(dist |> group_by(model) |> summarise(cor = cor(observed, predicted), MAE_total = mean(abs(observed - predicted))))
cat("done\n")
