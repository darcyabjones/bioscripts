#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG="${PWD}/config.json"

DEBUG=false
ASSEMBLY_NAME=
ASSEMBLY_LONG_NAME=
ASSEMBLY_ALIASES=( )

URL_BASE=
URL_BASE_="https://storage.googleapis.com/jbrowse-sscl-data"


usage() {
  echo -e "USAGE:
$(basename $0) [--scale] [--strand] [--out PREFIX] FAI BAM

Note that options (e.g. --scale) must come before positional arguments.
"
}

usage_err() {
  usage 1>&2
  echo -e '
Run "$(basename $0) --help" for extended usage information.' 1>&2
}

help() {
  echo -e "

--target=<value>
--assemblyName=<value>
--displayName=<value> 
--urlBase=<value>
"
}

check_nodefault_param() {
    FLAG="${1}"
    PARAM="${2}"
    VALUE="${3}"
    [ ! -z "${PARAM:-}" ] && (echo "Argument ${FLAG} supplied multiple times" 1>&2; exit 1)
    [ -z "${VALUE:-}" ] && (echo "Argument ${FLAG} requires a value" 1>&2; exit 1)
    true
}

check_param() {
    FLAG="${1}"
    VALUE="${2}"
    [ -z "${VALUE:-}" ] && (echo "Argument ${FLAG} requires a value" 1>&2; exit 1)
    true
}

if [[ $# -eq 0 ]]
then
  usage
  help
  exit 0
fi

while [[ $# -gt 0 ]]
do
  key="$1"

  case "${key}" in
    -h|--help)
      usage
      help
      exit 0
      ;;
    --assemblyName)
      check_param_nodefault "--assemblyName" "${ASSEMBLY_NAME:-}" "${2:-}"
      ASSEMBLY_NAME="${2}"
      shift 2
      ;;
    --displayName)
      check_param_nodefault "--displayName" "${ASSEMBLY_LONG_NAME:-}" "${2:-}"
      ASSEMBLY_LONG_NAME="${2}"
      shift 2
      ;;
    --alias)
      check_nodefault_param  "--alias" "${ASSEMBLY_ALIASES[@]:-}" "${2:-}"
      readarray -t ASS < <(echo "${2:-}" | tr ',' '\n')
      ASSEMBLY_ALIASES+=( "${ASS[@]}" )
      shift 2
      ;;
    --urlBase)
      check_nodefault_param  "--urlBase" "${URL_BASE:-}" "${2:-}"
      URL_BASE="${2}"
      shift 2
      ;;
    --target)
      check_param  "--target" "${2:-}"
      CONFIG="${2}"
      shift 2
      ;;
    --debug)
      DEBUG=true
      set -x
      shift
      ;;
    *)
      break
  esac
done

if [ -z "${CONFIG:-}" ]
then
  echo "ERROR: missing config path, specifiy --target." >&2
  usage_err
  exit 1
fi

if [ -z "${ASSEMBLY_NAME:-}" ]
then
  echo "ERROR: --assemblyName is required" >&2
  usage_err
  exit 1
fi

if [ -z "${URL_BASE:-}" ]
then
    URL_BASE="${URL_BASE_}/${ASSEMBLY_NAME}"
fi

[ -z "${ASSEMBLY_LONG_NAME}" ] && ASSEMBLY_LONG_NAME="${ASSEMBLY_NAME}"


## Don't touch this please

NUCLEAR_BASENAME="${ASSEMBLY_NAME}-nuclear"
NUCLEAR_ALIGNMENTS_BASENAME="${NUCLEAR_BASENAME}-alignments"
NUCLEAR_COMPOSITION_BASENAME="${NUCLEAR_BASENAME}-composition"
NUCLEAR_GENE_PREDICTIONS_BASENAME="${NUCLEAR_BASENAME}-gene_predictions"

