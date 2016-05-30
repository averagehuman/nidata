"""
Download information about approximately 38,000 trees in Belfast (N. Ireland) from
the opendatani.gov.uk data api and convert from JSON to CSV.

Usage::

    $ python get_belfast_trees_csv.py <outfile>

where <outfile> is a local file path to which the csv file will be written.

Example::

    $ python get_belfast_trees_csv.py trees.csv

There is actually a quicker alternative::

    $ curl -G -L -o trees.csv -A "Mozilla/5.0 (X11; Linux x86_64)" http://www.belfastcity.gov.uk/nmsruntime/saveasdialog.aspx?lID=14543&sID=2430

which is equivalent to clicking on the website download link.

But here we prefer to call the data api directly.

Requires the requests library. Tested with Python3.

"""

import os
import time
import csv
import argparse

import requests

DATA_API_URL = "https://www.opendatani.gov.uk/api/action/datastore_search_sql"

DATA_API_QUERY = {
    'sql': 'SELECT * from "b501ba21-e26d-46d6-b854-26a95db78dd9"',
}

JSON_FIELDS = [
    'TYPEOFTREE', 'SPECIESTYPE', 'SPECIES', 'AGE', 'DESCRIPTION', 'TREESURROUND',
    'VIGOUR', 'CONDITION', 'DIAMETERinCENTIMETRES', 'SPREADRADIUSinMETRES',
    'LONGITUDE', 'LATITUDE', 'TREETAG', 'TREEHEIGHTinMETRES',
]

# For the CSV header, convert the JSON fields to lower case and remove units description
CSV_FIELDS = [field.partition('in')[0].lower() for field in JSON_FIELDS]

# By default, don't download if there is already a file downloaded less than four weeks ago
DEFAULT_FRESH_SECONDS = 4 * 7 * 24 * 60 * 60


def file_is_current(filepath, seconds):
    """
    Return True if file exists and was last modified less than 'seconds' ago.
    """
    if not os.path.exists(filepath):
        return False
    return time.time() - os.path.getmtime(filepath) < seconds


def main(outfile, url=DATA_API_URL, params=DATA_API_QUERY, fresh=DEFAULT_FRESH_SECONDS):
    """
    Make request to api and convert returned JSON to CSV.

    :outfile:  filename to write the CSV output
    :url:      belfast trees json endpoint
    :params:   url querystring data as a dict
    """
    if file_is_current(outfile, fresh):
        return
    response = requests.get(url, params=params)
    content = response.json()
    assert content['success'] is True
    with open(outfile, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, CSV_FIELDS)
        writer.writeheader()
        for record in content['result']['records']:
            row = {}
            for key in JSON_FIELDS:
                row[key.partition('in')[0].lower()] = record.get(key, '')
            writer.writerow(row)


def parse_command_line():
    """
    Parse command line options with argparse.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("outfile")
    parser.add_argument(
        "--fresh",
        type=int, 
        default=DEFAULT_FRESH_SECONDS,
        help="The time in seconds to consider an already downloaded file to be valid. Default is 4 weeks."
    )
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_command_line()
    main(args.outfile, fresh=args.fresh)

