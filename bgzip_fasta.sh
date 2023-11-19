#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ] || [ -z "${1:-}" ]
then
  echo "USAGE: $(basename $0) [in.fasta|-] [out.fasta.gz]"
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


cat "${INFILE}" | bgzip --stdout > "${OUTFILE}"
bgzip --reindex "${OUTFILE}"
samtools faidx "${OUTFILE}"

cd $(dirname "${OUTFILE}")
md5sum $(basename "${OUTFILE}") > "${OUTFILE}.md5"
