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
