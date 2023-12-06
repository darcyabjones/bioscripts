#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${BIN_DIR}")/lib"

CMD=$(__generate-cli.py "$(basename $0)" "$@" <<EOF
dest="BASENAME", type="str", help="The directory name." 
dest="INFILE", type="str", help="The file to add as a jbrowse track."
short="-i", long="--trackId", dest="TRACK_ID", type="str", default="", help="The ID associated with the track."
short="-n", long="--name", dest="NAME", type="str", default="", help="The display name to give the track."
short="-a", long="--assemblyName", dest="ASSEMBLY_NAME", type="str", help="The name of the assembly to add."
short="-d", long="--description", dest="DESCRIPTION", type="str", default="", help="Some descriptive text to add for the track."
long="--category", dest="CATEGORIES", type="str", nargs="+", default=[], help="Labels to use for the track."
short="-u", long="--urlBase", dest="URL_BASE", type="str", help="The basename used for URLs of files."
short="-t", long="--target", dest="TARGET", type="str", default="${PWD}/config.json", help="The jbrowse2 config json file."
long="--config", dest="TRACK_CONFIG_CLI", type="str", default="", help="Additional json data to add to the track."
short="-e", long="--extension", dest="EXTENSION", type="str", default="", help="The file type to add. Exclude the dot, and a .gz extension if there is one."
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

if [ "${DEBUG:-}"=True ]
then
  set +x
fi

if [ -z "${EXTENSION:-}" ] && [[ "${INFILE}" == *.gz ]]
then
  BN="${INFILE%.gz}"
  EXTENSION="${BN##*.}"
  BN="${BN%.*}"
elif [ -z "${EXTENSION:-}" ]
then
  EXTENSION="${INFILE##*.}"
  BN="${INFILE%.*}"
else
  EXTENSION="${EXTENSION%.gz}"
  EXTENSION="${EXTENSION#.}"
  BN="${INFILE%.gz}"
  BN="${BN%.${EXTENSION}}"
fi

TRACK_META_FILE="${BN}-metadata.json"
TRACK_CONFIG_FILE="${BN}-jbrowse_config.json"
BN="$(basename "${BN}")"

if [ -z "${NAME:-}" ]
then
  NAME="${BN}"
fi

if [ -z "${TRACK_ID:-}" ]
then
  TRACK_ID="${BASENAME}-${BN}-${EXTENSION}"
fi

if [ ! -s "${TRACK_CONFIG_FILE}" ]
then
  TRACK_CONFIG_FILE=""
fi

if [ ! -s "${TRACK_META_FILE}" ]
then
  TRACK_META_FILE=""
fi

TMPFILE_CONFIG_CLI=".$(basename ${0}).${BN}-config-cli-$$.json"

if [ ! -z "${TRACK_CONFIG_CLI}" ]
then
  echo "${TRACK_CONFIG_CLI}" > "${TMPFILE_CONFIG_CLI}"
else
  TMPFILE_CONFIG_CLI=""
fi

TMPFILE_META_FILE=".$(basename ${0}).${BN}-meta-file--$$.json"
trap "rm -f '${TMPFILE_CONFIG_CLI}' '${TMPFILE_META_FILE}'" EXIT

if [ ! -z "${TRACK_META_FILE}" ]
then
  NAME="$(cat "${TRACK_META_FILE}" | jq -r 'if .name then .name else "" end')"
  if [ -z "${NAME:-}" ]
  then
    NAME="${BN}"
  fi

  DESCRIPTION_="$(cat "${TRACK_META_FILE}" | jq -r 'if .description then .description else "" end')"
  if [ ! -z "${DESCRIPTION_:-}" ]
  then
    DESCRIPTION="${DESCRIPTION_}"
  fi

  TRACK_META_CONTENTS="$(cat "${TRACK_META_FILE}")"
  if [ ! -z "${TRACK_META_CONTENTS:-}" ]
  then
    echo "{\"metadata\": ${TRACK_META_CONTENTS}}" > "${TMPFILE_META_FILE}"
  fi
  unset TRACK_META_CONTENTS
else
  TMPFILE_META_FILE=""
fi


if [ ! -z "${TRACK_CONFIG_FILE}" ] || [ ! -z "${TMPFILE_META_FILE}" ] || [ ! -z "${TMPFILE_CONFIG_CLI}" ]
then
  TRACK_CONFIG=$("${BIN_DIR}"/merge_json_recursive.sh ${TRACK_CONFIG_FILE} ${TMPFILE_META_FILE} ${TMPFILE_CONFIG_CLI})
else
  TRACK_CONFIG="{}"
fi

rm -f "${TMPFILE_META_FILE}" "${TMPFILE_CONFIG_CLI}"
unset TMPFILE_META_FILE TMPFILE_CONFIG_CLI

if [ -z "${BASENAME}" ]
then
  URI="${URL_BASE}/$(basename ${INFILE})"
else
  URI="${URL_BASE}/${BASENAME}/$(basename ${INFILE})"
fi

jbrowse add-track \
  --target "${TARGET}" \
  --assemblyNames "${ASSEMBLY_NAME}" \
  --trackId "${TRACK_ID}" \
  --name "${NAME}" \
  --category "${CATEGORIES}" \
  --description "${DESCRIPTION}" \
  --config "${TRACK_CONFIG}" \
  "${URI}"
