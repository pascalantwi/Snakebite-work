# Adjusted associations of all covariates with snakebite incidence (Section 3.5, Table 5).
# Data: district-month-sex rows (include_main == 1, October 2020 - December 2025), offset log(sex-specific population).
# Model: negative-binomial GLMM with sex, district poverty (per 10 percentage points of poverty incidence), rainfall
# regime (calendar-month effects by regime with sum-to-zero month contrasts, so that the regime effect is the average
# over months), year effects (reference 2021), cross-bases of rainfall, maximum and minimum temperature and NDVI
# (lag 9, natural splines with 2 df), region and district random intercepts.
# Also: likelihood-ratio tests of sex x climate and poverty x climate interactions, and the cumulative rainfall and
# maximum-temperature rate ratios at low and high poverty.
# Run from the repository root:  Rscript analysis/covariate_effects.R      (about 15 minutes on 4 cores)
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(dlnm); library(glmmTMB); library(parallel) })
source("analysis/primary_common.R")
L <- 9; MAIN <- c("rainfall", "tmax", "tmin", "ndvi")
d <- load_panel()                                   # district-month panel, for the cross-bases
cbs <- setNames(lapply(MAIN, function(v) crossbasis(d[[v]], lag = L, group = d$district,
  argvar = list(fun = "ns", df = 2), arglag = list(fun = "ns", df = 2))), paste0("cb_", MAIN))
pov <- if (any(!is.na(d$poverty_H))) "poverty_H" else "H_male_head"
s <- read_csv("data/snakebite_unified_district_month_sex.csv", show_col_types = FALSE) |>
  mutate(year_f = relevel(factor(year), ref = "2021"), month_f = factor(month), regime = relevel(factor(regime), ref = "bimodal"),
         region = factor(region), district = factor(district), sex = relevel(factor(sex), ref = "female"))
contrasts(s$month_f) <- contr.sum(12)
s$pov10 <- s[[pov]] / 10
key <- paste(d$district, d$t); idx <- match(paste(s$district, s$t), key)
for (n in names(cbs)) s[[n]] <- unclass(cbs[[n]])[idx, , drop = FALSE]
rows <- s$include_main == 1 & s$t > L
s <- s[rows, ]
s$pov_c <- (s$pov10 - mean(s$pov10))
male <- as.numeric(s$sex == "male")
for (v in MAIN) { s[[paste0("cbm_", v)]] <- s[[paste0("cb_", v)]] * male; s[[paste0("cbp_", v)]] <- s[[paste0("cb_", v)]] * s$pov_c }
CB <- paste(names(cbs), collapse = " + ")
RE <- "+ offset(log(population_sex)) + (1 | region) + (1 | region:district)"
F0 <- paste("cases ~ sex + pov10 + regime * month_f + year_f +", CB, RE)
F1 <- paste(F0, "+", paste0("cbm_", MAIN, collapse = " + "))
F2 <- paste(F0, "+", paste0("cbp_", MAIN, collapse = " + "))
fits <- mclapply(list(main = F0, sex_int = F1, pov_int = F2), function(f)
  glmmTMB(as.formula(f), data = s, family = nbinom2, control = glmmTMBControl(profile = TRUE)), mc.cores = 3)
m <- fits$main
b <- fixef(m)$cond; V <- vcov(m)$cond; se <- sqrt(diag(V))
irr <- function(term, label, group) tibble(group = group, covariate = label, IRR = exp(b[[term]]),
  lo = exp(b[[term]] - 1.96 * se[[term]]), hi = exp(b[[term]] + 1.96 * se[[term]]), p = 2 * pnorm(-abs(b[[term]] / se[[term]])))
tab <- bind_rows(
  irr("sexmale", "Male (reference: female)", "Sex"),
  irr("pov10", paste0("Per 10 percentage points of poverty incidence (", pov, ")"), "District poverty"),
  irr("regimeunimodal", "Unimodal (reference: bimodal)", "Rainfall regime"),
  irr("regimetransition", "Transition (reference: bimodal)", "Rainfall regime"),
  bind_rows(lapply(c("2020", "2022", "2023", "2024", "2025"), function(y) irr(paste0("year_f", y), paste0(y, " (reference: 2021)"), "Year"))))
