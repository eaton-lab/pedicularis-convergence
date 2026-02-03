#!/bin/bash
#SBATCH --account=dsi
#SBATCH --job-name=PB_job
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=16
#SBATCH --mem=32G
#SBATCH --time=48:00:00

module load phylobayes/mpi-1.8
mpirun pb_mpi -d data.phy -cat -gtr chain1

