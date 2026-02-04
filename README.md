# 1. run trimming on list of input OGS
```bash
mkdir -p OGS/
python SCRIPTS/find-ogs-todo.py TMP_OGS/ '.fa' OGS/ '.trim.nt.fa' | shuf > FILE_LISTS/TODO-1.txt
sbatch SLURM_SCRIPTS/1-twig-macse-trim.sbatch FILE_LISTS/TODO-1.txt OGS/
find TMP_OGS/ -type f -name '*.fa' -size +1b | wc -l
# 13232
```

# 2. run isoform-pruning on list of trimmed OGS
```bash
python SCRIPTS/find-ogs-todo.py OGS/ 'trim.nt.fa' OGS/ '.trim.iso.nt.fa' | shuf > FILE_LISTS/TODO-2.txt
sbatch SLURM_SCRIPTS/2-twig-macse-iso.sbatch FILE_LISTS/TODO-2.txt
find OGS/ -type f -name '*.trim.iso.nt.fa' | wc -l
# 13232
```

# 3. run alignment on list of iso-pruned OGS
```bash
python SCRIPTS/find-ogs-todo.py OGS/ 'trim.iso.nt.fa' OGS/ '.msa_raw.nt.fa' | shuf > FILE_LISTS/TODO-3.txt
sbatch SLURM_SCRIPTS/3-twig-macse-align.sbatch FILE_LISTS/TODO-3.txt
find OGS/ -type f -name '*.msa_raw.nt.fa' | wc -l
# 13228  [ discard the remaining 4 -- very large, takes too long to run ]
```

# 4. run refinement on list of alignments
```bash
python SCRIPTS/find-ogs-todo.py OGS/ '.msa_raw.nt.fa' OGS/ '.msa.nt.fa' | shuf > FILE_LISTS/TODO-4.txt
sbatch SLURM_SCRIPTS/4-twig-macse-refine.sbatch FILE_LISTS/TODO-4.txt
find OGS/ -type f -name '*.msa.nt.fa' -size +1b | wc -l
# 13207  [ x filtered out by minsamp filter ]
```

# 5. run partitioned ML tree inference on refined alignments
```bash
python SCRIPTS/find-ogs-todo.py OGS/ '.msa.nt.fa' OGS/ '.msa.nt.fa.raxml.support' | shuf > FILE_LISTS/TODO-5.txt
sbatch SLURM_SCRIPTS/5-raxml-ng.sbatch FILE_LISTS/TODO-5.txt
find OGS/ -type f -name '*.raxml.support' | wc -l 
# 13195
```

# 6. filter trees to collapse low-support branches and require at least one outgroup
```bash
# filter trees to require 25 tips, require outgroup, collapse <50 support, require 10 edges
parallel --progress -j 50 ' \
  twig tree-filter \
    -i {} \
    -o {}.collapse50.glabel \
    -d "|" \
    -di 0 \
    -s 50 \
    -e 10 \
    -m 25 \
    -O TAXONOMY/OUTGROUPS.tsv \
    --require \
    2>{}.collapse50.glabel.log
  ' \
  ::: $(find OGS/ -type f -name '*.raxml.support' -size +1b)
find OGS/ -type f -name '*.collapse50.glabel' -size +1b | wc -l
# 9418
```

# 7. infer draft astral species tree and relabel it
```bash
find OGS/ -type f -name "*.glabel" -size +1b -print0 | xargs -0 cat > TREES/tree-set-glabel-filtered.nwk
twig tree-filter -i TREES/tree-set-glabel-filtered.nwk -d "|" -di 0 -rd > TREES/tree-set-alabel-filtered.nwk
astral-pro \
    -i TREES/tree-set-alabel-filtered.nwk \
    -o TREES/sptree-alabel-filtered.nwk \
    -t 24 \
    --root SRR11748982 \
    --seed 42
twig tree-filter \
    -i TREES/sptree-alabel-filtered.nwk \
    -o TREES/sptree-alabel-filtered-relabeled.nwk \
    -d '|' \
    -di 0 \
    -ri \
    -I TAXONOMY/IMAP.tsv
```

# 8. root trees given the species tree topology
```bash
parallel -j 50 --progress " \
    twig tree-rooter \
        -i {} \
        -d '|' -di 0 \
        -I TAXONOMY/OUTGROUPS.tsv \
        -s TREES/sptree-alabel-filtered.nwk \
        1>{}.rooted \
        2>{}.rooted.log \
    " \
    ::: $(find OGS/ -type f -name '*.glabel' -size +1b)
find OGS/ -type f -name '*.rooted' -size +1b | wc -l
# 8400
```

