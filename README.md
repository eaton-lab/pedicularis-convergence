# run trimming on list of input OGS
```bash
mkdir -p OGS/
python SCRIPTS/find-ogs-todo.py TMP_OGS/ '.fa' OGS/ '.trim.nt.fa' | shuf > FILE_LISTS/TODO.txt
sbatch SLURM_SCRIPTS/1-twig-macse-trim.sbatch FILE_LISTS/TODO.txt OGS/
find TMP_OGS/ -type f -name '*.fa' -size +1b | wc -l
# 13232
```

# run isoform-pruning on list of trimmed OGS
```bash
python SCRIPTS/find-ogs-todo.py OGS/ 'trim.nt.fa' OGS/ '.trim.iso.nt.fa' | shuf > FILE_LISTS/TODO.txt
sbatch SLURM_SCRIPTS/2-twig-macse-iso.sbatch FILE_LISTS/TODO.txt
find OGS/ -type f -name '*.trim.iso.nt.fa' | wc -l
# 13232
```

# run alignment on list of iso-pruned OGS
```bash
python SCRIPTS/find-ogs-todo.py OGS/ 'trim.iso.nt.fa' OGS/ '.msa_raw.nt.fa' | shuf > FILE_LISTS/TODO-3.txt
sbatch SLURM_SCRIPTS/3-twig-macse-align.sbatch FILE_LISTS/TODO-3.txt
find OGS/ -type f -name '*.msa_raw.nt.fa' | wc -l
# 13226  [ few large ones remain ]
```

# run refinement on list of alignments
```bash
python SCRIPTS/find-ogs-todo.py OGS/ '.msa_raw.nt.fa' OGS/ '.msa.nt.fa' | shuf > FILE_LISTS/TODO-4.txt
sbatch SLURM_SCRIPTS/4-twig-macse-refine.sbatch FILE_LISTS/TODO-4.txt
find OGS/ -type f -name '*.msa.nt.fa' | wc -l
# 13195  [ 37 filtered out by minsamp filter ]
```

# run partitioned ML tree inference on refined alignments
```bash
python SCRIPTS/find-ogs-todo.py OGS/ '.msa.nt.fa' OGS/ '.msa.nt.fa.raxml.support' | shuf > FILE_LISTS/TODO-5.txt
sbatch SLURM_SCRIPTS/5-raxml-ng.sbatch FILE_LISTS/TODO-5.txt
find OGS/ -type f -name '*.raxml.support' | wc -l 
# 13183
```

# ...
