#!/usr/bin/env bash

set -euo pipefail
set +H

INFILE=
FASTA=
# BAM, SAM, CRAM
OUTFORMAT=
STRATEGY='exclude'

DEBUG=false
PREFIX=

SEP="#"
NSEP=1

INTERNAL_SEP="&%&%&%&%&%&"

declare -A TARGETS
export TARGETS

# Yeah I know i could upper or lower case, but i'm tired.
declare -A FMT2EXT=([CRAM]="cram" [BAM]="bam" [SAM]="sam")
declare -A EXT2FMT=([cram]="CRAM" [bam]="BAM" [sam]="SAM")

usage() {
  echo -e "USAGE:
$(basename $0) [--prefix OUTPREFIX] [--sep SEP] in.bam [name1 out1.bam name2 out2.bam]
"
}

usage_err() {
  usage 1>&2
  echo -e '
Run "$(basename $0) --help" for extended usage information.' 1>&2
}

help() {
  echo -e "
-p|--sep 'string' [Default '#']
-n|--nsep Integer [Default 1]
-t|--table 'filename.tsv' [Optional] Specify output filenames with a two column tab delimited file.
-r|--reference genome.fasta [Optional, required for CRAM]. 
--strategy exclude|reset|nothing How should reads split between multiple references be handled?
    'exclude' (Default) removes both members, 'reset' leaves the single read aligned, and nothing 'leaves' it all there.
-f|--format BAM|CRAM|SAM The output format for the split files (Default BAM).
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
    -o|--prefix)
      check_nodefault_param "--prefix" "${PREFIX}" "${2:-}"
      PREFIX="${2}"
      shift 2
      ;;
    -r|--reference)
      check_nodefault_param "--reference" "${FASTA}" "${2:-}"
      FASTA="${2}"

      if [ ! -s "${FASTA}" ]
      then
          echo "ERROR: You specified an input reference fasta '${FASTA}', but it doesn't exist." 1>&2
	  exit 1
      fi
      shift 2
      ;;
    -f|--format)
      check_nodefault_param "--format" "${OUTFORMAT}" "${2:-}"
      # We uppercase it.
      OUTFORMAT="${2^^}"

      if [ "${OUTFORMAT}" != "CRAM" ] && [ "${OUTFORMAT}" != "BAM" ] && [ "${OUTFORMAT}" != "SAM" ]
      then
          echo "ERROR: The output format must be one of BAM [default], CRAM, or SAM." 1>&2
	  exit 1
      fi
      shift 2
      ;;
    -p|--sep)
      check_param "--sep" "${2:-}"
      SEP="${2}"
      shift 2
      ;;
    -n|--nsep)
      check_param "--nsep" "${2:-}"
      if echo "${2}" | grep '^[0-9][0-9]*$'
      then
          NSEP="${2}"
      else
	  echo "ERROR: --nsep must be given an integer, got '${2}'." 1>&2
	  exit 1
      fi
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
    --strategy)
      check_param "--strategy" "${2:-}"
      if [ "${2}" == "exclude" ] || [ "${2}" == "reset" ] || [ "${2}" == "nothing" ]
      then
          STRATEGY="${2}"
      else
	  echo "ERROR: --strategy must 'exclude', 'reset', or 'nothing'. Got '${2}'." 1>&2
	  exit 1
      fi
      shift 2
      ;;
    --debug)
      DEBUG=true
      set -x
      shift
      ;;
    *)
      check_nodefault_param "INFILE" "${INFILE}" "${1:-}"
      INFILE="${1}"

      if [ "${INFILE}" = "-" ] 
      then
          INFILE="/dev/stdin"
      elif [ ! -s "${INFILE}" ]
      then
	  echo "ERROR: It seems like your input file doesn't exist." 1>&2
	  exit 1
      fi
      shift 1
      break
      ;;
  esac
done

for TABLE in "${TABLES[@]}"
do
    while read LINE
    do
      if echo "${LINE}" | grep '^[[:space:]]*$' > /dev/null
      then
          continue
      fi

      NAME=$(echo "${LINE}" | awk -F"\t" '{print $1}')
      OUTFILE=$(echo "${LINE}" | awk -F"\t" '{print $2}')

      EXT="${OUTFILE##*.}"

      if [ ! -z "${OUTFORMAT:-}" ] && [ "${EXT2FMT[${EXT}]}" != "${OUTFORMAT}" ]
      then
          echo "ERROR: you've specified to output in '${OUTFORMAT}' format, but the file extension in '${OUTFILE}' has an incompatible extension." 1>&2
	  echo "ERROR: please change the extension to '${EXT2FMT[${EXT}]}' or unset --format to output multiple formats." 1>&2
	  exit 1
      fi

      if [ -z "${TARGETS[${NAME}]:-}" ]
      then
          TARGETS["${NAME}"]="${OUTFILE}"
      else
	  echo "ERROR: we've received multiple output filenames for key '${NAME}'. '${OUTFILE}' and '${TARGETS[${NAME}]}'" 1>&2
	  exit 1
      fi
    done < "${TABLE}"
done


