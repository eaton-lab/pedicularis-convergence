#!/usr/bin/env bash
#
# Generate the unrooted draft gene tree set for inferring the draft species tree
# that will be used for rooting. Here we collapse low support edges and require
# that at least one member of TAXONOMY/OUTGROUPS.txt is present.
#
# USAGE:
#   - bash SCRIPTS/5-twig-tree-filter-require-and-collapse DIR THREADS
# EXAMPLE:
#   - bash SCRIPTS/5-twig-tree-filter-require-and-collapse PROCESSED_OGS THREADS
#

# parse OUT arg, make dir, and export it
DIR=${1:?Usage: $0 INDIR OUTDIR [CORES]}
CORES=${2:-4}
mkdir -p "$OUT"

# get list of files to process
mkdir -p FILE_LISTS/
find $DIR/ -maxdepth 2 -type f -name 'OG*.raxml.support' | LC_ALL=C sort > FILE_LISTS/trees_orig.txt

# twig macse-prep
parallel --progress -j $CORES ' \

    # parse i/o handles
    in="{}"                             # PROCESSED_OGS/OG_100/OG_100.msa_raw.nt.fa
    base="{/}"                          # OG_100.msa_raw.nt.fa
    og="${base%.msa_raw.nt.fa}"         # OG_100
    ogdir="{//}"                        # PROCESSED_OGS/OG_100/
    pre="${ogdir}/${og}.msa"            # PROCESSED_OGS/OG_100/OG_100.msa
    echo "$ogdir"

    # filter trees to require 25 tips, require outgroup, and collapse < min-support 50
    # write result with gene labels
    twig tree-filter \
      -i "$in" \
      -o "${in}.collapse50.glabel" \
      -d "|" \
      -di 0 \
      -s 50
      -m 25 \
      -O "TAXONOMY/OUTGROUPS.tsv" \
      --require \
      2>"${in}.collapse50.glabel.log"
    ' \
    :::: FILE_LISTS/trees_orig.txt

# make concat nwk tree set
mkdir -p TREES/
cat $IN/*/*.raxml.support.collapse50.glabel > TREES/tree-set-collapse50-glabel.nwk
ntrees=$(wc -l TREES/tree-set-collapse50-glabel.nwk)

# relabel tree set only taxon names
twig tree-filter -i TREES/tree-set-glabel-filtered.nwk -d "|" -di 0 -rd > TREES/tree-set-collapse50-alabel.nwk

# run astral-pro on the tree set
astral-pro \
    -i TREES/tree-set-alabel-filtered.nwk \
    -o TREES/sptree-alabel-filtered.nwk \
    -t 20 \
    --root SRR11748982 \
    --seed 42

# report
echo "${ntrees} passed filtering run in astral-pro to infer species tree: ${sptree}"
