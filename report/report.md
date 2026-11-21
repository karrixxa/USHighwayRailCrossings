# Ranking Crash Risk at U.S. Highway–Rail Crossings: A Hierarchical Bayesian Approach

STAT 425 Final Report · Charis Xiong (cx25) · December 2026

## 1. Statement of the problem

From 2016 to 2024, U.S. highway–rail crossings averaged about 2,150 collisions and 250 deaths a year, according to FRA figures compiled by Operation Lifesaver (2026). Agencies cannot upgrade all 124,280 open public highway crossings in FRA's inventory, so they need two estimates that raw data handle poorly: how risky each crossing really is, and how much warning devices such as gates reduce that risk. This project makes both estimates with a hierarchical Bayesian model and asks three questions:

1. **Warning devices.** Do gates and flashing lights reduce crashes once road traffic, train traffic and crossing design are taken into account?
2. **Prioritization.** Which non-gated crossings should be upgraded first, and does a Bayesian ranking find crossings that go on to have more crashes than simpler rankings?
3. **Geography.** How much does risk vary between states and counties beyond what traffic explains, and does Harris County (Houston) stand out?

## 2. Introduction and background

Two features of crossing data make a naive analysis misleading.

**Crashes are rare at any single crossing.** In my sample, 89.7% of crossings had no crash in ten years (Section 3). A crossing's count is therefore a noisy measure of its risk: one unlucky collision makes a quiet crossing look dangerous, and ranking crossings by recent crashes invites regression to the mean.

**Warning devices are not assigned at random.** Federal guidance tells agencies to consider gates where exposure or predicted risk is high, for example at crossings with 20 or more trains a day, more than 2,000 vehicles a day in urban areas (500 in rural areas), multiple tracks, or a high predicted crash frequency that includes the last five years of crashes (FHWA, 2007, p. 148). Gates therefore sit where traffic is heaviest and crashes have already occurred, so raw comparisons make gates look harmful.

Agencies address noisy counts with *safety performance functions*, regression models of a site's expected crashes, combined with the site's own crash history through the *empirical Bayes* method to correct for regression to the mean (TxDOT, HSM Part C). FRA introduced a new crossing prediction model in 2020 (Brod and Gillen, 2020), and Mathew, Benekohal and Medina (2019) found that negative-binomial predictions adjusted by empirical Bayes outperformed the older U.S. DOT models.

This project fits a fully Bayesian version of that approach. A hierarchical negative-binomial model includes exposure and design covariates, so devices are compared at similar exposure, and state and county random effects, so sparse areas borrow strength from the rest of their state. Its gamma-Poisson form gives each crossing a posterior crash rate that blends the model's prediction with the crossing's own history: the empirical Bayes idea, with full posterior uncertainty. I became interested in the topic through a capstone project with the Houston Fire Department on blocked crossings; this project uses different data to ask where crashes are most likely nationwide.

## 3. Data collection and description

All data are public Federal Railroad Administration (FRA) records from data.transportation.gov: the Crossing Inventory (Form 71), with each crossing's warning device, traffic, train counts, train speed and tracks; the Grade Crossing Incident Data (Form 57), with one record per collision; and, for the robustness checks, the historical inventory, which keeps every past revision of each crossing record. Records are linked by crossing ID.

**Sample.** The unit of analysis is a crossing, and the outcome is its number of collisions from 2016 to 2025. I started from 124,280 open, public, at-grade highway crossings. Of the 21,680 collisions in those years, 17,889 (83%) match one of them; most of the rest are at private or since-closed crossings. Three cleaning steps removed crossings with untrustworthy key values:

| Step | Crossings removed | Reason |
| --- | --- | --- |
| Zero trains per day, no FRA flag for "less than one train per day" | 2,370 | Train count cannot be verified |
| Missing traffic, train speed or track data | 1,057 | Needed as predictors |
| 100 or more trains per day | 638 | Light-rail corridors, whose collisions FRA largely does not record |

FRA records lines with fewer than one train per day as zero trains and flags them; I set the 21,443 flagged crossings to 0.5 trains per day and added an indicator. The final sample has **120,211 crossings** in 50 states and 2,680 counties, with **17,441 crashes**. Predictors are log vehicles per day and log trains per day (exposure), the warning device (gates, flashing lights or passive), log maximum train speed, two or more main tracks, urban road and the less-than-one-train flag. States and counties are the grouping levels.

