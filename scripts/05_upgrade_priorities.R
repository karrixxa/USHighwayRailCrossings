# Which crossings should get gates first?
#
# For every crossing without gates, estimate the crashes per year that gates
# would prevent:
#   avoided_i = (lambda_i / 10) * (1 - exp(b_gates - b_current_i))
# where lambda_i is the crossing's own ten-year crash rate given its record and
# b_current_i is 0 for passive crossings or b_lights for flashing lights.
# This treats the adjusted gate effect as causal and the same everywhere; the
# report discusses that assumption.
#
# Then compare three ways to pick K crossings: highest expected crashes avoided
# (Bayesian), most past crashes, and most exposure (vehicles x trains).
#
# Usage (from the repository root, after 03_fit_models.R):
#   Rscript scripts/05_upgrade_priorities.R TX 50
#   Rscript scripts/05_upgrade_priorities.R ALL 200
#
# Input:  outputs/<scope>/fits/nb_hier.rds
# Output: outputs/<scope>/upgrade_strategies_K<K>.csv  crashes avoided per year by strategy
#         outputs/<scope>/upgrade_top<K>.csv           the Bayesian top K crossings

source("R/utils.R")
set.seed(SEED)

args  <- commandArgs(trailingOnly = TRUE)
scope <- if (length(args) >= 1) args[1] else "TX"
K     <- if (length(args) >= 2) as.integer(args[2]) else if (scope == "TX") 50L else 200L
out   <- output_dir(scope)

crossings <- load_crossings(scope)
fit <- readRDS(file.path(out, "fits", "nb_hier.rds"))
n_draws <- if (scope == "ALL") 400 else 1000

rates <- crossing_rate_draws(fit, crossings, n_draws)     # draws x crossings, ten-year rate
draws <- posterior::as_draws_df(fit)[seq_len(n_draws), ]

# Relative reduction from adding gates, per draw, for each candidate crossing.
candidates <- which(crossings$device != "gates")
reduction <- sapply(candidates, function(i) {
  if (crossings$device[i] == "lights") 1 - exp(draws$b_devicegates - draws$b_devicelights)
  else 1 - exp(draws$b_devicegates)
})
avoided <- rates[, candidates] / 10 * reduction           # crashes avoided per year

candidate_table <- crossings[candidates, ] |>
  mutate(avoid_mean = colMeans(avoided),
         avoid_lo90 = apply(avoided, 2, quantile, 0.05),
         avoid_hi90 = apply(avoided, 2, quantile, 0.95),
         exposure   = aadt * trains_per_day)
in_top_k <- t(apply(avoided, 1, function(draw) rank(-draw, ties.method = "first") <= K))
candidate_table$p_topK <- colMeans(in_top_k)

picks <- list(
  "Bayesian (expected crashes avoided)" = order(-candidate_table$avoid_mean)[1:K],
  "Raw crash count"                     = order(-candidate_table$crashes, -candidate_table$aadt)[1:K],
  "Highest exposure (cars x trains)"    = order(-candidate_table$exposure)[1:K]
)
strategies <- bind_rows(lapply(names(picks), function(name) {
  total <- rowSums(avoided[, picks[[name]], drop = FALSE])
  tibble(strategy = name, mean = mean(total),
         lo90 = quantile(total, 0.05), hi90 = quantile(total, 0.95))
}))
print(strategies)
write.csv(strategies, file.path(out, sprintf("upgrade_strategies_K%d.csv", K)), row.names = FALSE)

top <- candidate_table[picks[[1]], ] |>
  select(crossingid, statename, countyname, cityname, device, aadt, trains_per_day,
         crashes, avoid_mean, avoid_lo90, avoid_hi90, p_topK)
write.csv(top, file.path(out, sprintf("upgrade_top%d.csv", K)), row.names = FALSE)
print(head(top, 10))
