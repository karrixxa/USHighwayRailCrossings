# Ranking Crash Risk at U.S. Highway–Rail Crossings

A hierarchical Bayesian analysis of ten years (2016–2025) of collisions at 120,211 public highway–rail crossings, using public data from the Federal Railroad Administration (FRA). STAT 425 final project, Charis Xiong.

The project asks three questions:

1. **Warning devices.** Do gates and flashing lights reduce crashes once road traffic, train traffic and crossing design are taken into account?
2. **Prioritization.** Which crossings without gates should be upgraded first, and does a Bayesian ranking pick crossings that go on to have more crashes?
3. **Geography.** How much does risk vary between states and counties beyond what traffic explains, and does Houston stand out?

## Main results

| Finding | Estimate |
| --- | --- |
| Gates vs. signs only, same exposure (national) | crash rate ratio 0.41 (95% CrI 0.38–0.43), about 59% fewer crashes |
| Flashing lights vs. signs only (national) | 0.79 (0.74–0.85) |
| Gate effect across five priors (Texas) | 0.34–0.40 |
| Harris County (Houston) vs. its predicted risk | 3.2 times (2.6–3.9), 18th of 2,680 counties |
| Out-of-time test of the ranking (Texas) | ties ranking by past crashes; both find about 3 times the future crashes of ranking by traffic |

In the raw data, gated crossings have 2.4 times as many crashes as sign-only crossings, because gates go where traffic is heaviest. The model compares crossings at the same exposure. The full write-up is in [report/](report/).

## Repository layout

```
├── README.md
├── run_all.sh                  # runs the whole pipeline (or a Texas-only demo)
├── requirements.txt            # Python packages
├── install_packages.R          # R packages, including CmdStan
├── R/
│   └── utils.R                 # shared R helpers: data loading, priors, model summaries
├── scripts/
│   ├── common.py               # shared Python paths, settings and cleaning helpers
│   ├── 01_download_data.py     # download the FRA data
│   ├── 02_build_dataset.py     # clean and join into one row per crossing
│   ├── 03_fit_models.R         # fit and check the Poisson, NB and hierarchical NB models
│   ├── 04_prior_sensitivity.R  # refit under five priors (Texas)
│   ├── 05_upgrade_priorities.R # expected crashes avoided if gated; compare rankings
│   ├── 06_county_effects.R     # county risk multipliers (national)
│   ├── 07_build_texas_snapshots.py  # Texas crossings as they stood in 2015 and 2020
│   ├── 08_robustness_texas.R   # out-of-time test, gate-effect and Houston checks
│   ├── 09_make_figures.R       # the five report figures
│   ├── 10_make_equation.py     # typeset model equation image
│   └── 11_build_report_docx.py # Markdown report -> Word
├── data/                       # not in the repository; created by script 01 (see data/README.md)
├── outputs/                    # result tables (CSV) and figures; model fits are not committed
└── report/                     # report source (Markdown), Word and PDF versions
```

## Installation

You need Python 3.9+ and R 4.3+.

```bash
git clone https://github.com/karrixxa/USHighwayRailCrossings.git
cd USHighwayRailCrossings
python -m pip install -r requirements.txt
Rscript install_packages.R
```

`install_packages.R` installs brms, rstan, loo, posterior, dplyr, tidyr, readr and ggplot2 from CRAN, plus cmdstanr and CmdStan, which the national model uses. CmdStan needs a C++ toolchain (Xcode Command Line Tools on macOS, Rtools on Windows).

## Data

The data are public and are not stored in the repository (about 150 MB). `scripts/01_download_data.py` downloads exactly the rows and columns used, through the data.transportation.gov API, into `data/raw/`:

