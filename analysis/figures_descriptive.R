# Descriptive figures for Results sections 3.1 and 3.2, January 2020 - December 2025.
#   Fig 2: national monthly snakebite cases (A) and mean district rainfall (B)
#   Fig 3: mean monthly rainfall by calendar month and rainfall regime (line = mean over years, band = range over years)
#   Fig 4: incidence relative to the district mean by months since rainy-season onset (mean and 95% CI over district-years);
#          onset = first month from February with mean rainfall >= 2 mm/day (section 2.3)
# Colours: Okabe-Ito colour-blind-safe palette. No titles on the images: captions are in the manuscript.
# Run from the repository root:  Rscript analysis/figures_descriptive.R
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(ggplot2); library(patchwork); library(scales)
})

d <- read_csv("data/snakebite_unified_district_month.csv", show_col_types = FALSE) |>
  filter(include_main == 1) |>
  mutate(date = as.Date(paste0(date, "-01")))

REG_COL <- c(Unimodal = "#D55E00", Transition = "#009E73", Bimodal = "#0072B2")   # Okabe-Ito
REG_LAB <- c(Unimodal = "Unimodal (47 districts)", Transition = "Transition (22 districts)", Bimodal = "Bimodal (192 districts)")
CASE_COL <- "#1A1A1A"; RAIN_COL <- "#56B4E9"; RAIN_EST <- "#BFE1F6"
d <- d |> mutate(regime = factor(tools::toTitleCase(regime), levels = names(REG_COL)))

theme_pub <- function(base = 10) {
  theme_classic(base_size = base, base_family = "sans") +
    theme(axis.title = element_text(colour = "black"),
          axis.text = element_text(colour = "grey20"),
          axis.line = element_line(colour = "grey30", linewidth = 0.4),
          axis.ticks = element_line(colour = "grey30", linewidth = 0.4),
          panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3),
          legend.position = "top", legend.justification = "left", legend.title = element_text(face = "bold"),
          legend.key.width = unit(1.4, "lines"),
          plot.tag = element_text(face = "bold", size = base + 2),
          plot.margin = margin(6, 10, 6, 6))
}
save_fig <- function(p, name, w, h) {
  ggsave(file.path("figures", paste0(name, ".png")), p, width = w, height = h, dpi = 300, bg = "white")
  ggsave(file.path("figures", paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf, bg = "white")
  message("saved figures/", name, ".png and .pdf")
}

# ---- Fig 2: national monthly cases and rainfall --------------------------------------------------------
nat <- d |> group_by(date) |>
  summarise(cases = sum(cases_total), rainfall = mean(rainfall, na.rm = TRUE),
            estimated = any(climate_imputed == 1), .groups = "drop")
yr_lines <- as.Date(paste0(2021:2025, "-01-01"))
x_scale <- scale_x_date(limits = as.Date(c("2019-12-10", "2025-12-22")), breaks = seq(as.Date("2020-01-01"), as.Date("2025-07-01"), by = "6 months"), date_labels = "%b\n%Y", expand = c(0, 0))
pA <- ggplot(nat, aes(date, cases)) +
  geom_vline(xintercept = yr_lines - 15, colour = "grey85", linewidth = 0.3) +
  geom_line(colour = CASE_COL, linewidth = 0.6) +
  geom_point(colour = CASE_COL, size = 1.2) +
  scale_y_continuous(labels = label_comma(), limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  x_scale + labs(x = NULL, y = "Snakebite cases per month", tag = "A") + theme_pub() +
  theme(axis.text.x = element_blank())
pB <- ggplot(nat, aes(date, rainfall)) +
  geom_vline(xintercept = yr_lines - 15, colour = "grey85", linewidth = 0.3) +
  geom_col(aes(fill = estimated), width = 24) +
  scale_fill_manual(values = c(`FALSE` = RAIN_COL, `TRUE` = RAIN_EST), guide = "none") +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  x_scale + labs(x = "Month", y = "Mean rainfall (mm/day)", tag = "B") + theme_pub()
save_fig(pA / pB + plot_layout(heights = c(1, 0.8)), "Fig2", 7.2, 5.2)

cat("\nNational monthly totals\n"); print(summary(nat$cases))
cat("max:"); print(nat[which.max(nat$cases), ]); cat("min:"); print(nat[which.min(nat$cases), ])
pk <- nat |> mutate(year = format(date, "%Y")) |> group_by(year) |>
  summarise(total = sum(cases), peak_month = format(date[which.max(cases)], "%b"), peak = max(cases),
            low_month = format(date[which.min(cases)], "%b"), low = min(cases),
            rain_peak = format(date[which.max(rainfall)], "%b"))
print(pk)
cat("correlation of cases with rainfall at lags 0-3 months:\n")
for (k in 0:3) cat(" lag", k, round(cor(nat$cases[(k + 1):nrow(nat)], nat$rainfall[1:(nrow(nat) - k)]), 2), "\n")

# ---- Fig 3: rainfall by calendar month and regime ------------------------------------------------------
rs <- d |> group_by(regime, year, month) |> summarise(rain = mean(rainfall), .groups = "drop") |>
  group_by(regime, month) |> summarise(mean = mean(rain), lo = min(rain), hi = max(rain), .groups = "drop")
p3 <- ggplot(rs, aes(month, mean, colour = regime, fill = regime)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.8) +
  scale_colour_manual(values = REG_COL, labels = REG_LAB, name = "Rainfall regime") +
  scale_fill_manual(values = REG_COL, labels = REG_LAB, name = "Rainfall regime") +
  scale_x_continuous(breaks = 1:12, labels = month.abb, expand = expansion(mult = 0.02)) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(x = "Calendar month", y = "Mean rainfall (mm/day)") + theme_pub()
save_fig(p3, "Fig3", 7.0, 4.4)

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
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.8) +
  scale_colour_manual(values = REG_COL, labels = REG_LAB, name = "Rainfall regime") +
  scale_fill_manual(values = REG_COL, labels = REG_LAB, name = "Rainfall regime") +
  scale_x_continuous(breaks = -3:6) +
  labs(x = "Months since rainy-season onset", y = "Incidence relative to district mean") + theme_pub()
save_fig(p4, "Fig4", 7.0, 4.4)
cat("\nRelative incidence by months since onset\n"); print(as.data.frame(ev |> mutate(across(c(m, lo, hi), \(x) round(x, 2)))))
