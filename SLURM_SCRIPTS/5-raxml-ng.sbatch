#!/usr/bin/env bash
#
# USAGE:
#   find PROCESSED_OGS/ -type f -name *.msa_raw.nt.fa | shuf > FILE_LISTS/burg_msa_raw_ogs_rng.txt
#   sbatch SLURM_SCRIPTS/3-macse-refine.sbatch
# ACTION:
#   Runs `twig macse-refine` on all msa_raw.nt.fa files to write final msas.
# INPUT:
#   Run the find command (above) to generate the file list.
# OUTPUT:
#   .msa.nt.fa and msa.aa.fa will be created.
# CLUSTER RESOURCES REQUESTED:
#   - submits 1000 jobs (cluster limit) with up to 500 running concurrently.
#   - files are assigned evenly among jobs (~10 per job)
#   - each job has 1 core for 10 hours with 8G RAM
#
#SBATCH --account=e3b
#SBATCH -J twig
#SBATCH -t 10:00:00
#SBATCH --cpus-per-task=12
#SBATCH --mem=8G
#SBATCH --array=1-50
#SBATCH -o twig-refine_%A_%a.log
#SBATCH -e twig-refine_%A_%a.log

# THE FILE LIST
LIST="$1"

# set pipefail
set -euo pipefail

# cd into the submit directory
cd "${SLURM_SUBMIT_DIR:-$PWD}"

# load conda env
source "/burg/home/de2356/miniconda3/etc/profile.d/conda.sh"
conda activate twig

# Build ordered list of files to process
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

# read only the input filename for this array task ID and process it
sed -n "${start},${end}p" "$LIST" | while IFS= read -r aln; do

    # skip if .raxml.support already exists
    support="${aln}.raxml.support"
    if [[ -s "$support" ]]; then
        echo "[${SLURM_ARRAY_TASK_ID:-na}] skip (exists): $support"
        continue
    fi

    # write partitions file
    twig partition-cds \
        -i "$aln" \
	-n 3 \
	-m "GTR+G" \
	> "${aln}.partitions"

    # run raxml-ng
    raxml-ng \
        --all \
        --msa "${aln}" \
        --model "${aln}.partitions" \
        --brlen scaled \
        --seed 42 \
        --bs-trees 100 \
        --threads "${SLURM_CPUS_PER_TASK}"
done
