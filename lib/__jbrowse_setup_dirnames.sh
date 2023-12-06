#!/usr/bin/env bash

ASSEMBLY_NAME="${1:-}"

if [ -z "${1:-}" ]
then
  echo "ERROR: please provide an assembly name to __setup_dirnames.sh" >&2
  exit 1
fi

URL_BASE_DEFAULT="https://storage.googleapis.com/jbrowse-sscl-data"

NUCLEAR_BASENAME="${ASSEMBLY_NAME}-nuclear"
NUCLEAR_ALIGNMENTS_BASENAME="${NUCLEAR_BASENAME}-alignments"
NUCLEAR_COMPOSITION_BASENAME="${NUCLEAR_BASENAME}-composition"
NUCLEAR_GENE_PREDICTIONS_BASENAME="${NUCLEAR_BASENAME}-gene_predictions"

## Don't touch this
NUCLEAR_MRNA_BASENAME="${NUCLEAR_BASENAME}-mRNA"
NUCLEAR_MRNA_FUNCTIONS_BASENAME="${NUCLEAR_MRNA_BASENAME}-functions"
NUCLEAR_MRNA_ALIGNMENTS_BASENAME="${NUCLEAR_MRNA_BASENAME}-alignments"


NUCLEAR_TE_BASENAME="${NUCLEAR_BASENAME}-TE"
NUCLEAR_RRNA_BASENAME="${NUCLEAR_BASENAME}-rRNA"
NUCLEAR_TRNA_BASENAME="${NUCLEAR_BASENAME}-tRNA"

NUCLEAR_PROTEIN_BASENAME="${NUCLEAR_BASENAME}-protein"
NUCLEAR_PROTEIN_FUNCTIONS_BASENAME="${NUCLEAR_PROTEIN_BASENAME}-functions"
NUCLEAR_PROTEIN_ALIGNMENTS_BASENAME="${NUCLEAR_PROTEIN_BASENAME}-alignments"

NUCLEAR_GENOMIC_ALIGNMENTS="${ASSEMBLY_NAME}-nuclear-genomic_alignments"
NUCLEAR_TRANSCRIPTOMIC_ALIGNMENTS="${ASSEMBLY_NAME}-nuclear-transcriptomic_alignments"
NUCLEAR_DATABASE_ALIGNMENTS="${ASSEMBLY_NAME}-nuclear-database_alignments"

NUCLEAR_VARIANTS_BASENAME="${NUCLEAR_BASENAME}-variants"
