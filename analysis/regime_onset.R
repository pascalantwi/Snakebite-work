# Sections 3.7 (heterogeneity by rainfall regime) and 3.8 (rainy-season onset).
# 3.7: the selected DLNM (lag 9, 2/2 df) fitted separately in each regime (stage 1), reduced to the overall cumulative
#      exposure-response (centred on the national median) and the lag curve at the national 90th percentile, then pooled
#      by multivariate meta-analysis with mixmeta (stage 2): Cochran Q and I2. One-stage check: likelihood-ratio test of
#      regime-specific cross-bases. Sensitivity: transition zone merged with each neighbouring regime.
# 3.8: event-study model by regime, months since onset -2..6 (reference: 3 months before onset and months outside the
#      window), replacing calendar-month effects; secondary models of peak month and rainy-season total on onset.
# Run from the repository root:  Rscript analysis/regime_onset.R      (about 20 minutes on 4 cores)
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(dlnm); library(glmmTMB)
  library(mixmeta); library(parallel) })
source("analysis/primary_common.R")
L <- 9; MAIN <- c("rainfall", "tmax", "tmin", "ndvi"); REGS <- c("unimodal", "transition", "bimodal")
d <- load_panel()
cb <- setNames(lapply(MAIN, function(v) crossbasis(d[[v]], lag = L, group = d$district,
  argvar = list(fun = "ns", df = 2), arglag = list(fun = "ns", df = 2))), paste0("cb_", MAIN))
rows <- d$include_main == 1 & d$t > L
RE <- "+ offset(log(population)) + (1 | region) + (1 | region:district)"
fit <- function(f, dat) glmmTMB(as.formula(f), data = dat, family = nbinom2, control = glmmTMBControl(profile = TRUE))
with_rows <- function(r, extra = list()) { dat <- d[r, ]; for (n in names(c(cb, extra))) dat[[n]] <- unclass(c(cb, extra)[[n]])[r, , drop = FALSE]; dat }
q <- sapply(MAIN, function(v) quantile(d[[v]][rows], c(0.01, 0.5, 0.9, 0.99)))
CBS <- paste(names(cb), collapse = " + ")

# ---- stage 1: one model per group ------------------------------------------------------------------------------
groups <- list(unimodal = "unimodal", transition = "transition", bimodal = "bimodal",
               `unimodal+transition` = c("unimodal", "transition"), `transition+bimodal` = c("transition", "bimodal"))
st1 <- mclapply(names(groups), function(g) {
  r <- rows & d$regime %in% groups[[g]]
  f <- paste("cases_total ~ year_f + pov_z +", if (length(groups[[g]]) > 1) "regime * month_f" else "month_f", "+", CBS, RE)
  m <- fit(f, with_rows(r))
  red <- lapply(MAIN, function(v) {
    i <- grep(paste0("^cb_", v), names(fixef(m)$cond)); b <- fixef(m)$cond[i]; V <- vcov(m)$cond[i, i]
    ov <- crossreduce(cb[[paste0("cb_", v)]], coef = b, vcov = V, model.link = "log", type = "overall", cen = q["50%", v])
    lg <- crossreduce(cb[[paste0("cb_", v)]], coef = b, vcov = V, model.link = "log", type = "var", value = q["90%", v], cen = q["50%", v])
    rng <- quantile(d[[v]][r], c(0.01, 0.99)); xs <- seq(rng[1], rng[2], length.out = 60)
    # separate predictions: crosspred() sorts the values in 'at', so the 90th percentile is predicted on its own
    p90 <- crosspred(cb[[paste0("cb_", v)]], coef = b, vcov = V, model.link = "log", at = q["90%", v], cen = q["50%", v], bylag = 1)
    pc  <- crosspred(cb[[paste0("cb_", v)]], coef = b, vcov = V, model.link = "log", at = xs, cen = q["50%", v])
    list(ov = ov, lg = lg,
         lag = tibble(group = g, variable = v, lag = 0:L, RR = p90$matRRfit[1, ], lo = p90$matRRlow[1, ], hi = p90$matRRhigh[1, ]),
         cum = tibble(group = g, variable = v, x = xs, RR = pc$allRRfit, lo = pc$allRRlow, hi = pc$allRRhigh),
         cum90 = tibble(group = g, variable = v, RR = p90$allRRfit[1], lo = p90$allRRlow[1], hi = p90$allRRhigh[1]))
  })
  names(red) <- MAIN
  list(n = sum(r), districts = n_distinct(d$district[r]), cases = sum(d$cases_total[r]), red = red,
       minus2LL = -2 * as.numeric(logLik(m)), converged = m$fit$convergence == 0 && isTRUE(m$sdr$pdHess))
}, mc.cores = 4, mc.preschedule = FALSE)
names(st1) <- names(groups)
print(sapply(st1, function(s) c(n = s$n, districts = s$districts, cases = s$cases, converged = s$converged)))
write_csv(bind_rows(lapply(st1, function(s) bind_rows(lapply(s$red, `[[`, "lag")))), "analysis/output/regime_lag_curves.csv")
write_csv(bind_rows(lapply(st1, function(s) bind_rows(lapply(s$red, `[[`, "cum")))), "analysis/output/regime_cumulative_curves.csv")
write_csv(bind_rows(lapply(st1, function(s) bind_rows(lapply(s$red, `[[`, "cum90")))), "analysis/output/regime_cumRR90.csv")

