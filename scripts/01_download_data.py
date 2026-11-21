"""Download the FRA crossing and crash data from data.transportation.gov.

All four files are public. Each request asks the Socrata API for only the
columns we use, so the downloads stay small (about 150 MB in total).

Usage (from the repository root):
    python scripts/01_download_data.py

Outputs, in data/raw/:
    inventory_public_atgrade.csv   current inventory, open public at-grade highway crossings
    inventory_train_freq.csv       the "less than one train a day" flag for the same crossings
    incidents_2015plus.csv         every reported collision since 2015
    inventory_history_TX.csv       every past revision of Texas crossing records
"""
import urllib.parse
import urllib.request

from common import RAW_DIR

API = "https://data.transportation.gov/resource/{}.csv"
INVENTORY_ID = "m2f8-22s6"   # Crossing Inventory Data (Form 71) - Current
INCIDENT_ID = "7wn6-i5b9"    # Highway-Rail Grade Crossing Incident Data (Form 57)
HISTORY_ID = "vhwz-raag"     # Crossing Inventory Data (Form 71) - Historical

OPEN_PUBLIC_AT_GRADE = ("crossingclosed='No' AND crossingtypecode='3' "
                        "AND crossingpositioncode='1' AND crossingpurposecode='1'")

INVENTORY_COLUMNS = [
    "crossingid", "statename", "statecode", "countycode", "countyname", "cityname",
    "latitude", "longitude",
    "totaldaylightthrutrains", "totalnighttimethrutrains", "totalswitchingtrains",
    "maximumtimetablespeed", "numberofmaintracks", "wdcode", "countroadwaygatearms",
    "annualaveragedailytrafficcount", "trafficlane", "highwayspeedlimit",
    "roadatcrossing", "developmenttype", "whistleban", "crossingilluminated",
    "highwaypaved", "smallestcrossingangle", "estimatedpercenttrucks", "revisiondate",
]
TRAIN_FREQUENCY_COLUMNS = ["crossingid", "movementsperdaycode", "movementsperday",
                           "totaltransittrains", "typeoftrainservice1"]
INCIDENT_COLUMNS = [
    "reportkey", "gradecrossingid", "year", "date", "statename", "countyname",
    "cityname", "publicprivate", "highwayuser", "crossinguserskilled",
    "crossingusersinjured", "totalkilledform57", "totalinjuredform57",
    "crossingwarningexpanded1", "trainspeed",
]
HISTORY_COLUMNS = [
    "crossingid", "revisiondate", "reasondescription", "crossingclosed",
    "crossingtypecode", "crossingpositioncode", "crossingpurposecode",
    "countycode", "countyname", "wdcode", "annualaveragedailytrafficcount",
    "totaldaylightthrutrains", "totalnighttimethrutrains", "totalswitchingtrains",
    "movementsperday", "maximumtimetablespeed", "numberofmaintracks", "roadatcrossing",
]


def download(dataset_id, columns, where, limit, filename):
    """Save one filtered extract of a data.transportation.gov dataset as CSV.

    Args:
        dataset_id: Socrata dataset ID, e.g. "m2f8-22s6".
        columns: list of column names to request.
        where: SoQL filter, e.g. "year >= '2015'".
        limit: maximum number of rows (set above the dataset's size).
        filename: name of the output file inside data/raw/.
    """
    query = urllib.parse.urlencode({
        "$select": ",".join(columns), "$where": where, "$limit": str(limit),
    })
    destination = RAW_DIR / filename
    print(f"Downloading {dataset_id} -> {destination}")
    with urllib.request.urlopen(f"{API.format(dataset_id)}?{query}", timeout=900) as response:
        destination.write_bytes(response.read())


def main():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    download(INVENTORY_ID, INVENTORY_COLUMNS, OPEN_PUBLIC_AT_GRADE, 500_000,
             "inventory_public_atgrade.csv")
    download(INVENTORY_ID, TRAIN_FREQUENCY_COLUMNS, OPEN_PUBLIC_AT_GRADE, 500_000,
             "inventory_train_freq.csv")
    download(INCIDENT_ID, INCIDENT_COLUMNS, "year >= '2015'", 200_000,
             "incidents_2015plus.csv")
    # Texas only: the national history has about 5 million rows and is only
    # needed for the Texas robustness checks.
    download(HISTORY_ID, HISTORY_COLUMNS, "statename='TEXAS'", 600_000,
             "inventory_history_TX.csv")


if __name__ == "__main__":
    main()
