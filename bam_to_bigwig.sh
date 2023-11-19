set -euo pipefail

FAI=
BAM=
OUTPREFIX=

STRAND=false
SCALE=false
DEBUG=false


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
    -o|--out)
      check_param "-o|--out" "${2:-}"
      OUTPREFIX="${2}"
      shift 2
      ;;
    --debug)
      DEBUG=true
      set -x
      shift
      ;;
    --scale)
      SCALE=true
      shift
      ;;
    --strand)
      STRAND=true
      shift
      ;;
    *)
      break
  esac
done

if [ $# -ne 2 ]
then
  echo "ERROR: please provide the FAI and BAM or CRAM files" >&2
  echo >&2
  usage_err
  exit 1
fi

FAI="${1}"
BAM="${2}"

if [ -z "${OUTPREFIX:-}" ]
then
  BAM_TYPE="${BAM##*.}"
  OUTPREFIX="${BAM%.${BAM_TYPE}}"
fi

OUTPREFIX="${OUTPREFIX%.bw}"

if [ "${FAI:-}" == "-" ]
then
  echo "ERROR: Sorry, this tool doesn't support stdin for the FAI" >&2
  exit 1
elif [ "${FAI:-}" == "-" ]
then
  echo "ERROR: Sorry, this tool doesn't support stdin for the BAM" >&2
  exit 1
fi

count_reads () {
  samtools flagstat -O tsv "${1}" \
  | awk '
    BEGIN {TOTAL=0; SEC=0; SUPP=0}
    $3 ~ /^total/ {TOTAL=$1}
    $3 ~ /^secondary/ {SEC=$1}
    $3 ~ /^supplementary/ {SUPP=$1}
    END {print TOTAL - SEC - SUPP}
  '
}

if [ "${SCALE}" = "true" ]
then
  SCALE_FACTOR=$(count_reads "${BAM}")
  SCALE_FACTOR=$(awk -v NREADS="${SCALE_FACTOR}" 'BEGIN {print(1000000 / NREADS)}')
else
  SCALE_FACTOR=1
fi


TMPFILE="/tmp/$(basename "${OUTPREFIX}")-bam_to_bigwig-$$.bedgraph"
trap "rm -f '${TMPFILE}'" EXIT


if [ "${STRAND}" = "true" ]
then
  samtools view -O BAM "${BAM}" \
  | bedtools genomecov -scale "${SCALE_FACTOR}" -strand "+" -bga -split -ibam - \
  > "${TMPFILE}"

  # on bioconda as ucsc-bedgraphtobigwig
  bedGraphToBigWig "${TMPFILE}" "${FAI}" "${OUTPREFIX}-forward.bw"

  samtools view -O BAM "${BAM}" \
  | bedtools genomecov -scale "${SCALE_FACTOR}" -strand "-" -bga -split -ibam - \
  > "${TMPFILE}"

  # on bioconda as ucsc-bedgraphtobigwig
  bedGraphToBigWig "${TMPFILE}" "${FAI}" "${OUTPREFIX}-reverse.bw"

  cd $(dirname "${OUTPREFIX}")
  md5sum $(basename "${OUTPREFIX}-forward.bw") > "${OUTPREFIX}-forward.bw.md5"
  md5sum $(basename "${OUTPREFIX}-reverse.bw") > "${OUTPREFIX}-reverse.bw.md5"
else
  samtools view -O BAM "${BAM}" \
  | bedtools genomecov -scale "${SCALE_FACTOR}" -bga -split -ibam - \
  > "${TMPFILE}"

  # on bioconda as ucsc-bedgraphtobigwig
  bedGraphToBigWig "${TMPFILE}" "${FAI}" "${OUTPREFIX}.bw"
  cd $(dirname "${OUTPREFIX}")
  md5sum $(basename "${OUTPREFIX}.bw") > "${OUTPREFIX}.bw.md5"
fi
