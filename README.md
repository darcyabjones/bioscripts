# bioscripts

Handy scripts to use for doing bioinformatics on the command line.
I often need things like this and have to trawl through old notes to find them.
This just puts them all in one place where I can copy-paste what I need (though it could also just go on your PATH).

For personal use but go ahead and use it without restrictions if you like.

Cheers,
Darcy


## `trim_alphafold_cifs.py`

This one might actually be helpful to people.
AlphaFold structures often have a bunch of junk at the ends of the sequence.
This is because most of the time whole sequences are run through it, but in the real world proteins are often cleaved.
Particularly proteins with signal peptides etc.
These regions present in structural predictions as low-confidence and/or disordered areas.

This script runs TargetP2 to find any signal peptides, and uses the LDDT structures present in the MMCIF versions of alphafold predicted structures to trim off the unstructured ends.

Basically, you set an LDDT threshold and a window size, and we run a rolling mean window and try to find point where the structure starts getting good..
Then we trim by either the signal peptide or the threshold cutoff site, whichever is bigger.
The process is the same for the C-terminus, but we don't attempt to find signal peptides (even though sometimes it does happen, i'm not aware of any good tools).


This program required the python package [Biopython](https://biopython.org/).


```
usage: trim_alphafold_cifs.py [-h] [-o OUTDIR] [-g] [-t THRESHOLD] [-w WINDOW] [--plant] [--targetp TARGETP] [-c CHUNKSIZE] infiles

Remove low confidence ends and signal peptides from alphafold structures.

positional arguments:
  infiles               A new-line delimited file containing CIF file paths to process.
                        These can be gzipped.
                        Use '-' to take from stdin.

options:
  -h, --help            show this help message and exit
  -o OUTDIR, --outdir OUTDIR
                        Where to store the processed PDB files. Default: 'processed_pdbs'.
  -g, --compress        Should we gzip compress the output PDB files for you?
  -t THRESHOLD, --threshold THRESHOLD
                        The LDDT threshold to use for trimming low quality ends [1-100]. Default: 70
  -w WINDOW, --window WINDOW
                        The size of the sliding window to use to remove low quality ends.
                        1 will stop trimming after encountering the first residue passing the threshold.
                        Default: 3.
  --plant               Should we run TargetP with the plant models?
                        NB if sequences are a mix, use the plant model.
  --targetp TARGETP     Specify a specific path to look for the targetp2 executable.
                        By default looks for it in your PATH.
  -c CHUNKSIZE, --chunksize CHUNKSIZE
                        How many structures should we process at a time?
                        Running TargetP with too few (< 100) or too many sequences (>5000) at a time is slow.
                        This is also important for memory consumption as all of the structures have to be stored.
                        Default: 1000
```

The simplest way to run it for a small number of files would be like this.

```
ls *.cif | trim_alphafold_cifs.py -
```

Piping the output of `ls` creates a new-line delimited stream which put into the scripts stdin.

My typical use case for this kind of thing would be for working with a large number of files.
`ls` is often quite slow at listing large numbers of files, and there's a limit on how many parameters you can supply to a command, so the globbing approach to extension filtering won't work.

In this case where you have thousands of CIF files to process, i'd suggest pairing [`find`](https://www.gnu.org/software/findutils/manual/html_mono/find.html) with [GNU `parallel`](https://www.gnu.org/software/parallel/).

```
find . -name "*.cif" | parallel --max-procs 1 --pipe -N1000 'trim_alphafold_cifs.py --compress -'
```

Here parallel will send out jobs processing 1000 CIFs at a time (`-N`).
In this example it's single threaded because the main bottlenecks will be targetp and IO, but you could run multiple chunks in parallel by changing `--max-procs`.
GNU parallel does have options for distributing jobs via MPI and there are tricks for sending jobs out using `srun` on SLURM clusters.

> NOTE: TargetP uses OpenMP to parallelise when running on CPUs, and will use all available CPUs by default.
> If you're running on a shared computer or trying to run with `--max-procs` > 1,
> you'll need to restrict the number of CPUs used with the OMP_NUM_THREADS environment variable.
> E.g. `export OMP_NUM_THREADS=8`


I have no idea yet how robust the actual program is, so your milage may vary, but the approach does what I wanted it to.


## `prefix_fasta.sh`

Adds prefixes to a fasta for multi-genome analyses (e.g. constructing a pangenome graph or mixed RNAseq alignment).
You provide names and fasta files, and the program simply puts the name in front of each seqid. Simple, but useful.

Each name and fasta filename is provided in an alternating pattern (i.e. `name1 genome1.fasta name2 genome2.fasta`).
To make it more readable, you can separate the pairs using `--` (e.g. `name1 genome1.fasta -- name2 genome2.fasta`).

Examples.
Say we have two fasta files, both with a single sequence called `chr1`.

```bash
prefix_fasta.sh --out combined.fasta --sep "#" \
  genome1 g1.fasta \
  genome2 g2.fasta
```

The output fasta sequence ids will be:

```
>genome1#chr1
ATGC
>genome2#chr1
CGTA
```

You can also input from a table which may be more convenient as you can keep track of the changes easily.

```bash
cat <<EOF > table.tsv
genome1	g1.fasta
genome2	g2.fasta
EOF

prefix_fasta.sh --table table.tsv --out combined.fasta --sep "#"
# Alternatively using '-' to take the table from stdin.
cat table.tsv | prefix_fasta.sh --table - --out combined.fasta --sep "#"
```

This will produce identical results.
`--table` can be specified multiple times to read from multiple tables, and table input can be combined with the argument name pairs.

We suggest using '#' as the separator (it's the default) as it is recommended by people working with pangenomes ([See: PanSN-spec](https://github.com/pangenome/PanSN-spec)).
You could run the program multiple times if you want to properly conform to the PanSN spec, e.g. adding your haplotype names first and then the ids, or just providing the haplotype number directly in the prefix.


## `prefix_gff.sh`

Like `prefix_fasta.sh`, but it adds a prefix to genome annotation sequence ids and [optionally] their gene/transcript ids.
Despite the name, `prefix_gff.sh` will happily process GTF and BED files as well.

The interface is similar to `prefix_fasta.sh`.

E.G.

```bash
prefix_gff.sh --out combined.gff3 --sep "#" \
  genome1 g1.gff3 \
  genome2 g2.gff3
```

Will produce something like:

```
genome1#chr1	source	gene	1000	2000	0.1	+	.	ID=gene1
genome2#chr1	source	gene	1500	2500	1.0	-	.	ID=gene1
```

Like with `prefix_fasta.sh` you can provide a table of name/gff pairs.

Because we shouldn't really have multiple genes with the same name, we can also prefix the `ID`, `Parent`, and `Derives_from` fields in the GFF3 attributes column using the `--ids` flag.

```bash
prefix_gff.sh --ids --out combined.gff3 --sep "#" \
  genome1 g1.gff3 \
  genome2 g2.gff3
```

Will produce something like:

```
genome1#chr1	source	gene	1000	2000	0.1	+	.	ID=genome1#gene1
genome1#chr1	source	mRNA	1000	2000	0.1	+	.	ID=genome1#mRNA1;Parent=genome1#gene1
genome2#chr1	source	gene	1500	2500	1.0	-	.	ID=genome2#gene1
```

By providing the `--format` argument, we can change this to rename GTF or BED gene ids.
For GTF files (`--format gtf`) the `gene_id` and `transcript_id` attributes are prefixed, and for BED files (`--format bed`) column 4 is prefixed (as it is the standard BED name column).
For BED files with the names in a different column, you can also provide a number after format to add the prefix to that column. E.G. `--format 5` will add the prefix to column 5.

> NOTE: `--format gff3` also enables some special handling of comments.
> `##sequence-region` directives are also prefixed and `###` lines are filtered out. 


Sorting the output file can be enabled with the `--sort` option. In this case, GFF and GTF files are sorted on columns 1, 4, and 5, and BED files are sorted by the first three columns. Make sure you're specifying the right --format if you use this.



## `split_bam_by_prefix.sh`

Splits an input BAM (or SAM/CRAM) aligned to a multi-organism genome by their reference prefix. This is designed to work with `prefix_fasta.sh` and `prefix_gff.sh`.

You just need an input alignment and the prefix separation character.
For CRAMs you'll also need the combined reference sequence.

Assuming your reference sequences that the reads were aligned to are separated by a "#" (e.g. 'genome1#chr1', 'genome2#chr2'), you can split it into genome1 and 2 like so.

```bash
split_bam_by_prefix.sh --sep "#" --format BAM aligned.bam 
```

By default this will split it info files by the prefix (e.g. genome1.bam, genome2.bam`).

You can specify the output files for prefixes specifically as with the `prefix\_\*.sh` commands, by providing a table or as positional arguments.

```bash
split_bam_by_prefix.sh --sep "#" --format BAM aligned.bam \
  genome1 aligned1.bam
```

Will write genome1 to aligned1.bam.
If any targets were specified (e.g. here we excluded genome2), then they will not be processed.

If your prefixes have multiple `--sep` characters (e.g. if you're following the PanSN spec), you can use the `--nsep` flag to allow multiples.
E.g. for a reference sequence "genome1#haplotype1#chr1" `--nsep 1` (default) would output the prefix as "genome1", and `--nsep 2` would output the prefix "genome1#haplotype1"  

You can specify the output file as BAM, CRAM, or SAM with the `--format` parameter.
If you are inputting or outputting a CRAM file, you'll need to provide the fasta reference that you aligned against (i.e. with the prefixes).

Three methods of handling reads split across to multiple genomes (matching different prefixes) are offered and specified by the `--strategy` parameter.
"exclude" (default) simply removes any alignments where a paired read or split alignment is aligned to another genome.
"reset" removes any reference to the other member of the read pair or split aligned region, essentially leaving it as an unpaired alignment or short read alignment.
Finally "nothing" makes no attempt to remove references to the other genomes, and you can deal with it yourself :). 

> NB. `--strategy reset` will take much longer than the other two because it first has to sort by read-name and then by position.
> "exclude" is probably the right option in most cases. If you're getting lots of reads split across genomes it's probably worth looking at your aligner parameters first.
