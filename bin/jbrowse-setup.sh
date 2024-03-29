#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${BIN_DIR}")/lib"

CMD=$(__generate-cli.py "$(basename $0)" "$@" <<EOF
short="-a", long="--assemblyName", dest="ASSEMBLY_NAME", type="str", help="The name of the assembly to add."
long="--displayName", dest="ASSEMBLY_LONG_NAME", type="str", default="", help="The displayed name of the assembly to add."
long="--alias", dest="ASSEMBLY_ALIASES", type="str", nargs="+", default=[], help="Alternative names of the assembly."
short="-u", long="--urlBase", dest="URL_BASE", type="str", help="The basename used for URLs of files."
short="-t", long="--target", dest="TARGET", type="str", default="${PWD}/config.json", help="The jbrowse2 config json file."
short="-k", long="--kind", dest="KIND", type="str", choice=["nuclear", "mitochondrial", "chloroplast"], default="nuclear", help="The kind of genome."
long="--debug", dest="DEBUG", type="FLAG", default=False, help="Print extra logs to stdout."
EOF
)

if [ ! -s "base.config.json" ]
then
cat <<'EOF' > base.config.json || :
{
  "plugins": [
    {
    "name": "Linkout",
    "url": "https://storage.googleapis.com/jbrowse-sscl-data/linkout.js"
    },
    {
    "name": "ChildAttributes",
    "url": "https://storage.googleapis.com/jbrowse-sscl-data/child_attributes.js"
    }
  ]
}
EOF
fi

if ! (echo "${CMD}" | grep '^### __generate-cli output$' > /dev/null)
then
  # help or an error occurred
  echo "# $(basename $0)"
  echo "${CMD}"
  exit 0
fi

eval "${CMD}"

if [ "${DEBUG:-}"=True ]
then
  set +x
  DEBUG_FLAG="--debug"
else
  DEBUG_FLAG=""
fi

source "${LIB_DIR}/__jbrowse_setup_dirnames.sh" "${ASSEMBLY_NAME}"

if [ "${KIND}" == "nuclear" ]
then
  ANAME="${ASSEMBLY_NAME}"
  BASENAME="${NUCLEAR_BASENAME}"
  ALIGNMENTS_BASENAME="${NUCLEAR_ALIGNMENTS_BASENAME}"
  COMPOSITION_BASENAME="${NUCLEAR_COMPOSITION_BASENAME}"
  GENE_PREDICTIONS_BASENAME="${NUCLEAR_GENE_PREDICTIONS_BASENAME}"
  MRNA_BASENAME="${NUCLEAR_MRNA_BASENAME}"
  MRNA_FUNCTIONS_BASENAME="${NUCLEAR_MRNA_FUNCTIONS_BASENAME}"
  MRNA_ALIGNMENTS_BASENAME="${NUCLEAR_MRNA_ALIGNMENTS_BASENAME}"
  TE_BASENAME="${NUCLEAR_TE_BASENAME}"
  RRNA_BASENAME="${NUCLEAR_RRNA_BASENAME}"
  TRNA_BASENAME="${NUCLEAR_TRNA_BASENAME}"
  NCRNA_BASENAME="${NUCLEAR_NCRNA_BASENAME}"
  PSEUDOGENE_BASENAME="${NUCLEAR_PSEUDOGENE_BASENAME}"
  PROTEIN_BASENAME="${NUCLEAR_PROTEIN_BASENAME}"
  PROTEIN_FUNCTIONS_BASENAME="${NUCLEAR_PROTEIN_FUNCTIONS_BASENAME}"
  PROTEIN_ALIGNMENTS_BASENAME="${NUCLEAR_PROTEIN_ALIGNMENTS_BASENAME}"
  GENOMIC_ALIGNMENTS="${NUCLEAR_GENOMIC_ALIGNMENTS}"
  TRANSCRIPTOMIC_ALIGNMENTS="${NUCLEAR_TRANSCRIPTOMIC_ALIGNMENTS}"
  DATABASE_ALIGNMENTS="${NUCLEAR_DATABASE_ALIGNMENTS}"
  VARIANTS_BASENAME="${NUCLEAR_VARIANTS_BASENAME}"
  MRNA_FUNCTIONS_BASENAME="${NUCLEAR_MRNA_FUNCTIONS_BASENAME}"
