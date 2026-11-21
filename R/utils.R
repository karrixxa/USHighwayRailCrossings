# Shared helpers for the R scripts.
#
# Each script starts with `source("R/utils.R")` and is run from the repository
# root, so every path here is relative to that root.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

DEVICE_LEVELS <- c("passive", "lights", "gates")   # passive = signs only, the baseline
OUTPUT_DIR <- "outputs"
SEED <- 425

if (!dir.exists("R") || !dir.exists("scripts")) {
  stop("Run the scripts from the repository root, e.g. `Rscript scripts/03_fit_models.R TX`.")
}


#' Standardize a numeric vector to mean 0 and SD 1.
standardize <- function(x) (x - mean(x)) / sd(x)


#' Add the columns the regression models use.
#'
#' @param crossings Data frame with `device`, `log_aadt`, `log_trains`,
#'   `log_train_speed`, `numberofmaintracks` and `urban`.
#' @return The same data frame with `device` as a factor (passive first),
#'   standardized `z_aadt`, `z_trains`, `z_speed`, and a 0/1 `tracks2` for two
#'   or more main tracks. Standardizing keeps the N(0, 1) priors on a sensible scale.
add_model_columns <- function(crossings) {
  crossings |>
    mutate(device   = factor(device, levels = DEVICE_LEVELS),
           z_aadt   = standardize(log_aadt),
           z_trains = standardize(log_trains),
           z_speed  = standardize(log_train_speed),
           tracks2  = as.integer(numberofmaintracks >= 2),
           urban    = as.integer(urban))
}


#' Load the processed crossings and prepare them for modeling.
#'
#' @param scope "TX" for Texas only or "ALL" for every state.
#' @param file  Processed CSV to read (default: data/processed/crossings.csv).
#' @return A data frame, one row per crossing, ready for brms.
load_crossings <- function(scope = c("TX", "ALL"), file = "data/processed/crossings.csv") {
  scope <- match.arg(scope)
  crossings <- read_csv(file, show_col_types = FALSE,
                        col_types = cols(countycode = col_character()))
  if (scope == "TX") crossings <- filter(crossings, statename == "TEXAS")
  add_model_columns(crossings)
}


#' Folder for one scope's outputs, created if needed (e.g. "outputs/TX").
output_dir <- function(scope) {
  path <- file.path(OUTPUT_DIR, scope)
  dir.create(file.path(path, "fits"), recursive = TRUE, showWarnings = FALSE)
  path
}


#' Baseline weakly informative priors on the log-rate scale.
#'
#' The mean ten-year crash count is about 0.15, so the intercept is centred
#' near log(0.15) = -1.9.
#' @param hierarchical Include a prior for the random-effect SDs?
#' @return A brms prior object.
baseline_priors <- function(hierarchical = TRUE) {
  priors <- c(brms::prior(normal(-2, 2), class = Intercept),
              brms::prior(normal(0, 1), class = b))
  if (hierarchical) priors <- c(priors, brms::prior(normal(0, 1), class = sd))
  priors
}


#' Posterior draws of each crossing's own crash rate, given its crash record.
#'
#' The negative binomial is a gamma-Poisson mixture, so with the model's mean
#' mu_i and dispersion phi, crossing i's rate given its count y_i is
#'   lambda_i | y_i ~ Gamma(phi + y_i, rate = phi / mu_i + 1),
#' a weighted average of the model's prediction and the observed count.
#'
#' @param fit A fitted brms negative-binomial model.
#' @param crossings The data the model was fit to.
#' @param ndraws Number of posterior draws to use.
#' @param outcome Name of the count column (default "crashes").
#' @return Matrix of draws (rows) by crossings (columns), on the same
#'   ten-year scale as the outcome.
crossing_rate_draws <- function(fit, crossings, ndraws, outcome = "crashes") {
  mu  <- brms::posterior_epred(fit, ndraws = ndraws)
  phi <- posterior::as_draws_df(fit)$shape[seq_len(nrow(mu))]
  y   <- matrix(crossings[[outcome]], nrow(mu), ncol(mu), byrow = TRUE)
  matrix(rgamma(length(mu), shape = phi + y, rate = phi / mu + 1), nrow(mu))
}


#' Summarize the warning-device rate ratios from a fitted model.
#'
#' @param fit A fitted brms model with `device` coefficients.
#' @return Tibble with one row per device (vs. passive): posterior median,
#'   95% credible interval, and probability the device lowers crash risk.
device_rate_ratios <- function(fit) {
  draws <- posterior::as_draws_df(fit)
  summarize_one <- function(name, b) {
    tibble(device = name, median = median(exp(b)),
           lo95 = quantile(exp(b), 0.025), hi95 = quantile(exp(b), 0.975),
           p_lt_1 = mean(b < 0))
  }
  bind_rows(summarize_one("Flashing lights vs passive", draws$b_devicelights),
            summarize_one("Gates vs passive", draws$b_devicegates))
}
