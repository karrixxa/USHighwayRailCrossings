# Install the R packages the analysis needs.
#
#   Rscript install_packages.R
#
# The national model also uses CmdStan through cmdstanr; the last lines
# install it (a one-time download and compile of about 10 minutes).

cran_packages <- c("brms", "rstan", "loo", "posterior", "dplyr", "tidyr", "readr", "ggplot2")
missing <- setdiff(cran_packages, rownames(installed.packages()))
if (length(missing) > 0) install.packages(missing, repos = "https://cloud.r-project.org")

if (!requireNamespace("cmdstanr", quietly = TRUE)) {
  install.packages("cmdstanr", repos = c("https://stan-dev.r-universe.dev",
                                         "https://cloud.r-project.org"))
}
if (is.null(cmdstanr::cmdstan_version(error_on_NA = FALSE))) cmdstanr::install_cmdstan()
