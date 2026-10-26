# Section 3.4 (additional check): falsification test with finer seasonal control.
# The selected model (lag 9, 2/2 df) with calendar-month effects by region (instead of by rainfall regime) and a
# district random intercept; future climate (leads of 1 and 2 months, standardized) is then added and tested.
# Also reports the cumulative rate ratios at the 90th percentile under this seasonal control.
# Run from the repository root:  Rscript analysis/falsification_region.R
suppressPackageStartupMessages({ library(readr); library(dplyr); library(dlnm); library(glmmTMB); library(parallel) })
source("analysis/primary_common.R")
L <- 9; MAIN <- c("rainfall", "tmax", "tmin", "ndvi")
d <- load_panel()
cb <- setNames(lapply(MAIN, function(v) crossbasis(d[[v]], lag = L, group = d$district,
  argvar = list(fun = "ns", df = 2), arglag = list(fun = "ns", df = 2))), paste0("cb_", MAIN))
lead_k <- function(x, k) ave(x, d$district, FUN = function(v) c(v[-(1:k)], rep(NA, k)))
for (v in MAIN) for (k in 1:2) d[[paste0(v, "_lead", k)]] <- as.numeric(scale(lead_k(d[[v]], k)))
leads <- paste0(rep(MAIN, each = 2), "_lead", 1:2)
rows_f <- d$include_main == 1 & d$t > L & d$t <= max(d$t) - 2
dat <- d[rows_f, ]; for (n in names(cb)) dat[[n]] <- unclass(cb[[n]])[rows_f, , drop = FALSE]
f0 <- paste("cases_total ~ year_f + pov_z + region * month_f +", paste(names(cb), collapse = " + "),
            "+ offset(log(population)) + (1 | district)")
f1 <- paste(f0, "+", paste(leads, collapse = " + "))
fits <- mclapply(list(f0, f1), function(f) glmmTMB(as.formula(f), data = dat, family = nbinom2,
                 control = glmmTMBControl(profile = TRUE)), mc.cores = 2)
lr <- -2 * (as.numeric(logLik(fits[[1]])) - as.numeric(logLik(fits[[2]])))
m1 <- fits[[2]]
fal <- tibble(term = leads, estimate = fixef(m1)$cond[leads], se = sqrt(diag(vcov(m1)$cond))[leads]) |>
  mutate(RR_perSD = exp(estimate), lo = exp(estimate - 1.96 * se), hi = exp(estimate + 1.96 * se), p = 2 * pnorm(-abs(estimate / se)))
lrt <- tibble(seasonal_control = "calendar month by region", chisq = lr, df = length(leads),
              p = pchisq(lr, length(leads), lower.tail = FALSE), n = nrow(dat),
              converged = all(sapply(fits, function(m) m$fit$convergence == 0 && isTRUE(m$sdr$pdHess))))
print(fal); print(lrt)
write_csv(fal, "analysis/output/falsification_region_leads.csv"); write_csv(lrt, "analysis/output/falsification_region_lrt.csv")
m0 <- fits[[1]]; rows <- d$include_main == 1 & d$t > L
cum <- bind_rows(lapply(MAIN, function(v) {
  i <- grep(paste0("^cb_", v), names(fixef(m0)$cond))
  p <- crosspred(cb[[paste0("cb_", v)]], coef = fixef(m0)$cond[i], vcov = vcov(m0)$cond[i, i], model.link = "log",
                 at = quantile(d[[v]][rows], 0.9), cen = median(d[[v]][rows]))
  tibble(variable = v, cumRR90 = p$allRRfit, lo = p$allRRlow, hi = p$allRRhigh)
}))
print(cum); write_csv(cum, "analysis/output/falsification_region_cumRR.csv")
cat("done\n")
