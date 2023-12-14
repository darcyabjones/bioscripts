#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq "0" ]
then
  echo "USAGE: $(basename $0) id_map.tsv genes.gff3"
  exit 0
elif [ "$#" != "2" ]
then
  echo "USAGE: $(basename $0) id_map.tsv genes.gff3" 1>&2;
  exit 1
fi

MAP="$1"
GFF="$2"

if [ "${GFF}" == "-" ]
then
  GFF=/dev/stdin
fi

awk -F"\t" -v OFS="\t" -v ID_FILE="${MAP}" '
BEGIN {while (getline < ID_FILE) {split($0, line, "\t"); IDS[line[1]]=line[2]}}
/^#/ {print; next}
{
    split($9, attr, ";")
    new_attrs = ""
    for (i in attr) {
        attri = attr[i]
        attri = gensub(/^[[:space:]]*/, "", "g", attri)
        attri = gensub(/[[:space:]]*$/, "", "g", attri)

        if (attri ~ /^Parent=/) {
            attri = gensub(/Parent=/, "", "g", attri)
            split(attri, parents, ",")
            new_parents = ""

            for (j in parents) {
                parentj = parents[j]
                parentj=gensub(/^[[:space:]][[:space:]]*/, "", "g", parentj);
                parentj=gensub(/[[:space:]][[:space:]]*$/, "", "g", parentj);

                if (IDS[parentj] != "") {
                    parentj = IDS[parentj]
                }

                if (new_parents == "" ) {
                    new_parents = parentj
                } else {
                    new_parents = "," parentj
                }
            }

            if (new_parents != "") {
                new_parents = "Parent=" new_parents
            }
            attri = new_parents

        } else if (attri ~ /^Derives_from=/) {
            attri = gensub(/Derives_from=/, "", "g", attri)
            split(attri, parents, ",")
            new_parents = ""

            for (j in parents) {
                parentj = parents[j]
                parentj=gensub(/^[[:space:]][[:space:]]*/, "", "g", parentj);
                parentj=gensub(/[[:space:]][[:space:]]*$/, "", "g", parentj);
                if (IDS[parentj] != "") {
                    parentj = IDS[parentj]
                }

                if (new_parents == "" ) {
                    new_parents = parentsj
                } else {
                    new_parents = "," parentsj
                }
            }
            if (new_parents != "") {
                new_parents = "Derives_from=" new_parents
            }
            attri = new_parents
        } else if (attri ~ /^ID=/) {
            attri = gensub(/ID=/, "", "g", attri)
            attri = gensub(/^[[:space:]][[:space:]]*/, "", "g", attri);
            attri = gensub(/[[:space:]][[:space:]]*$/, "", "g", attri);

            if (IDS[attri] != "") {
                attri = "ID=" IDS[attri]
            } else if (attri != "") {
                attri = "ID=" attri
            }
        }
        if ((attri != "") && (new_attrs == "")) {
            new_attrs = attri
        } else if ((attri != "") && (new_attrs != "")) {
            new_attrs = new_attrs ";" attri
        }
    }

    $9 = new_attrs
    print
}' < "${GFF}"
