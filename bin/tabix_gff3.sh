#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ] || [ -z "${1:-}" ]
then
  echo "USAGE: $(basename $0) [in.gff3|-] [out.gff3.gz]"
  exit 0
elif [ "${1:-}" == "-" ]
then
  INFILE="/dev/stdin"
else
  INFILE="${1}"
fi

if [ -z "${2:-}" ] && ( [ "${1:-}" == "-" ] || [ "${1:-}" == "/dev/stdin" ] )
then
    echo "ERROR: if you are piping input to stdin, you need to specify an outfile with the second argument" >&2
    exit 1
elif [ "${2:-}" == "-" ]
then
    echo "ERROR: cannot output to stdout." >&2
    exit 1
elif [ -z "${2:-}" ]
then
    OUTFILE="${INFILE}.gz"
else
    OUTFILE="${2:-}"
fi

if [[ "${OUTFILE}" != *".gz" ]]
then
    echo "ERROR: your output file doesn't end with a .gz extension, but will still be gzipped." >&2
    exit 1
fi

IF="$(cat "${INFILE}")"
HEADER="$(echo "${IF}" | tr -dc '[[:print:][:space:]]' | (grep '^#' || :) | (grep -v '^###$' || :))"
NOTHEADER="$(echo "${IF}" | tr -dc '[[:print:][:space:]]' | (grep -v '^#' || :))"

(echo "${HEADER}"; echo "${NOTHEADER}" | sort -k1,1 -k4,4n ) \
| (grep -v '^$' || :) \
| bgzip --stdout \
> "${OUTFILE}"

bgzip --force --force --reindex "${OUTFILE}"
tabix -p gff "${OUTFILE}"

cd $(dirname "${OUTFILE}")
md5sum $(basename "${OUTFILE}") > "$(basename "${OUTFILE}.md5")"
