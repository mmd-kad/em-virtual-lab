#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Repository hygiene checks (these are what CI can verify without MATLAB).

MATLAB itself cannot run on a public CI runner, so the physics suites
(test_core / smoke_gui / fuzz_probe) are run locally and their results are
recorded in README.md and docs/STATUS.md.  What CI *can* check is everything
that silently rots in a teaching repository:

  1. every .m file is pure ASCII (the project rule)
  2. no absolute local paths or personal data leaked into the sources
  3. every image and relative link used by the READMEs actually exists
  4. every Python helper still compiles
  5. the LaTeX guide has no raw Unicode math symbols outside math mode
     (B Nazanin has no such glyphs, so they would render as rectangles)
  6. the standard project files are present

Run:  python tests/repo_checks.py
Exit code 0 = all checks passed.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

SKIP_DIRS = {'.git', 'build', 'small', '__pycache__', '.venv', 'venv'}
FAILURES = []


def fail(check, detail):
    FAILURES.append('%s: %s' % (check, detail))


def walk(exts=None):
    for dp, dns, fns in os.walk(ROOT):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for f in fns:
            if exts is None or os.path.splitext(f)[1] in exts:
                yield os.path.join(dp, f)


def rel(p):
    return os.path.relpath(p, ROOT).replace('\\', '/')


# 1 ---------------------------------------------------------------- ASCII .m
for p in walk({'.m'}):
    raw = open(p, 'rb').read()
    bad = [(i, b) for i, b in enumerate(raw) if b > 127]
    if bad:
        line = raw[:bad[0][0]].count(b'\n') + 1
        fail('ascii-m', '%s line %d has non-ASCII byte 0x%02X' % (rel(p), line, bad[0][1]))

# 2 ------------------------------------------------- local paths / personal data
PRIVATE = re.compile(
    r'[A-Za-z]:\\Users\\|[A-Za-z]:/Users/|I:\\Hermes|I:/Hermes|'
    r'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}', re.I)
for p in walk({'.m', '.py', '.md', '.tex', '.yml', '.yaml', '.cff'}):
    if os.path.abspath(p) == os.path.abspath(__file__):
        continue          # this checker necessarily contains the patterns
    txt = open(p, encoding='utf-8', errors='ignore').read()
    m = PRIVATE.search(txt)
    if m:
        fail('privacy', '%s contains %r' % (rel(p), m.group(0)[:40]))

# 3 ------------------------------------------------------- links and images
LINK = re.compile(r'!?\[[^\]]*\]\(([^)]+)\)')
for name in ('README.md', 'README.fa.md', 'CONTRIBUTING.md', 'CHANGELOG.md'):
    p = os.path.join(ROOT, name)
    if not os.path.exists(p):
        fail('links', '%s is missing' % name)
        continue
    txt = open(p, encoding='utf-8').read()
    for target in LINK.findall(txt):
        if target.startswith(('http://', 'https://', '#', 'mailto:')):
            continue
        target = target.split('#')[0]
        if not target:
            continue
        if not os.path.exists(os.path.join(ROOT, target)):
            fail('links', '%s -> %s does not exist' % (name, target))

# 4 ------------------------------------------------------------- python compiles
for p in walk({'.py'}):
    try:
        # compile() in memory: py_compile would try to write a .pyc, and
        # os.devnull is not a regular file on Windows
        compile(open(p, encoding='utf-8').read(), p, 'exec')
    except SyntaxError as exc:
        fail('python', '%s line %s: %s' % (rel(p), exc.lineno, exc.msg))

# 5 ------------------------------------------------- guide: no raw Unicode math
tex = os.path.join(ROOT, 'docs', 'EM_VirtualLab_UserGuide_FA.tex')
if os.path.exists(tex):
    body = open(tex, encoding='utf-8').read()
    body = body.split('\\begin{document}', 1)[-1]
    body = re.sub(r'\$[^$]*\$', '', body)            # math is fine
    body = re.sub(r'\\lr\{[^{}]*\}', '', body)       # Latin runs are fine
    forbidden = '₀₁₂₃₄₅₆₇₈₉⁰¹²³⁴⁵⁶⁷⁸⁹⁻√∠−±∝Γθηςλαδωμτεφρ•'
    found = sorted({ch for ch in body if ch in forbidden})
    if found:
        fail('guide-glyphs', 'raw symbols outside math mode: %s' % ' '.join(found))
else:
    fail('guide-glyphs', 'docs/EM_VirtualLab_UserGuide_FA.tex is missing')

# 6 ------------------------------------------------------- required project files
for name in ('LICENSE', 'README.md', 'README.fa.md', '.gitignore', '.gitattributes',
             'CHANGELOG.md', 'CONTRIBUTING.md', 'CITATION.cff', 'run_lab.m',
             'core/em_constants.m', 'core/em_solve.m', 'gui/EM_VirtualLab.m',
             'tests/test_core.m', 'tests/smoke_gui.m',
             'docs/SPECIFICATION.md', 'docs/VALIDATION.md',
             'docs/EM_VirtualLab_UserGuide_FA.pdf'):
    if not os.path.exists(os.path.join(ROOT, name)):
        fail('files', '%s is missing' % name)

# ---------------------------------------------------------------------- report
if FAILURES:
    print('REPO CHECKS FAILED (%d)' % len(FAILURES))
    for f in FAILURES:
        print('  -', f)
    sys.exit(1)
print('REPO CHECKS PASSED')
print('  ASCII .m files, no private paths, all links resolve,')
print('  Python helpers compile, guide has no raw Unicode math,')
print('  all standard project files present.')
