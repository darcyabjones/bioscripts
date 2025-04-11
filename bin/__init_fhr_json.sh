#!/usr/bin/env bash

set -euo pipefail

NAME="${1}"
KIND="${2}"

if [ "${KIND}"="mitochondrial" ]
then
  SHORT_KIND="-MT"
elif [ "${KIND}"="chloroplast" ]
then
  SHORT_KIND="-CP"
else
  # Nuclear
  SHORT_KIND=""
fi


cat <<EOF
{
  "schema": "https://raw.githubusercontent.com/FAIR-bioHeaders/FHR-Specification/main/fhr.json",
  "schemaVersion": 1,
  "taxon": {
    "name": "Species name and accession name",
    "uri": "https://identifiers.org/taxonomy:000000"
  },
  "genome": "${NAME}${SHORT_KIND}",
  "genomeSynonym": [
    "${NAME}${SHORT_KIND}",
    "${NAME}-${KIND}"
  ],
  "version": 1,
  "metadataAuthor": [
    {
      "name": "First Last",
      "uri": "https://orcid.org/xxxx-xxxx-xxxx-xxxx"
    }
  ],
  "assemblyAuthor": [
    {
      "name": "First Last",
      "uri": "https://orcid.org/xxxx-xxxx-xxxx-xxxx"
    }
  ],
  "dateCreated": "YYYY-MM-DD",
  "instrument": [
  ],
  "scholarlyArticle": "DOI",
  "assemblySoftware": "software:version",
  "reuseConditions": "public domain",
  "identifier": [
    "database:accession"
  ],
  "relatedLink": [
    "URL"
  ]
}
EOF
