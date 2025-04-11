#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${BIN_DIR}")/lib"


CMD=$(__generate-cli.py "$(basename $0)" "$@" <<EOF
short="-a", long="--assemblyName", dest="ASSEMBLY_NAME", type="str", help="The name of the assembly to add."
short="-k", long="--kind", dest="KIND", type="str", choice=["nuclear", "mitochondrial", "chloroplast"], default="nuclear", help="The kind of genome."
short="-f", long="--fasta", dest="FASTA", type="str", help="The genome fasta to use."
short="-m", long="--mRNA", dest="MRNA", type="str", default="", help="The mRNA gff3 file."
short="-r", long="--rRNA", dest="RRNA", type="str", default="", help="The rRNA gff3 file."
short="-t", long="--tRNA", dest="TRNA", type="str", default="", help="The tRNA gff3 file."
short="-e", long="--TE", dest="TE", type="str", default="", help="The TE gff3 file."
long="--ncRNA", dest="NCRNA", type="str", default="", help="The ncRNA gff3 file."
long="--pseudogene", dest="PSEUDOGENE", type="str", default="", help="The pseudogene gff3 file."
short="-b", long="--baseDir", dest="BASEDIR", type="str", default=".", help="Where to place the main directory."
long="--debug", dest="DEBUG", type="FLAG", default=False, help="Print extra logs to stdout."
EOF
)

if ! (echo "${CMD}" | grep '^### __generate-cli output$' > /dev/null)
then
  # help or an error occurred
  echo "# $(basename $0)"
  echo "${CMD}"
  exit 0
fi

eval "${CMD}"

if [ "${DEBUG:-}"="True" ]
then
  set +x
fi

source "${LIB_DIR}/__jbrowse_setup_dirnames.sh" "${ASSEMBLY_NAME}" "${KIND}" "${BASEDIR:-}"
source "${LIB_DIR}/external_tool_helpers.sh"

mkdir -p \
  "${COMPOSITION_BASENAME}" \
  "${FEATURE_PREDICTIONS_BASENAME}" \
  "${MRNA_FUNCTIONS_BASENAME}" \
  "${MRNA_ALIGNMENTS_BASENAME}" \
  "${PROTEIN_FUNCTIONS_BASENAME}" \
  "${PROTEIN_ALIGNMENTS_BASENAME}" \
  "${GENOMIC_ALIGNMENTS}" \
  "${TRANSCRIPTOMIC_ALIGNMENTS}" \
  "${DATABASE_ALIGNMENTS}" \
  "${VARIANTS_BASENAME}"


bash "${BIN_DIR}/__init_fhr_json.sh" "${ASSEMBLY_NAME}" "${KIND}" > "${BASENAME}-metadata.json" 

if [ ! -s "${FASTA}" ]
then
    echo "ERROR: The input fasta file ${FASTA} doesn't seem to exist." >&2
    exit 1
fi

bash "${BIN_DIR}/bgzip_fasta.sh" "${FASTA}" "${BASENAME}.fasta.gz"

if [ ! -z "${MRNA}" ]
then
  if [ ! -s "${MRNA}" ]
  then
    echo "ERROR: The input file ${MRNA} doesn't seem to exist." >&2
    exit 1
  fi

  bash "${BIN_DIR}/tabix_gff3.sh" "${MRNA}" "${MRNA_BASENAME}.gff3.gz"
  try_extract_cds "${FASTA}" "${MRNA}" "${MRNA_BASENAME}"
  try_extract_protein "${FASTA}" "${MRNA}" "${MRNA_BASENAME}"
  try_extract_transcript "${FASTA}" "${MRNA}" "${MRNA_BASENAME}"
fi

if [ ! -z "${RRNA}" ]
then
  if [ -s "${RRNA}" ]
  then
    bash "${BIN_DIR}/tabix_gff3.sh" "${RRNA}" "${RRNA_BASENAME}.gff3.gz"
  else
    echo "ERROR: The input file ${RRNA} doesn't seem to exist." >&2
    exit 1
  fi
fi

if [ ! -z "${TRNA}" ]
then
  if [ -s "${TRNA}" ]
  then
    bash "${BIN_DIR}/tabix_gff3.sh" "${TRNA}" "${TRNA_BASENAME}.gff3.gz"
  else
    echo "ERROR: The input file ${TRNA} doesn't seem to exist." >&2
    exit 1
  fi
fi

if [ ! -z "${TE}" ]
then
  if [ -s "${TE}" ]
  then
    bash "${BIN_DIR}/tabix_gff3.sh" "${TE}" "${TE_BASENAME}.gff3.gz"
  else
    echo "ERROR: The input file ${TE} doesn't seem to exist." >&2
    exit 1
  fi
fi

if [ ! -z "${NCRNA}" ]
then
  if [ -s "${NCRNA}" ]
  then
    bash "${BIN_DIR}/tabix_gff3.sh" "${NCRNA}" "${NCRNA_BASENAME}.gff3.gz"
  else
    echo "ERROR: The input file ${NCRNA} doesn't seem to exist." >&2
    exit 1
  fi
fi

if [ ! -z "${PSEUDOGENE}" ]
then
  if [ -s "${PSEUDOGENE}" ]
  then
    bash "${BIN_DIR}/tabix_gff3.sh" "${PSEUDOGENE}" "${PSEUDOGENE_BASENAME}.gff3.gz"
  else
    echo "ERROR: The input file ${PSEUDOGENE} doesn't seem to exist." >&2
    exit 1
  fi
fi