# ---- stage 2: multivariate meta-analysis ------------------------------------------------------------------------
meta <- function(gs, what) bind_rows(lapply(MAIN, function(v) {
  B <- t(sapply(gs, function(g) coef(st1[[g]]$red[[v]][[what]]))); S <- lapply(gs, function(g) vcov(st1[[g]]$red[[v]][[what]]))
  mm <- mixmeta(B ~ 1, S = S, method = "reml"); qt <- qtest(mm)
  out <- tibble(set = paste(gs, collapse = " / "), curve = c(ov = "overall cumulative", lg = "lag at 90th percentile")[[what]],
         variable = v, Q = qt$Q[1], df = qt$df[1], p = qt$pvalue[1], I2 = max(0, (qt$Q[1] - qt$df[1]) / qt$Q[1]) * 100)
  if (what == "ov") {                        # pooled cumulative RR at the national 90th percentile
    bx <- onebasis(q["90%", v], fun = "ns", knots = attr(cb[[paste0("cb_", v)]], "argvar")$knots,
                   Boundary.knots = attr(cb[[paste0("cb_", v)]], "argvar")$Boundary.knots) -
          onebasis(q["50%", v], fun = "ns", knots = attr(cb[[paste0("cb_", v)]], "argvar")$knots,
                   Boundary.knots = attr(cb[[paste0("cb_", v)]], "argvar")$Boundary.knots)
    est <- drop(bx %*% coef(mm)); se <- sqrt(drop(bx %*% vcov(mm) %*% t(bx)))
    out <- mutate(out, pooled_RR90 = exp(est), pooled_lo = exp(est - 1.96 * se), pooled_hi = exp(est + 1.96 * se))
  }
  out
}))
het <- bind_rows(meta(REGS, "ov"), meta(REGS, "lg"),
                 meta(c("unimodal+transition", "bimodal"), "ov"), meta(c("unimodal+transition", "bimodal"), "lg"),
                 meta(c("unimodal", "transition+bimodal"), "ov"), meta(c("unimodal", "transition+bimodal"), "lg"))
print(het, n = 40, width = 200); write_csv(het, "analysis/output/regime_heterogeneity.csv")

# ---- one-stage likelihood-ratio test of regime-specific cross-bases ---------------------------------------------
ind <- lapply(c("transition", "bimodal"), function(g) as.numeric(d$regime == g)); names(ind) <- c("transition", "bimodal")
xtra <- list()
for (v in MAIN) for (g in names(ind)) xtra[[paste0("cbx_", v, "_", g)]] <- unclass(cb[[paste0("cb_", v)]]) * ind[[g]]
dat_all <- with_rows(rows, xtra)
f0 <- paste("cases_total ~ year_f + pov_z + regime * month_f +", CBS, RE)
f1 <- paste("cases_total ~ year_f + pov_z + regime * month_f +", CBS, "+", paste(names(xtra), collapse = " + "), RE)
os <- mclapply(list(f0, f1), fit, dat = dat_all, mc.cores = 2)
lr <- -2 * (as.numeric(logLik(os[[1]])) - as.numeric(logLik(os[[2]])))
dfl <- attr(logLik(os[[2]]), "df") - attr(logLik(os[[1]]), "df")
onestage <- tibble(chisq = lr, df = dfl, p = pchisq(lr, dfl, lower.tail = FALSE), n = nrow(dat_all))
print(onestage); write_csv(onestage, "analysis/output/regime_onestage_lrt.csv")