**Descriptive summary.** Counts are sparse: 89.7% of crossings had no crash, 9,457 had one, and the maximum was 30. The device groups differ far more in exposure than in crash rates:

| Device | Crossings | Crashes | Mean crashes per crossing | Median vehicles per day | Median trains per day | Median train speed (mph) |
| --- | --- | --- | --- | --- | --- | --- |
| Gates | 54,329 | 11,149 | 0.205 | 1,245 | 8 | 45 |
| Flashing lights | 15,095 | 1,994 | 0.132 | 1,320 | 2 | 20 |
| Passive | 50,787 | 4,298 | 0.085 | 111 | 2 | 25 |

Gated crossings have 2.4 times the crashes of passive ones, but about 11 times the road traffic, four times the trains and faster trains. Figure 1 groups crossings by exposure (vehicles per day times trains per day). Within the middle three quintiles, where most crossings fall, gated crossings have fewer crashes than passive ones. Section 4 makes this comparison formally.

[Figure 1: mean crashes per crossing by warning device, overall and within exposure quintiles. File: outputs/report_figs/fig1_exposure.png]

## 4. Data analysis and results

**4.1 Model.** For crossing *i* in county *c* of state *s*, the ten-year crash count is modeled as

[Equation. File: outputs/report_figs/eq_model.png]

Here x holds standardized log vehicles per day, log trains per day and log train speed, plus indicators for two or more tracks, an urban road and fewer than one train per day; γ is the effect of the crossing's warning device, with passive crossings as the baseline; and u and v are state and county random effects with standard deviations σs and σc. So exp(γ) for gates is the crash rate ratio for gated versus passive crossings at the same exposure and design. Priors are N(−2, 2) on the intercept (the mean count is about 0.15, and log 0.15 ≈ −1.9), N(0, 1) on coefficients, half-N(0, 1) on σs and σc, and the brms default inverse-gamma(0.4, 0.3) on the dispersion φ. I fit the model in brms with CmdStan: 4 chains of 1,000 warmup and 1,000 sampling iterations. All R-hat values are at most 1.012 (1.006 for σs, with bulk effective sample size 1,084), with no divergent transitions. Simpler Poisson and non-hierarchical negative-binomial models with the same predictors serve as baselines.

**4.2 Model checking.** Leave-one-out cross-validation strongly prefers the hierarchical model: the non-hierarchical negative binomial is worse by 1,135 in expected log predictive density (SE 51) and the Poisson by 3,789 (SE 187). Only 10 of 120,211 crossings had Pareto k above 0.67. Posterior predictive checks show why (Figure 2). The Poisson model predicts about 87.8% of crossings with no crash against an observed 89.7%, and its largest simulated count is around 7–12 against an observed 30. The hierarchical model reproduces both. The estimated dispersion φ = 0.71 confirms strong overdispersion.

[Figure 2: posterior predictive checks. Left: share of crossings with no crash; right: largest crash count at any crossing. Grey: Poisson; blue: hierarchical negative binomial. The orange line is the observed value. File: outputs/report_figs/fig2_ppc.png]

**4.3 Warning devices.** At the same exposure and design, gated crossings have a crash rate ratio of **0.41 (95% CrI 0.38–0.43)** relative to passive crossings, about 59% fewer crashes, and flashing lights have 0.79 (0.74–0.85), about 21% fewer (Figure 3). The raw ratio for gates was 2.4. Exposure drives risk strongly: a one-standard-deviation increase multiplies the crash rate by 1.83 for log vehicles, 1.62 for log trains and 1.92 for log train speed; two or more tracks and an urban road each raise it by about 35%.

[Figure 3: crash rate ratios versus passive crossings, raw and model-adjusted, for Texas and the nation (95% credible intervals). File: outputs/report_figs/fig3_rate_ratios.png]

The gate estimate barely depends on the prior. In Texas, refits under wide N(0, 2.5), tight N(0, 0.5), skeptical (gate and lights coefficients N(0, 0.25), meaning devices do little) and optimistic (gates N(log 0.25, 0.25)) priors give gate ratios from 0.34 to 0.40 (Figure 4). Even the skeptical prior, which puts 95% of its mass on ratios between 0.6 and 1.6, cannot pull the estimate near 1.

