# How much riskier is each county than its traffic and design predict?
#
# A county's risk multiplier is exp(state effect + county effect) from the
# national model: 1 means "as predicted", 2 means twice the predicted crashes.
#
# Usage (from the repository root, after 03_fit_models.R ALL):
#   Rscript scripts/06_county_effects.R
#
# Input:  outputs/ALL/fits/nb_hier.rds
# Output: outputs/ALL/county_risk_multipliers.csv, and Harris County's result on screen

source("R/utils.R")

out <- output_dir("ALL")
crossings <- load_crossings("ALL")
fit <- readRDS(file.path(out, "fits", "nb_hier.rds"))

state_effects  <- brms::ranef(fit, summary = FALSE)$statename[, , "Intercept"]
county_effects <- brms::ranef(fit, summary = FALSE)$`statename:countycode`[, , "Intercept"]

counties <- crossings |>
  group_by(statename, countycode, countyname) |>
  summarise(crossings = n(), crashes = sum(crashes), .groups = "drop") |>
  mutate(level = paste(statename, countycode, sep = "_")) |>
  filter(level %in% colnames(county_effects))

multiplier <- exp(state_effects[, counties$statename] + county_effects[, counties$level])
counties <- counties |>
  mutate(mult_median = apply(multiplier, 2, median),
         mult_lo95   = apply(multiplier, 2, quantile, 0.025),
         mult_hi95   = apply(multiplier, 2, quantile, 0.975),
         p_above_1   = colMeans(multiplier > 1)) |>
  select(-level)
write.csv(counties, file.path(out, "county_risk_multipliers.csv"), row.names = FALSE)

harris <- filter(counties, countyname == "HARRIS", statename == "TEXAS")
cat(sprintf("Harris County: %.2f times predicted crashes (95%% CrI %.2f-%.2f); rank %d of %d counties\n",
            harris$mult_median, harris$mult_lo95, harris$mult_hi95,
            sum(counties$mult_median >= harris$mult_median), nrow(counties)))
