#!/usr/bin/env bash

set -euo pipefail


DEBUG=false
OUTFILE=
SEP="#"
INTERNAL_SEP="&%&%&%&%&%&"

FASTAS=( )
TABLES=( )

usage() {
  echo -e "USAGE:
$(basename $0) [--out OUTFILE] [--sep SEP] name in.fasta name2 in2.fasta
"
}

usage_err() {
  usage 1>&2
  echo -e '
Run "$(basename $0) --help" for extended usage information.' 1>&2
}

help() {
  echo -e "
-o|--out 'filename.fasta' [Default stdout]
-p|--sep 'string' [Default '#']
-t|--table 'filename.fasta' [Optional] Take input files from a two column tab delimited input file.
--debug [Default false]. Print commands as they are executed.
--help   Displays this message.
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

check_named_param() {
    FLAG="${1}"
    NAME="${2}"
    VALUE="${3}"
    if [ -z "${NAME:-}" ] || [ -z "${VALUE:-}" ]
    then
        echo "Argument ${FLAG} requires two values, the name and the file." 1>&2
	exit 1
    elif [ ! -s "${VALUE:-}" ]
    then
        echo "Argument ${FLAG} value '${VALUE:-}' is not a file, please check that you have a name and a file." 1>&2
	exit 1
    fi
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
    -o|--out)
      check_nodefault_param "--out" "${OUTFILE}" "${2:-}"
      OUTFILE="${2}"
      shift 2
      ;;
    -p|--sep)
      check_param "--sep" "${2:-}"
      SEP="${2}"
      shift 2
      ;;
    -t|--table)
      check_param "--table" "${2:-}"

      if [ "${2}" = "-" ]
      then
          TABLES+=( "/dev/stdin" )
      elif [ -s "${2}" ]
      then
          TABLES+=( "${2}" )
      else
	  echo "ERROR: the specified input table '${2}' does not exist." 1>&2
	  exit 1
      fi
      shift 2
      ;;
    --debug)
      DEBUG=true
      set -x
      shift
      ;;
    --)
      shift
      ;;
    *)
      check_named_param "FASTA" "${1:-}" "${2:-}"

      if echo "${1}" | grep "[[:space:]]" >/dev/null
      then
	  echo "ERROR: the specified name '${1}' has spaces in it, which will cause problems later." 1>&2
	  exit 1
      fi

      if [ -s "${2}" ]
      then
          FASTAS+=( "${1}${INTERNAL_SEP}${2}" )
      else
	  echo "ERROR: the specified input fasta '${2}' does not exist." 1>&2
	  exit 1
      fi
      shift 2
  esac
done

for TABLE in "${TABLES[@]}"
do
    while read LINE
    do
      NAME=$(echo "${LINE}" | awk -F"\t" '{print $1}')
      FASTA=$(echo "${LINE}" | awk -F"\t" '{print $2}')

      if echo "${NAME}" | grep "[[:space:]]" >/dev/null
      then
	  echo "ERROR: the specified name '${NAME}' in table '${TABLE}' has spaces in it, which will cause problems later." 1>&2
	  exit 1
      fi

      if [ -s "${FASTA}" ]
      then
          FASTAS+=( "${NAME}${INTERNAL_SEP}${FASTA}" )
      else
	  echo "ERROR: the specified input fasta '${FASTA}' in table '${TABLE}' does not exist." 1>&2
	  exit 1
      fi
    done < "${TABLE}"
done


if [ "${#FASTAS[@]}" -eq 0 ]
then
    echo "ERROR: we need at least one file to add names to." 1>&2
    exit 1
fi



if [ -z "${OUTFILE}" ]
then
    OUTFILE="/dev/stdout"
else
    mkdir -p "$(dirname "${OUTFILE}")"
fi


for NAME_FASTA in "${FASTAS[@]}"
do
    NAME=$(echo "${NAME_FASTA}" | awk -F"${INTERNAL_SEP}" '{print $1}')
    FASTA=$(echo "${NAME_FASTA}" | awk -F"${INTERNAL_SEP}" '{print $2}')
    sed "/>/ s/^>/>${NAME}${SEP}/" "${FASTA}"
done > "${OUTFILE}"