while [[ $# -gt 0 ]]
do
  key="$1"
  case "${key}" in
    --)
      shift
      ;;
    *)
      check_named_param "TARGET" "${1:-}" "${2:-}"

      NAME="${1}"
      OUTFILE="${2}"

      EXT="${OUTFILE##*.}"

      if [ ! -z "${OUTFORMAT:-}" ] && [ "${EXT2FMT[${EXT}]}" != "${OUTFORMAT}" ]
      then
          echo "ERROR: you've specified to output in '${OUTFORMAT}' format, but the file extension in '${OUTFILE}' has an incompatible extension." 1>&2
	  echo "ERROR: please change the extension to '${EXT2FMT[${EXT}]}' or unset --format to output multiple formats." 1>&2
	  exit 1
      fi

      if [ -z "${TARGETS[${NAME}]:-}" ]
      then
          TARGETS["${NAME}"]="${OUTFILE}"
      else
	  echo "ERROR: we've received multiple output filenames for key '${NAME}'. '${TARGET}' and '${TARGETS[${NAME}]}'" 1>&2
	  exit 1
      fi
      shift 2
  esac
done


find_regions() {
  BAM="$1"
  SEP="$2"
  NSEP="$3"
  samtools view -H "${BAM}" \
  | awk -v N="${NSEP}" -v SEP="${SEP}" -v OFS="\t" '
    BEGIN {re="[^" SEP "]+"; i=1; while (i < N) {re=re SEP "[^" SEP "]+"; i++}; re="^SN:(" re ")"SEP".*$"}
    $1 ~ /^@SQ/ {
      GENOME=gensub(re, "\\1", "g", $2);
      TARGET=gensub(/^SN:/, "", "g", $2);
      print GENOME, TARGET
    }
  '
}

select_regions() {
  REGIONS="$1"
  shift
  TARGETS=$(printf '%s%%&%%&%%&' $@ | sed 's/%&%&%&$//')
  echo "${REGIONS}" | awk -v OFS="\t" -v TARGETS="${TARGETS}" '
  BEGIN {split(TARGETS, ARR, "%&%&%&")}
  {
    for (i in ARR) {
      TARGET=ARR[i]
      if ( $2 ~ "^" TARGET ) {
        print TARGET, $2
      }
    }
  }
'
}

ALL_REGIONS=$(find_regions "${INFILE}" "${SEP}" "${NSEP}")

if [ "${#TARGETS[@]}" -eq 0 ] || [ -z "${TARGETS[@]}" ]
then
  if [ -z "${OUTFORMAT:-}" ]
  then
    OUTFORMAT="BAM"
  fi
  EXT="${FMT2EXT[${OUTFORMAT}]}"
  NAMES=( $(echo "${ALL_REGIONS}" | awk -F '\t' '{print $1}' | sort -u) )

  for NAME in "${NAMES[@]}"
  do
    OUTFILE="${PREFIX:-}${NAME}.${EXT}"
    TARGETS["${NAME}"]="${OUTFILE}"
  done
fi

if [ "${#TARGETS[@]}" -gt 0 ]
then
  REGIONS=$(select_regions "${ALL_REGIONS}" "${!TARGETS[@]}")
else
  echo "ERROR: this shouldn't be possible" 1>&2
  exit 1
fi


gen_header_transform() {
  # Note, we can't filter out the unused SQ lines.
  # I think it's because there are references to what would be excluded sequences somewhere? But i'm not sure.
  # For now I just have to leave them there with no reads aligned
  G="${1}"
  S="${2}"
  echo "sed -e '/SN:${G}[${S}]/s/^\(@SQ.*\)\(\tSN:\)${G}[${S}]/\1\2/'"
}

strategy() {
    STRAT="${1}"
    shift
    OTHER_NAMES=( "${@}" )

    if [ "${STRAT}" = "reset" ]
    then
      samtools sort -u -n - | samtools fixmate -u - -
    elif [ "${STRAT}" = "exclude" ]
    then
      EXPR="$(printf '(rnext !~ "%s") && \n' "${OTHER_NAMES[@]}" | tr '\n' ' ' | sed 's/[[:space:]]*&&[[:space:]]*$//' )"
      samtools view -u --expr "${EXPR}"
    else
      cat -
    fi
}

TMPFILE_PREFIX="$(basename "${0%.sh}")-$$"
trap "rm -rf -- '${TMPFILE_PREFIX}'*" EXIT

for TARGET in "${!TARGETS[@]}"
do
  SEQ=( $(echo "${REGIONS}" | awk -F "\t" -v TARGET="${TARGET}" '$1 == TARGET {print $2}' | sort -u) )

  if [ ! -z "${FASTA:-}" ]
  then
    REF="--reference ${FASTA}"
  else
    REF=""
  fi

  OTHER_TARGETS=( $(echo "${ALL_REGIONS}" | awk -F'\t' -v TARGET="${TARGET}" '$1 != TARGET {print $1}' | sort -u) )

  OUTFILE="${TARGETS[${TARGET}]}"
  EXT="${OUTFILE##*.}"
  OFMT="${EXT2FMT[${EXT}]}"
 
  if [ "${OFMT}" = "CRAM" ] && [ ! -z "${FASTA:-}" ]
  then
    samtools faidx "${FASTA}" "${SEQ[@]}" \
      | awk -v TARGET="^>${TARGET}${SEP}" '/^>/ {$0=gensub(TARGET, ">", "g", $0)} {print}' \
      > "${TMPFILE_PREFIX}-${TARGET}.fasta"
    OUTREF="--reference ${TMPFILE_PREFIX}-${TARGET}.fasta"
    OFMT="${OFMT},embed_ref"
  else
    OUTREF=""
  fi

  samtools view -u \
    ${REF} \
    "${INFILE}" \
    "${SEQ[@]}" \
    | samtools reheader -c "$(gen_header_transform "${TARGET}" "${SEP}")" /dev/stdin \
    | strategy "${STRATEGY}" "${OTHER_TARGETS[@]}" \
    | samtools sort ${OUTREF} -O "${OFMT}" -o "${OUTFILE}" - 
done
