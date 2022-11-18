#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ] || [ -z "${1:-}" ]
then
  echo "USAGE: $(basename $0) [in.tsv|-] > out.fasta"
elif [ "${1:-}" == "-" ]
then
  INFILE="/dev/stdin"
else
  INFILE="${1}"
fi

awk -F '\t' '{ printf(">%s\n%s\n", $1, $2) }' < "${INFILE}"
