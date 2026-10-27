# Figure 4 (Results, section 3.3): (A) observed seasonal cycle of incidence by rainfall regime with the cycles fitted by
# calendar-month terms (M1), own lagged climate (M2) and placebo climate (median of the GLMM placebo fits);
# (B) distribution of the placebo-climate statistic relative to the own-climate fit.
# Run after analysis/primary_models.R and analysis/primary_placebo.R:  Rscript analysis/fig4_primary.R
source("analysis/primary_common.R")
suppressPackageStartupMessages({ library(ggplot2); library(patchwork); library(tidyr) })

d <- load_panel(); cb <- make_cb(d); rows <- analysis_rows(d, cb); dd <- with_cb(d, cb, rows)
fits <- readRDS("analysis/output/primary_fits.rds"); pf <- readRDS("analysis/output/placebo_median_fit.rds")
REG <- c(unimodal = "Unimodal", transition = "Transition", bimodal = "Bimodal")
cyc <- tibble(regime = REG[as.character(dd$regime)], month = dd$month, pop = dd$population, Observed = dd$cases_total,
              `Calendar-month terms (M1)` = fitted(fits$M1), `Own lagged climate (M2)` = fitted(fits$M2),
              `Placebo climate` = fitted(pf)) |>
  pivot_longer(-c(regime, month, pop), names_to = "series", values_to = "n") |>
  group_by(regime, month, series) |> summarise(inc = sum(n) / sum(pop) * 1e5, .groups = "drop") |>
  mutate(regime = factor(regime, levels = REG),
         series = factor(series, levels = c("Observed", "Calendar-month terms (M1)", "Own lagged climate (M2)", "Placebo climate")))
SER_COL <- c("Observed" = "#000000", "Calendar-month terms (M1)" = "#9A9A9A", "Own lagged climate (M2)" = "#1F5F99", "Placebo climate" = "#4D4D4D")
SER_LT  <- c("Observed" = "blank", "Calendar-month terms (M1)" = "dashed", "Own lagged climate (M2)" = "solid", "Placebo climate" = "dotted")
pA <- ggplot(cyc, aes(month, inc, colour = series, linetype = series)) +
  geom_line(data = ~ subset(.x, series != "Observed"), linewidth = 1) +
  geom_point(data = ~ subset(.x, series == "Observed"), size = 2.2) +
  facet_wrap(~ regime, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = SER_COL, name = NULL, breaks = names(SER_COL)) +
  scale_linetype_manual(values = SER_LT, name = NULL, breaks = names(SER_LT)) +
  guides(colour = guide_legend(override.aes = list(shape = c(16, NA, NA, NA), size = 2.2,
                                                   linetype = c("blank", "dashed", "solid", "dotted"))), linetype = "none") +
  scale_x_continuous(breaks = 1:12, labels = substr(month.abb, 1, 1)) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(x = "Calendar month", y = "Cases per 100,000 per month", tag = "A") +
  theme_classic(base_size = 11) +
  theme(legend.position = "top", legend.justification = "left", strip.background = element_blank(),
        strip.text = element_text(face = "bold", size = 11), legend.key.width = unit(1.8, "lines"))

pl <- read_csv("analysis/output/placebo_deviances.csv", show_col_types = FALSE)
pB <- ggplot(pl, aes(diff_vs_own)) +
  geom_histogram(bins = 40, fill = "#1F5F99", colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = 0, colour = "#000000", linewidth = 1) +
  annotate("text", x = 0, y = Inf, label = "Own climate", hjust = -0.08, vjust = 1.5, colour = "#000000", size = 3.6) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(x = "Increase in -2 log-likelihood with placebo climate", y = "Number of placebo permutations", tag = "B") +
  theme_classic(base_size = 11)

p <- pA / pB + plot_layout(heights = c(1.15, 1))
ggsave("figures/Fig4.png", p, width = 8.5, height = 7.2, dpi = 300, bg = "white")
ggsave("figures/Fig4.pdf", p, width = 8.5, height = 7.2, device = cairo_pdf, bg = "white")
print(cyc |> pivot_wider(names_from = series, values_from = inc) |> mutate(across(where(is.numeric), \(x) round(x, 2))), n = 40)
cat("saved figures/Fig4.png and .pdf\n")
