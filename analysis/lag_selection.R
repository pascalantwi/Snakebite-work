# Lag selection (Sections 2.4.4 and 3.4): pre-specified grid of maximum lag L (3, 6, 9, 12) and degrees of freedom of the
# exposure and lag splines (2, 3, 4 each), compared by AIC and leave-one-year-out cross-validation (log score, CRPS);
# penalized DLNM with L = 12 as a check on the lag shape; falsification test with future climate (leads of 1 and 2 months).
# Main exposures: rainfall, maximum and minimum temperature and NDVI (Section 2.4.3). Base model: year effects,
# calendar month by regime, region and district random intercepts, log(population) offset, negative binomial.
# All candidates use the same rows: months with a complete 12-month lag history (January 2021 - December 2025).
# Each candidate is saved when finished, so an interrupted run resumes. Run from the repository root:
#   Rscript analysis/lag_selection.R        (about 1.5 hours on 4 cores)
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(dlnm); library(glmmTMB)
  library(parallel); library(mgcv) })
source("analysis/primary_common.R")
MAIN <- c("rainfall", "tmax", "tmin", "ndvi")
CK <- "analysis/output/lag_grid_progress"; dir.create(CK, showWarnings = FALSE, recursive = TRUE)

d <- load_panel()
cb_spec <- function(L, dfv, dfl, clim = d) {
  arglag <- if (dfl > 2) list(fun = "ns", knots = logknots(L, nk = dfl - 2)) else list(fun = "ns", df = 2)
  setNames(lapply(MAIN, function(v) crossbasis(clim[[v]], lag = L, group = d$district,
                                               argvar = list(fun = "ns", df = dfv), arglag = arglag)), paste0("cb_", MAIN))
}
rows <- d$include_main == 1 & d$t > 12
BASE <- "cases_total ~ year_f + regime * month_f"
RHS_RE <- "+ offset(log(population)) + (1 | region) + (1 | region:district)"
form_cb <- as.formula(paste(BASE, "+", paste(paste0("cb_", MAIN), collapse = " + "), RHS_RE))
fit_tmb <- function(f, dat) glmmTMB(f, data = dat, family = nbinom2, control = glmmTMBControl(profile = TRUE))

crps_nb <- function(y, mu, size) {
  K <- max(qnbinom(0.99999, size = size, mu = max(mu)), max(y)); k <- 0:K
  vapply(seq_along(y), function(i) { F <- pnbinom(k, size = size, mu = mu[i]); sum((F - (y[i] <= k))^2) }, 0)
}
cv_scores <- function(f, dat) {
  bind_rows(lapply(sort(unique(dat$year)), function(y) {
    tr <- dat[dat$year != y, ] |> mutate(year_f = droplevels(year_f)); te <- dat[dat$year == y, ]
    m <- fit_tmb(f, tr)
    eta <- sapply(levels(tr$year_f), function(Y) { nd <- te; nd$year_f <- factor(Y, levels = levels(tr$year_f))
      log(predict(m, newdata = nd, type = "response")) })
    mu <- exp(rowMeans(eta)); s <- sigma(m)
    tibble(year = y, n = nrow(te), logS = mean(-dnbinom(te$cases_total, size = s, mu = mu, log = TRUE)),
           CRPS = mean(crps_nb(te$cases_total, mu, s)))
  }))
}

grid <- expand.grid(L = c(3, 6, 9, 12), dfv = 2:4, dfl = 2:4)
run_one <- function(i) {
  g <- grid[i, ]; out <- file.path(CK, sprintf("L%02d_v%d_l%d.csv", g$L, g$dfv, g$dfl))
  if (file.exists(out)) return(invisible(NULL))
  dat <- with_cb(d, cb_spec(g$L, g$dfv, g$dfl), rows)
  m <- fit_tmb(form_cb, dat); cv <- cv_scores(form_cb, dat)
  res <- tibble(L = g$L, df_var = g$dfv, df_lag = g$dfl, n = nrow(dat), cb_parameters = g$dfv * g$dfl * length(MAIN),
                minus2LL = -2 * as.numeric(logLik(m)), AIC = AIC(m), converged = m$fit$convergence == 0 && isTRUE(m$sdr$pdHess),
                logS = weighted.mean(cv$logS, cv$n), CRPS = weighted.mean(cv$CRPS, cv$n),
                logS_by_year = paste(round(cv$logS, 5), collapse = ";"), CRPS_by_year = paste(round(cv$CRPS, 5), collapse = ";"))
  write_csv(res, out); cat("grid", i, "done\n")
}
invisible(mclapply(seq_len(nrow(grid)), run_one, mc.cores = 4, mc.preschedule = FALSE))
tab <- bind_rows(lapply(list.files(CK, full.names = TRUE), read_csv, show_col_types = FALSE)) |>
  arrange(L, df_var, df_lag) |> mutate(dAIC = AIC - min(AIC), dlogS = logS - min(logS), dCRPS = CRPS - min(CRPS))
stopifnot(nrow(tab) == nrow(grid))

