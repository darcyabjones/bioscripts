#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEBUG=false

ASSEMBLY_NAME=
FASTA=
MRNA=
TRNA=
RRNA=
TE=

KIND="nuclear"

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
    --fasta)
      check_param_nodefault "--fasta" "${ASSEMBLY_LONG_NAME:-}" "${2:-}"
      ASSEMBLY_LONG_NAME="${2}"
      shift 2
      ;;
    --mRNA)
      check_param_nodefault "--mRNA" "${ASSEMBLY_LONG_NAME:-}" "${2:-}"
      MRNA="${2}"
      shift 2
      ;;
    --tRNA)
      check_nodefault_param  "--tRNA" "${URL_BASE:-}" "${2:-}"
      TRNA="${2}"
      shift 2
      ;;
    --rRNA)
      check_nodefault_param  "--rRNA" "${URL_BASE:-}" "${2:-}"
      RRNA="${2}"
      shift 2
      ;;
    --TE)
      check_nodefault_param  "--TE" "${URL_BASE:-}" "${2:-}"
      TE="${2}"
      shift 2
      ;;
    --kind)
      check_param  "--kind" "${2:-}"
      if [ "${KIND}" != "mitochondrial" ] || [ "${KIND}" != "nuclear" ]
      then
        echo "ERROR: --kind can only be mitochondrial or nuclear. Not ${2}" >&2
        exit 1
      fi
      KIND="${2}"
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

if [ -z "${ASSEMBLY_NAME}" ]
then
    echo "ERROR: We need an --assemblyName" >&2
    exit 1
fi

if [ -z "${FASTA}" ]
then
    echo "ERROR: We need a --fasta" >&2
    exit 1
elif [ ! -s "${FASTA}" ]
then
    echo "ERROR: The input fasta file ${FASTA} doesn't seem to exist." >&2
    exit 1
fi


BASENAME="${ASSEMBLY_NAME}-${KIND}"
ALIGNMENTS_BASENAME="${BASENAME}-alignments"
COMPOSITION_BASENAME="${BASENAME}-composition"
GENE_PREDICTIONS_BASENAME="${BASENAME}-gene_predictions"

MRNA_BASENAME="${BASENAME}-mRNA"
MRNA_FUNCTIONS_BASENAME="${MRNA_BASENAME}-functions"
MRNA_ALIGNMENTS_BASENAME="${MRNA_BASENAME}-alignments"

TE_BASENAME="${BASENAME}-TE"
RRNA_BASENAME="${BASENAME}-rRNA"
TRNA_BASENAME="${BASENAME}-tRNA"

GENOMIC_ALIGNMENTS="${BASENAME}-genomic_alignments"
TRANSCRIPTOMIC_ALIGNMENTS="${BASENAME}-transcriptomic_alignments"
DATABASE_ALIGNMENTS="${BASENAME}-database_alignments"

VARIANTS_BASENAME="${BASENAME}-variants"


bash "${SCRIPT_DIR}/../bgzip_fasta.sh" "${FASTA}" "${BASENAME}.fasta.gz"

if [ ! -z "${MRNA}" ]
then
  if [ -s "${MRNA}" ]
  then
    bash "${SCRIPT_DIR}/../tabix_gff.sh" "${MRNA}" "${MRNA_BASENAME}.gff3.gz"
  else
    echo "ERROR: The input file ${MRNA} doesn't seem to exist." >&2
    exit 1
  fi
fi

if [ ! -z "${RRNA}" ]
then
  if [ -s "${RRNA}" ]
  then
    bash "${SCRIPT_DIR}/../tabix_gff.sh" "${RRNA}" "${RRNA_BASENAME}.gff3.gz"
  else
    echo "ERROR: The input file ${RRNA} doesn't seem to exist." >&2
    exit 1
  fi
fi

if [ ! -z "${TRNA}" ]
then
  if [ -s "${TRNA}" ]
  then
    bash "${SCRIPT_DIR}/../tabix_gff.sh" "${TRNA}" "${TRNA_BASENAME}.gff3.gz"
  else
    echo "ERROR: The input file ${TRNA} doesn't seem to exist." >&2
    exit 1
  fi
fi

if [ ! -z "${TE}" ]
then
  if [ -s "${TE}" ]
  then
    bash "${SCRIPT_DIR}/../tabix_gff.sh" "${TE}" "${TE_BASENAME}.gff3.gz"
  else
    echo "ERROR: The input file ${TE} doesn't seem to exist." >&2
    exit 1
  fi
fi

mkdir -p \
  "${ALIGNMENTS_BASENAME}" \
  "${COMPOSITION_BASENAME}" \
  "${GENE_PREDICTIONS_BASENAME}" \
  "${MRNA_FUNCTIONS_BASENAME}" \
  "${MRNA_ALIGNMENTS_BASENAME}" \
  "${PROTEIN_FUNCTIONS_BASENAME}" \
  "${PROTEIN_ALIGNMENTS_BASENAME}" \
  "${GENOMIC_ALIGNMENTS}" \
  "${TRANSCRIPTOMIC_ALIGNMENTS}" \
  "${DATABASE_ALIGNMENTS}" \
  "${VARIANTS_BASENAME}"