NUCLEAR_MRNA_BASENAME="${NUCLEAR_BASENAME}-mRNA"
NUCLEAR_MRNA_FUNCTIONS_BASENAME="${NUCLEAR_MRNA_BASENAME}-functions"
NUCLEAR_MRNA_ALIGNMENTS_BASENAME="${NUCLEAR_MRNA_BASENAME}-alignments"


NUCLEAR_TE_BASENAME="${NUCLEAR_BASENAME}-TE"
NUCLEAR_RRNA_BASENAME="${NUCLEAR_BASENAME}-rRNA"
NUCLEAR_TRNA_BASENAME="${NUCLEAR_BASENAME}-tRNA"

NUCLEAR_PROTEIN_BASENAME="${NUCLEAR_BASENAME}-protein"
NUCLEAR_PROTEIN_FUNCTIONS_BASENAME="${NUCLEAR_PROTEIN_BASENAME}-functions"
NUCLEAR_PROTEIN_ALIGNMENTS_BASENAME="${NUCLEAR_PROTEIN_BASENAME}-alignments"

NUCLEAR_GENOMIC_ALIGNMENTS="${ASSEMBLY_NAME}-nuclear-genomic_alignments"
NUCLEAR_TRANSCRIPTOMIC_ALIGNMENTS="${ASSEMBLY_NAME}-nuclear-transcriptomic_alignments"
NUCLEAR_DATABASE_ALIGNMENTS="${ASSEMBLY_NAME}-nuclear-database_alignments"

NUCLEAR_VARIANTS_BASENAME="${NUCLEAR_BASENAME}-variants"


if [ -d "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}" ]
then
    ls "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}" \
      | (grep "^Predector" || :) \
      | sed 's/Predector:\([^:]*\).*/Predector:\1/' \
      | sort -u \
      | readarray -t PREDECTOR_VERSIONS
else
    PREDECTOR_VERSIONS=( )
fi

if [ -d "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}" ]
then
    ls "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}" \
      | (grep "^InterProScan" || :) \
      | sed 's/InterProScan:\([^:]*\).*/InterProScan:\1/' \
      | sort -u \
      | readarray -t IPS_VERSIONS
else
    IPS_VERSIONS=( )
fi

find_greatest_common_prefix() {
  if command -v gsed
  then
    SED=gsed
  else
    SED=sed
  fi
  printf '%s\n' "${@}" | ${SED} -e 'N;s/^\(.*\).*\n\1.*$/\1\n\1/;D'
}


# https://jbrowse.org/jb2/docs/config_guides/assemblies/#fasta-header-location
# https://raw.githubusercontent.com/FAIR-bioHeaders/FHR-Specification/main/examples/example.fhr.yaml


