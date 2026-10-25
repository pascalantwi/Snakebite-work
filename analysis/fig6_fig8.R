# Figures 6, 7 and 8 (Results, sections 3.5 and 3.6). Run after analysis/exposure_response.R.
#   Fig 6: lag-response at the 90th percentile versus the median, all exposures on one axis.
#   Fig 7: cumulative exposure-response over lags 0-9, one panel per exposure.
#   Fig 8: lag-response for a 1-SD positive anomaly, from the climatology-anomaly model (all exposures on one axis).
suppressPackageStartupMessages({ library(readr); library(dplyr); library(ggplot2); library(patchwork) })
BLUE <- "#1F5F99"; BAND <- "#A9C4DE"
LAB <- c(rainfall = "Rainfall", tmax = "Maximum temperature", tmin = "Minimum temperature", ndvi = "NDVI")
XLAB <- c(rainfall = "Rainfall (mm/day)", tmax = "Maximum temperature (\u00B0C)", tmin = "Minimum temperature (\u00B0C)", ndvi = "NDVI")
th <- theme_classic(base_size = 11) + theme(strip.background = element_blank(), strip.text = element_text(face = "bold"))
save_fig <- function(p, name, w, h) {
  ggsave(file.path("figures", paste0(name, ".png")), p, width = w, height = h, dpi = 300, bg = "white")
  ggsave(file.path("figures", paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf, bg = "white")
}
VCOL <- c("Rainfall" = "#1F5F99", "Maximum temperature" = "#D4541F", "Minimum temperature" = "#000000", "NDVI" = "#138A5F")
VLT  <- c("Rainfall" = "solid", "Maximum temperature" = "dashed", "Minimum temperature" = "dotdash", "NDVI" = "longdash")
VSH  <- c("Rainfall" = 16, "Maximum temperature" = 17, "Minimum temperature" = 15, "NDVI" = 18)
dg <- position_dodge(width = 0.55)
one_axis <- function(dat, ylab) {
  ggplot(dat, aes(lag, RR, colour = variable, linetype = variable, shape = variable, group = variable)) +
    geom_hline(yintercept = 1, linewidth = 0.4) +
    geom_linerange(aes(ymin = lo, ymax = hi), position = dg, linewidth = 0.6, linetype = "solid") +
    geom_line(position = dg, linewidth = 0.9) + geom_point(position = dg, size = 2.4) +
    scale_colour_manual(values = VCOL, name = NULL) + scale_linetype_manual(values = VLT, name = NULL) +
    scale_shape_manual(values = VSH, name = NULL) + scale_x_continuous(breaks = 0:9) +
    labs(x = "Lag (months)", y = ylab) +
    theme_classic(base_size = 11) + theme(legend.position = "top", legend.justification = "left", legend.key.width = unit(2, "lines"))
}
lc <- read_csv("analysis/output/rr_lag_curves.csv", show_col_types = FALSE) |> filter(percentile == "90th") |>
  mutate(variable = factor(LAB[variable], levels = LAB))
save_fig(one_axis(lc, "Rate ratio (90th percentile vs median)"), "Fig6", 7.5, 4.8)
cc <- read_csv("analysis/output/rr_cumulative_curves.csv", show_col_types = FALSE)
p7 <- wrap_plots(lapply(names(LAB), function(v) {
  ggplot(filter(cc, variable == v), aes(x, RR)) + geom_hline(yintercept = 1, linewidth = 0.4) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = BAND, alpha = 0.6) + geom_line(colour = BLUE, linewidth = 1) +
    labs(x = XLAB[[v]], y = if (v == "rainfall") "Cumulative rate ratio" else NULL, title = LAB[[v]]) + th +
    theme(plot.title = element_text(face = "bold", size = 11, hjust = 0.5))
}), nrow = 1)
save_fig(p7, "Fig7", 10, 3.6)

an <- read_csv("analysis/output/anomaly_lag_curves.csv", show_col_types = FALSE) |> filter(anomaly_sd == 1) |>
  mutate(variable = factor(LAB[variable], levels = LAB))
save_fig(one_axis(an, "Rate ratio per 1-SD positive anomaly"), "Fig8", 7.5, 4.8)
cat("saved figures/Fig6, Fig7 and Fig8\n")
