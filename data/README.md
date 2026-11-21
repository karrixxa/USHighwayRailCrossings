# Data

Nothing in this folder is committed to the repository. Run

```bash
python scripts/01_download_data.py
python scripts/02_build_dataset.py
python scripts/07_build_texas_snapshots.py
```

from the repository root to create it:

```
data/
├── raw/                              # straight from data.transportation.gov
│   ├── inventory_public_atgrade.csv  # ~27 MB
│   ├── inventory_train_freq.csv      # ~6 MB
│   ├── incidents_2015plus.csv        # ~4 MB
│   └── inventory_history_TX.csv      # ~60 MB
└── processed/                        # built by the scripts
    ├── crossings.csv                 # one row per crossing, 2016-2025 crash count
    ├── tx_asof_2015.csv              # Texas crossings as of Dec 31, 2015
    └── tx_asof_2020.csv              # Texas crossings as of Dec 31, 2020
```

## Sources

All three datasets are published by the Federal Railroad Administration on data.transportation.gov:

- Crossing Inventory Data (Form 71), Current: https://data.transportation.gov/d/m2f8-22s6
- Crossing Inventory Data (Form 71), Historical: https://data.transportation.gov/d/vhwz-raag
- Highway-Rail Grade Crossing Incident Data (Form 57): https://data.transportation.gov/d/7wn6-i5b9

The download script filters on the server (open, public, at-grade highway crossings; incidents from 2015 on; Texas history only) and asks for just the columns in use. If the API is unavailable, you can export the same datasets as CSV from those pages, apply the same filters, and save them under the file names above.

## Key columns in `crossings.csv`

| Column | Meaning |
| --- | --- |
| `crossingid` | FRA seven-character crossing ID |
| `statename`, `countycode`, `countyname` | location (county code is the 5-digit FIPS code) |
| `crashes` | collisions reported at the crossing, 2016–2025 |
| `device` | highest warning device: `gates`, `lights` (flashing lights) or `passive` (signs only) |
| `aadt` | average daily vehicles |
| `trains_per_day` | daily trains (0.5 for lines with fewer than one a day) |
| `lt1_train` | 1 if FRA flags fewer than one train a day |
| `maximumtimetablespeed` | maximum train speed (mph) |
| `numberofmaintracks` | number of main tracks |
| `urban` | 1 if the road is classed as urban |
| `log_aadt`, `log_trains`, `log_train_speed` | log(1 + value) versions used in the model |

## Cleaning rules

Set in `scripts/common.py` and applied in `02_build_dataset.py`:

1. Keep open, public, at-grade highway crossings.
2. Count collisions from 2016 through 2025.
3. Crossings FRA flags as having fewer than one train a day get 0.5 trains/day and `lt1_train = 1`; crossings with zero trains and no flag are dropped.
4. Drop crossings missing traffic, train speed or track data.
5. Drop crossings with 100 or more trains a day (light rail, which FRA does not fully record).
