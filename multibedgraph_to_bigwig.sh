#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ] || [ -z "${1:-}" ]
then
  echo "USAGE: $(basename $0) FAI BEDGRAPH PREFIX"
  exit 0
elif [ "${1:-}" == "-" ]
then
  echo "ERROR: Sorry, this tool doesn't support stdin for the FAI" >&2
  exit 1
elif [ "${2:-}" == "-" ]
then
  echo "ERROR: Sorry, this tool doesn't support stdin for the bedgraph" >&2
  exit 1
fi

FAI="${1}"
BEDGRAPH="${2}"
PREFIX="${3}"

# Decide if the first line is a header based on whether it has two numbers in the 2nd and 3rd columns
if head -n 1 "${BEDGRAPH}" | grep $'^[^[:space:]]*\t[[:digit:]][[:digit:]]*\t[[:digit:]][[:digit:]]*\t' 1> /dev/null 2>&1
then
    NCOLS=$(awk -F'\t' '{print NF - 4}')
    COLS=( $(seq 1 "${NCOLS}") )
    TAILN=1
else
    COLS=( $(head -n 1 "${BEDGRAPH}" | cut -d$'\t' -f4-) )
    TAILN=2
fi

for i in "${!COLS[@]}"
do
    idx="$(( ${i} + 4 ))"
    col="${COLS[${i}]}"
    BGTMP="${PREFIX}${col}.bedgraph"
    trap "rm -f '${BGTMP}'" EXIT

    cut -d$'\t' -f1,2,3,${idx} "${BEDGRAPH}" | tail -n+${TAILN} | (grep -v '^#' || : ) | awk '$4 != "NA"' > "${BGTMP}"
    # on bioconda as ucsc-bedgraphtobigwig
    bedGraphToBigWig "${BGTMP}" "${FAI}" "${PREFIX}${col}.bw"
    rm -f "${BGTMP}"
done
