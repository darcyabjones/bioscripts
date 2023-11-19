#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 5 ]
then
  echo "USAGE: $(basename $0) CONFIG ASSEMBLYNAME URLBASE MRNAFUNCSBASE IPS"
  exit 0
fi

CONFIG="$1"
ASSEMBLY_NAME="$2"
URL_BASE="$3"
NUCLEAR_MRNA_FUNCTIONS_BASENAME="$4"
IPS="$5"

IPS_FORMAT_DETAILS='{"formatDetails": {"feature": "jexl: linkout_defaults(feature)", "subfeatures": "jexl: linkout_defaults(feature)"}}'

for f in "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${IPS}"*.gff3.gz
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  BN="$(basename "${f%.gff3.gz}")"
  TOOL="${BN#${IPS}:}"

  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${BN}" \
    --name "${TOOL}" \
    --category "Protein functions,${IPS}" \
    --description "Location feature results for ${IPS} analysis ${TOOL}" \
    --config "${IPS_FORMAT_DETAILS}" \
    "${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/$(basename ${f})"
done