elif [ "${KIND}" == "mitochondrial" ]
then
  ANAME="${ASSEMBLY_NAME}-MT"
  BASENAME="${MITOCHONDRIAL_BASENAME}"
  ALIGNMENTS_BASENAME="${MITOCHONDRIAL_ALIGNMENTS_BASENAME}"
  COMPOSITION_BASENAME="${MITOCHONDRIAL_COMPOSITION_BASENAME}"
  GENE_PREDICTIONS_BASENAME="${MITOCHONDRIAL_GENE_PREDICTIONS_BASENAME}"
  MRNA_BASENAME="${MITOCHONDRIAL_MRNA_BASENAME}"
  MRNA_FUNCTIONS_BASENAME="${MITOCHONDRIAL_MRNA_FUNCTIONS_BASENAME}"
  MRNA_ALIGNMENTS_BASENAME="${MITOCHONDRIAL_MRNA_ALIGNMENTS_BASENAME}"
  TE_BASENAME="${MITOCHONDRIAL_TE_BASENAME}"
  RRNA_BASENAME="${MITOCHONDRIAL_RRNA_BASENAME}"
  TRNA_BASENAME="${MITOCHONDRIAL_TRNA_BASENAME}"
  NCRNA_BASENAME="${MITOCHONDRIAL_NCRNA_BASENAME}"
  PSEUDOGENE_BASENAME="${MITOCHONDRIAL_PSEUDOGENE_BASENAME}"
  PROTEIN_BASENAME="${MITOCHONDRIAL_PROTEIN_BASENAME}"
  PROTEIN_FUNCTIONS_BASENAME="${MITOCHONDRIAL_PROTEIN_FUNCTIONS_BASENAME}"
  PROTEIN_ALIGNMENTS_BASENAME="${MITOCHONDRIAL_PROTEIN_ALIGNMENTS_BASENAME}"
  GENOMIC_ALIGNMENTS="${MITOCHONDRIAL_GENOMIC_ALIGNMENTS}"
  TRANSCRIPTOMIC_ALIGNMENTS="${MITOCHONDRIAL_TRANSCRIPTOMIC_ALIGNMENTS}"
  DATABASE_ALIGNMENTS="${MITOCHONDRIAL_DATABASE_ALIGNMENTS}"
  VARIANTS_BASENAME="${MITOCHONDRIAL_VARIANTS_BASENAME}"
  MRNA_FUNCTIONS_BASENAME="${MITOCHONDRIAL_MRNA_FUNCTIONS_BASENAME}"
