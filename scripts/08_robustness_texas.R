# Robustness checks in Texas, using crossings as they stood in the past.
#
#   A. Out-of-time test of the ranking. Fit on 2016-2020 crashes with the
#      inventory as of 2020, pick crossings that had no gates in 2020, and count
#      their real 2021-2025 crashes. No information from after 2020 is used.
#   B. Gate effect with the device fixed in 2015, before the crashes counted.
#   C. Is Harris County's excess risk robust to the model and data choices?
#
# Usage (from the repository root, after 03_fit_models.R TX and
# 07_build_texas_snapshots.py):
#   Rscript scripts/08_robustness_texas.R      # about 25 minutes the first time
#
# Input:  data/processed/tx_asof_2015.csv, tx_asof_2020.csv, crossings.csv
# Output: outputs/TX/robustness_holdout_asof2020.csv   (A)
#         outputs/TX/robustness_gate_effect.csv        (B)
#         outputs/TX/robustness_houston.csv            (C)
#         outputs/TX/robustness_houston_match_rate.csv (C, data quality)

source("R/utils.R")
suppressPackageStartupMessages({
  library(tidyr)
  library(brms)
})
options(mc.cores = 4)
set.seed(SEED)

out <- output_dir("TX")
HARRIS <- "48201"
county_model <- "device + z_aadt + z_trains + z_speed + tracks2 + urban + lt1_train + (1 | countycode)"

#' Fit (or load the cached) Texas hierarchical model.
#' @param name   Cache file name under outputs/TX/fits/.
#' @param outcome Count column to model.
#' @param data   Prepared crossings data.
#' @param extra  Extra terms to add to the formula, e.g. "+ z_hwy".
fit_texas <- function(name, outcome, data, extra = "") {
  brm(bf(as.formula(paste(outcome, "~", county_model, extra))), data = data,
      family = negbinomial(), prior = baseline_priors(),
      chains = 4, iter = 2000, warmup = 1000, seed = SEED, refresh = 0,
      file = file.path(out, "fits", name), file_refit = "on_change")
}

#' Load one of the snapshots built by 07_build_texas_snapshots.py.
load_snapshot <- function(year) {
  read_csv(sprintf("data/processed/tx_asof_%d.csv", year), show_col_types = FALSE,
           col_types = cols(countycode = col_character())) |>
    add_model_columns()
}


# ---- A. Out-of-time test of the ranking --------------------------------------

asof_2020 <- load_snapshot(2020)
m_2020 <- fit_texas("asof2020_train2016_20", "y_2016_20", asof_2020)
asof_2020$post_rate <- colMeans(crossing_rate_draws(m_2020, asof_2020, 1000, outcome = "y_2016_20"))
asof_2020$exposure  <- asof_2020$aadt * asof_2020$trains_per_day
candidates <- filter(asof_2020, device != "gates")

#' Real 2021-2025 crashes at the top K crossings under each ranking, plus a
#' bootstrap of the Bayesian-minus-past-crashes difference.
score_rankings <- function(K) {
  top_bayes <- order(-candidates$post_rate)[1:K]
  top_raw   <- order(-candidates$y_2016_20, -candidates$aadt)[1:K]
  top_expo  <- order(-candidates$exposure)[1:K]
  boot <- replicate(2000, {
    s <- candidates[sample(nrow(candidates), replace = TRUE), ]
    sum(s$y_2021_25[order(-s$post_rate)[1:K]]) -
      sum(s$y_2021_25[order(-s$y_2016_20, -s$aadt)[1:K]])
  })
  tibble(K = K,
         bayesian  = sum(candidates$y_2021_25[top_bayes]),
         raw_count = sum(candidates$y_2021_25[top_raw]),
         exposure  = sum(candidates$y_2021_25[top_expo]),
         bayes_minus_raw_lo90 = quantile(boot, 0.05),
         bayes_minus_raw_hi90 = quantile(boot, 0.95),
         p_bayes_better = mean(boot > 0))
}
holdout <- bind_rows(lapply(c(25, 50, 100, 200), score_rankings))
cat("\nA. Out-of-time test (Texas, inventory as of 2020):\n"); print(holdout)
write.csv(holdout, file.path(out, "robustness_holdout_asof2020.csv"), row.names = FALSE)