rows_d <- d$include_main == 1 & d$t > L
clim <- bind_rows(lapply(MAIN, function(v) {
  i <- grep(paste0("^cb_", v), names(b)); q <- quantile(d[[v]][rows_d], c(0.25, 0.5, 0.75, 0.9))
  p1 <- crosspred(cbs[[paste0("cb_", v)]], coef = b[i], vcov = V[i, i], model.link = "log", at = q[["75%"]], cen = q[["25%"]])
  p2 <- crosspred(cbs[[paste0("cb_", v)]], coef = b[i], vcov = V[i, i], model.link = "log", at = q[["90%"]], cen = q[["50%"]])
  bind_rows(tibble(group = "Climate (cumulative, lags 0-9)", covariate = paste0(v, ": 75th vs 25th percentile (",
                   signif(q[["75%"]], 3), " vs ", signif(q[["25%"]], 3), ")"), IRR = p1$allRRfit, lo = p1$allRRlow, hi = p1$allRRhigh, p = NA),
            tibble(group = "Climate (cumulative, lags 0-9)", covariate = paste0(v, ": 90th percentile vs median (",
                   signif(q[["90%"]], 3), " vs ", signif(q[["50%"]], 3), ")"), IRR = p2$allRRfit, lo = p2$allRRlow, hi = p2$allRRhigh, p = NA))
}))
tab <- bind_rows(tab, clim)
re <- tibble(group = "Variation", covariate = c("SD of region intercepts", "SD of district intercepts", "Negative-binomial dispersion (theta)"),
             IRR = c(attr(VarCorr(m)$cond[["region"]], "stddev"), attr(VarCorr(m)$cond[["region:district"]], "stddev"), sigma(m)))
tab <- bind_rows(tab, re) |> mutate(n = nrow(s), poverty_measure = pov)
print(tab, n = 50, width = 200); write_csv(tab, "analysis/output/covariate_effects.csv")

lr <- function(a, bb) { x <- -2 * (as.numeric(logLik(fits[[a]])) - as.numeric(logLik(fits[[bb]])))
  k <- attr(logLik(fits[[bb]]), "df") - attr(logLik(fits[[a]]), "df"); tibble(test = bb, chisq = x, df = k, p = pchisq(x, k, lower.tail = FALSE)) }
tests <- bind_rows(lr("main", "sex_int"), lr("main", "pov_int")); print(tests); write_csv(tests, "analysis/output/covariate_interactions.csv")
# climate effects at low (25th percentile) and high (75th percentile) district poverty, from the poverty-interaction model
mp <- fits$pov_int; bp <- fixef(mp)$cond; Vp <- vcov(mp)$cond
pq <- quantile(s$pov_c[!duplicated(s$district)], c(0.25, 0.75))
eff <- bind_rows(lapply(MAIN, function(v) bind_rows(lapply(names(pq), function(nm) {
  i <- grep(paste0("^cb_", v), names(bp)); j <- grep(paste0("^cbp_", v), names(bp))
  bb <- bp[i] + pq[[nm]] * bp[j]
  A <- cbind(diag(length(i)), pq[[nm]] * diag(length(i))); VV <- A %*% Vp[c(i, j), c(i, j)] %*% t(A)
  q <- quantile(d[[v]][rows_d], c(0.5, 0.9))
  p <- crosspred(cbs[[paste0("cb_", v)]], coef = bb, vcov = VV, model.link = "log", at = q[["90%"]], cen = q[["50%"]])
  tibble(variable = v, poverty = c(`25%` = "low (25th percentile)", `75%` = "high (75th percentile)")[[nm]],
         cumRR90 = p$allRRfit, lo = p$allRRlow, hi = p$allRRhigh)
}))))
print(eff); write_csv(eff, "analysis/output/climate_by_poverty.csv")
cat("rows", nrow(s), "| poverty measure", pov, "\ndone\n")
