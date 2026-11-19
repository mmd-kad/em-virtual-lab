#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Compile docs/EM_VirtualLab_UserGuide_FA.tex with XeLaTeX.

* finds xelatex.exe (PATH, then the usual MiKTeX locations),
* switches MiKTeX to on-the-fly package installation for the first run,
* runs XeLaTeX three times (TOC + longtable + cross references),
* reports the page count and any LaTeX errors.

Run:  python compile_guide_tex.py
"""
import os
import glob
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DOCS = os.path.join(ROOT, 'docs')
TEXNAME = 'EM_VirtualLab_UserGuide_FA.tex'
OUTPDF = os.path.join(DOCS, 'EM_VirtualLab_UserGuide_FA.pdf')


def find_exe(name):
    p = shutil.which(name)
    if p:
        return p
    localapp = os.path.expandvars(r'%LOCALAPPDATA%')
    pats = []
    for base in (os.path.join(localapp, 'Programs', 'MiKTeX'),
                 os.path.join(localapp, 'Programs', 'MiKTeX 2.9'),
                 r'C:\Program Files\MiKTeX'):
        for sub in ('miktex/bin/x64', 'miktex/bin'):
            pats.append(os.path.join(base, sub, name + '.exe'))
    for pat in pats:
        for hit in glob.glob(pat):
            if os.path.exists(hit):
                return hit
    # last resort: anywhere under the user profile (bounded depth)
    for base in (os.path.expandvars(r'%LOCALAPPDATA%\Programs'),
                 r'C:\Program Files'):
        for hit in glob.glob(os.path.join(base, '**', name + '.exe'), recursive=True):
            if os.path.basename(os.path.dirname(hit)).lower() in ('x64', 'bin'):
                return hit
    return None


xelatex = find_exe('xelatex')
print('xelatex:', xelatex)
if not xelatex:
    sys.exit('xelatex not found - is MiKTeX installed?')

bindir = os.path.dirname(xelatex)
initexmf = find_exe('initexmf') or os.path.join(bindir, 'initexmf.exe')
if os.path.exists(initexmf):
    print('enabling MiKTeX auto-install ...')
    subprocess.run([initexmf, r'--set-config-value=[MPM]AutoInstall=1'],
                   capture_output=True, text=True)
    subprocess.run([initexmf, '--update-fndb'], capture_output=True, text=True)

env = dict(os.environ)
env['PATH'] = bindir + os.pathsep + env.get('PATH', '')
ok = True
for run in (1, 2, 3):
    print('--- xelatex pass %d ---' % run)
    r = subprocess.run([xelatex, '-interaction=nonstopmode', '-halt-on-error',
                        TEXNAME],
                       cwd=DOCS, env=env, capture_output=True, text=True,
                       errors='replace', timeout=1200)
    log = os.path.join(DOCS, TEXNAME.replace('.tex', '.log'))
    txt = ''
    if os.path.exists(log):
        with open(log, encoding='utf-8', errors='replace') as fh:
            txt = fh.read()
    errs = [l for l in txt.splitlines() if l.startswith('!')]
    if r.returncode != 0 or errs:
        print('pass %d FAILED (rc=%d)' % (run, r.returncode))
        for l in errs[:15]:
            print('   ', l)
        # show the context of the first error
        for i, l in enumerate(txt.splitlines()):
            if l.startswith('!'):
                print('\n'.join(txt.splitlines()[i:i + 8]))
                break
        ok = False
        break
    print('   ok')

if ok and os.path.exists(OUTPDF):
    import pymupdf
    d = pymupdf.open(OUTPDF)
    print('\nPDF:', OUTPDF)
    print('  size: %.2f MB   pages: %d' % (os.path.getsize(OUTPDF) / 1e6, d.page_count))
    # quick sanity: images + persian text
    imgs = sum(len(p.get_images(full=True)) for p in d)
    import re
    fa = sum(len(re.findall(r'[\u0600-\u06FF]', p.get_text())) for p in d)
    print('  embedded images:', imgs, ' persian chars:', fa)
    print('COMPILE OK')
else:
    sys.exit('COMPILE FAILED - see the log in docs/')