[Figure 4: Texas posterior medians and 95% credible intervals under five prior choices. File: outputs/report_figs/fig4_priors.png]

Because gates are often installed after crashes, I also fixed each Texas crossing's device as of December 31, 2015, using FRA's historical inventory, and counted crashes from 2016 to 2025:

| Texas sample | Crossings | Gates vs. passive (95% CrI) |
| --- | --- | --- |
| Main model, current inventory | 8,854 | 0.36 (0.30–0.43) |
| Device as of 2015, crossings still open | 7,789 | 0.45 (0.37–0.55) |
| Device as of 2015, still open and device unchanged | 6,633 | 0.36 (0.29–0.45) |
| Device as of 2015, all 2015 crossings | 12,171 | 0.80 (0.67–0.97) |

The last row is biased: 3,304 passive crossings closed after 2015 had almost no crashes (rate 0.007) because they stopped being at risk, which makes passive crossings look safer. With comparable exposure periods, gates are associated with 55–64% fewer crashes. The prospective estimate of 0.45 is conservative, since crossings upgraded after 2015 are counted under their old device. The Texas estimate for flashing lights is unstable across these samples (0.64 to 1.32), so I rely on the national estimate.

**4.4 Geography.** Risk varies more between counties than between states: σc = 0.46 (0.42–0.49) and σs = 0.33 (0.26–0.43). A typical county's crash rate differs from its state's by a factor of about 1.6 after adjusting for traffic and design. Harris County stands out at **3.20 times** its predicted risk (2.64–3.89), 18th of 2,680 counties and the highest among the 20 counties with the most crossings (Figure 5). The excess holds in Texas-only checks: 2.7 times in the main model, 2.7 times after adding road speed limit and lane count, 2.2 times after removing Harris County's 10 highest-crash crossings, and 2.3 times using the 2015 inventory. Harris County incidents match an inventory crossing about as often as the rest of Texas (78% versus 81%), so the excess is not a record-matching artifact.

