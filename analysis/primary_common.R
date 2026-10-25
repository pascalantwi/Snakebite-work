# Shared data preparation and model definitions for the primary analysis (Section 2.4.5).
suppressPackageStartupMessages({ library(readr); library(dplyr); library(dlnm); library(glmmTMB) })

L_MAX <- 6                                   # main maximum lag (Section 2.4.4)
VARS  <- c("rainfall", "rel_humidity", "tmax", "tmin", "ndvi")

load_panel <- function(path = "data/snakebite_unified_district_month.csv") {
  read_csv(path, show_col_types = FALSE) |>
    arrange(district, t) |>
    mutate(year_f = factor(year), month_f = factor(month), regime = factor(regime),
           region = factor(region), district = factor(district)) |>
    # two districts lack climate in 2024-2025, months that are excluded from the analysis; fill them with the
    # district's calendar-month mean so that shifted or swapped climate series never carry missing values
    group_by(district, month) |>
    mutate(across(all_of(VARS), ~ ifelse(is.na(.x), mean(.x, na.rm = TRUE), .x))) |>
    ungroup() |> arrange(district, t)
}

# cross-bases of the five climate variables, lags computed within district (data ordered by district, t)
make_cb <- function(d, clim = d[, VARS]) {
  setNames(lapply(VARS, function(v)
    crossbasis(clim[[v]], lag = L_MAX, group = d$district,
               argvar = list(fun = "ns", df = 3),
               arglag = list(fun = "ns", knots = logknots(L_MAX, nk = 1)))), paste0("cb_", VARS))
}

# analysis rows: recommended rows with a complete lag history (from month L_MAX + 1, July 2020)
analysis_rows <- function(d, cb) {
  ok <- d$include_main == 1 & d$t > L_MAX
  for (m in cb) ok <- ok & complete.cases(m)
  ok
}

FORM <- list(
  M0 = cases_total ~ year_f + regime,
  M1 = cases_total ~ year_f + regime * month_f,
  M2 = cases_total ~ year_f + regime + cb_rainfall + cb_rel_humidity + cb_tmax + cb_tmin + cb_ndvi,
  M3 = cases_total ~ year_f + regime * month_f + cb_rainfall + cb_rel_humidity + cb_tmax + cb_tmin + cb_ndvi)
RE <- "+ offset(log(population)) + (1 | region) + (1 | region:district)"

fit_model <- function(name, dd, start = NULL) {
  f <- as.formula(paste(deparse(FORM[[name]], width.cutoff = 500L), RE))
  glmmTMB(f, data = dd, family = nbinom2, start = start,
          control = glmmTMBControl(parallel = 1))
}

# attach cross-basis matrices to the data frame as matrix columns
with_cb <- function(d, cb, rows) {
  dd <- d[rows, ]
  for (n in names(cb)) dd[[n]] <- unclass(cb[[n]])[rows, , drop = FALSE]
  dd
}
