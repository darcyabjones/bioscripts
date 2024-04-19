#!/usr/bin/env python3

def cli():
    import sys
    import argparse

    parser = argparse.ArgumentParser(
        prog="split_assembly_at_variants.py",
        description="Splits putative misassemblies at structural variant break points detected by sniffles2."
    )

    parser.add_argument(
        "fasta",
        type=argparse.FileType('r'),
        help=("A fasta to split")
    )

    parser.add_argument(
        "vcf",
        type=str,
        help=("A VCF from sniffles2")
    )

    parser.add_argument(
        "-o", "--outfile",
        type=argparse.FileType('w'),
        default=sys.stdout,
        help="Where write the fasta to. Default: stdout.",
    )

    parser.add_argument(
        "--hets",
        default=False,
        action="store_true",
        help="Include heterozygote predictions."
    )

    parser.add_argument(
        "--min-dv",
        default=4,
        type=float,
        help="Minimum read coverage supporting variant."
    )

    parser.add_argument(
        "--max-dr",
        default=float("inf"),
        type=float,
        help="Maximum read coverage supporting reference."
    )

    parser.add_argument(
        "--min-dvdr",
        default=1.5,
        type=float,
        help="Minimum variant/reference supporting reads."
    )

    parser.add_argument(
        "--min-contig",
        default=100,
        type=float,
        help="Don't write out split sequences smaller than this."
    )
    return parser.parse_args()



def find_breaks(vcf, min_dv: int = 4, max_dr: int = 100, min_dvdr = 1.5, hets = False):
    import re
    from collections import defaultdict
    from pysam import VariantFile
    
    regex = re.compile(r"[A-Z]+[\[\]](?P<chrom>[^:]+):(?P<pos>\d+)[\[\]]")
    variants = VariantFile(vcf)

    breaks = defaultdict(list)
    for variant in variants.fetch():
        if variant.info.get("SVTYPE", None) != "BND":
            continue
    
        genotype = variant.samples[0]
        alleles = genotype.allele_indices
        alt = variant.alts[0]
        dr = int(genotype.get("DR", 0))
        dv = int(genotype.get("DV", 0))
    
        if not (
            (dv >= min_dv)
            and (dr <= max_dr)
            and ((dv / (dr + 1e-6)) >= min_dvdr)
        ):
            continue
        
        if (sum(alleles) > 1) or (hets and sum(alleles) > 0):
            breaks[variant.chrom].append(variant.pos)
    
            match = regex.match(alt)
            assert match is not None, alt
            match = match.groupdict()
    
            breaks[match["chrom"]].append(int(match["pos"]))

    return breaks


def break_seq(seq, breaks, min_length: int = 100):
    i = 0
    n = 1

    out = []
    for j in sorted(breaks):
        if i == j:
            continue

        if (j - i) > min_length:
            new_seq = seq[i:j]
            new_seq.id = f"{seq.id}_{n}"
            new_seq.name = new_seq.id
            new_seq.description = f"{i} {j}"
            out.append(new_seq)
            n += 1
        
        i = j

    if i < (len(seq) - min_length):
        new_seq = seq[i:]
        new_seq.id = f"{seq.id}_{n}"
        new_seq.name = new_seq.id
        new_seq.description = f"{i} {len(seq)}"
        out.append(new_seq)

    return out


def main():
    from Bio import SeqIO
    args = cli()

    breaks = find_breaks(
        args.vcf,
        min_dv=args.min_dv,
        max_dr=args.max_dr,
        min_dvdr=args.min_dvdr,
        hets=args.hets
    )

    seqs = SeqIO.parse(args.fasta, "fasta")

    out_seqs = []
    for seq in seqs:
        if seq.id in breaks:
            out_seqs.extend(break_seq(seq, breaks[seq.id], min_length=args.min_contig))
        else:
            out_seqs.append(seq)

    SeqIO.write(out_seqs, args.outfile, "fasta")


if __name__ == "__main__":
    main()
