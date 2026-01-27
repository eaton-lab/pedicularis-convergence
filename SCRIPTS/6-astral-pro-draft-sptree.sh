#!/usr/bin/env bash
#
# Generate the unrooted draft gene tree set for inferring the draft species tree
# that will be used for rooting. Here we collapse low support edges and require
# that at least one member of TAXONOMY/OUTGROUPS.txt is present.
#
# USAGE:
#   - bash SCRIPTS/6-astral-pro-draft-sptree.sh IN OUT THREADS
# EXAMPLE:
#   - bash SCRIPTS/6-astral-pro-draft-sptree.sh PROCESSED_OGS TREES 20
#

# parse OUT arg, make dir, and export it
INDIR=${1:?Usage: $0 INDIR OUTDIR [CORES]}
OUTDIR=${1:?Usage: $0 INDIR OUTDIR [CORES]}
CORES=${2:-4}

# make concat nwk tree set
mkdir -p $OUTDIR
cat $IN/*/*.raxml.support.collapse50.glabel > $OUT/tree-set-collapse50-glabel.nwk
ntrees=$(wc -l $OUT/tree-set-collapse50-glabel.nwk)

# relabel tree set only taxon names
twig tree-filter -i $OUT/tree-set-glabel-filtered.nwk -d "|" -di 0 -rd > $OUT/tree-set-collapse50-alabel.nwk

# run astral-pro on the tree set
astral-pro \
    -i $OUT/tree-set-alabel-filtered.nwk \
    -o $OUT/sptree-alabel-filtered.nwk \
    -t $CORES \
    --root SRR11748982 \
    --seed 42

# report
echo "${ntrees} filtered trees run in astral-pro to infer species tree: $OUT/sptree-alabel-filtered.nwk"
