has_gffread() {
    command -v "gffread" > /dev/null
}

has_genometools() {
    command -v "gt" > /dev/null
}

try_extract_cds() {
    GENOME="$1"
    GFF="$2"
    PREFIX="$3"

    if has_gffread
    then
        extract_gffread_cds "${GENOME}" "${GFF}" "${PREFIX}"
    elif has_genometools
    then
        extract_genometools_cds "${GENOME}" "${GFF}" "${PREFIX}"
    fi
}

try_extract_protein() {
    GENOME="$1"
    GFF="$2"
    PREFIX="$3"

    if has_gffread
    then
        extract_gffread_protein "${GENOME}" "${GFF}" "${PREFIX}"
    elif has_genometools
    then
        extract_genometools_protein "${GENOME}" "${GFF}" "${PREFIX}"
    fi
}

try_extract_transcript() {
    GENOME="$1"
    GFF="$2"
    PREFIX="$3"

    if has_gffread
    then
        extract_gffread_transcript "${GENOME}" "${GFF}" "${PREFIX}"
    elif has_genometools
    then
        extract_genometools_transcript "${GENOME}" "${GFF}" "${PREFIX}"
    fi
}

extract_gffread_cds() {
    GENOME="$1"
    GFF="$2"
    PREFIX="$3"
    gffread -x "${PREFIX}-CDS.fasta.tmp" -g "${GENOME}" "${GFF}"
    bash "${BIN_DIR}/bgzip_fasta.sh" "${PREFIX}-CDS.fasta.tmp" "${PREFIX}-CDS.fasta.gz"
    rm -f "${PREFIX}-CDS.fasta.tmp"
}

extract_gffread_protein() {
    gffread -y "${PREFIX}-protein.fasta.tmp" -g "${GENOME}" "${GFF}"
    bash "${BIN_DIR}/bgzip_fasta.sh" "${PREFIX}-protein.fasta.tmp" "${PREFIX}-protein.fasta.gz"
    rm -f "${PREFIX}-protein.fasta.tmp"
}

extract_gffread_transcript() {
    gffread --w-nocds -w "${PREFIX}.fasta.tmp" -g "${GENOME}" "${GFF}"
    bash "${BIN_DIR}/bgzip_fasta.sh" "${PREFIX}.fasta.tmp" "${PREFIX}.fasta.gz"
    rm -f "${PREFIX}.fasta.tmp"
}

extract_genometools_cds() {
    GENOME="$1"
    GFF="$2"
    PREFIX="$3"

    gt gff3 -tidy -sort -retainids -checkids "${GFF}" \
    | gt extractfeat -join -type CDS -matchdescstart -retainids -seqfile "${GENOME}" \
    > "${PREFIX}-CDS.fasta.tmp"

    bash "${BIN_DIR}/bgzip_fasta.sh" "${PREFIX}-CDS.fasta.tmp" "${PREFIX}-CDS.fasta.gz"
    rm -f "${PREFIX}-CDS.fasta.tmp"
}

extract_genometools_protein() {
    GENOME="$1"
    GFF="$2"
    PREFIX="$3"

    gt gff3 -tidy -sort -retainids -checkids "${GFF}" \
    | gt extractfeat -join -type CDS -translate -matchdescstart -retainids -seqfile "${GENOME}" \
    > "${PREFIX}-protein.fasta.tmp"

    bash "${BIN_DIR}/bgzip_fasta.sh" "${PREFIX}-protein.fasta.tmp" "${PREFIX}-protein.fasta.gz"
    rm -f "${PREFIX}-protein.fasta.tmp"
}

extract_genometools_transcript() {
    GENOME="$1"
    GFF="$2"
    PREFIX="$3"

    gt gff3 -tidy -sort -retainids -checkids "${GFF}" \
    | gt extractfeat -join -type exon -matchdescstart -retainids -seqfile "${GENOME}" \
    > "${PREFIX}.fasta.tmp"

    bash "${BIN_DIR}/bgzip_fasta.sh" "${PREFIX}.fasta.tmp" "${PREFIX}.fasta.gz"
    rm -f "${PREFIX}.fasta.tmp"
}
