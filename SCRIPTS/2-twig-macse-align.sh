#!/usr/bin/env bash
#
# USAGE:
#   - bash SCRIPTS/2-twig-macse-align.sh IN OUT CORES
#

# parse OUT arg, make dir, and export it
IN=${1:?Usage: $0 INDIR OUTDIR [CORES]}
OUT=${2:?Usage: $0 INDIR OUTDIR [CORES]}
CORES=${3:-10}
mkdir -p "$OUT"
export OUT   # make OUT visible inside GNU parallel jobs

# get list of files to process
mkdir -p FILE_LISTS/
find $IN/ -maxdepth 2 -type f -name 'OG*.trim.nt.fa' | LC_ALL=C sort > FILE_LISTS/trim_ogs.txt

# twig macse-prep
parallel --progress -j $CORES ' \

    # parse i/o handles
    in="{}"                             # PROCESSED_OGS/OG_100/OG_100.trim.nt.fa
    base="{/}"                          # OG_100.trim.nt.fa
    og="${base%.trim.nt.fa}"            # OG_100
    ogdir="{//}"                        # PROCESSED_OGS/OG_100/
    out="${ogdir}/${og}.msa_raw.nt.fa"  # PROCESSED_OGS/OG_100/OG_100.msa_raw.nt.fa
    echo "$ogdir"

    # run alignment (skips if alignment file already exists unless -f)
    twig macse-align \
        -i "$in" \
        -o "$out" \
    ' \
    :::: FILE_LISTS/trim_ogs.txt
