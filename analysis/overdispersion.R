# Formal test of overdispersion (Sections 2.4.2 and 3.1): the selected model (Section 3.4) fitted as a Poisson and as a
# negative-binomial (NB2) mixed model to the same district-months. The likelihood-ratio statistic for the dispersion
# parameter lies on the boundary of the parameter space (Poisson as theta -> infinity), so its p-value is half the
# chi-square(1) tail probability. Also the Pearson dispersion statistic, sum of squared Pearson residuals / residual df.
# Run from the repository root:  Rscript analysis/overdispersion.R
suppressPackageStartupMessages({ library(readr); library(dplyr); library(dlnm); library(glmmTMB) })
source("analysis/primary_common.R")
MAIN <- c("rainfall", "tmax", "tmin", "ndvi")
d <- load_panel()
cb <- setNames(lapply(MAIN, function(v) crossbasis(d[[v]], lag = 9, group = d$district, argvar = list(fun = "ns", df = 2),
                                                   arglag = list(fun = "ns", df = 2))), paste0("cb_", MAIN))
rows <- d$include_main == 1 & d$t > 9
dd <- d[rows, ]; for (n in names(cb)) dd[[n]] <- unclass(cb[[n]])[rows, , drop = FALSE]
f <- as.formula(paste("cases_total ~ year_f + pov_z + regime * month_f +", paste(names(cb), collapse = " + "),
                      "+ offset(log(population)) + (1 | region) + (1 | region:district)"))
fits <- list(Poisson = glmmTMB(f, data = dd, family = poisson),
             NB2 = glmmTMB(f, data = dd, family = nbinom2, control = glmmTMBControl(profile = TRUE)))
pear <- sapply(fits, function(m) sum(residuals(m, type = "pearson")^2) / df.residual(m))
ll <- sapply(fits, function(m) as.numeric(logLik(m)))
lr <- 2 * (ll[["NB2"]] - ll[["Poisson"]])
out <- tibble(model = names(fits), n = nrow(dd), logLik = ll, AIC = sapply(fits, AIC), pearson_dispersion = pear,
              theta = c(NA, sigma(fits$NB2)), LR = c(NA, lr), p_boundary = c(NA, 0.5 * pchisq(lr, 1, lower.tail = FALSE)))
print(out, width = 200); write_csv(out, "analysis/output/overdispersion_test.csv")
print(sapply(fits, function(m) c(convergence = m$fit$convergence, pdHess = m$sdr$pdHess)))
