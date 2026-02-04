#!/usr/bin/env bash
#
# USAGE:
#   - bash SCRIPTS/4-partitioned-raxml.sh DIR JOBS THREADS
# EXAMPLE:
#   - bash SCRIPTS/4-partitioned-raxml.sh PROCESSED_OGS 4 10
#

# parse OUT arg, make dir, and export it
DIR=${1:?Usage: $0 INDIR OUTDIR [CORES]}
JOBS=${2:-4}
THREADS=${3:-10}

# get list of files to process
mkdir -p FILE_LISTS/
find $IN/ -maxdepth 2 -type f -name 'OG*.msa.nt.fa' | LC_ALL=C sort > FILE_LISTS/msa_nts.txt

# twig macse-prep
parallel --progress -j $JOBS ' \

    # parse i/o handles
    in="{}"                             # PROCESSED_OGS/OG_100/OG_100.msa_raw.nt.fa
    base="{/}"                          # OG_100.msa_raw.nt.fa
    og="${base%.msa_raw.nt.fa}"         # OG_100
    ogdir="{//}"                        # PROCESSED_OGS/OG_100/
    pre="${ogdir}/${og}.msa"            # PROCESSED_OGS/OG_100/OG_100.msa
    echo "$ogdir"

    # write partitions file
    twig partition-cds \
        -i "$in" \
	-n 3 \
	-m "GTR+G" \
	> "${in}.partitions"

    # run raxml-ng
    raxml-ng \
        --all \
        --msa "$in" \
        --model "${in}.partitions" \
        --brlen scaled \
        --seed 42 \
        --bs-trees 100 \
        --threads "$THREADS" \
    ' \
    :::: FILE_LISTS/msa_nts.txt
