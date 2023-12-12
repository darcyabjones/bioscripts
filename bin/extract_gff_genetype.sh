#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "${BIN_DIR}")/lib"

CMD=$(__generate-cli.py "$(basename $0)" "$@" <<EOF
dest="GFF", type="str", help="The GFF to extract features from"
dest="TYPES", type="str", nargs="+", help="Which type subgraphs to fetch."
short="-p", long="--prefix", dest="PREFIX", type="str", default="none", help="Output basename."
short="-d", long="--derives", dest="DERIVES", type="FLAG", default=False, help="Also fetch Derives_from features."
long="--debug", dest="DEBUG", type="FLAG", default=False, help="Print extra logs to stdout."
EOF
)

# Eventually i'd like this to be arbitrary, for now its just whether or not to include derives from.
# short="-f", long="--fields", DEST="FIELDS", type="STR", nargs="+", default=["ID", "Parent", "Derives_from"], help="Which attribute fields to search for ids."

if ! (echo "${CMD}" | grep '^### __generate-cli output$' > /dev/null)
then
  # help or an error occurred
  echo "# $(basename $0)"
  echo "${CMD}"
  exit 0
fi

eval "${CMD}"

if [ "${DEBUG:-}" == "True" ]
then
  set +x
fi


if [ "${PREFIX}" == "none" ]
then
  PREFIX="$(basename "${GFF%.gff3*}")"
fi


TMPDIR="${TMPDIR:-${PWD}/.}/tmp$(basename "$0")-$(basename "${GFF}")$$"
export TMPDIR

mkdir -p "${TMPDIR}"

trap "rm -rf -- '${TMPDIR}'" EXIT


split_gff() {
    local GFF="$1"
    local TYPE="$2"
    local WITHOUT="${3}"
    local DERIVES="${4}"
    local DEBUG="${5}"

    if [ "${DERIVES}" == "True" ]
    then
      DERIVES_FLAG="--derives"
    else
      DERIVES_FLAG=""
    fi

    if [ "${DEBUG}" == "True" ]
    then
      DEBUG_FLAG="--debug"
    else
      DEBUG_FLAG=""
    fi

    TMPFILE="${TMPDIR}/$(basename ${GFF})-${TYPE}-${WITHOUT}-${DERIVES}"

    bash "${BIN_DIR}"/extract_gff_ids.sh ${DEBUG_FLAG} --type "${TYPE}" "${GFF}" > "${TMPFILE}"
    MD5_BEFORE=$(md5sum "${TMPFILE}" | cut -f1 -d' ')
    MD5_AFTER=""

    while [ "${MD5_BEFORE}" != "${MD5_AFTER}" ]
    do
      MD5_BEFORE=$(md5sum "${TMPFILE}" | cut -f1 -d' ')
      bash "${BIN_DIR}"/subset_gff_by_ids.sh ${DERIVES_FLAG} ${DEBUG_FLAG} "${GFF}" "${TMPFILE}" > "${TMPFILE}.gff3"
      bash "${BIN_DIR}"/extract_gff_ids.sh ${DEBUG_FLAG} "${TMPFILE}.gff3" > "${TMPFILE}"
      rm -f "${TMPFILE}.gff3"

      MD5_AFTER=$(md5sum "${TMPFILE}" | cut -f1 -d' ')
    done

    if [ "${WITHOUT}" == "True" ]
    then
      bash "${BIN_DIR}"/subset_gff_by_ids.sh --invert ${DERIVES_FLAG} ${DEBUG_FLAG} "${GFF}" "${TMPFILE}"
    else
      bash "${BIN_DIR}"/subset_gff_by_ids.sh ${DERIVES_FLAG} ${DEBUG_FLAG} "${GFF}" "${TMPFILE}"
    fi

    rm -f "${TMPFILE}"*
}


REST="${TMPDIR}/rest.gff3"
cp "${GFF}" "${REST}"

NTYPES="${#TYPES[@]}"
I=1
for TYPE in "${TYPES[@]}"
do
  mkdir -p "$(dirname "${PREFIX}")"
  split_gff "${REST}" "${TYPE}" "False" "${DERIVES}" "${DEBUG}" | bash "${BIN_DIR}/drop_missing_gff_parents.sh" -  > "${PREFIX}-${TYPE}.gff3"

  if [ "${I}" -lt "${NTYPES}" ]
  then
    split_gff "${REST}" "${TYPE}" "True" "${DERIVES}" "${DEBUG}" > "${REST}.tmp"
    mv "${REST}.tmp" "${REST}"
  fi

  I=$(( I + 1 ))
done
