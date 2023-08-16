#!/usr/bin/env python3

import re

import os
import shutil
import gzip
from os import makedirs
from os.path import basename, splitext, isfile
from os.path import join as pjoin
from typing import NamedTuple

from Bio.PDB import MMCIFParser
from Bio.PDB.MMCIF2Dict import MMCIF2Dict
from Bio.PDB import PDBIO, Select

from Bio.SeqRecord import SeqRecord
from Bio.Seq import Seq


CS_POS_REGEX = re.compile(
    r"CS\s+pos:\s+\d+-(?P<cs>\d+)\.?\s+"
    r"[A-Za-z]+-[A-Za-z]+\.?\s+"
    r"Pr: (?P<cs_prob>[-+]?\d*\.?\d+)"
)

PL_CS_POS_REGEX = re.compile(
    r"CS\s+"
    r"pos\s*(?P<kind>luTP|cTP|mTP|SP)?:\s+\d+-(?P<cs>\d+)\.?\s+"
    r"(?P<AA>[A-Za-z]+-[A-Za-z]+)?\.?\s*"
    r"Pr: (?P<cs_prob>[-+]?\d*\.?\d+)"
)


def try_convert(val, fn, err):
    try:
        return fn(val)
    except:
        raise ValueError(err)


def test_if_gzipped(filename):
    with gzip.open(filename) as handle:
        try:
            handle.read(1)
            return True
        except gzip.BadGzipFile:
            return False


def trim_lddt_left(lddt, threshold=70, window_size=5):

    j = 1

    for i in range(len(lddt) - window_size):
        j = i + window_size

        av = sum(lddt[i:j]) / window_size

        if av >= threshold:
            break

    current_trim = j
    while current_trim >= 0 and lddt[current_trim - 1] >= threshold:
        current_trim -= 1

    return current_trim


def trim_lddt_right(lddt, threshold=70, window_size=5):

    i = len(lddt) - 1

    for j in range(len(lddt), window_size, -1):
        i = j - window_size

        av = sum(lddt[i:j]) / window_size

        if av >= threshold:
            break

    current_trim = i
    while current_trim < len(lddt) and lddt[current_trim] >= threshold:
        current_trim += 1

    return current_trim


class MMCIFData(NamedTuple):

    filename: str
    id: str
    seq: SeqRecord
    lddt: list[float]
    left_trim: int
    right_trim: int

    @classmethod
    def from_file(cls, filename, lddt_threshold=70, lddt_window_size=5):
        d = read_mmcif_dict(filename)

        assert '_ma_qa_metric_local.metric_value' in d, "Your structure does not contain the LDDT values"
        lddt = list(map(float, d.get('_ma_qa_metric_local.metric_value', [])))

        assert len(lddt) > 0, "This shouldn't happen"


        assert '_entity_poly.pdbx_seq_one_letter_code_can' in d, "Your structure does not contain the Sequence."

        # NB this has newlines in it, so we need to substitute it.
        seq_str = re.sub(r"[\s*]+", "", d['_entity_poly.pdbx_seq_one_letter_code_can'][0])
        seqid = d['_entry.id'][0]

        seq = SeqRecord(
            id=seqid,
            seq=Seq(seq_str)
        )

        ltrim = trim_lddt_left(lddt, threshold=lddt_threshold, window_size=lddt_window_size)
        rtrim = trim_lddt_right(lddt, threshold=lddt_threshold, window_size=lddt_window_size)

        if ltrim > rtrim:
            raise ValueError(
                f"None of the sequence in {basename(filename)} "
                "has a high enough LDDT to pass your thresholds."
            )

        return cls(
            filename,
            seqid,
            seq,
            lddt,
            ltrim,
            rtrim
        )


class TargetPPlant(NamedTuple):

    id: str
    prediction: str
    notp: float
    sp: float
    mtp: float
    ctp: float
    lutp: float
    cs: int | None

    @classmethod
    def from_string(cls, string: str) -> "TargetPPlant":
        sline = string.strip().split("\t")

        if (len(sline) != 8) and (len(sline) != 7):
            print(string)
            raise ValueError(f"Expected 8 columns.")

        if len(sline) == 8 and len(sline[7]) != 0:
            cs = cls.parse_cs_pos(sline[7])
        else:
            cs = None

        return cls(
            sline[0],
            sline[1],
            try_convert(sline[2], float, f"Expect column notp to be a float. Got {sline[2]}"),
            try_convert(sline[3], float, f"Expect column so to be a float. Got {sline[3]}"),
            try_convert(sline[4], float, f"Expect column mtp to be a float. Got {sline[4]}"),
            try_convert(sline[5], float, f"Expect column ctp to be a float. Got {sline[5]}"),
            try_convert(sline[6], float, f"Expect column lutp to be a float. Got {sline[6]}"),
            cs
        )

    @staticmethod
    def parse_cs_pos(string: str):
        matches = PL_CS_POS_REGEX.findall(string)

        if (matches is None) or len(matches) == 0:
            raise ValueError(f"Received no cutsite locations in {string}")

        cs = max([int(f[1]) for f in matches])
        return cs

    @classmethod
    def from_iter(cls, lines):
        for line in lines:
            sline = line.strip()
            if sline.startswith("#") or len(sline) == 0:
                continue

            yield cls.from_string(sline)
        return


