#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ]
then
    echo "USAGE: $(basename $0) [-|getorf.faa]"
    exit 0
elif [ $# -ne 1 ]
then
    echo "USAGE: $(basename $0) [-|getorf.faa]" >&2
    exit 1
fi

if [ "$1" == "-" ]
then
    IN="/dev/stdin"
else
    IN="$1"
fi

awk -v OFS="\t" -v MINLENGTH=60 '
    />/ {
        contig=gensub(/^>([^_]+).*$/, "\\1", "g", $0);
        start=gensub(/^.*\[([0-9][0-9]*)[[:space:]].*$/, "\\1", "g", $0);
        end=gensub(/^.*[[:space:]]([0-9][0-9]*)\].*$/, "\\1", "g", $0);
        start=start + 0;
        end=end + 0;
        score=".";
        phase=0;
        if (start > end) {strand="-"; s=end; end=start; start=s} else {strand="+"};
        len=end - start + 1;
        if (len < MINLENGTH) {next}
        print contig, "getorf", "CDS", start, end, score, strand, phase, "."
    }' "${IN}" \
    | sort -u -k1,1 -k4,4n -k5,5n -k7,7 \
    | awk -F "\t" -v OFS="\t" -v NUM=1 '
        {
            len=$5 - $4 + 1
            gattr=sprintf("ID=ORF%07d;length=%d", NUM, len);
            cattr=sprintf("ID=CDS.ORF%07d;Parent=ORF%07d;length=%d", NUM, NUM, len);
            print $1, $2, "gene", $4, $5, $6, $7, ".", gattr;
            print $1, $2, "CDS", $4, $5, $6, $7, "0", cattr;
            NUM=NUM+1;
        }'