# selection rule: the most parsimonious candidate within 2 AIC units of the best, or within one standard error of the
# best cross-validated log score (standard error of the year-to-year differences from the best candidate)
best_cv <- tab[which.min(tab$logS), ]
yr <- function(s) as.numeric(strsplit(s, ";")[[1]])
tab$se_vs_best <- sapply(tab$logS_by_year, function(s) sd(yr(s) - yr(best_cv$logS_by_year)) / sqrt(length(yr(s))))
tab <- tab |> mutate(within_AIC = dAIC <= 2, within_CV = dlogS <= se_vs_best)
pick <- function(x) x |> arrange(cb_parameters, L) |> slice(1)
sel_aic <- pick(filter(tab, within_AIC)); sel_cv <- pick(filter(tab, within_CV))
sel <- pick(bind_rows(sel_aic, sel_cv))
write_csv(tab, "analysis/output/lag_grid.csv")
write_csv(bind_rows(mutate(sel_aic, rule = "AIC"), mutate(sel_cv, rule = "CV"), mutate(sel, rule = "selected")),
          "analysis/output/lag_selected.csv")
print(tab |> select(L, df_var, df_lag, cb_parameters, dAIC, logS, CRPS, within_AIC, within_CV), n = 40)
cat("selected: L =", sel$L, " df_var =", sel$df_var, " df_lag =", sel$df_lag, "\n")

# ---- falsification: add future climate (leads of 1 and 2 months) to the selected model -----------------------------
lead_k <- function(x, k) ave(x, d$district, FUN = function(v) c(v[-(1:k)], rep(NA, k)))
for (v in MAIN) for (k in 1:2) d[[paste0(v, "_lead", k)]] <- as.numeric(scale(lead_k(d[[v]], k)))
leads <- paste0(rep(MAIN, each = 2), "_lead", 1:2)
rows_f <- rows & d$t <= max(d$t) - 2
datf <- with_cb(d, cb_spec(sel$L, sel$df_var, sel$df_lag), rows_f)
m0 <- fit_tmb(form_cb, datf)
m1 <- fit_tmb(update(form_cb, as.formula(paste(". ~ . +", paste(leads, collapse = " + ")))), datf)
lr <- -2 * (as.numeric(logLik(m0)) - as.numeric(logLik(m1)))
fal <- tibble(term = leads, estimate = fixef(m1)$cond[leads], se = sqrt(diag(vcov(m1)$cond))[leads]) |>
  mutate(RR_perSD = exp(estimate), lo = exp(estimate - 1.96 * se), hi = exp(estimate + 1.96 * se),
         p = 2 * pnorm(-abs(estimate / se)))
print(fal); cat("falsification LRT: chisq =", round(lr, 2), "df =", length(leads), "p =", signif(pchisq(lr, length(leads), lower.tail = FALSE), 3), "\n")
write_csv(fal, "analysis/output/falsification_leads.csv")
write_csv(tibble(chisq = lr, df = length(leads), p = pchisq(lr, length(leads), lower.tail = FALSE), n = nrow(datf)),
          "analysis/output/falsification_lrt.csv")

# ---- penalized DLNM, L = 12 (Gasparrini et al. 2017), fitted with mgcv; compared with the selected model -------------
cbp <- setNames(lapply(MAIN, function(v) crossbasis(d[[v]], lag = 12, group = d$district,
                argvar = list(fun = "ps", df = 5), arglag = list(fun = "ps", df = 8))), paste0("pcb_", MAIN))
datp <- d[rows, ]; for (n in names(cbp)) datp[[n]] <- unclass(cbp[[n]])[rows, , drop = FALSE]
pen <- lapply(cbp, cbPen)
gp <- gam(as.formula(paste(BASE, "+", paste(names(cbp), collapse = " + "),
                           "+ s(region, bs = 're') + s(district, bs = 're') + offset(log(population))")),
          data = datp, family = nb(), paraPen = pen, method = "REML")
datsel <- with_cb(d, cb_spec(sel$L, sel$df_var, sel$df_lag), rows); msel <- fit_tmb(form_cb, datsel)
cmp <- bind_rows(lapply(MAIN, function(v) {
  x90 <- quantile(d[[v]][rows], 0.9); x50 <- median(d[[v]][rows])
  ip <- grep(paste0("^pcb_", v), names(coef(gp)))
  pp <- crosspred(cbp[[paste0("pcb_", v)]], coef = coef(gp)[ip], vcov = vcov(gp)[ip, ip], model.link = "log",
                  at = x90, cen = x50, bylag = 1)
  cbs <- cb_spec(sel$L, sel$df_var, sel$df_lag)[[paste0("cb_", v)]]
  is <- grep(paste0("^cb_", v), names(fixef(msel)$cond))
  ps <- crosspred(cbs, coef = fixef(msel)$cond[is], vcov = vcov(msel)$cond[is, is], model.link = "log",
                  at = x90, cen = x50, bylag = 1)
  bind_rows(tibble(variable = v, model = "penalized", lag = 0:12, RR = pp$matRRfit[1, ], lo = pp$matRRlow[1, ], hi = pp$matRRhigh[1, ]),
            tibble(variable = v, model = "selected", lag = 0:sel$L, RR = ps$matRRfit[1, ], lo = ps$matRRlow[1, ], hi = ps$matRRhigh[1, ]))
}))
edf <- sapply(names(cbp), function(n) sum(gp$edf[grep(paste0("^", n), names(coef(gp)))]))
print(cmp, n = 120); print(round(edf, 2))
write_csv(cmp, "analysis/output/lag_curves_selected_vs_penalized.csv")
write_csv(tibble(term = names(edf), edf = edf), "analysis/output/penalized_edf.csv")
cat("done\n")