# 9. run final species tree inference on filtered trees (filtered, rooted, multi or single-copy)
```bash
find OGS/ -type f -name '*.glabel.rooted' -size +1b > TREES/tree-set-glabel-filtered-rooted.nwk

# get multicopy trees labeled as {acc}-{spp}
twig tree-filter \
    -i TREES/tree-set-glabel-filtered-rooted.nwk \
    -d "|" -di 0 \
    -I TAXONOMY/IMAP.tsv -ri \
    > TREES/tree-set-accspplabel-filtered-rooted-multicopy.nwk
wc -l TREES/tree-set-accspplabel-filtered-rooted-multicopy.nwk
# 8400

# get singlecopy trees labeled as {acc}-{spp}
twig tree-filter \
    -i TREES/tree-set-glabel-filtered-rooted.nwk \
    -d "|" -di 0 \
    -c 1 \
    -I TAXONOMY/IMAP.tsv -ri \
    > TREES/tree-set-accspplabel-filtered-rooted-singlecopy.nwk
wc -l TREES/tree-set-accspplabel-filtered-rooted-singlecopy.nwk
# 7278

# infer species tree from multicopy
astral-pro \
    -i TREES/tree-set-accspplabel-filtered-rooted-multicopy.nwk \
    -o TREES/sptree-accpplabel-filtered-rooted-multicopy.nwk \
    -t 20 \
    --root Rehmannia-glutinosa-SRR11748982 \
    --seed 42

# infer species tree from singlecopy
astral-pro \
    -i TREES/tree-set-accspplabel-filtered-rooted-singlecopy.nwk \
    -o TREES/sptree-accpplabel-filtered-rooted-singlecopy.nwk \
    -t 20 \
    --root Rehmannia-glutinosa-SRR11748982 \
    --seed 42
```

# 10. get subset trees suitable for network analysis
```bash

# get subset for NET1 phylonet analysis; require outgroup and 20 IMAP samples
twig tree-filter \
    -i TREES/tree-set-glabel-filtered-rooted.nwk \
    -d "|" -di 0 \
    -I TAXONOMY/NET1.tsv \
    -ri \
    -c 1 \
    -m 20 \
    --subsample \
    --collapse \
    --require \
    > TREES/tree-set-accspplabel-filtered-rooted-singlecopy-NET1.nwk \
    2> TREES/tree-set-accspplabel-filtered-rooted-singlecopy-NET1.log
# 6944 trees w/ min=20,max=29 tips

twig tree-filter \
    -i TREES/tree-set-glabel-filtered-rooted.nwk \
    -d "|" -di 0 \
    -I TAXONOMY/NET2.tsv \
    -ri \
    -c 1 \
    -m 20 \
    --subsample \
    --collapse \
    --require \
    > TREES/tree-set-accspplabel-filtered-rooted-singlecopy-NET2.nwk \
    2> TREES/tree-set-accspplabel-filtered-rooted-singlecopy-NET2.log
# 5775 trees w/ min=20,max=24 tips

twig tree-filter \
    -i TREES/tree-set-glabel-filtered-rooted.nwk \
    -d "|" -di 0 \
    -I TAXONOMY/NET3.tsv \
    -ri \
    -c 1 \
    -m 24 \
    --subsample \
    --collapse \
    --require \
    > TREES/tree-set-accspplabel-filtered-rooted-singlecopy-NET3.nwk \
    2> TREES/tree-set-accspplabel-filtered-rooted-singlecopy-NET3.log
# 6545 trees w/ min=20,max=31 tips
```

# 11. get rooted tree forced to match sptree for csubst/gene analyses
```bash
parallel -j 40 --progress ' \
  twig tree-skeleton \
    -i {} \
    -d "|" \
    -di 0 \
    -s TREES/sptree-alabel-filtered.nwk \
    >{}.skel \
  ' \
  ::: $(find OGS/ -type f -name '*.collapse50.glabel.rooted' -size +1b)
# 8400 trees
```

# 12. HPC: run csubst analysis 
```bash
sbatch SLURM_SCRIPTS/12-csubst.sh
sbatch SLURM_SCRIPTS/12-csubst-skel.sh
```