# ---- B. Gate effect with the device fixed in 2015 ------------------------------

asof_2015 <- load_snapshot(2015)
# Crossings closed after 2015 stopped being at risk, so their ten-year counts
# aren't comparable; the "still open" sample is the fair comparison.
still_open <- asof_2015 |> filter(!is.na(device_now)) |> add_model_columns()
unchanged  <- asof_2015 |> filter(!is.na(device_now), as.character(device) == device_now) |>
  add_model_columns()

m_main      <- readRDS(file.path(out, "fits", "nb_hier.rds"))
m_2015_all  <- fit_texas("asof2015_y2016_25", "y_2016_25", asof_2015)
m_2015_open <- fit_texas("asof2015_y2016_25_stillopen", "y_2016_25", still_open)
m_2015_same <- fit_texas("asof2015_y2016_25_stable", "y_2016_25", unchanged)

gate_checks <- bind_rows(
  mutate(device_rate_ratios(m_main),      analysis = "Main model (current inventory)", n = nrow(m_main$data)),
  mutate(device_rate_ratios(m_2015_all),  analysis = "Device as of 2015, all 2015 crossings (biased)", n = nrow(asof_2015)),
  mutate(device_rate_ratios(m_2015_open), analysis = "Device as of 2015, crossings still open", n = nrow(still_open)),
  mutate(device_rate_ratios(m_2015_same), analysis = "Device as of 2015, still open and unchanged", n = nrow(unchanged)))
cat("\nB. Gate effect checks:\n"); print(gate_checks, n = Inf)
write.csv(gate_checks, file.path(out, "robustness_gate_effect.csv"), row.names = FALSE)


# ---- C. Harris County ---------------------------------------------------------

texas <- load_crossings("TX") |>
  mutate(z_hwy  = standardize(replace_na(highwayspeedlimit, median(highwayspeedlimit, na.rm = TRUE))),
         lanes2 = as.integer(replace_na(trafficlane, 2) > 2))
worst_10 <- texas |> filter(countycode == HARRIS) |> arrange(desc(crashes)) |> head(10)
# Keep the Texas-wide standardization so this fit differs only by the dropped rows.
without_worst <- texas |> filter(!crossingid %in% worst_10$crossingid)

#' Harris County's risk multiplier relative to the Texas average.
harris_multiplier <- function(model, label) {
  v <- exp(ranef(model, summary = FALSE)$countycode[, HARRIS, "Intercept"])
  tibble(analysis = label, multiplier = median(v),
         lo95 = quantile(v, 0.025), hi95 = quantile(v, 0.975))
}
houston <- bind_rows(
  harris_multiplier(m_main, "Main Texas model"),
  harris_multiplier(fit_texas("houston_extra_covariates", "crashes", texas, "+ z_hwy + lanes2"),
                    "+ road speed limit, more than 2 lanes"),
  harris_multiplier(fit_texas("houston_drop_top10", "crashes", without_worst),
                    "Without Harris County's 10 highest-crash crossings"),
  harris_multiplier(m_2015_all, "Inventory as of 2015"))
cat("\nC. Harris County vs. the Texas average:\n"); print(houston)
write.csv(houston, file.path(out, "robustness_houston.csv"), row.names = FALSE)

# Data-quality check: do Harris County crashes match an inventory record as
# often as crashes elsewhere in Texas?
inventory_ids <- read_csv("data/raw/inventory_public_atgrade.csv", show_col_types = FALSE,
                          col_types = cols(crossingid = col_character()))$crossingid
match_rate <- read_csv("data/raw/incidents_2015plus.csv", show_col_types = FALSE,
                       col_types = cols(gradecrossingid = col_character())) |>
  filter(year >= 2016, year <= 2025, statename == "TEXAS") |>
  mutate(harris = countyname == "HARRIS", matched = gradecrossingid %in% inventory_ids) |>
  group_by(harris) |>
  summarise(incidents = n(), match_rate = mean(matched))
print(match_rate)
write.csv(match_rate, file.path(out, "robustness_houston_match_rate.csv"), row.names = FALSE)
