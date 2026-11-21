"""Rebuild Texas crossings as they stood at a past date.

The robustness checks need each crossing's warning device and traffic *before*
the crashes they are compared with, not today's values. FRA's historical
inventory keeps every revision of every record, so for each crossing we take
its latest revision on or before the cutoff.

Usage (from the repository root):
    python scripts/07_build_texas_snapshots.py

Input:  data/raw/inventory_history_TX.csv, data/raw/incidents_2015plus.csv,
        data/processed/crossings.csv (for each crossing's device today)
Output: data/processed/tx_asof_2015.csv and data/processed/tx_asof_2020.csv
"""
import pandas as pd

from common import (PROCESSED_DIR, RAW_DIR, TRANSIT_TRAINS_PER_DAY, add_model_columns,
                    clean_train_counts, crashes_per_crossing, read_incidents)

CUTOFF_YEARS = (2015, 2020)
OUTPUT_COLUMNS = [
    "crossingid", "statename", "countycode", "countyname", "revisiondate",
    "device", "device_now", "wdcode", "aadt", "trains_per_day", "lt1_train",
    "log_aadt", "log_trains", "log_train_speed", "maximumtimetablespeed",
    "numberofmaintracks", "urban", "y_2016_20", "y_2021_25", "y_2016_25",
]


def snapshot(history, cutoff):
    """Return each crossing's latest record on or before `cutoff`, kept only if it
    was then an open, public, at-grade highway crossing.

    Args:
        history: DataFrame of inventory revisions with a datetime `revisiondate`.
        cutoff: pandas Timestamp.
    """
    latest = (history[history["revisiondate"] <= cutoff]
              .sort_values("revisiondate")
              .groupby("crossingid", as_index=False).tail(1))
    is_open_public = ((latest["crossingclosed"] == "No") & (latest["crossingtypecode"] == 3)
                      & (latest["crossingpositioncode"] == 1) & (latest["crossingpurposecode"] == 1))
    return latest[is_open_public]


def main():
    history = pd.read_csv(RAW_DIR / "inventory_history_TX.csv",
                          dtype={"crossingid": str, "countycode": str}, low_memory=False)
    history["revisiondate"] = pd.to_datetime(history["revisiondate"], errors="coerce")
    incidents = read_incidents()
    device_today = pd.read_csv(PROCESSED_DIR / "crossings.csv",
                               dtype={"crossingid": str}).set_index("crossingid")["device"]

    crash_windows = {
        "y_2016_20": crashes_per_crossing(incidents, 2016, 2020),
        "y_2021_25": crashes_per_crossing(incidents, 2021, 2025),
        "y_2016_25": crashes_per_crossing(incidents, 2016, 2025),
    }

    for year in CUTOFF_YEARS:
        cutoff = pd.Timestamp(f"{year}-12-31")
        crossings = snapshot(history, cutoff)
        crossings, _ = clean_train_counts(crossings)
        crossings = crossings[crossings["trains_per_day"] < TRANSIT_TRAINS_PER_DAY]
        crossings = add_model_columns(crossings).dropna(
            subset=["device", "aadt", "trains_per_day", "maximumtimetablespeed",
                    "numberofmaintracks"])

        for column, counts in crash_windows.items():
            crossings[column] = crossings["crossingid"].map(counts).fillna(0).astype(int)
        crossings["device_now"] = crossings["crossingid"].map(device_today)
        crossings["statename"] = "TEXAS"

        out_file = PROCESSED_DIR / f"tx_asof_{year}.csv"
        crossings[OUTPUT_COLUMNS].to_csv(out_file, index=False)
        print(f"As of {cutoff.date()}: {len(crossings):,} open public crossings -> {out_file}")
        print(pd.crosstab(crossings["device"],
                          crossings["device_now"].fillna("closed since")).to_string(), "\n")


if __name__ == "__main__":
    main()
