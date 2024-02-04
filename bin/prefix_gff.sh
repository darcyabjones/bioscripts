#!/usr/bin/env bash

set -euo pipefail


DEBUG=false
OUTFILE=
SEP="#"
INTERNAL_SEP="&%&%&%&%&%&"
UPDATE_IDS=false
FTYPE="gff3"
BED_COLUMN=4
SORT=false

GFFS=( )
TABLES=( )

usage() {
  echo -e "USAGE:
$(basename $0) [--out OUTFILE] [--sep SEP] [--ids] [--format gff3|gtf|bed|[0-9]+] \\
	[--table input.tsv]  name in.gff name2 in2.gff3
"
}

usage_err() {
  usage 1>&2
  echo -e '
Run "$(basename $0) --help" for extended usage information.' 1>&2
}

help() {
  echo -e "
-o|--out 'filename.gff3' [Default stdout]
-p|--sep 'string' [Default '#']
-d|--ids [Default false]
-f|--format gff3|gtf|bed|[0-9]+ What the input files are.
         This will affect id renaming (if --ids flagged) and some GFF3 specific directives.
	 Note, 'bed' assumes a standard bed6/bed12 format with the names in column 4.
	 Specifying a number will process as if the name was instead in the numbered column (1-indexed).
	 [Default gff3]
-s|--sort [Default false] Sort the output file according to the specified --format.
-t|--table 'filename.gff3' [Optional] Take input files from a two column tab delimited input file.
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
      check_nodefault_param "--prefix" "${OUTFILE}" "${2:-}"
      OUTFILE="${2}"
      shift 2
      ;;
    -p|--sep)
      check_param "--sep" "${2:-}"
      SEP="${2}"
      shift 2
      ;;
    -d|--ids)
      UPDATE_IDS=true
      shift
      ;;
    -s|--sort)
      SORT=true
      shift
      ;;
    -f|--format)
      check_param "--format" "${2:-}"
      
      if [ "${2}" == "gff3" ] || [ "${2}" == "gff" ]
      then
          FTYPE="gff3"
      elif [ "${2}" == "gtf" ]
      then
          FTYPE="gtf"
      elif [ "${2}" == "bed" ]
      then
          FTYPE="bed"
      elif echo "${2}" | grep '^[0-9][0-9]*$'
      then
	  FTYPE="bed"
	  BED_COLUMN="${2}"
      else
	  echo "ERROR: received invalid file format '${2}'" 1>&2
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
    --debug)
      DEBUG=true
      set -x
      shift
      ;;
    --)
      shift
      ;;
    *)
      check_named_param "GFF" "${1:-}" "${2:-}"

      if echo "${1}" | grep "[[:space:]]" >/dev/null
      then
	  echo "ERROR: the specified name '${1}' has spaces in it, which will cause problems later." 1>&2
	  exit 1
      fi

      if [ -s "${2}" ]
      then
          GFFS+=( "${1}${INTERNAL_SEP}${2}" )
      else
	  echo "ERROR: the specified input gff '${2}' does not exist." 1>&2
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
      GFF=$(echo "${LINE}" | awk -F"\t" '{print $2}')

      if echo "${NAME}" | grep "[[:space:]]" >/dev/null
      then
	  echo "ERROR: the specified name '${NAME}' in table '${TABLE}' has spaces in it, which will cause problems later." 1>&2
	  exit 1
      fi

      if [ -s "${GFF}" ]
      then
          GFFS+=( "${NAME}${INTERNAL_SEP}${GFF}" )
      else
	  echo "ERROR: the specified input gff '${GFF}' in table '${TABLE}' does not exist." 1>&2
	  exit 1
      fi
    done < "${TABLE}"
done


if [ "${#GFFS[@]}" -eq 0 ]
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


