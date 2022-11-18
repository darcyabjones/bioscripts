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

fasta_to_tsv() {
  awk '
    /^>/ {
      b=gensub(/^>\s*(\S+).*$/, "\\1", "g", $0);
      printf("%s%s\t", (N>0?"\n":""), b);
      N++;
      next;
    }
    {
      printf("%s", $0)
    }
    END {
      printf("\n");
    }
  '
}

# Remove gaps
# Remove trailing stops
# Replace internal stops, non-standard, and redundant AAs with X
sed '/^[^>]/ s/-.//g' "${INFILE}" \
  | fasta_to_tsv \
  | sed 's/\*$//g' \
  | awk -F '\t' '{ printf(">%s\n%s\n", $1, toupper($2)) }' \
  | sed '/^[^>]/ s/\*JBZUO/X/g'
