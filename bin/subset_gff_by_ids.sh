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
      id=gensub(/.*ID=([^;]+).*/, "\\1", "g", $9);
      id=gensub(/^[[:space:]][[:space:]]*/, "", "g", id);
      id=gensub(/[[:space:]][[:space:]]*$/, "", "g", id);
      if (IDS[id] == "true") {
        any = "true"
      }
    }

    if ($9 ~ /Parent=/) {
      split(gensub(/.*Parent=([^;]+).*/, "\\1", "g", $9), parents, ",")
      for (parenti in parents) {
        parent = parents[parenti]
        parent=gensub(/^[[:space:]][[:space:]]*/, "", "g", parent);
        parent=gensub(/[[:space:]][[:space:]]*$/, "", "g", parent);
        if (IDS[parent] == "true") {any = "true"}
      }
    }

    if ((DERIVES == "True") && ($9 ~ /Derives_from=/)) {
      split(gensub(/.*Derives_from=([^;]+).*/, "\\1", "g", $9), derives, ",")
      for (derivei in derives) {
        derive = parents[derivei]
        derive=gensub(/^[[:space:]][[:space:]]*/, "", "g", derive);
        derive=gensub(/[[:space:]][[:space:]]*$/, "", "g", derive);
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
