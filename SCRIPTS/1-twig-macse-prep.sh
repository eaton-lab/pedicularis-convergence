#!/usr/bin/env bash
#
# USAGE:
#   - bash SCRIPTS/1-twig-macse-prep.sh $RAW $OUT $CORES
#

# parse OUT arg, make dir, and export it
IN=${1:?Usage: $0 INDIR OUTDIR [CORES]}
OUT=${2:?Usage: $0 INDIR OUTDIR [CORES]}
CORES=${3:-10}
mkdir -p "$OUT"
export OUT CORES

# write list of files from RAW dir with >24 sequences
mkdir -p FILE_LISTS/
find $IN/ -maxdepth 1 -type f -name 'OG*.fa' | LC_ALL=C sort > FILE_LISTS/raw_ogs.txt

# twig macse-prep
parallel --progress -j $CORES ' \

    # parse i/o
    in="{}"
    base="{/}"                        # e.g., OG0000009.fa
    id="${base#OG}"; id="${id%.fa}"   # strip OG + .fa -> 0000009
    id=$((10#$id))                    # drop leading zeros safely (base-10)
    og="OG_${id}"                     # OG9
    ogdir="$OUT/$og"
    trim="${ogdir}/${og}.trim.nt.fa"
    log="${ogdir}/${og}.trim.log"
    mkdir -p "$ogdir"
    echo $ogdir

    # run macse-prep
    twig macse-prep \
        -i "$in" \
        -o "$trim" \
        -hf 0.3 -hi 0.6 -ml 200 -mc 25 -hc 15 -ti 33 -te 33 -f \
        2> "$log" \

    # remove the ogdir if it did not pass filtering
    if [[ -e "$trim" && ! -s "$trim" ]]; then
      rm -r $ogdir
    fi

    ' \
    :::: FILE_LISTS/raw_ogs.txt
