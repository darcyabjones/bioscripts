#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ] || [ -z "${1:-}" ]
then
  echo "USAGE: $(basename $0) [in.fasta|-] > out.fasta"
  exit 0
elif [ "${1:-}" == "-" ]
then
  INFILE="/dev/stdin"
else
  INFILE="${1}"
fi

sed '/^>/ s/^\(>[^[:space:]][^[:space:]]*\).*$/\1/' "${INFILE}"