| File | Source dataset | Contents |
| --- | --- | --- |
| `inventory_public_atgrade.csv` | [Crossing Inventory (Form 71), Current](https://data.transportation.gov/d/m2f8-22s6) | open, public, at-grade highway crossings |
| `inventory_train_freq.csv` | same | the "less than one train a day" flag |
| `incidents_2015plus.csv` | [Grade Crossing Incident Data (Form 57)](https://data.transportation.gov/d/7wn6-i5b9) | every reported collision since 2015 |
| `inventory_history_TX.csv` | [Crossing Inventory (Form 71), Historical](https://data.transportation.gov/d/vhwz-raag) | every past revision of Texas crossing records |

FRA updates these datasets, so a fresh download can differ slightly from the November 2026 version used in the report. See [data/README.md](data/README.md) for details.

## Usage

Run everything from the repository root.

**Quick demo (Texas only, about 40 minutes):**

```bash
bash run_all.sh demo
```

This downloads the data, builds the dataset, fits the three Texas models, runs the prior sensitivity, the upgrade ranking and the Texas robustness checks. Results land in `outputs/TX/`; for example `outputs/TX/device_rate_ratios.csv` holds the gate and lights rate ratios.

**Full analysis (about 3 hours):**

```bash
bash run_all.sh
```

The national hierarchical model takes most of the time (about 45 minutes of sampling on 8 cores, then about 45 minutes for LOO). Every fit is cached in `outputs/<scope>/fits/`, so reruns skip sampling unless the data or model change.

You can also run the steps one at a time:

| Step | Command | Main outputs | Time |
| --- | --- | --- | --- |
| Download | `python scripts/01_download_data.py` | `data/raw/*.csv` | ~3 min |
| Build dataset | `python scripts/02_build_dataset.py` | `data/processed/crossings.csv` | <1 min |
| Fit models | `Rscript scripts/03_fit_models.R TX` (or `ALL`) | `loo_compare.csv`, `device_rate_ratios.csv`, `ppc_stats.csv`, `crossing_risk_ranking.csv` | 5 min / 1.5 h |
| Prior sensitivity | `Rscript scripts/04_prior_sensitivity.R` | `outputs/TX/prior_sensitivity.csv` | ~6 min |
| Upgrade ranking | `Rscript scripts/05_upgrade_priorities.R TX 50` (or `ALL 200`) | `upgrade_strategies_K*.csv`, `upgrade_top*.csv` | ~2 min |
| County effects | `Rscript scripts/06_county_effects.R` | `outputs/ALL/county_risk_multipliers.csv` | ~2 min |
| Texas snapshots | `python scripts/07_build_texas_snapshots.py` | `data/processed/tx_asof_2015.csv`, `tx_asof_2020.csv` | <1 min |
| Robustness | `Rscript scripts/08_robustness_texas.R` | `outputs/TX/robustness_*.csv` | ~25 min |
| Figures | `Rscript scripts/09_make_figures.R` | `outputs/report_figs/fig1–fig5` | ~1 min |
| Equation | `python scripts/10_make_equation.py` | `outputs/report_figs/eq_model.png` | seconds |
| Word report | `python scripts/11_build_report_docx.py` | `report/STAT425_final_report.docx` | seconds |

The scripts read only relative paths, so the repository works wherever it's cloned. To analyse a different state, change the `TX` filter in `load_crossings()` (`R/utils.R`) and the state in `01_download_data.py`.

## Where each report result comes from

| Report item | Produced by | File |
| --- | --- | --- |
| Data summary, Section 3 | `02_build_dataset.py` | console log, `data/processed/crossings.csv` |
| Figure 1 | `09_make_figures.R` | `outputs/report_figs/fig1_exposure.png` |
| LOO comparison, Section 4.2 | `03_fit_models.R ALL` | `outputs/ALL/loo_compare.csv` |
| Figure 2 | `03_fit_models.R ALL`, `09_make_figures.R` | `outputs/ALL/ppc_stats.csv`, `fig2_ppc.png` |
| Rate ratios, Figure 3 | `03_fit_models.R TX` and `ALL` | `outputs/*/device_rate_ratios.csv`, `fig3_rate_ratios.png` |
| Prior sensitivity, Figure 4 | `04_prior_sensitivity.R` | `outputs/TX/prior_sensitivity.csv`, `fig4_priors.png` |
| 2015-device table, Section 4.3 | `08_robustness_texas.R` | `outputs/TX/robustness_gate_effect.csv` |
| Houston, Figure 5 | `06_county_effects.R`, `08_robustness_texas.R` | `outputs/ALL/county_risk_multipliers.csv`, `outputs/TX/robustness_houston.csv` |
| Upgrade ranking, Section 4.5 | `05_upgrade_priorities.R ALL 200` | `outputs/ALL/upgrade_strategies_K200.csv` |
| Out-of-time table, Section 4.5 | `08_robustness_texas.R` | `outputs/TX/robustness_holdout_asof2020.csv` |

## Method notes

- **Model.** Negative binomial crash counts with log traffic, log trains, log train speed, track count, urban road and a low-traffic flag as predictors, plus random effects for counties (Texas) or for states and counties within states (national). Priors are N(0, 1) on standardized coefficients and half-N(0, 1) on the random-effect SDs.
- **Ranking.** Each crossing's posterior crash rate combines the model's prediction with its own crash count through the gamma-Poisson update (`crossing_rate_draws()` in `R/utils.R`).
- **Efficiency.** Fits are cached and reused; the national model uses within-chain threading; LOO is computed pointwise on 1,000 draws; posterior predictions are drawn in small batches to keep memory under control on a 16 GB laptop; downloads request only the needed columns.
- **Reproducibility.** Every random step uses the seed 425. The cleaning rules (light-rail cutoff, the low-traffic flag, the study years) are set once in `scripts/common.py`.
