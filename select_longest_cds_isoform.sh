#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ] || [ -z "${1:-}" ]
then
  echo "USAGE: $(basename $0) [in.gff3|-] > out.gff3"
  exit 0
elif [ "${1:-}" == "-" ]
then
  INFILE="/dev/stdin"
else
  INFILE="${1}"
fi


find_longest() {
    awk -F"\t" '
    BEGIN {OFS="\t"}
    !/^#/ && $3 == "mRNA" {
        ID=gensub(/^.*ID=([^;]+).*$/, "\\1", "g", $9);
        PARENT=gensub(/^.*Parent=([^;]+).*$/, "\\1", "g", $9);
        GENES[ID]=PARENT
    }
    !/^#/ && $3 == "CDS" {
        PARENT=gensub(/^.*Parent=([^;]+).*$/, "\\1", "g", $9);
        LENGTHS[PARENT] += $5 - $4
    }
    END {
        for (tid in LENGTHS) {
            print GENES[tid], tid, LENGTHS[tid]
        }
    }' \
    | sort -k 1,1 -k 3,3rn \
    | sort -u -k1,1
}

TMPFILE="${TMPDIR:-/tmp}/$$-select_longest_cds_isoform.txt"
trap "rm -f '${TMPFILE}'" EXIT

find_longest < "${INFILE}" | cut -f2 > "${TMPFILE}"

awk -v TMPFILE="${TMPFILE}" '
BEGIN {
  OFS="\t";
  while (getline < TMPFILE) {
      IDS[$0]="true"
  }
}
/^#/ { print }
$3 == "gene" { print }
$3 == "mRNA" {
    ID=gensub(/^.*ID=([^;]+).*$/, "\\1", "g", $9);
    if (IDS[ID] == "true") { print }
}
($3 == "exon" || $3 == "CDS") {
    PARENT=gensub(/^.*Parent=([^;]+).*$/, "\\1", "g", $9);
    if (IDS[PARENT] == "true") { print }
}' "${INFILE}"
