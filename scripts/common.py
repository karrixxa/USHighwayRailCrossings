"""Shared paths, settings and cleaning helpers for the Python scripts.

Every script is run from the repository root, e.g. `python scripts/02_build_dataset.py`,
so the paths below are relative to that root.
"""
from pathlib import Path

import numpy as np
import pandas as pd

RAW_DIR = Path("data/raw")
PROCESSED_DIR = Path("data/processed")

# Study window: ten full years of crashes.
FIRST_YEAR, LAST_YEAR = 2016, 2025

# Crossings with this many trains a day or more are light-rail corridors
# (e.g. Houston METRORail). FRA does not cover light rail, so their crashes
# are mostly missing from the incident file and we leave them out.
TRANSIT_TRAINS_PER_DAY = 100

# FRA's "highest warning device" codes, collapsed into three groups.
DEVICE_GROUPS = {
    "All other Gates": "gates",
    "Four Quad (full barrier) Gates": "gates",
    "Flashing lights": "lights",
    "Highway signals, bells": "lights",
    "Special Active Warning Devices": "lights",
    "Crossbucks": "passive",
    "Stop signs": "passive",
    "No signs or signals": "passive",
    "Other signs or signals": "passive",
}

TRAIN_COLUMNS = ["totaldaylightthrutrains", "totalnighttimethrutrains", "totalswitchingtrains"]


def crashes_per_crossing(incidents, first_year, last_year):
    """Count crashes per crossing in a range of years.

    Args:
        incidents: DataFrame of FRA Form 57 records with `year` and `gradecrossingid`.
        first_year, last_year: inclusive range of years to count.

    Returns:
        Series indexed by crossing ID with the number of crashes.
    """
    years = incidents["year"].astype(int)
    in_window = incidents[years.between(first_year, last_year)]
    return in_window.groupby("gradecrossingid").size()


def clean_train_counts(crossings):
    """Total the daily train counts and handle FRA's "less than one a day" flag.

    FRA writes 0 trains/day for lines with fewer than one train a day and marks
    them in `movementsperday`. Those crossings get 0.5 trains/day and an
    indicator `lt1_train`. A crossing with 0 trains and no such flag has an
    unverifiable count and is dropped.

    Args:
        crossings: DataFrame with the three FRA train-count columns and
            `movementsperday`.

    Returns:
        (cleaned DataFrame with `trains_per_day` and `lt1_train`,
         number of crossings dropped)
    """
    df = crossings.copy()
    df["trains_per_day"] = df[TRAIN_COLUMNS].sum(axis=1, min_count=1)

    less_than_one = df["movementsperday"].fillna("").str.startswith("Less Than One")
    zero = df["trains_per_day"] == 0
    df["lt1_train"] = (zero & less_than_one).astype(int)
    df.loc[zero & less_than_one, "trains_per_day"] = 0.5

    unverifiable = zero & ~less_than_one
    return df[~unverifiable], int(unverifiable.sum())


def add_model_columns(crossings):
    """Add the device group, urban flag and log-scale predictors the models use.

    Args:
        crossings: DataFrame with `wdcode`, `annualaveragedailytrafficcount`,
            `trains_per_day`, `maximumtimetablespeed` and `roadatcrossing`.

    Returns:
        A copy with `device`, `aadt`, `urban`, `log_aadt`, `log_trains` and
        `log_train_speed` added.
    """
    df = crossings.copy()
    df["device"] = df["wdcode"].map(DEVICE_GROUPS)
    df["aadt"] = df["annualaveragedailytrafficcount"]
    df["urban"] = df["roadatcrossing"].astype(str).str.contains("Urban").astype(int)
    df["log_aadt"] = np.log1p(df["aadt"])
    df["log_trains"] = np.log1p(df["trains_per_day"])
    df["log_train_speed"] = np.log1p(df["maximumtimetablespeed"])
    return df


def read_incidents():
    """Load the FRA incident file downloaded by 01_download_data.py."""
    return pd.read_csv(RAW_DIR / "incidents_2015plus.csv", dtype={"gradecrossingid": str})
