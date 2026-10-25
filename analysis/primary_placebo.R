# Primary analysis, part 2 (Section 2.4.5): spatial placebo-climate permutation test.
# Each district's climate series is replaced by that of a randomly chosen district from a different rainfall regime
# (calendar months aligned), the climate model is refitted, and its deviance is compared with that of the own-climate fit.
# Each full GLMM fit takes about a minute, so the 1,000 permutations use a negative-binomial model with the same
# fixed effects and cross-bases, district intercepts as fixed effects and the dispersion fixed at the GLMM estimate of M2;
# the own-climate statistic is computed with the same model. 20 permutations are also refitted with the full GLMM
# to check that the two statistics agree.
# Run after analysis/primary_models.R:  Rscript analysis/primary_placebo.R      (about 50 minutes on 4 cores)
source("analysis/primary_common.R")
suppressPackageStartupMessages({ library(MASS, warn.conflicts = FALSE); library(parallel) })
M_PERM <- 1000; M_CHECK <- 20
SEED <- 20251231                      # permutation r uses seed SEED + r, so results do not depend on the run order
CK <- "analysis/output/placebo_progress"; dir.create(CK, showWarnings = FALSE)

d <- load_panel(); cb <- make_cb(d); rows <- analysis_rows(d, cb); dd <- with_cb(d, cb, rows)
fits <- readRDS("analysis/output/primary_fits.rds")
theta <- sigma(fits$M2)
FE <- cases_total ~ year_f + district + cb_rainfall + cb_rel_humidity + cb_tmax + cb_tmin + cb_ndvi + offset(log(population))
dev_fe <- function(dat) -2 * as.numeric(logLik(glm(FE, data = dat, family = negative.binomial(theta))))

districts <- levels(d$district)
reg_of <- tapply(as.character(d$regime), d$district, `[`, 1)[districts]
pos <- split(seq_len(nrow(d)), d$district)[districts]             # rows of each district, in time order
placebo_data <- function() {
  donor <- vapply(districts, function(i) sample(districts[reg_of != reg_of[[i]]], 1), "")
  clim <- d[, VARS]
  for (i in districts) clim[pos[[i]], ] <- d[pos[[donor[[i]]]], VARS]
  with_cb(d, make_cb(d, clim), rows)
}

own_fe <- dev_fe(dd)
# permutations in batches of 40, each batch saved so that an interrupted run resumes where it stopped
for (b0 in seq(1, M_PERM, by = 40)) {
  f <- file.path(CK, sprintf("perm_%04d.csv", b0)); if (file.exists(f)) next
  r <- b0:min(b0 + 39, M_PERM)
  v <- unlist(mclapply(r, function(k) { set.seed(SEED + k); dev_fe(placebo_data()) }, mc.cores = 4))
  write_csv(tibble(replicate = r, minus2LL = v), f); cat("permutations done:", max(r), "\n")
}
perm <- bind_rows(lapply(list.files(CK, "^perm_", full.names = TRUE), read_csv, show_col_types = FALSE)) |> arrange(replicate)
stopifnot(nrow(perm) == M_PERM); perm <- perm$minus2LL
b <- sum(perm <= own_fe)
res <- tibble(statistic = "-2 log-likelihood, fixed-district NB model", own = own_fe, m = M_PERM, b = b,
              p = (b + 1) / (M_PERM + 1), placebo_min = min(perm), placebo_median = median(perm), placebo_max = max(perm))
print(res, width = 200)
write_csv(res, "analysis/output/placebo_test.csv")
write_csv(tibble(replicate = seq_along(perm), minus2LL = perm, diff_vs_own = perm - own_fe), "analysis/output/placebo_deviances.csv")

# check against the full GLMM on a subset of permutations; keep the fits for Fig 5
chk <- mclapply(seq_len(M_CHECK), function(r) {
  set.seed(SEED + M_PERM + r); pd <- placebo_data(); f <- fit_model("M2", pd)
  list(fe = dev_fe(pd), glmm = -2 * as.numeric(logLik(f)), fit = f)
}, mc.cores = 4)
cc <- tibble(fe = sapply(chk, `[[`, "fe"), glmm = sapply(chk, `[[`, "glmm")) |>
  mutate(fe_diff = fe - own_fe, glmm_diff = glmm - (-2 * as.numeric(logLik(fits$M2))))
print(cc); cat("correlation of FE and GLMM placebo statistics:", round(cor(cc$fe, cc$glmm), 3),
                "| GLMM placebo fits worse than own climate:", sum(cc$glmm_diff > 0), "of", nrow(cc), "\n")
write_csv(cc, "analysis/output/placebo_glmm_check.csv")
med <- which.min(abs(cc$glmm - median(cc$glmm)))
saveRDS(chk[[med]]$fit, "analysis/output/placebo_median_fit.rds")
cat("done\n")