# ---- 3.8: onset event study ---------------------------------------------------------------------------------------
dy <- d |> group_by(district, year) |> arrange(month, .by_group = TRUE) |>
  summarise(onset = { m <- month[month >= 2 & rainfall >= 2]; if (length(m)) min(m) else NA_integer_ },
            false_start = { o <- month[month >= 2 & rainfall >= 2]; if (length(o)) any(rainfall[month > min(o) & month <= min(o) + 2] < 1) else NA },
            .groups = "drop")
d2 <- d |> left_join(dy, by = c("district", "year")) |>
  mutate(k = month - onset, ev = ifelse(!is.na(k) & k >= -2 & k <= 6, as.character(k), "ref"),
         ev = factor(ev, levels = c("ref", as.character(-2:6))))
r2 <- d2$include_main == 1 & !is.na(d2$onset)
evf <- mclapply(REGS, function(g) {
  m <- fit(paste("cases_total ~ ev + year_f + pov_z", RE), d2[r2 & d2$regime == g, ])
  i <- grep("^ev", names(fixef(m)$cond)); b <- fixef(m)$cond[i]; se <- sqrt(diag(vcov(m)$cond))[i]
  tibble(regime = g, k = as.integer(sub("ev", "", names(b))), RR = exp(b), lo = exp(b - 1.96 * se), hi = exp(b + 1.96 * se),
         n = sum(r2 & d2$regime == g), converged = m$fit$convergence == 0 && isTRUE(m$sdr$pdHess))
}, mc.cores = 3)
ev <- bind_rows(evf); print(ev, n = 40); write_csv(ev, "analysis/output/onset_event_study.csv")

# secondary: peak month and rainy-season total (onset month to 5 months after) on onset month and false start
sy <- d2 |> filter(include_main == 1, !is.na(onset)) |> group_by(district, region, regime, year, year_f, onset, false_start, pov_z) |>
  summarise(total = sum(cases_total), peak = if (sum(cases_total) > 0) month[which.max(cases_total)] else NA_integer_,
            season = sum(cases_total[month >= first(onset) & month <= first(onset) + 5]),
            population = first(population), months = n(), .groups = "drop") |>
  filter(months == 12 | year == 2025) |>
  group_by(district) |> mutate(onset_c = onset - mean(onset)) |> ungroup()
pk <- glmmTMB(peak ~ onset + false_start + regime + pov_z + year_f + (1 | district), data = filter(sy, !is.na(peak)), family = gaussian)
st <- glmmTMB(season ~ onset + false_start + regime + pov_z + year_f + offset(log(population)) + (1 | region) + (1 | region:district),
              data = sy, family = nbinom2)
sec <- bind_rows(
  tibble(model = "peak month (months; linear mixed model)", term = names(fixef(pk)$cond), est = fixef(pk)$cond, se = sqrt(diag(vcov(pk)$cond))),
  tibble(model = "rainy-season cases (rate ratio; NB mixed model)", term = names(fixef(st)$cond), est = fixef(st)$cond, se = sqrt(diag(vcov(st)$cond)))) |>
  filter(term %in% c("onset", "false_startTRUE")) |>
  mutate(lo = est - 1.96 * se, hi = est + 1.96 * se, p = 2 * pnorm(-abs(est / se)),
         across(c(est, lo, hi), ~ ifelse(grepl("rate ratio", model), exp(.x), .x)))
print(sec, width = 200); write_csv(sec, "analysis/output/onset_secondary.csv")
cat("district-years:", nrow(sy), "| false starts:", sum(sy$false_start, na.rm = TRUE), "\n")
print(sy |> group_by(regime) |> summarise(n = n(), median_onset = median(onset), false_starts = sum(false_start),
                                          median_peak = median(peak, na.rm = TRUE)))
cat("done\n")
