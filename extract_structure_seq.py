#!/usr/bin/env python3

import re

import sys
import gzip
from os.path import basename

from Bio.PDB.MMCIF2Dict import MMCIF2Dict
from Bio.PDB import PDBParser

from Bio.SeqRecord import SeqRecord
from Bio.Seq import Seq
from Bio.SeqUtils import seq1
from Bio import SeqIO


def get_seq_from_mmcif(filename):
    d = read_mmcif_dict(filename)
    assert '_entity_poly.pdbx_seq_one_letter_code_can' in d, "Your structure does not contain the Sequence."

    # NB this has newlines in it, so we need to substitute it.
    seq_str = re.sub(r"[\s*]+", "", d['_entity_poly.pdbx_seq_one_letter_code_can'][0])

    seq = SeqRecord(
        id=basename(filename),
        seq=Seq(seq_str)
    )
    return seq


def get_seq_from_pdb(filename):
    s = read_pdb(filename)
    seq_str = [si.get_resname() for si in s.get_residues()]
    seq_str = seq1("".join(seq_str))

    seq = SeqRecord(
        id=basename(filename),
        seq=Seq(seq_str)
    )

    return seq


def test_if_gzipped(filename):
    with gzip.open(filename) as handle:
        try:
            handle.read(1)
            return True
        except gzip.BadGzipFile:
            return False


def read_gzipped_mmcif_dict(filename):
    from io import StringIO

    # For unknown reasons, the gzipped file seems to be in bytes
    # even if you specify mode = "r".
    # Wrapping in a StringIO/TextIO is necessary
    with gzip.open(filename, mode="rb") as handle:
        z = StringIO(handle.read().decode())
        mm = MMCIF2Dict(z)
    return mm


# This is just for consistency with the gzipped variants
def read_mmcif_dict(filename):
    if test_if_gzipped(filename):
        return read_gzipped_mmcif_dict(filename)
    else:
        return MMCIF2Dict(filename)


def read_pdb(filename):
    if test_if_gzipped(filename):
        return read_gzipped_pdb(filename)
    else:
        parser = PDBParser()
        return parser.get_structure(basename(filename), filename)


def read_gzipped_pdb(filename):
    from io import StringIO

    # For unknown reasons, the gzipped file seems to be in bytes
    # even if you specify mode = "r".
    # Wrapping in a StringIO/TextIO is necessary
    with gzip.open(filename, mode="rb") as handle:
        z = StringIO(handle.read().decode())
        parser = PDBParser()
        mm = parser.get_structure(basename(filename), z)
    return mm


def process_batch(
    structure_filenames,
    outfile,
    kind="auto"
):
    for filename in structure_filenames:
        filename = filename.strip()

        if kind == "auto":
            if filename.endswith("pdb.gz") or filename.endswith("pdb"):
                this_kind = "pdb"
            elif filename.endswith("cif.gz") or filename.endswith("cif"):
                this_kind = "cif"
            else:
                raise ValueError(f"Cannot determine filetype of {filename}")
        else:
            this_kind = kind


        if this_kind == "pdb":
            seq = get_seq_from_pdb(filename)
        elif this_kind == "cif":
            seq = get_seq_from_mmcif(filename)
        else:
            raise ValueError("This shouldn't be possible.")

        SeqIO.write([seq], outfile, "fasta")

    return


def cli():
    import argparse

    parser = argparse.ArgumentParser(
        prog="extract_structure_seq",
        description="Extract the amino acid sequence from a PDB or mmCIF file."
    )

    parser.add_argument(
        "infiles",
        type=argparse.FileType('r'),
        help=(
            "A new-line delimited file containing CIF file paths to process. "
            "These can be gzipped. "
            "Use '-' to take from stdin."
        )
    )

    parser.add_argument(
        "-o", "--outfile",
        type=argparse.FileType('w'),
        default=sys.stdout,
        help="Where write the sequences to. Default: stdout.",
    )

    parser.add_argument(
        "-l", "--kind",
        default="auto",
        choices=["pdb", "cif", "auto"],
        help="What kind of structure files should we expect? Default will try to figure it out by filename extension.",
    )
    return parser.parse_args()


def main():
    args = cli()
    process_batch(args.infiles, args.outfile, args.kind)
    return


if __name__ == "__main__":
    main()
