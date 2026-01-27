#!/usr/bin/env bash
#
# USAGE:
#   - bash SCRIPTS/3-twig-macse-refine.sh IN OUT CORES
# EXAMPLE:
#   - bash SCRIPTS/3-twig-macse-refine.sh PROCESSED_OGS PROCESSED_OGS 50
#

# parse OUT arg, make dir, and export it
IN=${1:?Usage: $0 INDIR OUTDIR [CORES]}
OUT=${2:?Usage: $0 INDIR OUTDIR [CORES]}
CORES=${3:-10}
mkdir -p "$OUT"
export OUT   # make OUT visible inside GNU parallel jobs

# get list of files to process
mkdir -p FILE_LISTS/
find $IN/ -maxdepth 2 -type f -name 'OG*.msa_raw.nt.fa' | LC_ALL=C sort > FILE_LISTS/msa_raws.txt

# twig macse-prep
parallel --progress -j $CORES ' \

    # parse i/o handles
    in="{}"                             # PROCESSED_OGS/OG_100/OG_100.msa_raw.nt.fa
    base="{/}"                          # OG_100.msa_raw.nt.fa
    og="${base%.msa_raw.nt.fa}"         # OG_100
    ogdir="{//}"                        # PROCESSED_OGS/OG_100/
    pre="${ogdir}/${og}.msa"            # PROCESSED_OGS/OG_100/OG_100.msa
    echo "$ogdir"

    # refine alignment (skips if alignment file already exists unless -f)
    twig macse-refine \
        -i "$in" \
        -o "$pre" \
	-mo 100 \
        -ms 25 \
        -ac 0.5 \
        -R \
    ' \
    :::: FILE_LISTS/msa_raws.txt
