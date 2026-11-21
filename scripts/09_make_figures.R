# Make the five report figures in one consistent style.
#
# Usage (from the repository root, after scripts 03-08):
#   Rscript scripts/09_make_figures.R
#
# Input:  data/processed/crossings.csv and the CSV summaries in outputs/TX and outputs/ALL
# Output: outputs/report_figs/fig1_exposure.png     crashes by device within exposure groups
#         outputs/report_figs/fig2_ppc.png          posterior predictive checks
#         outputs/report_figs/fig3_rate_ratios.png  raw vs. adjusted rate ratios
#         outputs/report_figs/fig4_priors.png       prior sensitivity
#         outputs/report_figs/fig5_counties.png     county risk multipliers

source("R/utils.R")
suppressPackageStartupMessages({
  library(tidyr)
  library(ggplot2)
})
out <- file.path(OUTPUT_DIR, "report_figs")
dir.create(out, showWarnings = FALSE, recursive = TRUE)

# ---- Shared look ----------------------------------------------------------------
col_dev  <- c(Passive = "#B5BCC6", "Flashing lights" = "#7FB2E5", Gates = "#1F5FA8")
col_ink  <- "#14213D"; col_soft <- "#5A6577"; col_hi <- "#C2571A"; col_raw <- "#A0A7B2"
#' Minimal ggplot theme shared by every figure; `base` is the base font size.
theme_report <- function(base = 15) {
  theme_minimal(base_size = base) +
    theme(plot.title = element_text(face = "bold", colour = col_ink, size = base + 3),
          plot.subtitle = element_text(colour = col_soft, margin = margin(b = 10)),
          plot.caption = element_text(colour = col_soft, size = base - 4, hjust = 0),
          plot.title.position = "plot", plot.caption.position = "plot",
          axis.title = element_text(colour = col_soft),
          axis.text = element_text(colour = col_ink),
          panel.grid.minor = element_blank(),
          strip.text = element_text(face = "bold", colour = col_ink, hjust = 0, size = base),
          legend.position = "top", legend.justification = "left",
          legend.title = element_blank(),
          legend.box.spacing = unit(2, "pt"), legend.margin = margin(0, 0, 0, 0),
          strip.placement = "outside",
          plot.background = element_rect(fill = "white", colour = NA),
          plot.margin = margin(14, 18, 10, 14))
}
#' Save a figure at report resolution (300 dpi, white background).
save_figure <- function(p, name, w = 10, h = 5.6) {
  ggsave(file.path(out, name), p, width = w, height = h, dpi = 300, bg = "white")
}

# ---- Figure 1: crashes by device within exposure quintiles -------------------
crossings_all <- load_crossings("ALL") |>
  mutate(device = factor(recode(as.character(device), passive = "Passive",
                                lights = "Flashing lights", gates = "Gates"),
                         levels = names(col_dev)))
qlab <- c("1\nlowest", "2", "3", "4", "5\nhighest")
banded <- crossings_all |>
  filter(aadt * trains_per_day > 0) |>
  mutate(q = cut(log(aadt * trains_per_day),
                 quantile(log(aadt * trains_per_day), 0:5 / 5),
                 include.lowest = TRUE, labels = qlab)) |>
  group_by(q, device) |> summarise(rate = mean(crashes), .groups = "drop") |>
  mutate(panel = "Within exposure quintiles")
overall <- crossings_all |> group_by(device) |> summarise(rate = mean(crashes), .groups = "drop") |>
  mutate(q = factor("All"), panel = "All crossings")
f1 <- bind_rows(overall, banded) |>
  mutate(panel = factor(panel, c("All crossings", "Within exposure quintiles")),
         q = factor(q, c("All", qlab)))
p1 <- ggplot(f1, aes(q, rate, fill = device)) +
  geom_rect(data = data.frame(panel = factor("Within exposure quintiles",
                                             levels(f1$panel))),
            aes(xmin = 1.5, xmax = 4.5, ymin = -Inf, ymax = Inf),
            inherit.aes = FALSE, fill = "#EEF3FA") +
  geom_col(position = position_dodge(width = 0.8), width = 0.72) +
  facet_grid(~ panel, scales = "free_x", space = "free_x") +
  scale_fill_manual(values = col_dev) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.06))) +
  labs(title = "Gates look riskier overall, but not at similar exposure",
       subtitle = "Mean crashes per crossing, 2016–2025. Shaded: quintiles 2–4, where gated crossings\nhave fewer crashes than passive ones.",
       x = "Exposure quintile (vehicles per day × trains per day)", y = "Crashes per crossing",
       caption = "Data: FRA Forms 57 and 71; 120,211 public crossings.") +
  theme_report() + theme(panel.grid.major.x = element_blank())
