#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${BIN_DIR}")/lib"

CMD=$(__generate-cli.py "$(basename $0)" "$@" <<EOF
short="-a", long="--assemblyName", dest="ASSEMBLY_NAME", type="str", help="The name of the assembly to add."
long="--displayName", dest="ASSEMBLY_LONG_NAME", type="str", default="", help="The displayed name of the assembly to add."
long="--alias", dest="ASSEMBLY_ALIASES", type="str", nargs="*", default=[], help="Alternative names of the assembly."
short="-u", long="--urlBase", dest="URL_BASE", type="str", help="The basename used for URLs of files."
short="-t", long="--target", dest="TARGET", type="str", default="${PWD}/config.json", help="The jbrowse2 config json file."
short="-k", long="--kind", dest="KIND", type="str", choice=["nuclear", "mitochondrial", "chloroplast"], default="nuclear", help="The kind of genome."
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

source "${LIB_DIR}/__jbrowse_setup_dirnames.sh" "${ASSEMBLY_NAME}"


if [ "${KIND}" == "nuclear" ]
then
  ANAME="${ASSEMBLY_NAME}"
  BASENAME="${NUCLEAR_BASENAME}"
elif [ "${KIND}" == "mitochondrial" ]
then
  ANAME="${ASSEMBLY_NAME}-MT"
  BASENAME="${MITOCHONDRIAL_BASENAME}"
elif [ "${KIND}" == "chloroplastic" ]
then
  ANAME="${ASSEMBLY_NAME}-CP"
  BASENAME="${CHLOROPLASTIC_BASENAME}"
else
  echo "ERROR: This shouldn't happen" >&2
  exit 0
fi

[ ! -z "${ASSEMBLY_LONG_NAME}" ] && ASSEMBLY_ALIASES+=( "${ASSEMBLY_LONG_NAME}" )
[ -z "${ASSEMBLY_LONG_NAME}" ] && ASSEMBLY_LONG_NAME="${ANAME}"
ASSEMBLY_ALIASES+=( "${ANAME}" )

if [ -s "${BASENAME}-metadata.json" ]
then
  readarray -t ASSEMBLY_ALIASES_ < <(jq -r 'if .genomeSynonym then (.genomeSynonym | join("\n")) else "" end' "${BASENAME}-metadata.json")
  if [ "${#ASSEMBLY_ALIASES_[@]}" -gt 0 ]
  then
    ASSEMBLY_ALIASES+=( "${ASSEMBLY_ALIASES_[@]}" )
  fi

  ASSEMBLY_LONG_NAME_=$(jq -r 'if .taxon then .taxon.name else "" end' "${BASENAME}-metadata.json")

  if [ "${KIND}" == "nuclear" ]
  then
    ASSEMBLY_LONG_NAME_="${ASSEMBLY_LONG_NAME_}"
  elif [ "${KIND}" == "mitochondrial" ]
  then
    ASSEMBLY_LONG_NAME_="${ASSEMBLY_LONG_NAME_} mitochondrial"
  elif [ "${KIND}" == "chloroplastic" ]
  then
    ASSEMBLY_LONG_NAME_="${ASSEMBLY_LONG_NAME_} chloroplastic"
  else
    echo "ERROR: This shouldn't happen" >&2
    exit 0
  fi

  if [ ! -z "${ASSEMBLY_LONG_NAME_:-}" ]
  then
    ASSEMBLY_ALIASES+=( "${ASSEMBLY_LONG_NAME_}" )
  fi

  read -d '' METADATA_CONFIG <<EOF || :
,
  "metadataLocation": {
    "uri": "${URL_BASE}/${BASENAME}-metadata.json",
    "locationType": "UriLocation"
  }
EOF
else
  METADATA_CONFIG=""
fi


if [ -s "${BASENAME}-chr_map.tsv" ]
then
  REFNAME_ALIAS_PARAM="--refNameAliases ${URL_BASE}/${BASENAME}-chr_map.tsv"
else
  REFNAME_ALIAS_PARAM=""
fi

# https://jbrowse.org/jb2/docs/config_guides/assemblies/#fasta-header-location
# https://raw.githubusercontent.com/FAIR-bioHeaders/FHR-Specification/main/examples/example.fhr.yaml

read -d '' GENOME_ADAPTER <<EOF || :
{
  "type": "BgzipFastaAdapter",
  "fastaLocation": {
    "uri": "${URL_BASE}/${BASENAME}.fasta.gz",
    "locationType": "UriLocation"
  },
  "faiLocation": {
    "uri": "${URL_BASE}/${BASENAME}.fasta.gz.fai",
    "locationType": "UriLocation"
  },
  "gziLocation": {
    "uri": "${URL_BASE}/${BASENAME}.fasta.gz.gzi",
    "locationType": "UriLocation"
  }${METADATA_CONFIG}
}
EOF


readarray -t ASSEMBLY_ALIASES < <(printf '%s\n' "${ASSEMBLY_ALIASES[@]}" | sort -u)

jbrowse add-assembly \
  --name "${ANAME}" \
  "${ASSEMBLY_ALIASES[@]/#/--alias=}" \
  --displayName "${ASSEMBLY_LONG_NAME}" \
  --load inPlace \
  --type custom \
  ${REFNAME_ALIAS_PARAM:-} \
  "${GENOME_ADAPTER}"
