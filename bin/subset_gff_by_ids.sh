#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${BIN_DIR}")/lib"

CMD=$(__generate-cli.py "$(basename $0)" "$@" <<EOF
dest="GFF", type="str", help="The GFF to extract features from"
dest="IDS", type="str", help="A file containing the IDS to extract, 1 per line."
short="-d", long="--derives", dest="DERIVES", type="FLAG", default=False, help="Also fetch Derives_from features."
short="-v", long="--invert", dest="WITHOUT", type="FLAG", default=False, help="Fetch all genes without these ids."
long="--debug", dest="DEBUG", type="FLAG", default=False, help="Print extra logs to stdout."
EOF
)

# Eventually i'd like this to be arbitrary, for now its just whether or not to include derives from.
# short="-f", long="--fields", DEST="FIELDS", type="STR", nargs="+", default=["ID", "Parent", "Derives_from"], help="Which attribute fields to search for ids."

if ! (echo "${CMD}" | grep '^### __generate-cli output$' > /dev/null)
then
  # help or an error occurred
  echo "# $(basename $0)"
  echo "${CMD}"
  exit 0
fi

eval "${CMD}"

if [ "${DEBUG:-}"=true ]
then
  set +x
fi


awk -F"\t" -v ID_FILE="${IDS}" -v WITHOUT="${WITHOUT}" -v DERIVES="${DERIVES}" '
  BEGIN {while (getline < ID_FILE) {IDS[$0]="true"}}
  /^#/ {print}
  NF == 9 {
    any = "false"
    if ($9 ~ /ID=/) {
      id=gensub(/.*ID=([^;\s]+).*/, "\\1", "g", $9)
      if (IDS[id] == "true") {
        any = "true"
      }
    }

    if ($9 ~ /Parent=/) {
      split(gensub(/.*Parent=([^;\s,]+).*/, "\\1", "g", $9), parents, ",")
      for (parent in parents) {
        if (IDS[parents[parent]] == "true") {any = "true"}
      }
    }

    if ((DERIVES == "True") && ($9 ~ /Derives_from=/)) {
      split(gensub(/.*Derives_from=([^;\s,]+).*/, "\\1", "g", $9), derives, ",")
      for (derive in derives) {
        if (IDS[derives[derive]] == "true") {any = "true"}
      }
    }

    if ((WITHOUT == "True") && (any == "false")) {
      print
    } else if ((WITHOUT == "False") && (any == "true")) {
      print
    }
  }
' "${GFF}"
