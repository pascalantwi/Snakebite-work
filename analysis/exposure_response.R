# Sections 3.5 and 3.6: exposure-lag-response associations from the selected model, and climatology versus anomaly.
# Selected cross-basis (Section 3.4): maximum lag 9 months, natural splines with 2 df for exposure and lag.
# Rows: recommended district-months with a complete 9-month climate history (October 2020 - December 2025).
# Run from the repository root:  Rscript analysis/exposure_response.R      (about 15 minutes on 4 cores)
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(dlnm); library(glmmTMB); library(parallel) })
source("analysis/primary_common.R")
L <- 9; DFV <- 2; DFL <- 2
MAIN <- c("rainfall", "tmax", "tmin", "ndvi")
d <- load_panel()
cbx <- function(x) crossbasis(x, lag = L, group = d$district, argvar = list(fun = "ns", df = DFV),
                              arglag = list(fun = "ns", df = DFL))
rows <- d$include_main == 1 & d$t > L
RE <- "+ offset(log(population)) + (1 | region) + (1 | region:district)"
fit <- function(f, dat) glmmTMB(as.formula(f), data = dat, family = nbinom2, control = glmmTMBControl(profile = TRUE))
attach_cb <- function(cb) { dat <- d[rows, ]; for (n in names(cb)) dat[[n]] <- unclass(cb[[n]])[rows, , drop = FALSE]; dat }

# ---- climatology and standardized anomaly (Section 2.3) ---------------------------------------------------------
for (v in c(MAIN, "rel_humidity")) {
  d[[paste0(v, "_clim")]] <- ave(d[[v]], d$district, d$month)
  dev <- d[[v]] - d[[paste0(v, "_clim")]]
  d[[paste0(v, "_anom")]] <- dev / sd(dev)
}

cb_main <- setNames(lapply(MAIN, function(v) cbx(d[[v]])), paste0("cb_", MAIN))
cb_rh   <- setNames(lapply(c("rainfall", "rel_humidity", "tmin", "ndvi"), function(v) cbx(d[[v]])),
                    paste0("cb_", c("rainfall", "rel_humidity", "tmin", "ndvi")))
cb_ca   <- c(setNames(lapply(MAIN, function(v) cbx(d[[paste0(v, "_clim")]])), paste0("cl_", MAIN)),
             setNames(lapply(MAIN, function(v) cbx(d[[paste0(v, "_anom")]])), paste0("an_", MAIN)))
ns0 <- function(v) paste0("splines::ns(", v, ", df = 2)")

jobs <- list(
  final   = list(f = paste("cases_total ~ year_f + regime * month_f +", paste(names(cb_main), collapse = " + "), RE), cb = cb_main),
  rh      = list(f = paste("cases_total ~ year_f + regime * month_f +", paste(names(cb_rh), collapse = " + "), RE), cb = cb_rh),
  concurrent = list(f = paste("cases_total ~ year_f + regime * month_f +", paste(sapply(MAIN, ns0), collapse = " + "), RE), cb = list()),
  noclim  = list(f = paste("cases_total ~ year_f + regime", RE), cb = list()),
  ca_full = list(f = paste("cases_total ~ year_f + regime +", paste(names(cb_ca), collapse = " + "), RE), cb = cb_ca),
  ca_clim = list(f = paste("cases_total ~ year_f + regime +", paste(grep("^cl_", names(cb_ca), value = TRUE), collapse = " + "), RE), cb = cb_ca),
  ca_anom = list(f = paste("cases_total ~ year_f + regime +", paste(grep("^an_", names(cb_ca), value = TRUE), collapse = " + "), RE), cb = cb_ca))
fits <- mclapply(names(jobs), function(n) fit(jobs[[n]]$f, attach_cb(jobs[[n]]$cb)), mc.cores = 4, mc.preschedule = FALSE)
names(fits) <- names(jobs)
saveRDS(fits, "analysis/output/exposure_response_fits.rds")
ll <- sapply(fits, function(m) -2 * as.numeric(logLik(m))); k <- sapply(fits, function(m) attr(logLik(m), "df"))
write_csv(tibble(model = names(ll), minus2LL = ll, parameters = k, AIC = sapply(fits, AIC),
                 converged = sapply(fits, function(m) m$fit$convergence == 0 && isTRUE(m$sdr$pdHess))),
          "analysis/output/exposure_response_models.csv")
cat("rows", sum(rows), "| cases", sum(d$cases_total[rows]), "| months", format(min(d$date[rows])), "to", format(max(d$date[rows])), "\n")
print(tibble(model = names(ll), minus2LL = round(ll, 1), parameters = k))

