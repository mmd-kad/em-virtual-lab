#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Report every character in the guide .tex that the Persian font cannot render.

Scans the document body, skips math ($...$), \\lr{...}, \\texttt{...}, verbatim
blocks and LaTeX command names, then checks the remaining characters against
B Nazanin's cmap.  Anything listed here would appear as a rectangle in the PDF.
"""
import os
import re
import collections
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TEX = os.path.join(ROOT, 'docs', 'EM_VirtualLab_UserGuide_FA.tex')
FONT = os.path.expandvars(
    r'%LOCALAPPDATA%\Microsoft\Windows\Fonts\B-NAZANIN.TTF')

cm = TTFont(FONT, lazy=True).getBestCmap()
text = open(TEX, encoding='utf-8').read()
body = text.split('\\begin{document}', 1)[1]

out = []
inverb = False
for line in body.split('\n'):
    if '\\begin{verbatim}' in line:
        inverb = True
        continue
    if '\\end{verbatim}' in line:
        inverb = False
        continue
    if inverb:
        continue
    s = line
    s = re.sub(r'\$[^$]*\$', '', s)                 # math
    s = re.sub(r'\\lr\{[^{}]*\}', '', s)            # Latin runs
    s = re.sub(r'\\texttt\{[^{}]*\}', '', s)
    s = re.sub(r'\\[A-Za-z]+\*?', '', s)            # command names
    s = re.sub(r'[{}\[\]&\\]', '', s)               # LaTeX syntax
    out.append(s)
plain = '\n'.join(out)

missing = collections.Counter(ch for ch in plain
                              if ord(ch) > 32 and ord(ch) not in cm)
print('characters B Nazanin cannot render (outside math/Latin):')
for ch, n in missing.most_common():
    print('   U+%04X %r  x%d' % (ord(ch), ch, n))
print('TOTAL:', sum(missing.values()))