elif [ "${KIND}" == "chloroplastic" ]
then
  ANAME="${ASSEMBLY_NAME}-CP"
  BASENAME="${CHLOROPLASTIC_BASENAME}"
  ALIGNMENTS_BASENAME="${CHLOROPLASTIC_ALIGNMENTS_BASENAME}"
  COMPOSITION_BASENAME="${CHLOROPLASTIC_COMPOSITION_BASENAME}"
  GENE_PREDICTIONS_BASENAME="${CHLOROPLASTIC_GENE_PREDICTIONS_BASENAME}"
  MRNA_BASENAME="${CHLOROPLASTIC_MRNA_BASENAME}"
  MRNA_FUNCTIONS_BASENAME="${CHLOROPLASTIC_MRNA_FUNCTIONS_BASENAME}"
  MRNA_ALIGNMENTS_BASENAME="${CHLOROPLASTIC_MRNA_ALIGNMENTS_BASENAME}"
  TE_BASENAME="${CHLOROPLASTIC_TE_BASENAME}"
  RRNA_BASENAME="${CHLOROPLASTIC_RRNA_BASENAME}"
  TRNA_BASENAME="${CHLOROPLASTIC_TRNA_BASENAME}"
  NCRNA_BASENAME="${CHLOROPLASTIC_NCRNA_BASENAME}"
  PSEUDOGENE_BASENAME="${CHLOROPLASTIC_PSEUDOGENE_BASENAME}"
  PROTEIN_BASENAME="${CHLOROPLASTIC_PROTEIN_BASENAME}"
  PROTEIN_FUNCTIONS_BASENAME="${CHLOROPLASTIC_PROTEIN_FUNCTIONS_BASENAME}"
  PROTEIN_ALIGNMENTS_BASENAME="${CHLOROPLASTIC_PROTEIN_ALIGNMENTS_BASENAME}"
  GENOMIC_ALIGNMENTS="${CHLOROPLASTIC_GENOMIC_ALIGNMENTS}"
  TRANSCRIPTOMIC_ALIGNMENTS="${CHLOROPLASTIC_TRANSCRIPTOMIC_ALIGNMENTS}"
  DATABASE_ALIGNMENTS="${CHLOROPLASTIC_DATABASE_ALIGNMENTS}"
  VARIANTS_BASENAME="${CHLOROPLASTIC_VARIANTS_BASENAME}"
  MRNA_FUNCTIONS_BASENAME="${CHLOROPLASTIC_MRNA_FUNCTIONS_BASENAME}"
else
  echo "ERROR: This shouldn't happen" >&2
  exit 0
fi

bash "${BIN_DIR}/jbrowse-add-assembly.sh" \
  --assemblyName "${ASSEMBLY_NAME}" \
  --displayName "${ASSEMBLY_LONG_NAME}" \
  --alias "${ALIAS[@]}" \
  --urlBase "${URL_BASE}" \
  --target "${TARGET}" \
  --kind "${KIND}" \
  ${DEBUG_FLAG}

if [ -d "${MRNA_FUNCTIONS_BASENAME}" ]
then
    readarray -t PREDECTOR_VERSIONS < <(
      ls "${MRNA_FUNCTIONS_BASENAME}" \
      | (grep "^Predector" || :) \
      | sed 's/Predector:\([^:]*\).*/Predector:\1/' \
      | sort -u
    )
else
    PREDECTOR_VERSIONS=( )
fi

bash "${BIN_DIR}/merge_json_recursive.sh" "base.config.json" "${TARGET}" > "${TARGET}.tmp"
mv "${TARGET}.tmp" "${TARGET}"

if [ -d "${MRNA_FUNCTIONS_BASENAME}" ]
then
    readarray -t IPS_VERSIONS < <(
      ls "${MRNA_FUNCTIONS_BASENAME}" \
      | (grep "^InterProScan" || :) \
      | sed 's/InterProScan:\([^:]*\).*/InterProScan:\1/' \
      | sort -u
    )
else
    IPS_VERSIONS=( )
fi

MRNA_DISPLAY="${MRNA_BASENAME}-jbrowse_config.json"

if [ ! -s "${MRNA_DISPLAY}" ]
then
  cat <<EOF > "${MRNA_DISPLAY}" || :
{
  "formatDetails": {
    "feature": "jexl: linkout_defaults(feature)",
    "subfeatures": "jexl: linkout_defaults(feature)"
  },
  "displays": [
    {
      "type": "LinearBasicDisplay",
      "displayId": "${MRNA_BASENAME}-LinearBasicDisplay",
      "renderer": {
        "type": "SvgFeatureRenderer",
        "labels": {
          "description": "jexl:childAttributes(feature, ';', 'product', ['hypothetical protein', 'hypothetical_protein'])"
        }
      }
    }
  ]
}
EOF
fi

if [ -s "${MRNA_BASENAME}.gff3.gz" ]
then
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --trackId "${MRNA_BASENAME}" \
    --name "mRNA" \
    --category "Genes" \
    --description "Protein coding gene predictions." \
    --urlBase "${URL_BASE}" \
    "" \
    "${MRNA_BASENAME}.gff3.gz"

