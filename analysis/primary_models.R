# Primary analysis, part 1 (Section 2.4.5): models M0-M3, temporal placebo and leave-one-year-out cross-validation.
# Negative-binomial GLMMs (glmmTMB) with district-within-region random intercepts and log(population) offset.
# Run from the repository root:  Rscript analysis/primary_models.R      (about 15 minutes on 4 cores)
source("analysis/primary_common.R")
library(parallel)
set.seed(20251231)
dir.create("analysis/output", showWarnings = FALSE)

d <- load_panel(); cb <- make_cb(d); rows <- analysis_rows(d, cb); dd <- with_cb(d, cb, rows)
cat("analysis rows", nrow(dd), "| cases", sum(dd$cases_total), "| districts", n_distinct(dd$district),
    "| months", format(min(dd$date)), "to", format(max(dd$date)), "\n")

# ---- M0-M3 ------------------------------------------------------------------------------------------------
fits <- mclapply(names(FORM), fit_model, dd = dd, mc.cores = 4); names(fits) <- names(FORM)
saveRDS(fits, "analysis/output/primary_fits.rds")
D <- sapply(fits, function(f) -2 * as.numeric(logLik(f)))
tab <- tibble(model = names(FORM),
              description = c("No seasonal terms", "Calendar month by regime", "Own lagged climate", "Month terms and own lagged climate"),
              parameters = sapply(fits, function(f) attr(logLik(f), "df")),
              minus2LL = D, AIC = sapply(fits, AIC),
              theta = sapply(fits, sigma),
              sd_region = sapply(fits, function(f) attr(VarCorr(f)$cond[["region"]], "stddev")),
              sd_district = sapply(fits, function(f) attr(VarCorr(f)$cond[["region:district"]], "stddev")),
              converged = sapply(fits, function(f) f$fit$convergence == 0 && isTRUE(f$sdr$pdHess)))
S_clim <- (D[["M0"]] - D[["M2"]]) / (D[["M0"]] - D[["M1"]])
S_res  <- (D[["M2"]] - D[["M3"]]) / (D[["M0"]] - D[["M1"]])
lrt <- function(a, b) { x <- D[[a]] - D[[b]]; k <- tab$parameters[tab$model == b] - tab$parameters[tab$model == a]
  c(chisq = x, df = k, p = pchisq(x, k, lower.tail = FALSE)) }
tests <- rbind(`M0 vs M1 (season)` = lrt("M0", "M1"), `M0 vs M2 (climate)` = lrt("M0", "M2"),
               `M2 vs M3 (season beyond climate)` = lrt("M2", "M3"), `M1 vs M3 (climate beyond season)` = lrt("M1", "M3"))
print(tab, width = 200); cat("S_clim =", round(S_clim, 3), " S_res =", round(S_res, 3), "\n"); print(tests)
write_csv(tab, "analysis/output/primary_models.csv")
write_csv(tibble(test = rownames(tests), as_tibble(tests)), "analysis/output/primary_lrt.csv")
write_csv(tibble(S_clim = S_clim, S_res = S_res), "analysis/output/primary_shares.csv")

# ---- temporal placebo: each district's own climate shifted by k whole years (k = 1..5, circular) ----------
shift_years <- function(k) {
  clim <- d[, VARS]
  idx <- unlist(lapply(split(seq_len(nrow(d)), d$district), function(i) i[((seq_along(i) - 1 + 12 * k) %% length(i)) + 1]))
  ord <- unlist(split(seq_len(nrow(d)), d$district))
  clim[ord, ] <- d[idx, VARS]
  with_cb(d, make_cb(d, clim), rows)
}
tp <- mclapply(1:5, function(k) { f <- fit_model("M2", shift_years(k)); c(k = k, minus2LL = -2 * as.numeric(logLik(f))) }, mc.cores = 4)
tp <- as_tibble(do.call(rbind, tp)) |> mutate(diff_vs_own = minus2LL - D[["M2"]])
print(tp); write_csv(tp, "analysis/output/temporal_placebo.csv")

# ---- leave-one-year-out cross-validation (log score and CRPS) ---------------------------------------------
crps_nb <- function(y, mu, size) {
  K <- max(qnbinom(0.99999, size = size, mu = max(mu)), max(y)) ; k <- 0:K
  vapply(seq_along(y), function(i) { F <- pnbinom(k, size = size, mu = mu[i]); sum((F - (y[i] <= k))^2) }, 0)
}
cv_one <- function(job) {
  m <- job$model; y <- job$year
  tr <- dd[dd$year != y, ] |> mutate(year_f = droplevels(year_f)); te <- dd[dd$year == y, ]
  f <- fit_model(m, tr)
  # held-out year: average the linear predictor over the training-year effects
  eta <- sapply(levels(tr$year_f), function(Y) { nd <- te; nd$year_f <- factor(Y, levels = levels(tr$year_f))
    log(predict(f, newdata = nd, type = "response", allow.new.levels = FALSE)) })
  mu <- exp(rowMeans(eta)); size <- sigma(f)
  tibble(model = m, year = y, n = nrow(te), logS = mean(-dnbinom(te$cases_total, size = size, mu = mu, log = TRUE)),
         CRPS = mean(crps_nb(te$cases_total, mu, size)))
}
jobs <- apply(expand.grid(model = names(FORM), year = sort(unique(dd$year)), stringsAsFactors = FALSE), 1, as.list)
jobs <- lapply(jobs, function(j) list(model = j$model, year = as.integer(j$year)))
cv <- bind_rows(mclapply(jobs, cv_one, mc.cores = 4))
cvs <- cv |> group_by(model) |> summarise(logS = weighted.mean(logS, n), CRPS = weighted.mean(CRPS, n),
                                          se_logS = sd(logS) / sqrt(n()), .groups = "drop")
print(cv); print(cvs)
write_csv(cv, "analysis/output/cv_by_year.csv"); write_csv(cvs, "analysis/output/cv_summary.csv")
cat("done\n")
