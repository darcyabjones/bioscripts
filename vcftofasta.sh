#!/usr/bin/env bash

set -euo pipefail

if [ $# -lt 2 ] || [ -z "${1:-}" ] || [ -z "${2:-}" ]
then
    echo "USAGE: $(basename $0) REFNAME [vcffile.vcf.gz|-]"
fi

REF="$1"

if [ "${2}" == "-" ]
then
    VCF="/dev/stdin"
else
    VCF="$2"
fi

bcftools query \
    --print-header \
    --format "%CHROM\\t%POS0\\t%END\\t%REF[\\t%TGT]\\n" \
    "${VCF}" \
| sed '1s/\\[[[:digit:]]*\\]//g' \
| sed '1s/:GT//g' \
| sed "1s/REF/${REF}/" \
| awk -F '\t' '{ printf(">%s\n%s\n", $1, $2) }'
