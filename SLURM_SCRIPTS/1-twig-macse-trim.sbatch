#!/usr/bin/env bash
#
# USAGE:
#   - `find TMP_OGS/ -type f -name "*.fa" | shuf > FILE_LISTS/burg-ogs-rng.txt`
#   - `sbatch SLURM_SCRIPTS/1-twig-macse-trim.sbatch
# ACTION:
#   - Runs `twig macse-trim` to trim/filter the raw orthogroups.
# INPUT:
#   - None. But you first must make a txt file with ordered files (see usage above)
# OUTPUT:
#   - OUT/{OG}.trim.nt.fa
#   - OUT/{OG}.trim.nt.fa.info.tsv
# CLUSTER RESOURCES REQUESTED:
#   - submits up to 1000 jobs (cluster limit).
#   - if ntasks (nfiles) is >1000 then multiple files are assigned to a job.
#   - each job gets 1 core for 11:59 hours with 8G RAM
#
#SBATCH --account=e3b
#SBATCH -J twig-trim
#SBATCH -t 11:59:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --array=1-900
#SBATCH -o twig-trim_%A_%a.log
#SBATCH -e twig-trim_%A_%a.log

# SET THE IN and OUT PATHS -------------------------
LIST="$1"
OUT="$2"
# --------------------------------------------------

# REQUIRE LIST TO BE NON EMPTY
[[ -s "$LIST" ]] || { echo "Missing/empty $LIST" >&2; exit 1; }

# ENSURE OUTDIR EXISTS
mkdir -p $OUT

# set pipefail
set -euo pipefail

# cd into the submit directory
cd "${SLURM_SUBMIT_DIR:-$PWD}"

# load conda env
source "/burg/home/de2356/miniconda3/etc/profile.d/conda.sh"
conda activate twig

# --- Figure out how many tasks/files need to be run per submitted job -----
N=$(wc -l < "$LIST")
(( N > 0 )) || { echo "No files listed in $LIST" >&2; exit 1; }

# derive array size robustly
MIN=${SLURM_ARRAY_TASK_MIN:-1}
MAX=${SLURM_ARRAY_TASK_MAX:-1000}
NTASKS=$(( MAX - MIN + 1 ))

# calculate number of tasks per sub-job
PER=$(( (N + NTASKS - 1) / NTASKS ))   # ceil(N/NTASKS)

# get the array task ID to assign tasks to sub-job array
tid=$(( SLURM_ARRAY_TASK_ID - 1 ))     # 0-based
start=$(( tid * PER + 1))
end=$(( start + PER - 1))

# if all jobs are finished, exit...
(( start <= N )) || exit 0
(( end > N )) && end=$N
# --------------------------------------------------------------------------

# read from the FILE_LIST the subset of files to run on this job
# (using the TASK_ID) and run them serially.
sed -n "${start},${end}p" "$LIST" | while IFS= read -r aln; do

  # aln                                  # OG_cds_fastas/OG0008000_OG0008999/OG0008847/OG0008847.cds.fasta
  base="$(basename $aln)"                # OG0008847.fa
  id="${base#OG}"; id="${id%.fa}"        # 0008847
  id="$((10#$id))"                       # 8847
  og="OG_${id}"                          # OG_8847
  ogdir="$OUT/${og}"                     # {OUT}/OG_8847/
  trim="${ogdir}/${og}.trim.nt.fa"       # {OUT}/OG_8847/OG_8847.trim.nt.fa
  log="${ogdir}/${og}.trim.log"          # {OUT}/OG_8847/OG_8847.trim.log
  mkdir -p "$ogdir"

  # skip if .log already exists; is written even if locus is filtered out
  if [[ -s "$log" ]]; then
    echo "[${SLURM_ARRAY_TASK_ID:-na}] skip (exists): ${trim}"
    continue
  fi

  # run macse-trim
  twig macse-trim \
    -i "$aln" \
    -o "$trim" \
    -hf 0.3 -hi 0.6 -ml 200 -mc 25 -hc 15 -ti 33 -te 33 -f \
    2>"$log"

done
