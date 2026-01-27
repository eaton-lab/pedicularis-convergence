#!/usr/bin/env bash
#
# USAGE:
#   - `sbatch SLURM_SCRIPTS/twig_refine.sbatch -- file-lists/files-raw_ogs.txt`
# ACTION:
#   - Runs `twig macse-prep` to trim/filter the raw orthogroups.
# INPUT:
#   - a txt file with ordered files from RAW_OGS/*.fa
#   - create with `find RAW_OGS -maxdepth 2 -type f -name "*.fa" -print | LC_ALL=C sort > file-lists/files-raw_ogs.txt`
# OUTPUT:
#   - PROCESSED_OGS/{OG}.trim.nt.fa
#   - PROCESSED_OGS/{OG}.trim.info
# CLUSTER RESOURCES REQUESTED:
#   - submits 1000 jobs (cluster limit) with up to 500 running concurrently.
#   - files are assigned evenly among jobs (~12 per job)
#   - each job has 1 core for 10 hours with 8G RAM
#
#SBATCH --account=eaton
#SBATCH -J twig
#SBATCH -t 10:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --array=1-1000%500
#SBATCH -o twig-refine_%A_%a.log
#SBATCH -e twig-refine_%A_%a.log

# set pipefail
set -euo pipefail

# cd into the submit directory
cd "${SLURM_SUBMIT_DIR:-$PWD}"

# load conda env
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate twig

# Build ordered list of files to process
LIST="file_list-msa_raw.txt"
[[ -s "$LIST" ]] || { echo "Missing/empty $LIST" >&2; exit 1; }

# ...
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
start=$(( tid * PER ))
end=$(( start + PER ))

# if all jobs are finished, exit...
(( start <= N )) || exit 0
(( end > N )) && end=$N

# read only the input filename for this array task ID and process it
sed -n "${start},${end}p" "$LIST" | while IFS= read -r aln; do
  hog_dir="$(dirname "$aln")"
  HOG_ID="$(basename "$hog_dir")"
  OUT="$hog_dir"
  mkdir -p "$OUT"

  twig macse-refine \
    -i "$aln" \
    -o "${OUT}/${HOG_ID}.msa" \
    -mo 100 \
    -ms 25 \
    -ac 0.5 \
    -R -f
done