save_figure(p1, "fig1_exposure.png")

# ---- Figure 2: posterior predictive checks -----------------------------------
ppc_file <- file.path(OUTPUT_DIR, "ALL", "ppc_stats.csv")   # written by 03_fit_models.R ALL
ppc <- read_csv(ppc_file, show_col_types = FALSE) |>
  pivot_longer(c(zero, max), names_to = "stat") |>
  mutate(value = ifelse(stat == "zero", 100 * value, value),
         stat = factor(stat, c("zero", "max"),
                       c("Share of crossings with no crash (%)", "Largest crash count at any crossing")),
         model = factor(model, c("Poisson", "Hierarchical negative binomial")))
obs <- data.frame(stat = levels(ppc$stat), value = c(100 * mean(crossings_all$crashes == 0), max(crossings_all$crashes))) |>
  mutate(stat = factor(stat, levels(ppc$stat)))
p2 <- ggplot(ppc, aes(value, fill = model)) +
  geom_histogram(bins = 30, colour = "white", linewidth = 0.2, alpha = 0.9) +
  geom_vline(data = obs, aes(xintercept = value), colour = col_hi, linewidth = 1.1) +
  geom_text(data = obs, aes(x = value, y = Inf, label = "observed"), inherit.aes = FALSE,
            colour = col_hi, vjust = 1.6, hjust = -0.08, size = 4.6, fontface = "bold") +
  facet_wrap(~ stat, scales = "free", ncol = 2) +
  scale_fill_manual(values = c(Poisson = col_raw, `Hierarchical negative binomial` = "#1F5FA8")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "The hierarchical model reproduces the data; Poisson does not",
       subtitle = "Each bar counts datasets simulated from the posterior. The orange line is the real data.",
       x = NULL, y = "Simulated datasets") +
  theme_report() + theme(panel.grid.major.x = element_blank(), axis.text.y = element_blank())
save_figure(p2, "fig2_ppc.png")

# ---- Figure 3: raw vs adjusted rate ratios -----------------------------------
raw <- bind_rows(lapply(c(TX = "TX", ALL = "ALL"), function(s) {
  scope_data <- load_crossings(s)
  mean_crashes <- tapply(scope_data$crashes, scope_data$device, mean)
  tibble(scope = s, device = c("Flashing lights", "Gates"),
         median = c(mean_crashes["lights"], mean_crashes["gates"]) / mean_crashes["passive"], lo95 = NA, hi95 = NA,
         type = "Raw comparison")
}))
adj <- bind_rows(lapply(c("TX", "ALL"), function(s) {
  read_csv(file.path("outputs", s, "device_rate_ratios.csv"), show_col_types = FALSE) |>
    mutate(scope = s, device = ifelse(grepl("Gates", device), "Gates", "Flashing lights"),
           type = "Bayesian model, same exposure")
}))
f3 <- bind_rows(raw, select(adj, scope, device, median, lo95, hi95, type)) |>
  mutate(scope = factor(recode(scope, TX = "Texas", ALL = "United States"),
                        c("Texas", "United States")),
         device = factor(paste(device, "vs. passive"), c("Gates vs. passive", "Flashing lights vs. passive")),
         type = factor(type, c("Raw comparison", "Bayesian model, same exposure")),
         lab = sprintf("%.2f", median))
p3 <- ggplot(f3, aes(median, scope, colour = type)) +
  geom_vline(xintercept = 1, colour = col_soft, linetype = "dashed") +
  geom_errorbar(aes(xmin = lo95, xmax = hi95), width = 0, orientation = "y", linewidth = 1.4, na.rm = TRUE,
                 position = position_dodge(width = 0.5)) +
  geom_point(size = 4.2, position = position_dodge(width = 0.5)) +
  geom_text(aes(label = lab), position = position_dodge(width = 0.5), vjust = -1.1,
            size = 4.4, show.legend = FALSE) +
  facet_wrap(~ device, ncol = 1) +
  scale_x_log10(breaks = c(0.3, 0.5, 0.75, 1, 1.5, 2, 3), limits = c(0.28, 3)) +
  scale_colour_manual(values = c("Raw comparison" = col_raw,
                                 "Bayesian model, same exposure" = "#1F5FA8")) +
  coord_cartesian(clip = "off") +
  labs(title = "Raw data make gates look harmful; adjusted, they cut crashes ~59%",
       subtitle = "Crash rate ratio relative to passive crossings (log scale). Lines: 95% credible intervals.",
       x = "Crash rate ratio (below 1 = fewer crashes)", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank())