fi


TE_DISPLAY="${TE_BASENAME}-jbrowse_config.json"
if [ ! -s "${TE_DISPLAY}" ]
then
  read -d '' TE_DISPLAY <<EOF || :
{
  "displays": [
    {
      "type": "LinearBasicDisplay",
      "displayId": "${MRNA_BASENAME}-LinearBasicDisplay",
      "renderer": {
        "type": "SvgFeatureRenderer",
        "labels": {
          "name": "jexl:get(feature, 'type') || get(feature, 'classification')"
        }
      }
    }
  ]
}
EOF
fi

if [ -s "${TE_BASENAME}.gff3.gz" ]
then
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --trackId "${TE_BASENAME}" \
    --name "TE" \
    --category "Genes" \
    --description "Transposable element and repeat predictions from EDTA." \
    --urlBase "${URL_BASE}" \
    "" \
    "${TE_BASENAME}.gff3.gz"
fi


if  [ -s "${RRNA_BASENAME}.gff3.gz" ]
then
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --trackId "${RRNA_BASENAME}" \
    --name "rRNA" \
    --category "Genes" \
    --description "rRNA gene predictions." \
    --urlBase "${URL_BASE}" \
    "" \
    "${RRNA_BASENAME}.gff3.gz"
fi


if [ -s  "${TRNA_BASENAME}.gff3.gz" ]
then
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --trackId "${TRNA_BASENAME}" \
    --name "tRNA" \
    --category "Genes" \
    --description "tRNA gene predictions." \
    --urlBase "${URL_BASE}" \
    "" \
    "${TRNA_BASENAME}.gff3.gz"
fi

if  [ -s "${NCRNA_BASENAME}.gff3.gz" ]
then
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --trackId "${NCRNA_BASENAME}" \
    --name "ncRNA" \
    --category "Genes" \
    --description "non-coding RNA gene predictions." \
    --urlBase "${URL_BASE}" \
    "" \
    "${NCRNA_BASENAME}.gff3.gz"
fi


if [ -s  "${PSEUDOGENE_BASENAME}.gff3.gz" ]
then
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --trackId "${PSEUDOGENE_BASENAME}" \
    --name "pseudogene" \
    --category "Genes" \
    --description "pseudogene predictions." \
    --urlBase "${URL_BASE}" \
    "" \
    "${PSEUDOGENE_BASENAME}.gff3.gz"
fi

THIS_CONFIG='{"displays": [{ "type": "LinearWiggleDisplay", "displayId": "'"${COMPOSITION_BASENAME}"'-GC-LinearWiggleDisplay", "minScore": 0, "maxScore": 1, "posColor": "red", "negColor": "blue", "bicolorPivot": "numeric", "bicolorPivotValue": 0.5}]}'


if [ -s "${COMPOSITION_BASENAME}/gc.bw" ]
then
  jbrowse add-track \
    --target "${TARGET}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${COMPOSITION_BASENAME}-GC" \
    --name "GC" \
    --category "Composition" \
    --description "Genome GC content in 1000bp windows." \
    --config "${THIS_CONFIG}" \
    "${URL_BASE}/${COMPOSITION_BASENAME}/gc.bw"
fi

THIS_CONFIG='{"displays": [{ "type": "LinearWiggleDisplay", "displayId": "'"${COMPOSITION_BASENAME}"'-CRI-LinearWiggleDisplay", "minScore": -1.5, "maxScore": 1.5, "posColor": "red", "negColor": "blue", "bicolorPivot": "numeric", "bicolorPivotValue": 0}]}'


if [ -s "${COMPOSITION_BASENAME}/cri.bw" ]
then
  jbrowse add-track \
    --target "${TARGET}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${COMPOSITION_BASENAME}-CRI" \
    --name "CRI" \
    --category "Composition" \
    --description "Genome composite RIP index (CRI) in 1000bp windows. Values > 0 indicate possible RIP." \
    --config "${THIS_CONFIG}" \
    "${URL_BASE}/${COMPOSITION_BASENAME}/cri.bw"
