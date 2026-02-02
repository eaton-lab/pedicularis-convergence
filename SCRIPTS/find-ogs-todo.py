#!/usr/bin/env python

"""

Usage
-----
>>> python todo.py INDIR/*.cds.fa OUTDIR/*.trim.nt.fa > todo.txt

"""


import sys
from pathlib import Path

idir = Path(sys.argv[1])
isuf = str(sys.argv[2])
odir = Path(sys.argv[3])
osuf = str(sys.argv[4])

# get paths
ifiles = list(idir.rglob('*' + isuf))
ofiles = list(odir.rglob('*' + osuf))

# get names of finished OGs
finished = []
for ff in ofiles:
    f = ff.name.split(".", 1)[0]
    finished.append(f)
finished = set(finished)

# get list of files to do
todo = []
for p in ifiles:
    name = p.name.split(".", 1)[0]

    if name.startswith("OG0"):
       og = name[2:].lstrip("0")
       name = f"OG_{og}"

    if name not in finished:
        todo.append(p)

print("\n".join(str(i) for i in todo))
