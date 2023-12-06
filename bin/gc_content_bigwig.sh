#!/usr/bin/env bash


set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]
then
  echo "USAGE: $(basename $0) PREFIX FASTA FAI [WINDOW]"
  exit 0
elif [ "${1:-}" == "-" ]
then
  echo "ERROR: Sorry, this tool doesn't support stdin for the FASTA" >&2
  exit 1
elif [ "${2:-}" == "-" ]
then
  echo "ERROR: Sorry, this tool doesn't support stdin for the FAI" >&2
  exit 1
fi

PREFIX=$1
FASTA="$2"
FAI="$3"
WINDOWSIZE="${4:-1000}"

FAI_CONT=$(awk -F'\t' -v OFS='\t' '{print $1, 0, $2}' "${FAI}")
WINDOWS=$(bedtools makewindows -b <(echo "${FAI_CONT}") -w 1000)

trap "rm -f '${PREFIX}.bedgraph'" EXIT

bedtools \
    nuc \
    -fi "${FASTA}" \
    -bed <(echo "${WINDOWS}") \
| awk -F '\t' -v OFS='\t' '{print $1, $2, $3, $5}' \
| grep -v "^#" \
| awk '$4 != "NA"' \
> "${PREFIX}.bedgraph"

bedGraphToBigWig "${PREFIX}.bedgraph" "${FAI}" "${PREFIX}.bw"
md5sum "${PREFIX}.bw" > "${PREFIX}.bw.md5"
