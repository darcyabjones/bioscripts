#!/usr/bin/env bash

set -xeuo pipefail

if [ "$#" -ne 5 ]
then
  echo "USAGE: $(basename $0) CONFIG ASSEMBLYNAME URLBASE MRNAFUNCSBASE PREDECTOR"
  exit 0
fi

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${BIN_DIR}")/lib"

echo "${BIN_DIR}"

CONFIG="$1"
ASSEMBLY_NAME="$2"
URL_BASE="$3"
NUCLEAR_MRNA_FUNCTIONS_BASENAME="$4"
PREDECTOR="$5"


for f in "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}"*.gff3.gz
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  BN="$(basename "${f%.gff3.gz}")"
  TOOL="${BN#${PREDECTOR}:}"

  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${CONFIG}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${BN}" \
    --name "${TOOL}" \
    --category "Protein functions,${PREDECTOR}" \
    --description "Location feature results for ${PREDECTOR} analysis ${TOOL}" \
    --urlBase "${URL_BASE}" \
    "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}" \
    "${f}"
done


TOOL="predutils:0.8.3-effector_score"
THIS_CONFIG='{"displays": [{ "type": "LinearWiggleDisplay", "displayId": "'"${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}"'-LinearWiggleDisplay", "minScore": -3, "maxScore": 3, "posColor": "red", "negColor": "blue", "bicolorPivot": "numeric", "bicolorPivotValue": 0, "defaultRendering": "density"}]}'

if [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}.bw" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}" \
    --name "${PREDECTOR}-effector_score" \
    --category "Protein functions,${PREDECTOR}" \
    --description "Effector ranking scores from ${PREDECTOR} analysis ${TOOL}" \
    --config "${THIS_CONFIG}" \
    "${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}.bw"
fi

TOOL="ApoplastP:1.0"
THIS_CONFIG='{"displays": [{ "type": "LinearWiggleDisplay", "displayId": "'"${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}"'-LinearWiggleDisplay", "minScore": 0, "maxScore": 1, "posColor": "red", "negColor": "blue", "bicolorPivot": "numeric", "bicolorPivotValue": 0.5, "defaultRendering": "density"}]}'

if  [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}.bw" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}" \
    --name "${PREDECTOR}:${TOOL}" \
    --category "Protein functions,${PREDECTOR}" \
    --description "Apoplastic localisation probabilities from ${TOOL} run as part of ${PREDECTOR}." \
    --config "${THIS_CONFIG}" \
    "${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}.bw"
fi


TOOL="EffectorP1:1.0"
THIS_CONFIG='{"displays": [{ "type": "LinearWiggleDisplay", "displayId": "'"${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}"'-LinearWiggleDisplay", "minScore": 0, "maxScore": 1, "posColor": "red", "negColor": "blue", "bicolorPivot": "numeric", "bicolorPivotValue": 0.5, "defaultRendering": "density"}]}'

if [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}.bw" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}" \
    --name "${PREDECTOR}:${TOOL}" \
    --category "Protein functions,${PREDECTOR}" \
    --description "Effector probabilities from ${TOOL} run as part of ${PREDECTOR}." \
    --config "${THIS_CONFIG}" \
    "${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}.bw"
fi


TOOL="EffectorP2:1.0"
THIS_CONFIG='{"displays": [{ "type": "LinearWiggleDisplay", "displayId": "'"${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}"'-display", "minScore": 0, "maxScore": 1, "posColor": "red", "negColor": "blue", "bicolorPivot": "numeric", "bicolorPivotValue": 0.5, "defaultRendering": "density"}]}'

if [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}.bw" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}" \
    --name "${PREDECTOR}:${TOOL}" \
    --category "Protein functions,${PREDECTOR}" \
    --description "Effector probabilities from ${TOOL} run as part of ${PREDECTOR}." \
    --config "${THIS_CONFIG}" \
    "${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}.bw"
fi


TOOL="EffectorP3:1.0"

if [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-apoplastic.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-cytoplasmic.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-noneffector.bw" ]
then
  bash "${BIN_DIR}/jbrowse-add-multibigwig_track.sh" \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}" \
    --name "${TOOL}" \
    --category "Protein functions,${PREDECTOR}" \
    --description "Effector probability scores from ${TOOL} run as part of ${PREDECTOR}." \
    --displayType prob \
    <<EOF
apoplastic none ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-apoplastic.bw
cytoplasmic none ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-cytoplasmic.bw
non_effector none ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-noneffector.bw
EOF
fi


TOOL="deepredeff:0.1.0"

if [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-fungi.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-oomycete.bw" ]
then
  bash "${BIN_DIR}"/jbrowse-add-multibigwig_track.sh \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}" \
    --name "${TOOL}" \
    --category "Protein functions,${PREDECTOR}" \
    --description "Effector probability scores from ${TOOL} run as part of ${PREDECTOR}." \
    --displayType prob \
    <<EOF
fungi none ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-fungi.bw
oomycete none ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-oomycete.bw
EOF
fi


TOOL="DeepLoc:1.0"

if   [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-membrane.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-nucleus.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-cytoplasm.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-mitochondrion.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-plastid.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-endoplasmic_reticulum.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-golgi.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-lysosome.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-peroxisome.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-cell_membrane.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-extracellular.bw" ]
then
  bash "${BIN_DIR}"/jbrowse-add-multibigwig_track.sh \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}" \
    --name "${TOOL}" \
    --category "Protein functions,${PREDECTOR}" \
    --description "Protein subcellular localisation predictions from ${PREDECTOR} analysis ${TOOL}." \
    --displayType prob \
    <<EOF
membrane membrane ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-membrane.bw
nucleus localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-nucleus.bw
cytoplasm localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-cytoplasm.bw
mitochondrion localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-mitochondrion.bw
plastid localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-plastid.bw
endoplasmic_reticulum localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-endoplasmic_reticulum.bw
golgi localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-golgi.bw
lysosome localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-lysosome.bw
peroxisome localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-peroxisome.bw
cell_membrane localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-cell_membrane.bw
extracellular localisation ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}-extracellular.bw
EOF
fi


TOOL="EMBOSS:6.6.0-pepstats"
if   [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_residue_number.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_molecular_weight.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_isoelectric_point.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_charge.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_acidic_number.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_alphatic_number.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_aromatic_number.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_basic_number.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_charged_number.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_c_number.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_non_polar_number.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_small_number.bw" ] \
  && [ -s "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_tiny_number.bw" ]
then
  bash "${BIN_DIR}"/jbrowse-add-multibigwig_track.sh \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${PREDECTOR}:${TOOL}" \
    --name "${TOOL}" \
    --category "Protein functions,${PREDECTOR}" \
    --description "Protein properties from ${TOOL} run as part of ${PREDECTOR}." \
    --displayType "local" \
    <<EOF
length size ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_residue_number.bw
molecular_weight size ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_molecular_weight.bw
isoelectric_point charge ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_isoelectric_point.bw
charge charge ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_charge.bw
n_acidic AA ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_acidic_number.bw
n_aliphatic AA ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_alphatic_number.bw
n_aromatic AA ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_aromatic_number.bw
n_basic AA ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_basic_number.bw
n_charged AA ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_charged_number.bw
n_cysteine AA ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_c_number.bw
n_non_polar AA ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_non_polar_number.bw
n_small AA ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_small_number.bw
n_tiny AA ${URL_BASE}/${NUCLEAR_MRNA_FUNCTIONS_BASENAME}/${PREDECTOR}:${TOOL}_aa_tiny_number.bw
EOF
fi
