"""Build the analysis dataset: one row per crossing with its crash count.

Joins the current FRA inventory to the 2016-2025 crash records, cleans the
train counts, and drops crossings whose key values can't be trusted.

Usage (from the repository root):
    python scripts/02_build_dataset.py

Input:  the files in data/raw/ from 01_download_data.py
Output: data/processed/crossings.csv, plus a short cleaning log on screen
"""
import pandas as pd

from common import (FIRST_YEAR, LAST_YEAR, PROCESSED_DIR, RAW_DIR, TRANSIT_TRAINS_PER_DAY,
                    add_model_columns, clean_train_counts, crashes_per_crossing,
                    read_incidents)

OUTPUT_COLUMNS = [
    "crossingid", "statename", "countycode", "countyname", "cityname",
    "latitude", "longitude", "crashes", "killed", "device", "wdcode",
    "aadt", "trains_per_day", "log_aadt", "log_trains", "log_train_speed",
    "maximumtimetablespeed", "numberofmaintracks", "highwayspeedlimit",
    "trafficlane", "urban", "lt1_train",
]
REQUIRED = ["device", "aadt", "trains_per_day", "maximumtimetablespeed", "numberofmaintracks"]


def main():
    inventory = pd.read_csv(RAW_DIR / "inventory_public_atgrade.csv",
                            dtype={"crossingid": str, "countycode": str, "statecode": str},
                            low_memory=False).drop_duplicates("crossingid")
    train_flags = (pd.read_csv(RAW_DIR / "inventory_train_freq.csv", dtype={"crossingid": str})
                   .drop_duplicates("crossingid")[["crossingid", "movementsperday"]])
    incidents = read_incidents()

    # Crash counts per crossing over the study window.
    in_window = incidents[incidents["year"].astype(int).between(FIRST_YEAR, LAST_YEAR)]
    crashes = crashes_per_crossing(incidents, FIRST_YEAR, LAST_YEAR)
    deaths = in_window.groupby("gradecrossingid")["totalkilledform57"].sum()
    inventory["crashes"] = inventory["crossingid"].map(crashes).fillna(0).astype(int)
    inventory["killed"] = inventory["crossingid"].map(deaths).fillna(0).astype(int)
    matched = inventory["crashes"].sum()
    print(f"Incidents {FIRST_YEAR}-{LAST_YEAR}: {len(in_window):,}; "
          f"matched to a current crossing: {matched:,} ({matched / len(in_window):.0%})")

    # Train counts, including the "less than one train a day" flag.
    inventory = inventory.merge(train_flags, on="crossingid", how="left")
    inventory, n_unverifiable = clean_train_counts(inventory)
    print(f"Dropped {n_unverifiable:,} crossings with zero trains and no FRA flag")

    crossings = add_model_columns(inventory)[OUTPUT_COLUMNS]

    n_before = len(crossings)
    crossings = crossings.dropna(subset=REQUIRED)
    print(f"Dropped {n_before - len(crossings):,} crossings missing key fields")

    transit = crossings["trains_per_day"] >= TRANSIT_TRAINS_PER_DAY
    print(f"Dropped {transit.sum():,} light-rail crossings "
          f"({crossings.loc[transit, 'crashes'].sum()} recorded crashes)")
    crossings = crossings[~transit]

    print(f"Final sample: {len(crossings):,} crossings, {crossings['crashes'].sum():,} crashes")
    print(crossings.groupby("device")["crashes"].agg(["size", "mean"]).round(3))

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    crossings.to_csv(PROCESSED_DIR / "crossings.csv", index=False)
    print(f"Wrote {PROCESSED_DIR / 'crossings.csv'}")


if __name__ == "__main__":
    main()
