#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq 0 ]
then
  echo "ERROR: Please provide some strings" >&2
  exit 1
fi

if command -v gsed
then
  SED=gsed
else
  SED=sed
fi

printf '%s\n' "${@}" | ${SED} -e 'N;s/^\(.*\).*\n\1.*$/\1\n\1/;D'
