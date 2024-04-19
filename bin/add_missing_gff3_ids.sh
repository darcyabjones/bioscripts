#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq "0" ]
then
  echo "USAGE: $(basename $0) [genes.gff3|-]"
  exit 0
elif [ "$#" != "1" ]
then
  echo "USAGE: $(basename $0) [genes.gff3|-]" 1>&2;
  exit 1
fi

GFF="$1"

if [ "${GFF}" == "-" ]
then
  GFF="/dev/stdin"
fi

awk -F"\t" -v OFS="\t" '
    /^#/ {print; next}
    $9 ~ /ID=/ {print; next}
    ($9 !~ /ID=/) && ($9 ~ /Parent=/) {
        parent = gensub(/^.*Parent=([^;]+).*$/, "\\1", "g", $9)
        parent = parent "-" $3

        if (parent_map[parent] == "") {
            parent_count = 1
        } else {
            parent_count = parent_map[parent]
        }

        newid = sprintf("%s%d", parent, parent_count)
        $9 = "ID=" newid ";" $9
        parent_map[parent] = parent_count + 1
        print
    }
' "${GFF}"
