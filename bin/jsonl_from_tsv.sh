#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ] || [ -z "${1:-}" ]
then
  echo "USAGE: $(basename $0) [in.tsv|-]"
  exit 0
elif [ "${1:-}" == "-" ]
then
  INFILE="/dev/stdin"
else
  INFILE="${1}"
fi

awk -F '\t' '
  NR == 1 {
    split($0, COLNAMES, "\t");
    COLSIZE=NF;
  }
  NR > 1 {
    printf("{");
    for (i=1; i < COLSIZE; i++) {
      if (($i != "-") && ($i != "")) {
	if (i > 1) {
	  printf(", ");
	}
        printf("\"%s\": \"%s\"", COLNAMES[i], $i);
      }

    }
    printf("}\n");
  }
' < "${INFILE}"
