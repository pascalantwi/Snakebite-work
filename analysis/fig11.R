# Figure 11 (Results, section 3.10): out-of-sample prediction of 2025. Run after analysis/prediction.R.
#   (A) national monthly cases observed and predicted by models A-C, with the 90% prediction interval of model C;
#   (B) non-randomised PIT histograms; (C) district totals for 2025, observed against predicted by model C.
suppressPackageStartupMessages({ library(readr); library(dplyr); library(ggplot2); library(patchwork) })
BLUE <- "#1F5F99"; BAND <- "#A9C4DE"
MCOL <- c("Model A (seasonal terms)" = "#9A9A9A", "Model B (+ lagged climate)" = "#D4541F", "Model C (+ onset)" = BLUE)
MLT  <- c("Model A (seasonal terms)" = "dashed", "Model B (+ lagged climate)" = "dotdash", "Model C (+ onset)" = "solid")
ML <- c(A = "Model A (seasonal terms)", B = "Model B (+ lagged climate)", C = "Model C (+ onset)")
th <- theme_classic(base_size = 11) + theme(strip.background = element_blank(), strip.text = element_text(face = "bold"))
nat <- read_csv("analysis/output/prediction_national_2025.csv", show_col_types = FALSE) |> mutate(model = factor(ML[model], levels = ML))
obs <- filter(nat, model == ML[["A"]])
pA <- ggplot(nat, aes(month)) +
  geom_ribbon(data = filter(nat, model == ML[["C"]]), aes(ymin = lo, ymax = hi), fill = BAND, alpha = 0.6) +
  geom_line(aes(y = predicted, colour = model, linetype = model), linewidth = 0.9) +
  geom_point(data = obs, aes(y = observed), size = 2.4) +
  scale_colour_manual(values = MCOL, name = NULL) + scale_linetype_manual(values = MLT, name = NULL) +
  scale_x_continuous(breaks = 1:12, labels = month.abb) + scale_y_continuous(labels = scales::label_comma(), limits = c(0, NA)) +
  labs(x = "Month of 2025", y = "Snakebite cases per month", tag = "A") + th +
  theme(legend.position = "top", legend.justification = "left", legend.key.width = unit(2, "lines"))
pit <- read_csv("analysis/output/prediction_pit.csv", show_col_types = FALSE) |> mutate(model = factor(ML[model], levels = ML))
pB <- ggplot(pit, aes(xmin = lower, xmax = upper, ymin = 0, ymax = density)) + geom_rect(fill = BLUE, colour = "white") +
  geom_hline(yintercept = 1, linetype = "dashed", linewidth = 0.4) + facet_wrap(~ model, nrow = 1) +
  scale_x_continuous(breaks = c(0, 0.5, 1)) + labs(x = "Probability integral transform", y = "Density", tag = "B") + th
dist <- read_csv("analysis/output/prediction_district_2025.csv", show_col_types = FALSE) |> filter(model == "C")
lim <- range(c(dist$observed, dist$predicted) + 1)
pC <- ggplot(dist, aes(predicted + 1, observed + 1)) + geom_abline(linetype = "dashed", linewidth = 0.4) +
  geom_point(colour = BLUE, alpha = 0.7, size = 1.6) + scale_x_log10(limits = lim) + scale_y_log10(limits = lim) +
  labs(x = "Predicted cases in 2025 + 1 (model C, log scale)", y = "Observed cases in 2025 + 1 (log scale)", tag = "C") + th
p <- pA / (pB | pC + plot_layout(widths = c(2.2, 1))) + plot_layout(heights = c(1.1, 1))
ggsave("figures/Fig11.png", p, width = 10, height = 8, dpi = 300, bg = "white")
ggsave("figures/Fig11.pdf", p, width = 10, height = 8, device = cairo_pdf, bg = "white")
cat("saved figures/Fig11\n")
