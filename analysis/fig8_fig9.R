# Figures 8 and 9 (Results, sections 3.7 and 3.8). Run after analysis/regime_onset.R.
#   Fig 8: (A) lag-specific rate ratios at the national 90th percentile versus the median, by rainfall regime;
#          (B) cumulative exposure-response over lags 0-9 by regime.
#   Fig 9: event-study rate ratios by months since rainy-season onset, by regime (one axis).
suppressPackageStartupMessages({ library(readr); library(dplyr); library(ggplot2); library(patchwork) })
REG_COL <- c(Unimodal = "#D4541F", Transition = "#138A5F", Bimodal = "#1C5DAF")   # as in Figs 3-4
REG_SH  <- c(Unimodal = 16, Transition = 17, Bimodal = 15)
LAB <- c(rainfall = "Rainfall", tmax = "Maximum temperature", tmin = "Minimum temperature", ndvi = "NDVI")
XLAB <- c(rainfall = "Rainfall (mm/day)", tmax = "Maximum temperature (°C)", tmin = "Minimum temperature (°C)", ndvi = "NDVI")
th <- theme_classic(base_size = 11) + theme(strip.background = element_blank(), strip.text = element_text(face = "bold"),
                                            legend.position = "top", legend.justification = "left")
save_fig <- function(p, name, w, h) {
  ggsave(file.path("figures", paste0(name, ".png")), p, width = w, height = h, dpi = 300, bg = "white")
  ggsave(file.path("figures", paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf, bg = "white")
}
tc <- function(x) factor(tools::toTitleCase(x), levels = names(REG_COL))
dg <- position_dodge(width = 0.6)

lc <- read_csv("analysis/output/regime_lag_curves.csv", show_col_types = FALSE) |> filter(group %in% c("unimodal", "transition", "bimodal")) |>
  mutate(regime = tc(group), variable = factor(LAB[variable], levels = LAB))
pA <- ggplot(lc, aes(lag, RR, colour = regime, shape = regime)) + geom_hline(yintercept = 1, linewidth = 0.4) +
  geom_linerange(aes(ymin = lo, ymax = hi), position = dg, linewidth = 0.5) +
  geom_line(position = dg, linewidth = 0.8) + geom_point(position = dg, size = 1.9) +
  facet_wrap(~ variable, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = REG_COL, name = "Rainfall regime") + scale_shape_manual(values = REG_SH, name = "Rainfall regime") +
  scale_x_continuous(breaks = seq(0, 9, 3)) + labs(x = "Lag (months)", y = "Rate ratio", tag = "A") + th
cc <- read_csv("analysis/output/regime_cumulative_curves.csv", show_col_types = FALSE) |> filter(group %in% c("unimodal", "transition", "bimodal")) |>
  mutate(regime = tc(group))
pB <- wrap_plots(lapply(names(LAB), function(v) {
  ggplot(filter(cc, variable == v), aes(x, RR, colour = regime, fill = regime)) + geom_hline(yintercept = 1, linewidth = 0.4) +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, colour = NA) + geom_line(linewidth = 0.9) +
    scale_colour_manual(values = REG_COL, guide = "none") + scale_fill_manual(values = REG_COL, guide = "none") +
    scale_y_log10() +
    labs(x = XLAB[[v]], y = if (v == "rainfall") "Cumulative rate ratio (log scale)" else NULL, tag = if (v == "rainfall") "B" else NULL) +
    theme_classic(base_size = 11)
}), nrow = 1)
save_fig(pA / pB + plot_layout(heights = c(1, 1)), "Fig8", 11, 7)

ev <- read_csv("analysis/output/onset_event_study.csv", show_col_types = FALSE) |> mutate(regime = tc(regime))
ev <- bind_rows(ev, tibble(regime = factor(names(REG_COL), levels = names(REG_COL)), k = -3L, RR = 1, lo = 1, hi = 1))
p9 <- ggplot(ev, aes(k, RR, colour = regime, shape = regime)) + geom_hline(yintercept = 1, linewidth = 0.4) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.4) +
  geom_linerange(aes(ymin = lo, ymax = hi), position = dg, linewidth = 0.6) +
  geom_line(position = dg, linewidth = 0.9) + geom_point(position = dg, size = 2.4) +
  scale_colour_manual(values = REG_COL, name = "Rainfall regime") + scale_shape_manual(values = REG_SH, name = "Rainfall regime") +
  scale_x_continuous(breaks = -3:6) + labs(x = "Months since rainy-season onset", y = "Rate ratio (reference: 3 months before onset)") + th
save_fig(p9, "Fig9", 7.5, 4.8)
cat("saved figures/Fig8 and Fig9\n")
