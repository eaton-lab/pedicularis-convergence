#!/usr/bin/env bash
#
# Generate the unrooted draft gene tree set for inferring the draft species tree
# that will be used for rooting. Here we collapse low support edges and require
# that at least one member of TAXONOMY/OUTGROUPS.txt is present.
#

# parse OUT arg, make dir, and export it
INDIR=${1:?Usage: $0 INDIR OUTDIR OUTGROUP [CORES]}
OUTDIR=${2:?Usage: $0 INDIR OUTDIR OUTGROUP [CORES]}
OUTGROUP=${3:?Usage: $0 INDIR OUTDIR OUTGROUP [CORES]}
CORES=${4:-4}

mkdir -p "${OUTDIR}/"
find "${INDIR}/" -type f -name '*.raxml.support' > FILE_LISTS/TODO-6.txt

# run tree filter in parallel
parallel --progress -j $CORES ' \

    in="{}"

    # filter trees to require 25 tips, require outgroup, and collapse < min-support 50
    # write result with gene labels
    twig tree-filter \
      -i "${in}" \
      -o "${in}.collapse50.glabel" \
      -d "|" \
      -di 0 \
      -s 50 \
      -e 10 \
      -m 25 \
      -O "TAXONOMY/OUTGROUPS.tsv" \
      --require \
      2>"${in}.collapse50.glabel.log"
    ' \
    :::: FILE_LISTS/TODO-6.txt

# make concat nwk tree set
find "${INDIR}/" -type f -name '.collapse50.glabel' > "${OUTDIR}/tree-set-collapse50-glabel.nwk"

# relabel tree set to only taxon names
twig tree-filter \
    -i "${OUTDIR}/tree-set-glabel-filtered.nwk" \
    -d "|" \
    -di 0 \
    -rd \
    > "${OUTDIR}/tree-set-collapse50-alabel.nwk"

# run astral-pro on the tree set
astral-pro \
    -i "${OUTDIR}/tree-set-alabel-filtered.nwk" \
    -o "${OUTDIR}/sptree-alabel-filtered.nwk" \
    -t 20 \
    --root "${OUTGROUP}" \
    --seed 42

# report
ntrees=$(wc -l "${OUTDIR}/tree-set-collapse50-glabel.nwk")
echo "${ntrees} filtered trees run in astral-pro to infer species tree: ${OUTDIR}/sptree-alabel-filtered.nwk"
