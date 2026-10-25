# Figures 6 and 7 (Results, sections 3.5 and 3.6). Run after analysis/exposure_response.R.
#   Fig 6: (A) lag-response at the 90th percentile versus the median; (B) cumulative exposure-response over lags 0-9.
#   Fig 7: lag-response for a 1-SD positive anomaly, from the climatology-anomaly model.
suppressPackageStartupMessages({ library(readr); library(dplyr); library(ggplot2); library(patchwork) })
BLUE <- "#1F5F99"; BAND <- "#A9C4DE"
LAB <- c(rainfall = "Rainfall", tmax = "Maximum temperature", tmin = "Minimum temperature", ndvi = "NDVI")
XLAB <- c(rainfall = "Rainfall (mm/day)", tmax = "Maximum temperature (\u00B0C)", tmin = "Minimum temperature (\u00B0C)", ndvi = "NDVI")
th <- theme_classic(base_size = 11) + theme(strip.background = element_blank(), strip.text = element_text(face = "bold"))
save_fig <- function(p, name, w, h) {
  ggsave(file.path("figures", paste0(name, ".png")), p, width = w, height = h, dpi = 300, bg = "white")
  ggsave(file.path("figures", paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf, bg = "white")
}
lc <- read_csv("analysis/output/rr_lag_curves.csv", show_col_types = FALSE) |> filter(percentile == "90th") |>
  mutate(variable = factor(LAB[variable], levels = LAB))
pA <- ggplot(lc, aes(lag, RR)) + geom_hline(yintercept = 1, linewidth = 0.4) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = BAND, alpha = 0.6) + geom_line(colour = BLUE, linewidth = 1) +
  geom_point(colour = BLUE, size = 1.6) + facet_wrap(~ variable, nrow = 1) +
  scale_x_continuous(breaks = 0:9) + labs(x = "Lag (months)", y = "Rate ratio", tag = "A") + th
cc <- read_csv("analysis/output/rr_cumulative_curves.csv", show_col_types = FALSE)
pB <- wrap_plots(lapply(names(LAB), function(v) {
  ggplot(filter(cc, variable == v), aes(x, RR)) + geom_hline(yintercept = 1, linewidth = 0.4) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = BAND, alpha = 0.6) + geom_line(colour = BLUE, linewidth = 1) +
    labs(x = XLAB[[v]], y = if (v == "rainfall") "Cumulative rate ratio" else NULL, tag = if (v == "rainfall") "B" else NULL) + th
}), nrow = 1)
save_fig(pA / pB, "Fig6", 10, 6.4)

an <- read_csv("analysis/output/anomaly_lag_curves.csv", show_col_types = FALSE) |> filter(anomaly_sd == 1) |>
  mutate(variable = factor(LAB[variable], levels = LAB))
p7 <- ggplot(an, aes(lag, RR)) + geom_hline(yintercept = 1, linewidth = 0.4) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = BAND, alpha = 0.6) + geom_line(colour = BLUE, linewidth = 1) +
  geom_point(colour = BLUE, size = 1.6) + facet_wrap(~ variable, nrow = 1) +
  scale_x_continuous(breaks = 0:9) + labs(x = "Lag (months)", y = "Rate ratio per 1-SD anomaly") + th
save_fig(p7, "Fig7", 10, 3.4)
cat("saved figures/Fig6 and Fig7\n")