process_file() {
  awk -F'\t' -v OFS='\t' -v NAME="${1}" -v SEP="${2}" -v UPDATE_IDS="${3}" -v FTYPE="${4}" -v BED_COLUMN="${5}" '
  function strip(str) {
     str = gensub(/^[[:space:]]*/, "", "g", str);
     str = gensub(/[[:space:]]*$/, "", "g", str);
     return str
  }
  function strip_quote(str) {
     str = gensub(/^[[:space:]]*"[[:space:]]*/, "", "g", str);
     str = gensub(/[[:space:]]*"[[:space:]]*$/, "", "g", str);
     return str
  }
  function prefix_gff3_ids(prefix, attrs)
  {
      split(attrs, attrarr, ";")
      new_attrs = ""
      for (i in attrarr) {
        attri = strip(attrarr[i])
  
        if (attri ~ /^ID=/) {
          attri = gensub(/ID=/, "", "g", attri)
  	  attri = strip_quote(attri)
  	  attri = "ID=" prefix attri
        } else if (attri ~ /^Parent=/) {
          attri = gensub(/Parent=[[:space:]]*/, "", "g", attri)
  	  split(attri, parents, ",")
  	  new_parents = ""
  	  for (j in parents) {
  	    p = strip_quote(parents[j])
	    if (p == "") {continue}
  	    if (new_parents == "" ) {
  	      new_parents = prefix p
  	    } else {
                new_parents = new_parents "," prefix p
              }
  	  }
  	  if (new_parents != "") {
  	    new_parents = "Parent=" new_parents
  	  }
  	  attri = new_parents
        } else if (attri ~ /^Derives_from=/) {
          attri = gensub(/Derives_from=[[:space:]]*/, "", "g", attri)
  	  split(attri, parents, ",")
  	  new_parents = ""
  	  for (j in parents) {
  	    p = strip_quote(parents[j])
	    if (p == "") {continue}
  	    if (new_parents == "" ) {
  	      new_parents = prefix p
  	    } else {
                new_parents = new_parents "," prefix p
              }
  	  }
  	  if (new_parents != "") {
  	    new_parents = "Derives_from=" new_parents
  	  }
  	  attri = new_parents
        }
  
        if ((attri != "") && (new_attrs == "")) {
          new_attrs = attri
        } else if ((attri != "") && (new_attrs != "")) {
          new_attrs = new_attrs ";" attri
        }
      }
      return new_attrs
  }
  function prefix_bed_ids(prefix, name)
  {
    return prefix name
  }
  function prefix_gtf_ids(prefix, attrs)
  {
      split(attrs, attrarr, ";")
      new_attrs = ""
      for (i in attrarr) {
        attri = strip(attrarr[i])
        if (attri ~ /^gene_id/) {
          attri = gensub(/gene_id/, "", "g", attri)
  	  attri = strip_quote(attri)
  	  attri = "gene_id \"" prefix attri "\""
        } else if (attri ~ /^transcript_id/) {
          attri = gensub(/transcript_id/, "", "g", attri)
  	  attri = strip_quote(attri)
  	  attri = "transcript_id \"" prefix attri "\""
  	}
        if ((attri != "") && (new_attrs == "")) {
          new_attrs = attri
        } else if ((attri != "") && (new_attrs != "")) {
          new_attrs = new_attrs "; " attri
        }
      }
      return new_attrs
  }
  /^###/ && (FTYPE == "gff3") {next}
  /^##sequence-region/ && (FTYPE == "gff3") {
  	$0=gensub(\
        /^##sequence-region[[:space:]]+([^[:space:]]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+)/, \
        "##sequence-region "NAME SEP"\\1", "g", $0 \
      );
    print;
    next
  } 
  /^#/ {print}
  {
      $1=NAME SEP $1;
      if ((UPDATE_IDS == "true") && (FTYPE == "gff3")) {
        $9=prefix_gff3_ids(NAME SEP, $9)
      } else if ((UPDATE_IDS == "true") && (FTYPE == "gtf")) {
        $9=prefix_gtf_ids(NAME SEP, $9)
      } else if ((UPDATE_IDS == "true") && (FTYPE == "bed")) {
        $BED_COLUMN=prefix_bed_ids(NAME SEP, $BED_COLUMN)
    }
    print
  }
  ' "${6}"
}

if [ "${SORT}" = "true" ] && [ "${FTYPE}" = "gff3" ]
then
  SORT_CMD="sort -k1,1 -k4,4n -k5,5n -k7"
elif [ "${SORT}" = "true" ] && [ "${FTYPE}" = "gtf" ]
then
  SORT_CMD="sort -k1,1 -k4,4n -k5,5n -k7"
elif [ "${SORT}" = "true" ] && [ "${FTYPE}" = "bed" ]
then
  SORT_CMD="sort -k1,1 -k2,2n -k3,3n -k4,4"
else
  SORT_CMD="cat -"
fi

for NAME_GFF in "${GFFS[@]}"
do
    NAME=$(echo "${NAME_GFF}" | awk -F"${INTERNAL_SEP}" '{print $1}')
    GFF=$(echo "${NAME_GFF}" | awk -F"${INTERNAL_SEP}" '{print $2}')
    process_file "${NAME}" "${SEP}" "${UPDATE_IDS}" "${FTYPE}" "${BED_COLUMN}" "${GFF}"
done | ${SORT_CMD} > "${OUTFILE}"