fi


for f in "${GENE_PREDICTIONS_BASENAME}/"*.gff3.gz
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  TOOL="$(basename "$f")"
  TOOL="${TOOL%.gff3.gz}"

  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --category "Gene predictions" \
    --description "Nuclear gene predections from ${TOOL}." \
    --urlBase "${URL_BASE}" \
    --extension "gff3" \
    "${GENE_PREDICTIONS_BASENAME}" \
    "${f}"
  unset TOOL
done


for f in "${DATABASE_ALIGNMENTS}/"*.gff3.gz
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  TOOL="$(basename "$f")"
  TOOL="${TOOL%.gff3.gz}"

  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --category "Database alignments" \
    --description "${TOOL} database alignments to nuclear genome." \
    --urlBase "${URL_BASE}" \
    --extension "gff3" \
    "${DATABASE_ALIGNMENTS}" \
    "${f}"
  unset TOOL
done


for PREDECTOR in "${PREDECTOR_VERSIONS[@]}"
do
    bash "${BIN_DIR}/jbrowse-add-predector_tracks.sh" \
        "${TARGET}" \
        "${ASSEMBLY_NAME}" \
        "${URL_BASE}" \
        "${MRNA_FUNCTIONS_BASENAME}" \
        "${PREDECTOR}"
done


for IPS in "${IPS_VERSIONS[@]}"
do
    bash "${BIN_DIR}/jbrowse-add-interproscan_tracks.sh" \
        "${TARGET}" \
        "${ASSEMBLY_NAME}" \
        "${URL_BASE}" \
        "${MRNA_FUNCTIONS_BASENAME}" \
        "${IPS}"
done


add_transcriptomic_cram() {
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --urlBase "${URL_BASE}" \
    --category "Transcriptomic sequencing alignments,reads" \
    --description "Aligned transcriptomic sequencing reads." \
    "${TRANSCRIPTOMIC_ALIGNMENTS}" \
    "${1}"
} 

add_transcriptomic_bigwig() {
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --urlBase "${URL_BASE}" \
    --category "Transcriptomic sequencing alignments,coverage" \
    --description "Coverage of aligned transcriptomic sequencing reads." \
    "${TRANSCRIPTOMIC_ALIGNMENTS}" \
    "${1}"
} 

add_genomic_cram() {
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --urlBase "${URL_BASE}" \
    --category "Genomic sequencing alignments,reads" \
    --description "Aligned genomic sequencing reads." \
    "${GENOMIC_ALIGNMENTS}" \
    "${1}"
} 

add_genomic_bigwig() {
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --urlBase "${URL_BASE}" \
    --category "Genomic sequencing alignments,coverage" \
    --description "Coverage of aligned genomic sequencing reads." \
    "${GENOMIC_ALIGNMENTS}" \
    "${1}"
} 

add_vcf() {
  bash "${BIN_DIR}/jbrowse-add-track.sh" \
    --target "${TARGET}" \
    --assemblyName "${ASSEMBLY_NAME}" \
    --urlBase "${URL_BASE}" \
    --category "Variants" \
    --description "Genomic variants." \
    "${VARIANTS_BASENAME}" \
    "${1}"
}


for f in "${TRANSCRIPTOMIC_ALIGNMENTS}"/*.cram
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  add_transcriptomic_cram "$f"
done

for f in "${TRANSCRIPTOMIC_ALIGNMENTS}"/*.bw
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  add_transcriptomic_bigwig "$f"
done

for f in "${GENOMIC_ALIGNMENTS}"/*.cram
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  add_genomic_cram "$f"
done

for f in "${GENOMIC_ALIGNMENTS}"/*.bw
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  add_genomic_bigwig "$f"
done

for f in "${VARIANTS_BASENAME}/"*.vcf.gz
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  add_vcf "$f"
done
