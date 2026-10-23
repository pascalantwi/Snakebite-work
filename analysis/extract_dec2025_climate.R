# Extract the missing December 2025 climate covariates for every district and add them to the unified dataset.
#
#   Rainfall, relative humidity, mean/max/min temperature : NASA POWER monthly API (same source as data_snake.csv)
#   NDVI                                                   : MODIS MOD13A3 monthly 1 km NDVI via MODISTools
#
# Each district is queried at the point in data/district_points.csv (a point inside its boundary polygon;
# Guan, which has no polygon, uses the point of a district with an identical NASA POWER series).
# Before December 2025 is filled, the extracted January-November 2025 values are compared with the values
# already in the dataset, so you can see that the extraction reproduces the original series.
#
# Run from the repository root:  Rscript analysis/extract_dec2025_climate.R
# Needs internet access. Re-running resumes from the cache in data/cache/.

pkgs <- c("nasapower", "MODISTools", "dplyr", "tidyr", "readr", "purrr")
new <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(new)) install.packages(new)
suppressPackageStartupMessages({
  library(nasapower); library(MODISTools); library(dplyr); library(tidyr); library(readr); library(purrr)
})

pts <- read_csv("data/district_points.csv", show_col_types = FALSE)
dm  <- read_csv("data/snakebite_unified_district_month.csv", show_col_types = FALSE)
dir.create("data/cache", showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------------------------------------
# 1. NASA POWER: monthly PRECTOTCORR (mm/day), RH2M (%), T2M, T2M_MAX, T2M_MIN (deg C) for 2025
# ---------------------------------------------------------------------------------------------------------
power_one <- function(district, lon, lat) {
  f <- file.path("data/cache", paste0("power_", gsub("[^a-z0-9]", "_", district), ".rds"))
  if (file.exists(f)) return(readRDS(f))
  x <- get_power(community = "ag", lonlat = c(lon, lat), temporal_api = "monthly",
                 pars = c("PRECTOTCORR", "RH2M", "T2M", "T2M_MAX", "T2M_MIN"),
                 dates = c(2024, 2025))            # monthly API: years
  out <- x |>
    select(PARAMETER, YEAR, JAN:DEC) |>
    pivot_longer(JAN:DEC, names_to = "mon", values_to = "value") |>
    mutate(month = match(mon, toupper(month.abb)), district = district, value = ifelse(value <= -999, NA, value)) |>
    select(district, year = YEAR, month, PARAMETER, value) |>
    pivot_wider(names_from = PARAMETER, values_from = value)
  saveRDS(out, f)
  Sys.sleep(0.5)                                   # be polite to the API
  out
}
power <- pmap_dfr(select(pts, district, lon, lat), function(district, lon, lat)
  tryCatch(power_one(district, lon, lat), error = function(e) { message(district, ": ", conditionMessage(e)); NULL })) |>
  rename(rainfall = PRECTOTCORR, rel_humidity = RH2M, t2m = T2M, tmax = T2M_MAX, tmin = T2M_MIN) |>
  filter(year == 2025)

# ---------------------------------------------------------------------------------------------------------
# 2. MODIS MOD13A3 NDVI: mean of the 1 km pixels within 5 km of the district point, scaled by 0.0001
#    The original NDVI is a district mean, so a point-based value is calibrated to it below.
# ---------------------------------------------------------------------------------------------------------
ndvi_one <- function(district, lon, lat) {
  f <- file.path("data/cache", paste0("ndvi_", gsub("[^a-z0-9]", "_", district), ".rds"))
  if (file.exists(f)) return(readRDS(f))
  x <- mt_subset(product = "MOD13A3", band = "1_km_monthly_NDVI", lat = lat, lon = lon,
                 start = "2024-01-01", end = "2025-12-31", km_lr = 5, km_ab = 5,
                 site_name = district, progress = FALSE)
  out <- x |>
    mutate(value = ifelse(value <= -2000, NA, value * 0.0001), date = as.Date(calendar_date)) |>
    group_by(date) |> summarise(ndvi_point = mean(value, na.rm = TRUE), .groups = "drop") |>
    mutate(district = district, year = as.integer(format(date, "%Y")), month = as.integer(format(date, "%m"))) |>
    select(district, year, month, ndvi_point)
  saveRDS(out, f)
  out
}
ndvi <- pmap_dfr(select(pts, district, lon, lat), function(district, lon, lat)
  tryCatch(ndvi_one(district, lon, lat), error = function(e) { message(district, ": ", conditionMessage(e)); NULL }))

# calibrate point NDVI to the district-mean NDVI already in the data (2024 - Nov 2025), district by district
cal <- ndvi |>
  inner_join(select(dm, district, year, month, ndvi), by = c("district", "year", "month")) |>
  filter(!is.na(ndvi), !is.na(ndvi_point)) |>
  group_by(district) |>
  summarise(n = n(), r2 = summary(lm(ndvi ~ ndvi_point))$r.squared,
            a = coef(lm(ndvi ~ ndvi_point))[1], b = coef(lm(ndvi ~ ndvi_point))[2], .groups = "drop")
ndvi_dec <- ndvi |> filter(year == 2025, month == 12) |>
  left_join(cal, by = "district") |>
  mutate(ndvi = ifelse(!is.na(b) & r2 >= 0.5, a + b * ndvi_point, ndvi_point),
         ndvi_method = ifelse(!is.na(b) & r2 >= 0.5, "MOD13A3 point, calibrated to district mean", "MOD13A3 point, uncalibrated")) |>
  select(district, year, month, ndvi, ndvi_method)

# ---------------------------------------------------------------------------------------------------------
# 3. Validation: does the extraction reproduce the January-November 2025 values already in the dataset?
# ---------------------------------------------------------------------------------------------------------
vars <- c("rainfall", "rel_humidity", "t2m", "tmax", "tmin")
check <- power |> filter(month <= 11) |>
  inner_join(select(dm, district, year, month, all_of(vars)), by = c("district", "year", "month"), suffix = c("_new", "_old"))
val <- map_dfr(vars, function(v) tibble(
  variable = v,
  mean_abs_diff = mean(abs(check[[paste0(v, "_new")]] - check[[paste0(v, "_old")]]), na.rm = TRUE),
  max_abs_diff  = max(abs(check[[paste0(v, "_new")]] - check[[paste0(v, "_old")]]), na.rm = TRUE),
  correlation   = cor(check[[paste0(v, "_new")]], check[[paste0(v, "_old")]], use = "complete.obs")))
print(val)
bad <- check |> group_by(district) |>
  summarise(rain_mad = mean(abs(rainfall_new - rainfall_old), na.rm = TRUE), .groups = "drop") |>
  filter(rain_mad > 0.1)
if (nrow(bad)) { message("Districts whose 2025 rainfall differs from the original by > 0.1 mm/day on average:"); print(bad) }
message("NDVI calibration: median R2 = ", round(median(cal$r2, na.rm = TRUE), 2),
        "; districts calibrated = ", sum(cal$r2 >= 0.5, na.rm = TRUE), " of ", nrow(cal))

# ---------------------------------------------------------------------------------------------------------
# 4. Write December 2025 values and fill them into the unified files
# ---------------------------------------------------------------------------------------------------------
dec <- power |> filter(month == 12) |>
  left_join(ndvi_dec, by = c("district", "year", "month")) |>
  mutate(climate_source_dec2025 = "NASA POWER monthly API; NDVI from MODIS MOD13A3 (see ndvi_method)")
write_csv(dec, "data/climate_dec2025.csv")
write_csv(val, "data/climate_dec2025_validation.csv")

fill <- function(file) {
  x <- read_csv(file, show_col_types = FALSE)
  is_dec <- x$year == 2025 & x$month == 12
  m <- match(x$district[is_dec], dec$district)
  for (v in c(vars, "ndvi")) x[[v]][is_dec] <- dec[[v]][m]
  x$climate_available <- as.integer(complete.cases(x[, c(vars, "ndvi")]))
  write_csv(x, file)
  message(file, ": December 2025 filled for ", sum(!is.na(m)), " rows")
}
fill("data/snakebite_unified_district_month.csv")
fill("data/snakebite_unified_district_month_sex.csv")
message("Done. Check data/climate_dec2025_validation.csv before using the December 2025 values.")
