#!/usr/bin/env bash
#
#SBATCH --account=e3b
#SBATCH -J twig
#SBATCH -t 11:59:00
#SBATCH --cpus-per-task=24
#SBATCH --mem=8G
#SBATCH -o twig-tf-astral_%A_%a.log
#SBATCH -e twig-tf-astral_%A_%a.log

bash SCRIPTS/6-...

