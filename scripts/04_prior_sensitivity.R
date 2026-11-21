# Prior sensitivity: refit the Texas hierarchical model under five priors.
#
# If the device rate ratios barely move across very different priors, the data
# (not the prior) are driving them.
#
# Usage (from the repository root, after 03_fit_models.R TX):
#   Rscript scripts/04_prior_sensitivity.R       # about 6 minutes
#
# Input:  data/processed/crossings.csv, outputs/TX/fits/nb_hier.rds (reused as the baseline)
# Output: outputs/TX/prior_sensitivity.csv

source("R/utils.R")
suppressPackageStartupMessages(library(brms))
options(mc.cores = 4)

out <- output_dir("TX")
crossings <- load_crossings("TX")
formula <- bf(crashes ~ device + z_aadt + z_trains + z_speed + tracks2 + urban + lt1_train +
                (1 | countycode))

# All priors are on the log-rate scale; exp(-1.39) = 0.25, a 75% reduction.
prior_sets <- list(
  "Baseline: N(0, 1)" = baseline_priors(),
  "Wide: N(0, 2.5)" = c(prior(normal(-2, 5), class = Intercept),
                        prior(normal(0, 2.5), class = b),
                        prior(normal(0, 2.5), class = sd)),
  "Tight: N(0, 0.5)" = c(prior(normal(-2, 2), class = Intercept),
                         prior(normal(0, 0.5), class = b),
                         prior(normal(0, 0.5), class = sd)),
  # A skeptic who thinks devices do little: 95% of the prior mass on rate ratios 0.6-1.6.
  "Skeptical device prior" = c(baseline_priors(),
                               prior(normal(0, 0.25), class = b, coef = devicegates),
                               prior(normal(0, 0.25), class = b, coef = devicelights)),
  # An optimist who thinks gates cut crashes by about 75%.
  "Optimistic gate prior" = c(baseline_priors(),
                              prior(normal(-1.39, 0.25), class = b, coef = devicegates))
)

fits <- lapply(names(prior_sets), function(name) {
  cache <- if (name == "Baseline: N(0, 1)") "nb_hier" else
    paste0("sens_", gsub("[^A-Za-z0-9]+", "_", name))
  cat("Fitting:", name, "\n")
  brm(formula, data = crossings, family = negbinomial(), prior = prior_sets[[name]],
      chains = 4, iter = 2000, warmup = 1000, seed = SEED, refresh = 0,
      file = file.path(out, "fits", cache), file_refit = "on_change")
})
names(fits) <- names(prior_sets)

# Posterior median and 95% interval of each quantity under each prior.
summarize_draws <- function(x) c(median = median(x), lo95 = quantile(x, 0.025, names = FALSE),
                                 hi95 = quantile(x, 0.975, names = FALSE))
summary_table <- bind_rows(lapply(names(fits), function(name) {
  draws <- posterior::as_draws_df(fits[[name]])
  quantities <- list("Gates vs passive (rate ratio)" = exp(draws$b_devicegates),
                     "Flashing lights vs passive (rate ratio)" = exp(draws$b_devicelights),
                     "Between-county SD (log scale)" = draws$sd_countycode__Intercept)
  bind_rows(lapply(names(quantities), function(q) {
    s <- summarize_draws(quantities[[q]])
    tibble(prior = name, quantity = q, median = s[["median"]], lo95 = s[["lo95"]], hi95 = s[["hi95"]])
  }))
}))

print(summary_table, n = Inf)
write.csv(summary_table, file.path(out, "prior_sensitivity.csv"), row.names = FALSE)
