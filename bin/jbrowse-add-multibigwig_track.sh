#!/usr/bin/env bash

set -euo pipefail

CONFIG=
ASSEMBLY_NAMES=( )
TRACK_ID=
TRACK_NAME=
CATEGORIES=( )
DESCRIPTION=

POS_COLOUR="red"
NEG_COLOUR="blue"

DISPLAY_TYPE="none"  # prob, predector, auto_global, local 

DEBUG=false

usage() {
  echo -e "USAGE:
$(basename $0) --assemblyNames NAME --trackId TRACK --name TRACKNAME <<EOF || :
TRACK GROUP URL
EOF
"
}

usage_err() {
  usage 1>&2
  echo -e '
Run "install.sh --help" for extended usage information.' 1>&2
}

help() {
  echo -e "
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
    --target)
      check_param "--target" "${2:-}"
      CONFIG="${2}"
      shift 2
      ;;
    -a|--assemblyNames)
      check_nodefault_param  "-a|--assemblyNames" "${ASSEMBLY_NAMES[@]:-}" "${2:-}"
      readarray -t ASS < <(echo "${2:-}" | tr ',' '\n')
      ASSEMBLY_NAMES+=( "${ASS[@]}" )
      shift 2
      ;;
    -d|--description)
      check_nodefault_param  "-a|--description" "${DESCRIPTION:-}" "${2:-}"
      DESCRIPTION="${2}"
      shift 2
      ;;
    --trackId)
      check_nodefault_param "--trackid" "${TRACK_ID}" "${2:-}"
      TRACK_ID="${2}"
      shift 2
      ;;
    --name)
      check_nodefault_param "--name" "${TRACK_NAME}" "${2:-}"
      TRACK_NAME="${2}"
      shift 2
      ;;
    --category)
      check_param "--category" "${2:-}"
      readarray -t CAT < <(echo "${2:-}" | tr ',' '\n')
      CATEGORIES+=( "${CAT[@]}" )
      unset CAT
      shift 2
      ;;
    --posColour|--posColor)
      check_param "--posColour" "${2:-}"
      POS_COLOUR="${2}"
      shift 2
      ;;
    --negColour|--negColor)
      check_param "--negColour" "${2:-}"
      NEG_COLOUR="${2}"
      shift 2
      ;;
    --displayType)
      check_param "--displayType" "${2:-}"
      case "$2" in
        prob|predector|auto_global|local|none)
          DISPLAY_TYPE="${2}"
	  ;;
	*)
	  echo "ERROR: Encountered an invalid option for --displayType '${2}'" 1>&2
	  echo "ERROR: Valid options are prob, predector, auto_global, local, none." 1>&2
	  exit 1
	  ;;
      esac
      shift 2
      ;;
    --debug)
      DEBUG=true
      set -x
      shift
      ;;
    *)
      echo "ERROR: Encountered an unknown parameter '${1:-}'." 1>&2
      usage_err
      exit 1
      ;;
  esac
done

if [ "${#ASSEMBLY_NAMES[@]}" -eq 0 ]
then
  echo "ERROR: missing an assembly name." 1>&2
  exit 1
fi

if [ -z "${TRACK_ID}" ]
then
  echo "ERROR: missing a track id." 1>&2
  exit 1
fi

if [ -z "${TRACK_NAME}" ]
then
  TRACK_NAME="${TRACK_ID}"
fi

# No whitespace allowed, any whitespace is delimiter
BW=$(cat /dev/stdin)
export BW


if [ -z "${BW:-}" ]
then
  echo "ERROR: Missing the bigwig config." 1>&2
  exit 1
fi

CATEGORIES=( "${CATEGORIES[@]/#/\"}" )
CATEGORIES="${CATEGORIES[@]/%/\",}"
CATEGORIES="${CATEGORIES%,}"

ASSEMBLY_NAMES=( "${ASSEMBLY_NAMES[@]/#/\"}" )
ASSEMBLY_NAMES="${ASSEMBLY_NAMES[@]/%/\",}"
ASSEMBLY_NAMES="${ASSEMBLY_NAMES%,}"

