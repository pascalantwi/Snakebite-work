# Figure 11 and S2 Fig (Results, section 3.11). Run after analysis/sensitivity.R.
#   S2 Fig: diagnostics of the selected model: (A) quantile-quantile plot of the randomized quantile residuals;
#           (B) simulated number of zero counts with the observed number; (C) residual autocorrelation within districts,
#           selected model and model with the autoregressive effect; (D) permutation distribution of Moran's I.
#   Fig 11: cumulative rate ratios (90th percentile vs median, lags 0-9) under each sensitivity analysis.
suppressPackageStartupMessages({ library(readr); library(dplyr); library(ggplot2); library(patchwork) })
BLUE <- "#1F5F99"; GREY <- "#9A9A9A"
LAB <- c(rainfall = "Rainfall", tmax = "Maximum temperature", tmin = "Minimum temperature", ndvi = "NDVI")
th <- theme_classic(base_size = 11) + theme(strip.background = element_blank(), strip.text = element_text(face = "bold"))
save_fig <- function(p, name, w, h) {
  ggsave(file.path("figures", paste0(name, ".png")), p, width = w, height = h, dpi = 300, bg = "white")
  ggsave(file.path("figures", paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf, bg = "white")
}
tests <- read_csv("analysis/output/diagnostics.csv", show_col_types = FALSE)
main <- filter(tests, model == "Selected model")
qq <- read_csv("analysis/output/diagnostics_qq.csv", show_col_types = FALSE)
pA <- ggplot(qq, aes(expected, observed)) + geom_abline(linetype = "dashed", linewidth = 0.4) +
  geom_point(colour = BLUE, size = 0.6) + coord_equal() +
  labs(x = "Expected quantile (uniform)", y = "Observed quantile residual", tag = "A") + th
zs <- read_csv("analysis/output/diagnostics_zero_sims.csv", show_col_types = FALSE)
pB <- ggplot(zs, aes(zeros)) + geom_histogram(bins = 30, fill = BLUE, colour = "white") +
  geom_vline(xintercept = main$zeros_obs, linewidth = 0.8) + scale_x_continuous(labels = scales::label_comma()) +
  labs(x = "Number of district-months with no cases", y = "Simulated datasets", tag = "B") + th
ac <- read_csv("analysis/output/diagnostics_acf.csv", show_col_types = FALSE)
band <- 1.96 / sqrt(min(ac$n))
pC <- ggplot(ac, aes(lag, acf, colour = model, shape = model)) + geom_hline(yintercept = 0, linewidth = 0.4) +
  geom_hline(yintercept = c(-band, band), linetype = "dashed", linewidth = 0.3) +
  geom_line(linewidth = 0.8) + geom_point(size = 2.2) +
  scale_colour_manual(values = c("Selected model" = BLUE, "With autoregressive effect" = GREY, "With spatial effect" = "#D4541F"), name = NULL) +
  scale_shape_manual(values = c("Selected model" = 16, "With autoregressive effect" = 17, "With spatial effect" = 15), name = NULL) +
  scale_x_continuous(breaks = 1:12) + labs(x = "Lag (months)", y = "Residual autocorrelation", tag = "C") + th +
  theme(legend.position = c(0.98, 0.98), legend.justification = c(1, 1))
mp <- read_csv("analysis/output/diagnostics_moran_perm.csv", show_col_types = FALSE) |> filter(model == "Selected model")
pD <- ggplot(mp, aes(I)) + geom_histogram(bins = 30, fill = BLUE, colour = "white") +
  geom_vline(xintercept = main$moran_I, linewidth = 0.8) +
  labs(x = "Moran's I of district mean residuals", y = "Permutations", tag = "D") + th
save_fig((pA | pB) / (pC | pD), "S2_Fig", 9, 7.5)

s <- read_csv("analysis/output/sensitivity_summary.csv", show_col_types = FALSE)
cl <- read_csv("analysis/output/sensitivity_clustered_se.csv", show_col_types = FALSE) |> filter(se == "cluster") |>
  mutate(id = "cluster_se", group = "Climate data", label = "Standard errors clustered by grid cell")
s <- bind_rows(s, cl)
ORDER <- c("main", "L3", "L6", "L12", "L9_23", "L9_32", "nb1", "zinb", "hurdle", "no_outliers", "no_2020", "no_dec2025",
           "fourier", "cell_re", "cluster_se", "pop_month", "thr75", "thr90", "tr_uni", "tr_bim", "ar1", "spatial")
s <- filter(s, id %in% ORDER)
lev <- unique(s$label[order(match(s$id, ORDER))])
s <- s |> mutate(label = factor(label, levels = rev(lev)), variable = factor(LAB[variable], levels = LAB),
                 is_main = id == "main")
ref <- s |> filter(is_main) |> select(variable, ref = cumRR)
p13 <- ggplot(s, aes(cumRR, label)) +
  geom_vline(xintercept = 1, linewidth = 0.4) +
  geom_vline(data = ref, aes(xintercept = ref), linetype = "dashed", colour = BLUE, linewidth = 0.4) +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0, colour = BLUE, linewidth = 0.6) +
  geom_point(aes(shape = is_main), colour = BLUE, size = 2) + scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 15), guide = "none") +
  scale_x_log10(breaks = c(0.6, 0.8, 1, 1.25, 1.5, 2)) + facet_wrap(~ variable, nrow = 1, scales = "free_x") +
  labs(x = "Cumulative rate ratio, 90th percentile vs median (log scale)", y = NULL) + th
save_fig(p13, "Fig11", 11, 6.5)
cat("saved figures/Fig11 and S2_Fig\n")
