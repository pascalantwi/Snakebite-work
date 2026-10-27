# Descriptive figures for Results sections 3.1 and 3.2, January 2020 - December 2025.
#   Fig 2: national monthly snakebite cases (line, left axis) and monthly rainfall of the average district (bars, right axis)
#   Fig 3: monthly rainfall by calendar month and rainfall regime (line = mean over years, band = range over years)
#   Rainfall is the monthly total in mm (NASA POWER daily mean x days in the month), averaged over districts.
#   S1 Fig: incidence relative to the district mean by months since rainy-season onset (mean and 95% CI over district-years);
#          onset = first month from February with mean rainfall >= 2 mm/day (section 2.3)
# Regime colours match the Fig 1 map. No titles on the images: captions are in the manuscript.
# Run from the repository root:  Rscript analysis/figures_descriptive.R
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

d <- read_csv("data/snakebite_unified_district_month.csv", show_col_types = FALSE) |>
  filter(include_main == 1) |>
  mutate(date = as.Date(paste0(date, "-01")),
         days = as.integer(as.Date(format(date + 31, "%Y-%m-01")) - date),
         rain_mm = rainfall * days)                      # monthly total rainfall (mm) from the daily mean (mm/day)

REG_COL <- c(Unimodal = "#D4541F", Transition = "#138A5F", Bimodal = "#1C5DAF")   # deeper shades of the Fig 1 map hues
REG_LAB <- c(Unimodal = "Unimodal (47 districts)", Transition = "Transition (22 districts)", Bimodal = "Bimodal (192 districts)")
CASE_COL <- "#000000"; RAIN_COL <- "#1F5F99"
d <- d |> mutate(regime = factor(tools::toTitleCase(regime), levels = names(REG_COL)))

theme_pub <- function(base = 11) {
  theme_classic(base_size = base) +
    theme(legend.position = "top", legend.justification = "left")
}
save_fig <- function(p, name, w, h) {
  ggsave(file.path("figures", paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf, bg = "white")
  message("saved figures/", name, ".pdf")
}

# ---- Fig 2: national monthly cases and rainfall --------------------------------------------------------
nat <- d |> group_by(date) |>
  summarise(cases = sum(cases_total), rainfall = mean(rain_mm, na.rm = TRUE), .groups = "drop")
K <- 4                                             # rainfall (mm) x K is drawn on the cases scale
p2 <- ggplot(nat, aes(date)) +
  geom_col(aes(y = rainfall * K, fill = "Rainfall"), width = 24) +
  geom_line(aes(y = cases, colour = "Snakebite cases"), linewidth = 1.1) +
  geom_point(aes(y = cases, colour = "Snakebite cases"), size = 1.9) +
  scale_fill_manual(values = c("Rainfall" = RAIN_COL), name = NULL) +
  scale_colour_manual(values = c("Snakebite cases" = CASE_COL), name = NULL) +
  scale_y_continuous(name = "Snakebite cases per month", labels = label_comma(), limits = c(0, 1400),
                     breaks = seq(0, 1400, 200), expand = c(0, 0),
                     sec.axis = sec_axis(~ . / K, name = "Rainfall (mm)", breaks = seq(0, 350, 50))) +
  scale_x_date(name = "Month", limits = as.Date(c("2019-12-10", "2025-12-22")),
               breaks = seq(as.Date("2020-01-01"), as.Date("2025-07-01"), by = "6 months"),
               date_labels = "%b\n%Y", expand = c(0, 0)) +
  guides(colour = guide_legend(order = 1), fill = guide_legend(order = 2)) +
  theme_pub()
save_fig(p2, "Fig2", 8.0, 4.6)

cat("\nNational monthly totals\n"); print(summary(nat$cases))
cat("max:"); print(nat[which.max(nat$cases), ]); cat("min:"); print(nat[which.min(nat$cases), ]); cat("rain range (mm):", range(nat$rainfall), "\n")
pk <- nat |> mutate(year = format(date, "%Y")) |> group_by(year) |>
  summarise(total = sum(cases), peak_month = format(date[which.max(cases)], "%b"), peak = max(cases),
            low_month = format(date[which.min(cases)], "%b"), low = min(cases),
            rain_peak = format(date[which.max(rainfall)], "%b"))
print(pk)
cat("correlation of cases with rainfall at lags 0-3 months:\n")
for (k in 0:3) cat(" lag", k, round(cor(nat$cases[(k + 1):nrow(nat)], nat$rainfall[1:(nrow(nat) - k)]), 2), "\n")

# ---- Fig 3: rainfall by calendar month and regime ------------------------------------------------------
rs <- d |> group_by(regime, year, month) |> summarise(rain = mean(rain_mm), .groups = "drop") |>
  group_by(regime, month) |> summarise(mean = mean(rain), lo = min(rain), hi = max(rain), .groups = "drop")
p3 <- ggplot(rs, aes(month, mean, colour = regime, fill = regime)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.22, colour = NA) +
  geom_line(linewidth = 1.1) + geom_point(size = 2.2) +
  scale_colour_manual(values = REG_COL, labels = REG_LAB, name = "Rainfall regime") +
  scale_fill_manual(values = REG_COL, labels = REG_LAB, name = "Rainfall regime") +
  scale_x_continuous(breaks = 1:12, labels = month.abb, expand = expansion(mult = 0.02)) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(x = "Calendar month", y = "Rainfall (mm)") + theme_pub()
save_fig(p3, "Fig3", 7.0, 4.4)
print(as.data.frame(rs |> mutate(across(c(mean, lo, hi), \(x) round(x)))))

# ---- Fig 4: relative incidence by months since onset ---------------------------------------------------
d <- d |> mutate(rate = cases_total / population) |> group_by(district) |> mutate(rr = rate / mean(rate)) |> ungroup()
onset <- d |> filter(month >= 2, rainfall >= 2) |> group_by(district, year, regime) |>
  summarise(t0 = min(t), .groups = "drop")
ev <- onset |> crossing(k = -3:6) |> mutate(t = t0 + k) |>
  inner_join(select(d, district, t, rr), by = c("district", "t")) |>
  group_by(regime, k) |> summarise(m = mean(rr), se = sd(rr) / sqrt(n()), .groups = "drop") |>
  mutate(lo = m - 1.96 * se, hi = m + 1.96 * se)
p4 <- ggplot(ev, aes(k, m, colour = regime, fill = regime)) +
  geom_hline(yintercept = 1, colour = "grey40", linewidth = 0.4) +
  geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.4, linetype = "dashed") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.22, colour = NA) +
  geom_line(linewidth = 1.1) + geom_point(size = 2.2) +
  scale_colour_manual(values = REG_COL, labels = REG_LAB, name = "Rainfall regime") +
  scale_fill_manual(values = REG_COL, labels = REG_LAB, name = "Rainfall regime") +
  scale_x_continuous(breaks = -3:6) +
  labs(x = "Months since rainy-season onset", y = "Incidence relative to district mean") + theme_pub()
save_fig(p4, "S1_Fig", 7.0, 4.4)
cat("\nRelative incidence by months since onset\n"); print(as.data.frame(ev |> mutate(across(c(m, lo, hi), \(x) round(x, 2)))))
