# Fit the crash-count models and check them.
#
# Fits three models with the same predictors: Poisson, negative binomial, and
# the hierarchical negative binomial with county effects (Texas) or state and
# county-within-state effects (all states). Then compares them with LOO, runs
# posterior predictive checks, summarizes the device rate ratios and ranks
# crossings by risk.
#
# Usage (from the repository root):
#   Rscript scripts/03_fit_models.R TX     # Texas, about 5 minutes
#   Rscript scripts/03_fit_models.R ALL    # all states, about 1.5 hours
#
# Input:  data/processed/crossings.csv
# Output: outputs/<scope>/fits/*.rds          fitted models (reused on reruns)
#         outputs/<scope>/loo_compare.csv      model comparison
#         outputs/<scope>/ppc_stats.csv        posterior predictive statistics
#         outputs/<scope>/device_rate_ratios.csv
#         outputs/<scope>/crossing_risk_ranking.csv
#         outputs/<scope>/nb_hier_summary.txt  full model summary

source("R/utils.R")
suppressPackageStartupMessages({
  library(brms)
  library(loo)
})
options(mc.cores = 4)
set.seed(SEED)

scope <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(scope)) scope <- "TX"
out <- output_dir(scope)
crossings <- load_crossings(scope)
is_national <- scope == "ALL"
cat(sprintf("%s: %d crossings, %d crashes, %d counties\n", scope, nrow(crossings),
            sum(crossings$crashes), n_distinct(crossings$countycode)))


# ---- Models -----------------------------------------------------------------

predictors <- "crashes ~ device + z_aadt + z_trains + z_speed + tracks2 + urban + lt1_train"
group_effects <- if (is_national) "(1 | statename) + (1 | statename:countycode)" else "(1 | countycode)"

# `file` caches each fit; it is only refit when the data or model change.
fit_model <- function(name, formula, family, priors, ...) {
  brm(formula, data = crossings, family = family, prior = priors,
      chains = 4, iter = 2000, warmup = 1000, seed = SEED,
      file = file.path(out, "fits", name), file_refit = "on_change", ...)
}

m_poisson <- fit_model("pois_flat", bf(as.formula(predictors)), poisson(),
                       baseline_priors(FALSE), refresh = 0)
m_negbin  <- fit_model("nb_flat", bf(as.formula(predictors)), negbinomial(),
                       baseline_priors(FALSE), refresh = 0)

# The national hierarchical model is slow on the default rstan backend, so it
# uses cmdstanr with two threads per chain (4 chains x 2 threads = 8 cores).
hier_formula <- bf(as.formula(paste(predictors, "+", group_effects)))
m_hier <- if (is_national) {
  fit_model("nb_hier", hier_formula, negbinomial(), baseline_priors(),
            backend = "cmdstanr", threads = threading(2), refresh = 200)
} else {
  fit_model("nb_hier", hier_formula, negbinomial(), baseline_priors(), refresh = 0)
}
capture.output(summary(m_hier), file = file.path(out, "nb_hier_summary.txt"))


# ---- Model comparison (LOO) ---------------------------------------------------

# Nationally, the full log-likelihood matrix would be several GB, so LOO runs
# pointwise on 1,000 draws. The model differences are in the thousands, far
# larger than the extra Monte Carlo error.
loo_draws <- if (is_national) 1000 else NULL
loos <- list(poisson = loo(m_poisson, pointwise = is_national, ndraws = loo_draws),
             nb      = loo(m_negbin,  pointwise = is_national, ndraws = loo_draws),
             nb_hier = loo(m_hier,    pointwise = is_national, ndraws = loo_draws))
comparison <- loo_compare(loos)
print(comparison)
write.csv(as.data.frame(comparison), file.path(out, "loo_compare.csv"))


# ---- Posterior predictive checks -----------------------------------------------

# For each simulated dataset, record the share of crossings with no crash and
# the largest count, the two features a Poisson model gets wrong. Drawing in
# batches of 20 keeps memory low on the national data.
ppc_stats <- function(model, label, n_batches = 10, batch_size = 20) {
  bind_rows(lapply(seq_len(n_batches), function(b) {
    y_rep <- posterior_predict(model, ndraws = batch_size)
    tibble(zero = rowMeans(y_rep == 0), max = apply(y_rep, 1, max), model = label)
  }))
}
ppc <- bind_rows(ppc_stats(m_poisson, "Poisson"),
                 ppc_stats(m_hier, "Hierarchical negative binomial"))
write.csv(ppc, file.path(out, "ppc_stats.csv"), row.names = FALSE)
cat(sprintf("Observed share with no crash: %.3f; observed max: %d\n",
            mean(crossings$crashes == 0), max(crossings$crashes)))
print(ppc |> group_by(model) |> summarise(zero = mean(zero), max = mean(max)))


# ---- Warning-device rate ratios ----------------------------------------------

ratios <- device_rate_ratios(m_hier)
print(ratios)
write.csv(ratios, file.path(out, "device_rate_ratios.csv"), row.names = FALSE)


# ---- Crossing risk ranking ----------------------------------------------------

# Each crossing's own rate blends the model prediction with its crash record
# (see crossing_rate_draws in R/utils.R). 400 draws keeps the national
# draws-by-crossings matrix under 1 GB.
n_draws <- if (is_national) 400 else 1000
rates <- crossing_rate_draws(m_hier, crossings, n_draws)
top_k <- ceiling(0.01 * ncol(rates))
in_top_1pct <- t(apply(rates, 1, function(draw) rank(-draw) <= top_k))

ranking <- crossings |>
  mutate(model_pred_crashes = colMeans(posterior_epred(m_hier, ndraws = n_draws)),
         post_mean_crashes  = colMeans(rates),
         p_top1pct          = colMeans(in_top_1pct),
         raw_rank           = rank(-crashes, ties.method = "min"),
         post_rank          = rank(-post_mean_crashes, ties.method = "min")) |>
  arrange(desc(p_top1pct)) |>
  select(crossingid, countyname, cityname, device, aadt, trains_per_day, crashes,
         model_pred_crashes, post_mean_crashes, p_top1pct, raw_rank, post_rank)
write.csv(ranking, file.path(out, "crossing_risk_ranking.csv"), row.names = FALSE)

top_overlap <- mean(head(ranking$crossingid[order(ranking$raw_rank)], top_k) %in%
                    head(ranking$crossingid[order(ranking$post_rank)], top_k))
cat(sprintf("Share of the raw top 1%% that stays in the posterior top 1%%: %.0f%%\n",
            100 * top_overlap))
cat("Done. Outputs in", out, "\n")
