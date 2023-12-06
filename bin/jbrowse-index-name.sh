#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ]
then
  echo "USAGE: $(basename $0) config.json trackName"
fi

TARGET="${1}"
NAME="${2}"
ATTR="${3:-}"

if [ -z "${ATTR}" ]
then
  ATTR="Name,ID,Alias,gene,product"
fi

TRACK_NAME="$(jq -r --arg name "${NAME}" '[.tracks[] | select(.name == $name) | .trackId] | join(",")' "${TARGET}")"

jbrowse text-index \
  --target "$(basename "${TARGET}")" \
  --attributes "${ATTR}" \
  --tracks "${TRACK_NAME}" \
  --force \
  --perTrack

