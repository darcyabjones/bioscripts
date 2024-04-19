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


TMPBASE="${PWD}/$(basename $0)-tmpfile$$"

TMPIN="${TMPBASE}-stdin.gff3"
TMPIDS="${TMPBASE}-ids.tsv"

trap "rm -f -- '${TMPIN}' '${TMPIDS}'" EXIT

GFF="$1"

if [ "${GFF}" == "-" ] || [ "${GFF}" == "/dev/stdin" ]
then
  cat "/dev/stdin" > "${TMPIN}"
  GFF="${TMPIN}"
fi


awk -F"\t" -v OFS="\t" -v IN="${GFF}" '
  BEGIN  {
    while (getline < IN) {
        split($0, line, "\t")
        if ((line[3] != "gene") || (line[9] !~ /ID=/)) {continue}
        gid = gensub(/^.*ID=([^;]+).*$/, "\\1", "g", line[9])
        if (gid != "") {
            GENES[gid] = "true"
        }
    }
  }
  $3 == "gene" {
    gid = gensub(/^.*ID=([^;]+).*$/, "\\1", "g", $9)
    print gid, gid
  }
  {
    id = gensub(/^.*ID=([^;]+).*$/, "\\1", "g", $9)
    parent = gensub(/^.*Parent=([^;]+).*$/, "\\1", "g", $9)
    if (GENES[parent] != "") {
        print id, parent
    }
  }
' "${GFF}" | sort -u > "${TMPIDS}" 

awk -F"\t" -v OFS="\t" -v IDFILE="${TMPIDS}" '
    BEGIN {
        while (getline < IDFILE) {split($0, line, "\t"); IDS[line[1]] = line[2]}
        missing_ids = 1
    }
    /^#/ {print; next}
    {
        id = gensub(/^.*ID=([^;]+).*$/, "\\1", "g", $9)

        if (IDS[id] == "") {
            id = gensub(/^.*Parent=([^;]+).*$/, "\\1", "g", $9)
        }

        split($9, ATTRS, ";")

        new_attrs = ""
        had_gene_id = 0
        for (i in ATTRS) {
            attri = ATTRS[i]
            attri = gensub(/^[[:space:]]*/, "", "g", attri)
            attri = gensub(/[[:space:]]*$/, "", "g", attri)

            if (attri == "") {continue}

            if (attri ~ /^gene_id/) {
                had_gene_id = 1
                continue
            }

            if (new_attrs == "") {
                new_attrs = attri
            } else {
                new_attrs = new_attrs ";" attri
            }
        }

        had_gene_id = 0
        if (!had_gene_id) {
            gene_id = IDS[id]
            if (gene_id != "") {
                new_attrs = new_attrs ";gene_id=" gene_id
            }
        }

        $9 = new_attrs
        print
    }
' "${GFF}"
