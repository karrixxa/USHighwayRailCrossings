#!/usr/bin/env bash
# Run the whole analysis in order.
#
#   bash run_all.sh demo   # Texas only, about 40 minutes: the quickest way to check the pipeline
#   bash run_all.sh        # everything in the report, about 3 hours (the national model is slow)
#
# Every step caches its model fits in outputs/, so a second run skips the
# sampling and only redoes the summaries.
set -euo pipefail
cd "$(dirname "$0")"

mode="${1:-full}"

python scripts/01_download_data.py
python scripts/02_build_dataset.py

Rscript scripts/03_fit_models.R TX
Rscript scripts/04_prior_sensitivity.R
Rscript scripts/05_upgrade_priorities.R TX 50
python scripts/07_build_texas_snapshots.py
Rscript scripts/08_robustness_texas.R

if [[ "$mode" == "demo" ]]; then
  echo "Demo finished. Texas results are in outputs/TX/."
  exit 0
fi

Rscript scripts/03_fit_models.R ALL
Rscript scripts/05_upgrade_priorities.R ALL 200
Rscript scripts/06_county_effects.R
Rscript scripts/09_make_figures.R
python scripts/10_make_equation.py
python scripts/11_build_report_docx.py
echo "Done. Results are in outputs/, figures in outputs/report_figs/, report in report/."