save_figure(p3, "fig3_rate_ratios.png", h = 6.4)

# ---- Figure 4: prior sensitivity -----------------------------------------------
f4 <- read_csv("outputs/TX/prior_sensitivity.csv", show_col_types = FALSE) |>
  filter(!grepl("county", quantity)) |>
  mutate(prior = factor(prior, rev(c("Baseline: N(0, 1)", "Wide: N(0, 2.5)", "Tight: N(0, 0.5)",
                                     "Skeptical device prior", "Optimistic gate prior")),
                        rev(c("Baseline  N(0, 1)", "Wide  N(0, 2.5)", "Tight  N(0, 0.5)",
                              "Skeptical (devices do little)", "Optimistic (gates −75%)"))),
         quantity = factor(ifelse(grepl("Gates", quantity), "Gates vs. passive", "Flashing lights vs. passive"),
                           c("Gates vs. passive", "Flashing lights vs. passive")),
         base = grepl("Baseline", prior), lab = sprintf("%.2f", median))
p4 <- ggplot(f4, aes(median, prior, colour = base)) +
  geom_vline(xintercept = 1, colour = col_soft, linetype = "dashed") +
  geom_errorbar(aes(xmin = lo95, xmax = hi95), width = 0, orientation = "y", linewidth = 1.3) +
  geom_point(size = 3.8) +
  geom_text(aes(label = lab), vjust = -1, size = 4.2, show.legend = FALSE) +
  facet_wrap(~ quantity) +
  scale_x_log10(breaks = c(0.25, 0.5, 1, 2), limits = c(0.25, 2)) +
  scale_colour_manual(values = c(`TRUE` = "#1F5FA8", `FALSE` = col_ink), guide = "none") +
  labs(title = "The gate estimate barely moves under five different priors",
       subtitle = "Texas model: posterior median and 95% credible interval of each rate ratio.",
       x = "Crash rate ratio relative to passive crossings (log scale)", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank(), panel.spacing.x = unit(3, "lines"))
save_figure(p4, "fig4_priors.png", h = 5.2)

# ---- Figure 5: county risk multipliers ---------------------------------------
cm <- read_csv("outputs/ALL/county_risk_multipliers.csv", show_col_types = FALSE,
               col_types = cols(countycode = col_character()))
top <- cm |> arrange(desc(crossings)) |> slice_head(n = 20)
f5 <- bind_rows(top, filter(cm, countyname == "HARRIS", statename == "TEXAS")) |>
  distinct(countycode, .keep_all = TRUE) |>
  mutate(label = paste0(tools::toTitleCase(tolower(countyname)), ", ",
                        state.abb[match(tools::toTitleCase(tolower(statename)), state.name)]),
         harris = countyname == "HARRIS" & statename == "TEXAS",
         label = reorder(label, mult_median))
p5 <- ggplot(f5, aes(mult_median, label, colour = harris)) +
  geom_vline(xintercept = 1, colour = col_soft, linetype = "dashed") +
  geom_errorbar(aes(xmin = mult_lo95, xmax = mult_hi95), width = 0, orientation = "y", linewidth = 1.1) +
  geom_point(size = 3.2) +
  geom_text(data = filter(f5, harris), aes(x = mult_lo95, label = sprintf("%.1f× predicted", mult_median)),
            hjust = 1.08, size = 4.6, fontface = "bold") +
  scale_x_log10(breaks = c(0.5, 1, 2, 3, 4)) +
  scale_colour_manual(values = c(`TRUE` = col_hi, `FALSE` = "#5B7FA8"), guide = "none") +
  labs(title = "Harris County (Houston) has the highest risk beyond its traffic",
       subtitle = "Crash rate relative to the model's prediction, for the 20 counties with the\nmost crossings plus Harris. 1 = as predicted from traffic and design.\nLog scale; lines are 95% credible intervals.",
       x = "Risk multiplier", y = NULL) +
  theme_report(14) + theme(panel.grid.major.y = element_blank(),
                           axis.text.y = element_text(colour = col_ink))
save_figure(p5, "fig5_counties.png", h = 7)

cat("Wrote 5 figures to", out, "\n")