prep_adapter() {
  NAME="$1"
  GROUP="$2"
  URL="$3"
  LAST="${4:-}"

  if [ ! -z "${LAST:-}" ] || [ "${LAST:-}" == "true" ]
  then
    COMMA=""
  else
    COMMA=","
  fi

  if [ ! -z "${GROUP:-}" ] && [ "${GROUP:-}" != "none" ]
  then
    GROUP=", \"group\": \"${GROUP}\""
  else
    GROUP=""
  fi

  cat <<EOF || :
{
  "type": "BigWigAdapter",
  "name": "${NAME}",
  "bigWigLocation": {
    "uri": "${URL}"
  }${GROUP}
}${COMMA}
EOF
}

readarray -t BW_NAMES < <(echo "${BW}" | awk '{print $1}')
readarray -t BW_GROUPS < <(echo "${BW}" | awk '{print $2}')
readarray -t BW_URLS < <(echo "${BW}" | awk '{print $3}')

ADAPTERS=""
N=$(( "${#BW_NAMES[@]}" - 1 ))
for I in "${!BW_NAMES[@]}"
do
  if [ "${I}" -eq "${N}" ]
  then
    LAST="true"
  fi
  
  ADAPTERS+="$(prep_adapter "${BW_NAMES[$I]}" "${BW_GROUPS[$I]}" "${BW_URLS[$I]}" ${LAST:-})"
done


prep_display() {
  TRACK_ID="$1"
  TYPE="$2"
  if [ "${TYPE}" == "prob" ]
  then
  read -d '' DISPLAY <<EOF || :
,
"displays": [
  {
    "type": "MultiLinearWiggleDisplay",
    "displayId": "${TRACK_ID}-MultiLinearWiggleDisplay",
    "minScore": 0,
    "maxScore": 1,
    "posColor": "${POS_COLOUR}",
    "negColor": "${NEG_COLOUR}",
    "bicolorPivot": "numeric",
    "bicolorPivotValue": 0.5,
    "defaultRendering": "multirowdensity"
  }
]
EOF
  elif [ "${TYPE}" == "predector" ]
  then
  read -d '' DISPLAY <<EOF || :
,
"displays": [
  {
    "type": "MultiLinearWiggleDisplay",
    "displayId": "${TRACK_ID}-MultiLinearWiggleDisplay",
    "minScore": -3,
    "maxScore": 3,
    "posColor": "${POS_COLOUR}",
    "negColor": "${NEG_COLOUR}",
    "bicolorPivot": "numeric",
    "bicolorPivotValue": 0.0,
    "defaultRendering": "multirowdensity"
  }
]
EOF
  elif [ "${TYPE}" == "auto_global" ]
  then
  read -d '' DISPLAY <<EOF || :
,
"displays": [
  {
    "type": "MultiLinearWiggleDisplay",
    "displayId": "${TRACK_ID}-MultiLinearWiggleDisplay",
    "autoscale": "globalsd",
    "color": "${POS_COLOUR}",
    "defaultRendering": "multirowdensity"
  }
]
EOF
  elif [ "${TYPE}" == "local" ]
  then
  read -d '' DISPLAY <<EOF || :
,
"displays": [
  {
    "type": "MultiLinearWiggleDisplay",
    "displayId": "${TRACK_ID}-MultiLinearWiggleDisplay",
    "autoscale": "local",
    "color": "${POS_COLOUR}",
    "defaultRendering": "multirowdensity"
  }
]
EOF
  fi
  echo "${DISPLAY:-}"
}

if [ ! -z "${DESCRIPTION:-}" ]
then
  DESCRIPTION="\"description\": \"${DESCRIPTION}\","
fi

DISPLAY="$(prep_display "${TRACK_ID}" "${DISPLAY_TYPE}")"

TMPFILE=".tmp$(basename "${0}")$$"
trap "rm -f '${TMPFILE}'" EXIT

cat <<EOF > "${TMPFILE}" || :
{
  "type": "MultiQuantitativeTrack",
  "trackId": "${TRACK_ID}",
  "name": "${TRACK_NAME}", ${DESCRIPTION}
  "category": [${CATEGORIES}],
  "assemblyNames": [${ASSEMBLY_NAMES}],
  "adapter": {
    "type": "MultiWiggleAdapter",
    "subadapters": [
${ADAPTERS}
    ]
  }${DISPLAY:-}
}
EOF

#cat "${TMPFILE}"

jbrowse add-track-json --target "${CONFIG}" "${TMPFILE}" 