jbrowse add-assembly \
  --name "${ASSEMBLY_NAME}" \
  ${ASSEMBLY_ALIASES[@]/#/ --alias=} \
  --displayName "${ASSEMBLY_LONG_NAME}" \
  --type bgzipFasta \
  "${URL_BASE}/${NUCLEAR_BASENAME}.fasta.gz"


read -d '' MRNA_DISPLAY <<EOF || :
{
  "formatDetails": {
    "feature": "jexl: linkout_defaults(feature)",
    "subfeatures": "jexl: linkout_defaults(feature)"
  },
  "displays": [
    {
      "type": "LinearBasicDisplay",
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


if [ -s "${NUCLEAR_MRNA_BASENAME}.gff3.gz" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_BASENAME}" \
    --name "mRNA" \
    --category "Genes" \
    --description "Protein coding gene predictions." \
    --config "${MRNA_DISPLAY}" \
    "${URL_BASE}/${NUCLEAR_MRNA_BASENAME}.gff3.gz"
fi


read -d '' TE_DISPLAY <<EOF || :
{
  "displays": [
    {
      "type": "LinearBasicDisplay",
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

if [ -s "${NUCLEAR_TE_BASENAME}.gff3.gz" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_TE_BASENAME}" \
    --name "TE" \
    --category "Genes" \
    --description "Transposable element and repeat predictions from EDTA." \
    --config "${TE_DISPLAY}" \
    "${URL_BASE}/${NUCLEAR_TE_BASENAME}.gff3.gz"
fi

if  [ -s "${NUCLEAR_RRNA_BASENAME}.gff3.gz" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_RRNA_BASENAME}" \
    --name "rRNA" \
    --category "Genes" \
    --description "rRNA gene predictions." \
    "${URL_BASE}/${NUCLEAR_RRNA_BASENAME}.gff3.gz"
fi


if [ -s  "${NUCLEAR_TRNA_BASENAME}.gff3.gz" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_TRNA_BASENAME}" \
    --name "tRNA" \
    --category "Genes" \
    --description "tRNA gene predictions." \
    "${URL_BASE}/${NUCLEAR_TRNA_BASENAME}.gff3.gz"
fi


THIS_CONFIG='{"displays": [{ "type": "LinearWiggleDisplay", "minScore": 0, "maxScore": 1, "posColor": "red", "negColor": "blue", "bicolorPivot": "numeric", "bicolorPivotValue": 0.5}]}'

if [ -s "${NUCLEAR_COMPOSITION_BASENAME}/gc.bw" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_COMPOSITION_BASENAME}-GC" \
    --name "GC" \
    --category "Composition" \
    --description "Genome GC content in 1000bp windows." \
    --config "${THIS_CONFIG}" \
    "${URL_BASE}/${NUCLEAR_COMPOSITION_BASENAME}/gc.bw"
fi

THIS_CONFIG='{"displays": [{ "type": "LinearWiggleDisplay", "minScore": -1.5, "maxScore": 1.5, "posColor": "red", "negColor": "blue", "bicolorPivot": "numeric", "bicolorPivotValue": 0}]}'

if [ -s "${NUCLEAR_COMPOSITION_BASENAME}/cri.bw" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_COMPOSITION_BASENAME}-CRI" \
    --name "CRI" \
    --category "Composition" \
    --description "Genome composite RIP index (CRI) in 1000bp windows. Values > 0 indicate possible RIP." \
    --config "${THIS_CONFIG}" \
    "${URL_BASE}/${NUCLEAR_COMPOSITION_BASENAME}/cri.bw"
fi


for f in "${NUCLEAR_GENE_PREDICTIONS_BASENAME}/"*.gff3.gz
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  TOOL="$(basename "${f%.gff3.gz}")"

  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_GENE_PREDICTIONS_BASENAME}-${TOOL}" \
    --name "${TOOL}" \
    --category "Gene predictions" \
    --description "Nuclear gene predections from ${TOOL}." \
    "${URL_BASE}/${NUCLEAR_GENE_PREDICTIONS_BASENAME}/$(basename ${f})"
done


for f in "${NUCLEAR_DATABASE_ALIGNMENTS}/"*.gff3.gz
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  TOOL="$(basename "${f%.gff3.gz}")"

  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}-${TOOL}" \
    --name "${TOOL}" \
    --category "Database alignments" \
    --description "${TOOL} database alignments to nuclear genome." \
    "${URL_BASE}/${NUCLEAR_DATABASE_ALIGNMENTS}/$(basename ${f})"
done


for PREDECTOR in "${PREDECTOR_VERSIONS[@]}"
do
    bash "${SCRIPT_DIR}/add_predector_tracks.sh" \
        "${CONFIG}" \
        "${ASSEMBLY_NAME}" \
        "${URL_BASE}" \
        "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}" \
        "${PREDECTOR}"
done

for IPS in "${IPS_VERSIONS[@]}"
do
    bash "${SCRIPT_DIR}/add_interproscan_tracks.sh" \
        "${CONFIG}" \
        "${ASSEMBLY_NAME}" \
        "${URL_BASE}" \
        "${NUCLEAR_MRNA_FUNCTIONS_BASENAME}" \
        "${IPS}"
done


for f in "${NUCLEAR_TRANSCRIPTOMIC_ALIGNMENTS}"/*.cram
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  BN="$(basename "${f%.cram}")"
  META="${f%.cram}-metadata.json"

  if [ -s "${META}" ]
  then
    NAME="$(cat "${META}" | jq -r '.name')"
    META="$(cat "${META}")"
    if [ ! -z "${META:-}" ]
    then
      META="{\"metadata\": ${META}}"
    else
      META="{}"
    fi

    if [ -z "${NAME}" ]
    then
      NAME="${BN}"
    fi

    jbrowse add-track \
      --target "${CONFIG}" \
      --assemblyNames "${ASSEMBLY_NAME}" \
      --trackId "${NUCLEAR_TRANSCRIPTOMIC_ALIGNMENTS}-${BN}" \
      --name "${NAME}" \
      --category "Transcriptomic sequencing alignments,reads" \
      --description "Aligned transcriptomic sequencing reads." \
      --config "${META}" \
      "${URL_BASE}/${NUCLEAR_TRANSCRIPTOMIC_ALIGNMENTS}/$(basename ${f})"
  else
    jbrowse add-track \
      --target "${CONFIG}" \
      --assemblyNames "${ASSEMBLY_NAME}" \
      --trackId "${NUCLEAR_TRANSCRIPTOMIC_ALIGNMENTS}-${BN}" \
      --name "${BN}" \
      --category "Transcriptomic sequencing alignments,reads" \
      --description "Aligned transcriptomic sequencing reads." \
      "${URL_BASE}/${NUCLEAR_TRANSCRIPTOMIC_ALIGNMENTS}/$(basename ${f})"
  fi
done


for f in "${NUCLEAR_GENOMIC_ALIGNMENTS}"/*.cram
do
  if [ ! -s "${f}" ]
  then
    continue
  fi

  BN="$(basename "${f%.cram}")"
  META="${f%.cram}-metadata.json"

  if [ -s "${META}" ]
  then
    NAME="$(cat "${META}" | jq -r '.name')"
    META="$(cat "${META}")"
    META="{\"metadata\": ${META}}"

    jbrowse add-track \
      --target "${CONFIG}" \
      --assemblyNames "${ASSEMBLY_NAME}" \
      --trackId "${NUCLEAR_GENOMIC_ALIGNMENTS}-${BN}" \
      --name "${NAME}" \
      --category "Genomic sequencing alignments,reads" \
      --description "Aligned genomic sequencing reads." \
      --config "${META}" \
      "${URL_BASE}/${NUCLEAR_GENOMIC_ALIGNMENTS}/$(basename ${f})"
  else
    jbrowse add-track \
      --target "${CONFIG}" \
      --assemblyNames "${ASSEMBLY_NAME}" \
      --trackId "${NUCLEAR_GENOMIC_ALIGNMENTS}-${BN}" \
      --name "${BN}" \
      --category "Genomic sequencing alignments,reads" \
      --description "Aligned genomic sequencing reads." \
      "${URL_BASE}/${NUCLEAR_GENOMIC_ALIGNMENTS}/$(basename ${f})"
  fi
done


TOOL="GATK:4.4.0.0"
if [ -s  "${NUCLEAR_VARIANTS_BASENAME}/${TOOL}.vcf.gz" ]
then
  jbrowse add-track \
    --target "${CONFIG}" \
    --assemblyNames "${ASSEMBLY_NAME}" \
    --trackId "${NUCLEAR_VARIANTS_BASENAME}-${TOOL}" \
    --name "Short variants" \
    --category "Variants" \
    --description "SNP and short INDEL/MNP predictions from illumina datasets." \
    "${URL_BASE}/${NUCLEAR_TRNA_BASENAME}/${TOOL}.vcf.gz"
fi
