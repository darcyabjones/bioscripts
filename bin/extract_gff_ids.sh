#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${BIN_DIR}")/lib"

CMD=$(__generate-cli.py "$(basename $0)" "$@" <<EOF
dest="GFF", type="str", help="The GFF to extract ids from"
short="-t", long="--type", dest="TYPE", type="str", default="", help="Which types to fetch ids from."
short="-p", long="--no-parents", dest="PARENTS", type="FLAG", default=True, help="Don't fetch Parents ids."
short="-d", long="--derives", dest="DERIVES", type="FLAG", default=False, help="Also fetch Derives_from ids."
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



if [ -z "${TYPE}" ]
then
  awk -F"\t" -v PARENTS="${PARENTS}" '
    NF == 9 {
      if ($9 ~ /ID=/) {
        id=gensub(/.*ID=([^;\s]+).*/, "\\1", "g", $9);
        if (id != "") {printf("%s\n", id)}
      }
      if ((PARENTS == "True") && ($9 ~ /Parent=/)) {
        split(gensub(/.*Parent=([^;\s]+).*/, "\\1", "g", $9), parents, ",")
        for (parent in parents) {
          if (parents[parent] != "") {printf("%s\n", parents[parent])}
        }
      }
    }
  ' "${GFF}" \
  | sort -u
else
  awk -F"\t" -v TYPE="${TYPE}" -v PARENTS="${PARENTS}" '
    $3 == TYPE {
      if ($9 ~ /ID=/) {
        id=gensub(/.*ID=([^;\s]+).*/, "\\1", "g", $9);
        if (id != "") {printf("%s\n", id)}
      }
      if ((PARENTS == "True") && ($9 ~ /Parent=/)) {
        split(gensub(/.*Parent=([^;\s]+).*/, "\\1", "g", $9), parents, ",")
        for (parent in parents) {
          if (parents[parent] != "") {printf("%s\n", parents[parent])}
        }
      }
    }
  ' "${GFF}" \
  | sort -u
fi
