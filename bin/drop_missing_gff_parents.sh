#!/usr/bin/env bash


set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${BIN_DIR}")/lib"

CMD=$(__generate-cli.py "$(basename $0)" "$@" <<EOF
dest="GFF", type="str", help="The GFF to extract ids from"
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

if [ "${DEBUG:-}" == "True" ]
then
  set -x
fi

if [ "${GFF}" == "-" ] || [ "${GFF}" == "" ]
then
  GFF="/dev/stdin"
fi

TMPGFF="${TMPDIR:-.}/tmp$(basename $0)$$.gff3"
trap "rm -f '${TMPGFF}'*" EXIT

cat "${GFF}" > "${TMPGFF}"

bash "${BIN_DIR}/extract_gff_ids.sh" --no-parents "${TMPGFF}" > "${TMPGFF}.ids"

awk -F"\t" -v ID_FILE="${TMPGFF}.ids" -v OFS="\t" '
  BEGIN {while (getline < ID_FILE) {IDS[$0]="true"}}
  /^#/ {print}
  NF == 9 {
    split($9, attr, ";")
    new_attrs = ""
    for (i in attr) {
      attri = attr[i]
      attri = gensub(/^[[:space:]]*/, "", "g", attri)
      attri = gensub(/[[:space:]]*$/, "", "g", attri)

      if (attri ~ /Parent=/) {
        attri = gensub(/Parent=/, "", "g", attri)
	split(attri, parents, ",")
	new_parents = ""
	for (j in parents) {
	  if (IDS[parents[j]] == "true") {
	    if (new_parents == "" ) {
	      new_parents = parents[j]
	    } else {
              new_parents = "," parents[j]
            }
	  }
	}
	if (new_parents != "") {
	  new_parents = "Parent=" new_parents
	}
	attri = new_parents
      }

      if (attri ~ /Derives_from=/) {
        attri = gensub(/Derives_from=/, "", "g", attri)
	split(attri, parents, ",")
	new_parents = ""
	for (j in parents) {
	  if (IDS[parents[j]] == "true") {
	    if (new_parents == "" ) {
	      new_parents = parents[j]
	    } else {
              new_parents = "," parents[j]
            }
	  }
	}
	if (new_parents != "") {
	  new_parents = "Derives_from=" new_parents
	}
	attri = new_parents
      }

      if ((attri != "") && (new_attrs == "")) {
        new_attrs = attri
      } else if ((attri != "") && (new_attrs != "")) {
        new_attrs = new_attrs ";" attri
      }
    }
    $9 = new_attrs
    print $0
  }
' "${TMPGFF}"
