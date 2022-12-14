#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ] || [ -z "${1:-}" ]
then
  echo "USAGE: $(basename $0) [in.fasta|-] > out.tsv"
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
  ' < "$1"
}

fasta_to_tsv "${INFILE}"