# ---- 3.5: lag-specific and cumulative RRs from the final model -------------------------------------------------
cp <- function(m, cb, name, at, cen) {
  i <- grep(paste0("^", name), names(fixef(m)$cond))
  crosspred(cb, coef = fixef(m)$cond[i], vcov = vcov(m)$cond[i, i], model.link = "log", at = at, cen = cen, bylag = 1)
}
pct <- function(v) quantile(d[[v]][rows], c(0.01, 0.10, 0.50, 0.90, 0.99))
summ <- list(); lagc <- list(); curve <- list()
for (v in MAIN) {
  q <- pct(v); m <- fits$final; cb <- cb_main[[paste0("cb_", v)]]
  p <- cp(m, cb, paste0("cb_", v), at = q[c("90%", "99%")], cen = q[["50%"]])
  for (j in 1:2) {
    lo <- p$matRRlow[j, ]; hi <- p$matRRhigh[j, ]; rr <- p$matRRfit[j, ]
    sig <- which(lo > 1 | hi < 1) - 1
    summ[[length(summ) + 1]] <- tibble(variable = v, percentile = c("90th", "99th")[j], value = q[[c("90%", "99%")[j]]],
      reference = q[["50%"]], cumRR = p$allRRfit[j], cum_lo = p$allRRlow[j], cum_hi = p$allRRhigh[j],
      peak_lag = which.max(abs(log(rr))) - 1, peak_RR = rr[which.max(abs(log(rr)))],
      lags_ci_excl_1 = if (length(sig)) paste(sig, collapse = ",") else "none")
    lagc[[length(lagc) + 1]] <- tibble(variable = v, percentile = c("90th", "99th")[j], lag = 0:L, RR = rr, lo = lo, hi = hi)
  }
  grid <- seq(q[["1%"]], q[["99%"]], length.out = 60)
  pc <- cp(m, cb, paste0("cb_", v), at = grid, cen = q[["50%"]])
  curve[[v]] <- tibble(variable = v, x = grid, RR = pc$allRRfit, lo = pc$allRRlow, hi = pc$allRRhigh)
}
# relative humidity from the alternative model (replacing maximum temperature)
q <- pct("rel_humidity"); p <- cp(fits$rh, cb_rh$cb_rel_humidity, "cb_rel_humidity", at = q[c("90%", "99%")], cen = q[["50%"]])
for (j in 1:2) { lo <- p$matRRlow[j, ]; hi <- p$matRRhigh[j, ]; rr <- p$matRRfit[j, ]; sig <- which(lo > 1 | hi < 1) - 1
  summ[[length(summ) + 1]] <- tibble(variable = "rel_humidity (alternative model)", percentile = c("90th", "99th")[j],
    value = q[[c("90%", "99%")[j]]], reference = q[["50%"]], cumRR = p$allRRfit[j], cum_lo = p$allRRlow[j], cum_hi = p$allRRhigh[j],
    peak_lag = which.max(abs(log(rr))) - 1, peak_RR = rr[which.max(abs(log(rr)))],
    lags_ci_excl_1 = if (length(sig)) paste(sig, collapse = ",") else "none") }
summ <- bind_rows(summ); print(summ, width = 200)
write_csv(summ, "analysis/output/rr_summary.csv"); write_csv(bind_rows(lagc), "analysis/output/rr_lag_curves.csv")
write_csv(bind_rows(curve), "analysis/output/rr_cumulative_curves.csv")

# variance inflation factors of the exposures (raw and anomalies), from their correlation matrix
vif <- function(vs) { r <- cor(as.data.frame(d[rows, vs]), use = "complete.obs"); setNames(diag(solve(r)), vs) }
vt <- bind_rows(tibble(set = "main (raw)", variable = MAIN, VIF = vif(MAIN)),
                tibble(set = "all five (raw)", variable = c(MAIN, "rel_humidity"), VIF = vif(c(MAIN, "rel_humidity"))),
                tibble(set = "all five (anomalies)", variable = paste0(c(MAIN, "rel_humidity"), "_anom"),
                       VIF = vif(paste0(c(MAIN, "rel_humidity"), "_anom"))))
print(vt, n = 30); write_csv(vt, "analysis/output/vif.csv")

# concurrent-only model: same-month climate, RR at the 90th percentile versus the median
conc <- bind_rows(lapply(MAIN, function(v) {
  q <- pct(v); nd <- d[rows, ][1:2, ]; nd[[v]] <- c(q[["50%"]], q[["90%"]])
  X <- splines::ns(d[[v]][rows], df = 2); b <- predict(X, c(q[["50%"]], q[["90%"]]))
  i <- grep(paste0("ns\\(", v), names(fixef(fits$concurrent)$cond))
  est <- drop((b[2, ] - b[1, ]) %*% fixef(fits$concurrent)$cond[i])
  se <- sqrt(drop(t(b[2, ] - b[1, ]) %*% vcov(fits$concurrent)$cond[i, i] %*% (b[2, ] - b[1, ])))
  tibble(variable = v, RR = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se))
}))
print(conc); write_csv(conc, "analysis/output/concurrent_only.csv")

# ---- 3.6: climatology versus anomaly -----------------------------------------------------------------------------
dc <- tibble(contrast = c("all climate terms (no climate vs climatology + anomaly)", "climatology given anomaly",
                          "anomaly given climatology"),
             chisq = c(ll[["noclim"]] - ll[["ca_full"]], ll[["ca_anom"]] - ll[["ca_full"]], ll[["ca_clim"]] - ll[["ca_full"]]),
             df = c(k[["ca_full"]] - k[["noclim"]], k[["ca_full"]] - k[["ca_anom"]], k[["ca_full"]] - k[["ca_clim"]])) |>
  mutate(p = pchisq(chisq, df, lower.tail = FALSE), share_of_total = chisq / chisq[1])
print(dc); write_csv(dc, "analysis/output/clim_anom_decomposition.csv")
an <- list()
for (v in MAIN) {
  p <- cp(fits$ca_full, cb_ca[[paste0("an_", v)]], paste0("an_", v), at = c(1, 2), cen = 0)
  for (j in 1:2) an[[length(an) + 1]] <- tibble(variable = v, anomaly_sd = c(1, 2)[j], lag = 0:L, RR = p$matRRfit[j, ],
    lo = p$matRRlow[j, ], hi = p$matRRhigh[j, ], cumRR = p$allRRfit[j], cum_lo = p$allRRlow[j], cum_hi = p$allRRhigh[j])
}
an <- bind_rows(an); print(an |> filter(anomaly_sd == 1), n = 50); write_csv(an, "analysis/output/anomaly_lag_curves.csv")
cat("anomaly correlation RH-Tmax:", round(cor(d$rel_humidity_anom[rows], d$tmax_anom[rows]), 2),
    " raw:", round(cor(d$rel_humidity[rows], d$tmax[rows]), 2), "\n")
cat("done\n")