class TargetP(NamedTuple):
    
    id: str
    prediction: str
    notp: float
    sp: float
    mtp: float
    cs: int | None

    @classmethod
    def from_string(cls, string: str) -> "TargetP":
        sline = string.strip().split("\t")

        if (len(sline) != 6) and (len(sline) != 5):
            print(string)
            raise ValueError(f"Expected 6 columns.")

        if len(sline) == 6 and len(sline[5]) != 0:
            cs = cls.parse_cs_pos(sline[5])
        else:
            cs = None

        return cls(
            sline[0],
            sline[1],
            try_convert(sline[2], float, f"Expect column notp to be a float. Got {sline[2]}"),
            try_convert(sline[3], float, f"Expect column so to be a float. Got {sline[3]}"),
            try_convert(sline[4], float, f"Expect column mtp to be a float. Got {sline[4]}"),
            cs
        )

    @staticmethod
    def parse_cs_pos(string: str):
        match = PL_CS_POS_REGEX.match(string)

        if (match is None):
            raise ValueError(f"Received no cutsite locations in {string}")

        # TargetP can still give lumen predictions even if in non-plant mode.
        # We'll simply ignore it.
        if match.groupdict("kind") in ("luTP", "cTP"):
            cs = None
        else:
            cs = int(match.groupdict()["cs"])

        return cs

    @classmethod
    def from_iter(cls, lines):
        for line in lines:
            sline = line.strip()
            if sline.startswith("#") or len(sline) == 0:
                continue

            yield cls.from_string(sline)
        return


def run_targetp(seqs, plant=False, cmd="targetp"):
    from subprocess import run
    from tempfile import NamedTemporaryFile

    from Bio import SeqIO

    if (shutil.which(cmd) is None) and (not isfile(cmd)):
        if isfile(pjoin(".", cmd)):
            cmd = pjoin(".", cmd)
        else:
            raise ValueError(
                "Targetp could not be found on your PATH "
                f"or did not exist in {cmd}"
            )

    with NamedTemporaryFile(mode="w") as fp:
        SeqIO.write(seqs, fp.name, "fasta")

        command = [
            cmd,
            "-org", ("pl" if plant else "non-pl"),
            "-fasta", fp.name,
            "-stdout"
        ]

        results = run(command, capture_output=True)

        if results.returncode != 0:
            raise ValueError(
                "Something went wrong while running TargetP. \n"
                f"STDERR: {results.stderr.decode()}"
                f"STDOUT: {results.stdout.decode()}"
            )

        if plant:
            matches = {t.id: t for t in TargetPPlant.from_iter(results.stdout.decode().split("\n"))}
        else:
            matches = {t.id: t for t in TargetP.from_iter(results.stdout.decode().split("\n"))}
    return matches


class MMCIFSelect(Select):

    def __init__(self, start, end):
        self.start = start
        self.end = end
        self.selected = False
        return

    def accept_chain(self, chain):
        # Just in case there are multiple chains, we only take the first.
        if self.selected:
            return 0
        else:
            self.selected = True
            return 1

    def accept_residue(self, residue):

        _, index, _ = residue.get_id()
        index -= 1

        if index < self.start:
            return 0
        elif index >= self.end:
            return 0
        else:
            return 1


def read_gzipped_mmcif_dict(filename):
    from io import StringIO

    # For unknown reasons, the gzipped file seems to be in bytes
    # even if you specify mode = "r".
    # Wrapping in a StringIO/TextIO is necessary
    with gzip.open(filename, mode="rb") as handle:
        z = StringIO(handle.read().decode())
        mm = MMCIF2Dict(z)
    return mm


def read_gzipped_mmcif(name, filename):
    from io import StringIO

    # For unknown reasons, the gzipped file seems to be in bytes
    # even if you specify mode = "r".
    # Wrapping in a StringIO/TextIO is necessary

    parser = MMCIFParser()
    with gzip.open(filename, mode="rb") as handle:
        z = StringIO(handle.read().decode())
        mm = parser.get_structure(name, z)
    return mm


# This is just for consistency with the gzipped variants
def read_mmcif_dict(filename):
    if test_if_gzipped(filename):
        return read_gzipped_mmcif_dict(filename)
    else:
        return MMCIF2Dict(filename)


# This is just for consistency with the gzipped variants
def read_mmcif(name, filename):
    if test_if_gzipped(filename):
        return read_gzipped_mmcif(name, filename)
    else:
        parser = MMCIFParser()
        return parser.get_structure(name, filename)


