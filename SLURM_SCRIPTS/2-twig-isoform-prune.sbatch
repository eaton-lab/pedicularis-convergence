#!/usr/bin/env bash
#
# USAGE:
#
# ACTION:
#
# INPUT:
#
# OUTPUT:
#
# CLUSTER RESOURCES REQUESTED:
#   - submits 1000 jobs (cluster limit) with up to 500 running concurrently.
#   - files are assigned evenly among jobs (~12 per job)
#   - each job has 1 core for 10 hours with 8G RAM
#
#SBATCH --account=e3b
#SBATCH -J twig
#SBATCH -t 10:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --array=1-500
#SBATCH -o twig-iso_%A_%a.log
#SBATCH -e twig-iso_%A_%a.log

# THE FILE LIST
LIST="$1"

# set pipefail
set -euo pipefail

# cd into the submit directory
cd "${SLURM_SUBMIT_DIR:-$PWD}"

# load conda env
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate twig

# Build ordered list of files to process --------------------------
[[ -s "$LIST" ]] || { echo "Missing/empty $LIST" >&2; exit 1; }

# count njobs
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
# ---------------------------------------------------------------

# read only the input filename for this array task ID and process it
sed -n "${start},${end}p" "$LIST" | while IFS= read -r aln; do

  # aln                               # PROCESSED_OGS/OG_9/OG_9.trim.nt.fa
  info="${aln}.info.tsv"              # ...
  ogdir="$(dirname $aln)"             # PROCESSED_OGS/OG_9/
  base="$(basename $aln)"             # OG_9.trim.nt.fa
  og="${base%.trim.nt.fa}"            # OG_9
  out="${ogdir}/${og}.trim.iso.nt.fa" #
  log="${ogdir}/${og}.trim.iso.log"
  #echo $aln $out $info $log

  # run macse-prep
  twig isoform-prune \
    -i "$aln" \
    -o "$out" \
    -I "$info" \
    -s '.' 1 \
    -l D \
    2> "${log}"
done