[Figure 5: county crash risk relative to the model's prediction for Harris County and the 20 counties with the most crossings (95% credible intervals). File: outputs/report_figs/fig5_counties.png]

**4.5 Ranking crossings for upgrades.** Each crossing's posterior crash rate combines the model's prediction with its own count through the gamma-Poisson update. Pooling moves noisy counts: 78% of the raw top-1% crossings stay in the posterior top 1%, and a Houston crossing with 12 crashes (755327J) is estimated at 6.2 for the decade. Gating the 200 non-gated crossings with the highest expected crashes avoided would prevent an estimated 23.4 crashes a year nationally (90% CrI 21.7–25.0), compared with 21.0 for the 200 with the most past crashes and 6.7 for the 200 with the most exposure. This comparison uses the model's own estimates and assumes the gate effect is causal and constant.

To test the ranking without that assumption, I rebuilt Texas crossings as of December 31, 2020, fit the model to 2016–2020 crashes, picked crossings without gates in 2020, and counted their actual crashes in 2021–2025:

| Crossings picked | Bayesian ranking | Most 2016–20 crashes | Most exposure | P(Bayesian better), bootstrap |
| --- | --- | --- | --- | --- |
| 25 | 19 | 18 | 3 | 0.45 |
| 50 | 36 | 32 | 11 | 0.69 |
| 100 | 64 | 46 | 20 | 0.99 |
| 200 | 75 | 80 | 24 | 0.22 |

The Bayesian ranking roughly ties ranking by past crashes: it is clearly better at 100 picks and slightly worse at 200. Both find about three times as many future crashes as ranking by exposure alone.

## 5. Summary and discussion

Three findings answer the questions in Section 1.

1. **Raw data point the wrong way on warning devices.** Gated crossings have 2.4 times as many crashes as passive ones, but at the same exposure and design they are associated with about 59% fewer crashes nationally (rate ratio 0.41, 95% CrI 0.38–0.43) and 55–64% fewer in Texas across priors and sample definitions. Flashing lights are associated with about 21% fewer crashes. A comparison that ignores exposure would reach the opposite conclusion.
2. **Location matters beyond traffic.** County effects vary by a factor of about 1.6, and Harris County runs 2.2–3.2 times its predicted risk under every check. That points to local factors the inventory does not record.
3. **For prioritizing upgrades, the Bayesian ranking is as good as crash history, with more to offer.** On crashes the model never saw, it roughly ties ranking by past crashes, and both find about three times as many future crashes as ranking by traffic. The model adds what counts alone cannot: an uncertainty for every crossing, protection against regression to the mean, and usable estimates for the 90% of crossings with no crash history.

In practice, these results support prioritizing crossings with models that combine exposure and crash history rather than traffic alone, treating passive crossings with heavy exposure as strong candidates for gates, and investigating why Houston's crossings are riskier than their traffic predicts.

**Limitations.**

- The data are observational, so the gate estimate is an adjusted association, not a proven causal effect. Agencies choose where to install gates, partly on risk factors the model cannot see. The checks with 2015 devices narrow this concern but do not remove it.
- Traffic and train counts are reported by railroads and states and are often several years old, so exposure is measured with error.
- Each crossing's ten-year total ignores changes within the period, such as upgrades, closures and traffic growth, and 17% of collisions occurred at crossings no longer in the current inventory.
- The leak-free validation and robustness checks cover Texas only, because they require rebuilding each crossing's history.
- Light-rail crossings were excluded because FRA does not fully record their collisions.

**Future work.** The next step is a yearly panel built from the historical inventory nationwide, so each crossing's device and traffic can change over time and the device effect can be estimated from upgrades directly. Other extensions are spatial random effects that let neighboring counties share information, a separate model for fatal crashes, and a cost-effectiveness ranking that weighs expected crashes avoided against upgrade costs. For Houston, linking crash risk to how long crossings stay blocked would test one explanation for the county's excess risk.

## 6. Appendix: code and reproducibility

All code is at https://github.com/karrixxa/USHighwayRailCrossings. It is written in R (modeling and figures) and Python (data download, cleaning and the Word report) and runs from the repository root. `bash run_all.sh` runs the full pipeline; `bash run_all.sh demo` runs a Texas-only version in about 40 minutes. The README lists installation steps, data sources and which script produces each table and figure.

| Script | What it does | Run time |
| --- | --- | --- |
| 01_download_data.py | Downloads the FRA inventory, incident and Texas history data | ~3 min |
| 02_build_dataset.py | Cleans and joins; writes one row per crossing | <1 min |
| 03_fit_models.R TX / ALL | Poisson, negative-binomial and hierarchical fits; LOO; posterior predictive checks; rate ratios; ranking | 5 min / ~1.5 h |
| 04_prior_sensitivity.R | Texas refits under five prior sets | ~6 min |
| 05_upgrade_priorities.R | Expected crashes avoided if gated; ranking comparison | ~2 min |
| 06_county_effects.R | County risk multipliers (national fit) | ~2 min |
| 07_build_texas_snapshots.py | Texas inventory as of 2015 and 2020 from the historical file | <1 min |
| 08_robustness_texas.R | Out-of-time ranking test, gate-effect and Houston checks | ~25 min |
| 09_make_figures.R | Figures 1–5 | ~1 min |
| 10_make_equation.py | Typeset model equation | seconds |
| 11_build_report_docx.py | Builds this report as a Word file | seconds |

Shared functions live in `R/utils.R` and `scripts/common.py`. Software: R 4.6 with brms (cmdstanr backend for the national model, CmdStan 2.40), loo, posterior, dplyr, tidyr and ggplot2; Python 3 with pandas, matplotlib and python-docx. Seeds are fixed (425). The national model ran 4 chains of 1,000 warmup and 1,000 sampling iterations with 2 threads per chain; LOO used 1,000 posterior draws to fit in memory.

## 7. References and acknowledgments

**Data**

- Federal Railroad Administration. Crossing Inventory Data (Form 71), Current. https://data.transportation.gov/d/m2f8-22s6
- Federal Railroad Administration. Crossing Inventory Data (Form 71), Historical. https://data.transportation.gov/d/vhwz-raag
- Federal Railroad Administration. Highway-Rail Grade Crossing Incident Data (Form 57). https://data.transportation.gov/d/7wn6-i5b9

**Literature**

- Brod, D., and Gillen, D. (2020). *New Model for Highway-Rail Grade Crossing Accident Prediction and Severity*. DOT/FRA/ORD-20/40. Federal Railroad Administration. https://rosap.ntl.bts.gov/view/dot/53342
- Federal Highway Administration (2007). *Railroad-Highway Grade Crossing Handbook, Revised Second Edition*. FHWA-SA-07-010. Section 4, Guidelines for Active Devices, p. 148. Copy hosted by the California Public Utilities Commission: https://www.cpuc.ca.gov/-/media/cpuc-website/files/legacyfiles/2/2881-2007fhwarailroadhighwaygradecrossinghandbooktb019e.pdf
- Mathew, J., Benekohal, R. F., and Medina, J. C. (2019). *Accident Prediction Models using Macro and Micro Scale Analysis: Dynamic Tree and Zero Inflated Negative Binomial Models with Empirical Bayes Accident History Adjustment*. CTS 19-02. University of Minnesota Center for Transportation Studies. https://cts-d10resmod-prd.oit.umn.edu/pdf/cts-19-02.pdf
- Operation Lifesaver, Inc. (2026). *Collisions, Fatalities & Injuries by Year* (source: Federal Railroad Administration; updated November 6, 2026). https://oli.org/about-us/news/collisions-casulties
- Texas Department of Transportation. *Traffic and Safety Analysis Procedures Manual*, Section 5.3.4, HSM Part C – Predictive Method. https://www.txdot.gov/manuals/des/tsp/chapter-5-safety-analysis-concepts/5-3-aashto-s-highway-safety-manual--hsm-/5-3-4-hsm-part-c---predictive-method.html

**Software**

- Bürkner, P.-C. (2017). brms: An R package for Bayesian multilevel models using Stan. *Journal of Statistical Software*, 80(1), 1–28.
- Stan Development Team. CmdStan 2.40 and the cmdstanr R interface. https://mc-stan.org
- Vehtari, A., Gelman, A., and Gabry, J. (2017). Practical Bayesian model evaluation using leave-one-out cross-validation and WAIC. *Statistics and Computing*, 27, 1413–1432.
- R Core Team. R: A language and environment for statistical computing. R Foundation for Statistical Computing.

**Acknowledgments.** Claude (Anthropic) assisted with code, debugging and drafting, as described in Section 9.

## 8. Individual self-reflection

[Charis to write in your own words. The assignment asks for:]

- Time spent on the project:
- Contributions:
- What I learned:
- Challenges:
- What I would do differently:
- Advice for future students:

## 9. AI use and prompt record

**Tool used.** Claude (Anthropic), through the Claude desktop app's coding environment, from November 12 to November 19, 2026.

**Purposes.**

- Brainstorming project topics and narrowing them to this one.
- Finding and downloading the FRA datasets; writing the Python cleaning code and the R/brms modeling code.
- Debugging: switching the national model to cmdstanr with threading, reducing memory use for LOO, and fixing a ranking that ignored each crossing's own crash history.
- Proposing robustness checks, including the leak-free holdout built from the historical inventory.
- Drafting the proposal and parts of this report.

**How outputs were checked.**

- Every number in the report comes from running the code on the data, not from the AI's text. Convergence was checked with R-hat, effective sample sizes and divergence counts.
- Several AI-produced results were found to be wrong and corrected. A first descriptive plot title overstated the evidence. A first ranking used only the model mean and ignored each crossing's history. The first holdout validation leaked future information because it used today's inventory. The corrected leak-free result is weaker and is the one reported.
- Literature citations were opened and checked against the source pages.
- No confidential, personal or restricted data were used; all data are public FRA records.

**Substantive prompts (summarized, in order).**

1. "Look at this [assignment PDF] and let me know what projects I can do, maybe dealing with stuff from my background."
2. Asked for project ideas that fit my background or would be good to show companies; chose the crossing-crash project.
3. "Draft the proposal, then can we work on it"; then "R with brms."
4. Asked to run the national model, then to restart it with a faster setup.
5. Asked to check crossings reporting zero trains per day.
6. Asked whether the results are good and what exactly they show.
7. Shared outside feedback on the results and asked to keep working; this led to the leak-free holdout and robustness checks.
8. Asked to cut the proposal to one page, then to add detail back.
9. Asked to build the presentation and start this report.

The full conversation can be exported from the Claude app and attached as a transcript if allowed.