def write_compressed_pdb(writer, filename, select):
    # The PDB writer can't write binary streams, so need this hack for now.

    from io import StringIO

    sio = StringIO()
    writer.save(sio, select)
    sio.seek(0)

    with gzip.open(filename, "wb") as handle:
        handle.write(sio.read().encode())


def trim_em(outdir, structure_data, targetp_results, compress=False):
    writer = PDBIO()

    makedirs(outdir, exist_ok=True)

    for id_, sdata in structure_data.items():

        tp = targetp_results.get(id_, None)
        filename = sdata.filename
        bname, ext = splitext(basename(filename))
        if ext == ".gz":
            bname, _ = splitext(bname) 

        if (tp is None) or (tp.cs is None):
            ltrim = sdata.left_trim
        else:
            # Should I raise a warning if cs > left_trim?
            ltrim = max([sdata.left_trim, tp.cs])

        rtrim = sdata.right_trim

        cif = read_mmcif(id_, filename)

        assert len(list(cif.get_chains())) == 1

        writer.set_structure(cif)

        if compress:
            write_compressed_pdb(writer, pjoin(outdir, f"{bname}.pdb.gz"), MMCIFSelect(ltrim, rtrim))
        else:
            writer.save(pjoin(outdir, f"{bname}.pdb"), MMCIFSelect(ltrim, rtrim))

    return


def process_batch(
    structure_filenames,
    outdir,
    lddt_threshold,
    lddt_window_size,
    plant,
    targetp_cmd,
    compress=False
):
    structure_data: dict[str, MMCIFData] = dict()

    for filename in structure_filenames:

        try:
            mm = MMCIFData.from_file(
                filename,
                lddt_threshold=lddt_threshold,
                lddt_window_size=lddt_window_size
            )
            structure_data[mm.id] = mm
        except Exception as e:
            if str(e).startswith("None of the sequence in"):
                print(f"WARNING: {str(e)}")
                continue
            raise ValueError(f"Got an error while processing {filename}: {str(e)}")

    if len(structure_data) == 0:
        return

    if targetp_cmd is not None:
        targetp_results = run_targetp(
            [sd.seq for sd in structure_data.values()],
            plant=plant,
            cmd=targetp_cmd
        )
    else:
        targetp_results = dict()

    trim_em(outdir, structure_data, targetp_results, compress)
    return


def cli():
    import argparse

    parser = argparse.ArgumentParser(
        prog="trim_alphafold_cifs",
        description="Remove low confidence ends and signal peptides from alphafold structures."
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
        "-o", "--outdir",
        type=str,
        default="processed_pdbs",
        help="Where to store the processed PDB files. Default: 'processed_pdbs'.",
    )

    parser.add_argument(
        "-g", "--compress",
        default=False,
        action="store_true",
        help="Should we gzip compress the output PDB files for you?",
    )


    parser.add_argument(
        "-t", "--threshold",
        type=float,
        default=70,
        help="The LDDT threshold to use for trimming low quality ends [1-100]. Default: 70"
    )

    parser.add_argument(
        "-w", "--window",
        type=int,
        default=3,
        help=(
            "The size of the sliding window to use to remove low quality ends. "
            "1 will stop trimming after encountering the first residue passing the threshold. "
            "Default: 3."
        )
    )

    parser.add_argument(
        "--plant",
        default=False,
        action="store_true",
        help="Should we run TargetP with the plant models? NB if sequences are a mix, use the plant model."
    )

    parser.add_argument(
        "--targetp",
        type=str,
        nargs="?",
        const="targetp",
        default=None,
        help=(
            "Specify a specific path to look for the targetp2 executable. "
            "By default it will not run targetp. If you specify '--targetp' but no path, it will look in your PATH."
        )
    )

    parser.add_argument(
        "-c", "--chunksize",
        type=int,
        default=1000,
        help=(
            "How many structures should we process at a time? "
            "Running TargetP with too few or too many sequences (>5000) at a time is slow. "
            "This is also important for memory consumption, as all of the structures have to be stored."
            "Default: 1000"
        )
    )

    return parser.parse_args()


def main():
    args = cli()

    infiles = [
        l.strip()
        for l
        in args.infiles
        if l.strip() != ""
    ]

    # I don't want any really small chunks left over at the end
    minsize = round(args.chunksize / 10)

    print("tp", args.targetp)

    for i in range(0, len(infiles), args.chunksize):
        if (i + args.chunksize + minsize) > len(infiles):
            j = len(infiles)
            should_break = True
        else:
            j = i + args.chunksize
            should_break = False

        process_batch(
            infiles[i:j],
            args.outdir,
            args.threshold,
            args.window,
            args.plant,
            args.targetp,
            args.compress
        )

        if should_break:
            break


if __name__ == "__main__":
    main()
