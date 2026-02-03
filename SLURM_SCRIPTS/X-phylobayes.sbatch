#!/usr/bin/env bash
# -------------------------
# Usage:
#   sbatch --array=1-10 -t 11:59:00 SCRIPT LIST.txt
# -------------------------
#
#SBATCH -J pb_test
#SBATCH -A e3b
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -t 11:59:00
#SBATCH --mem=32G
#SBATCH -o %x_%A_%a.out
#SBATCH -e %x_%A_%a.err
#SBATCH --array=1-10              # set at submit-time

set -euo pipefail

# -------------------------------------------------
LIST="$1"
[[ -s "$LIST" ]] || { echo "ERROR: list file not found or empty: $LIST"; exit 1; }

# -------------------------
# Select alignment for this array task
# -------------------------
ALIGN="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$LIST" | sed 's/[[:space:]]*$//')"
ogdir="$(dirname "$ALIGN")"
base="$(basename "$ALIGN")"
tag="${base}.pb"
CHAIN1="${tag}.chain1"
CHAIN2="${tag}.chain2"
cd "$ogdir"

# ---------------------------------------
echo "JobID      : $SLURM_JOB_ID"
echo "TaskID     : $SLURM_ARRAY_TASK_ID"
echo "Node       : $(hostname)"
echo "Alignment  : $ALIGN"
echo "tag        : $tag"
echo

# -------------------------------------------------------------------
# Run two chains concurrently (2 ranks each)
# -------------------------------------------------------------------
if [[ -f "$CHAIN1" ]]; then
    mpirun -np 2 pb_mpi "$CHAIN1" &
else
    mpirun -np 2 pb_mpi -d "$ALIGN" -gtr -cat -S -x 10 "$CHAIN1" &
fi
p1=$!

if [[ -f "$CHAIN2" ]]; then
    mpirun -np 2 pb_mpi "$CHAIN2" &
else
    mpirun -np 2 pb_mpi -d "$ALIGN" -gtr -cat -S -x 10 "$CHAIN2" &
fi
p2=$!

# --------------------------------------------------------------------
# check convergence stats at intervals and end if converged
# --------------------------------------------------------------------
THRESH=0.10
SLEEP_SECS=$((15 * 60))
while true; do

  # only try once both traces exist
  if [[ ! -f "${CHAIN1}.trace" || ! -f "${CHAIN2}.trace" ]]; then
    sleep "$SLEEP_SECS"
    continue
  fi

  # only try once both have >burnin
  n1=$(( $(wc -l < "${CHAIN1}.trace") - 1 ))
  n2=$(( $(wc -l < "${CHAIN2}.trace") - 1 ))
  if (( n1 <= BURNIN || n2 <= BURNIN )); then
    sleep "$SLEEP_SECS"
    continue
  fi

  # compute comps and write to logs (use default burnin of 10% and 20%, respectively)
  bpcomp -o "${tag}.bpcomp" "$CHAIN1" "$CHAIN2" > "${tag}.bpcomp.log" 2>&1 || true
  tracecomp "$CHAIN1" "$CHAIN2" > "${tag}.tracecomp.log" 2>&1 || true
  # compute diffs
  bp_maxdiff="$(awk '/maxdiff/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9.]+$/) v=$i} END{print v}' "${tag}.bpcomp.log")"
  tr_maxdiff="$(awk '/maxdiff/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9.]+$/) v=$i} END{print v}' "${tag}.tracecomp.log")"
  # report diffs
  echo "bpcomp   maxdiff: ${bp_maxdiff:-NA}"
  echo "tracecomp maxdiff: ${tr_maxdiff:-NA}"

  # end early if both maxdiff values are <= THRESH
  if awk -v bp="${bp_maxdiff:-nan}" -v tr="${tr_maxdiff:-nan}" -v th="$THRESH" '
    BEGIN {
      # ensure bp and tr are numeric
      if (bp+0 != bp || tr+0 != tr) exit 1
      exit( (bp <= th && tr <= th) ? 0 : 1 )
    }'
  then
    echo "CONVERGED: bpcomp and tracecomp maxdiff <= $THRESH"
    kill "$p1" "$p2" 2>/dev/null || true
    wait "$p1" "$p2" 2>/dev/null || true
    exit 0
  fi

  # wait 15 minutes and try again
  sleep "$SLEEP_SECS"
done
