#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Generate the Persian (RTL) LaTeX source of the EM Virtual Lab user guide.

Writes docs/EM_VirtualLab_UserGuide_FA.tex, which is compiled with XeLaTeX +
xepersian (B Nazanin for Persian, Times New Roman for Latin).

Run:  python build_guide_tex.py          (writes the .tex)
      xelatex -interaction=nonstopmode ... (twice, for the table of contents)
"""
import os
import re
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DOCS = os.path.join(ROOT, 'docs')
TEX = os.path.join(DOCS, 'EM_VirtualLab_UserGuide_FA.tex')

# ---------------------------------------------------------------- text helpers
def esc(s):
    """Escape LaTeX specials that may appear in Persian text."""
    for a, b in (('\\', r'\textbackslash{}'), ('&', r'\&'), ('%', r'\%'),
                 ('#', r'\#'), ('_', r'\_'), ('{', r'\{'), ('}', r'\}')):
        s = s.replace(a, b)
    return s


# --------------------------------------------------------------------------
# Symbols must never be typed as Unicode inside a Persian (B Nazanin) run:
# that font has no Greek letters, no sub/superscripts and no math operators,
# so they render as tofu boxes (XeLaTeX) or silently fall back to Calibri /
# Cambria Math / Arial (Word).  Everything technical goes through math mode.
# --------------------------------------------------------------------------
FORMULAS = [
    # (plain text as written in the content, LaTeX math) - longest first
    ('√(eps_r·mu_r)', r'\sqrt{\varepsilon_r\mu_r}'),
    ('η0√(mu_r/eps_r)', r'\eta_0\sqrt{\mu_r/\varepsilon_r}'),
    ('η = η0√(mu_r/eps_r)', r'\eta=\eta_0\sqrt{\mu_r/\varepsilon_r}'),
    ('n = √(eps_r·mu_r)', r'n=\sqrt{\varepsilon_r\mu_r}'),
    ('eps_c = eps_r − jσ/(ωε0)', r'\varepsilon_c=\varepsilon_r-j\sigma/(\omega\varepsilon_0)'),
    ('tan δ = σ/(ωε0 eps_r)', r'\tan\delta=\sigma/(\omega\varepsilon_0\varepsilon_r)'),
    ('α = −Im(k_z) ، δ_s = 1/α', r'\alpha=-\mathrm{Im}(k_z),\quad \delta_s=1/\alpha'),
    ('α = −Im(k_z)', r'\alpha=-\mathrm{Im}(k_z)'),
    ('δ_s = 1/α', r'\delta_s=1/\alpha'),
    ('|E| ∝ exp(−αz) ، توان ∝ exp(−۲αz)',
     r'|E|\propto e^{-\alpha z},\quad P\propto e^{-2\alpha z}'),
    ('exp(−۲αz)', r'e^{-2\alpha z}'),
    ('exp(−αz)', r'e^{-\alpha z}'),
    ('exp(+jωt)', r'e^{+j\omega t}'),
    ('exp(-j k·r)', r'e^{-j\mathbf{k}\cdot\mathbf{r}}'),
    ('n1 sin θ_i = n2 sin θ_t', r'n_1\sin\theta_i=n_2\sin\theta_t'),
    ('k_x = k1 sin θ_i = k2 sin θ_t', r'k_x=k_1\sin\theta_i=k_2\sin\theta_t'),
    ('Γ = (η2 cosθ_i − η1 cosθ_t)/(η2 cosθ_i + η1 cosθ_t) ، τ = 1 + Γ',
     r'\Gamma=\frac{\eta_2\cos\theta_i-\eta_1\cos\theta_t}{\eta_2\cos\theta_i+\eta_1\cos\theta_t},\quad \tau=1+\Gamma'),
    ('Γ = (η2 cosθ_t − η1 cosθ_i)/(η2 cosθ_t + η1 cosθ_i) ، 1 + Γ = τ cosθ_t/cosθ_i',
     r'\Gamma=\frac{\eta_2\cos\theta_t-\eta_1\cos\theta_i}{\eta_2\cos\theta_t+\eta_1\cos\theta_i},\quad 1+\Gamma=\tau\frac{\cos\theta_t}{\cos\theta_i}'),
    ('R = |Γ|² ، T = |τ|²(η1/η2) Re(cosθ_t)/cosθ_i ، R + T = 1',
     r'R=|\Gamma|^2,\quad T=|\tau|^2\frac{\eta_1}{\eta_2}\frac{\mathrm{Re}(\cos\theta_t)}{\cos\theta_i},\quad R+T=1'),
    ('θ_B = arctan(n2/n1)', r'\theta_B=\arctan(n_2/n_1)'),
    ('θ_c = arcsin(n2/n1)', r'\theta_c=\arcsin(n_2/n_1)'),
    ('cos θ_t = −j√((n1 sinθ_i/n2)² − 1)',
     r'\cos\theta_t=-j\sqrt{(n_1\sin\theta_i/n_2)^2-1}'),
    ('|E_y| = |1 + Γ exp(2j k_z1 z)|', r'|E_y|=|1+\Gamma e^{2jk_{z1}z}|'),
    ('|1 ± Γ exp(2j k_z1 z)|', r'|1\pm\Gamma e^{2jk_{z1}z}|'),
    ('SWR = (1 + |Γ|)/(1 − |Γ|)', r'\mathrm{SWR}=\frac{1+|\Gamma|}{1-|\Gamma|}'),
    ('SWR = (۱+|Γ|)/(۱−|Γ|)', r'\mathrm{SWR}=\frac{1+|\Gamma|}{1-|\Gamma|}'),
    ('Γ = −1 ، τ = 0 ، |J_s| = 2|H_i| cosθ_i (TE) یا 2|H_i| (TM)',
     r'\Gamma=-1,\ \tau=0,\ |J_s|=2|H_i|\cos\theta_i\ (\mathrm{TE}),\ 2|H_i|\ (\mathrm{TM})'),
    ('|J_s| = 2|H_i|cosθ_i', r'|J_s|=2|H_i|\cos\theta_i'),
    ('|J_s| = ۲|H_i|cosθ_i', r'|J_s|=2|H_i|\cos\theta_i'),
    ('|J_s| = ۲|H_i|', r'|J_s|=2|H_i|'),
    ('|J_s| = 2|H_i|', r'|J_s|=2|H_i|'),
    ('ρ_s = ۲ε0 eps_r sinθ_i', r'\rho_s=2\varepsilon_0\varepsilon_r\sin\theta_i'),
    ('۲|sin(k_z1 z)|', r'2|\sin(k_{z1}z)|'),
    ('2|sin(k_z1 z)|', r'2|\sin(k_{z1}z)|'),
    ('۲|sin(k₁z)|', r'2|\sin(k_1z)|'),
    ('(η1/η2) cosθ_t/cosθ_i', r'\frac{\eta_1}{\eta_2}\frac{\cos\theta_t}{\cos\theta_i}'),
    ('Im(cos θ_t) < 0', r'\mathrm{Im}(\cos\theta_t)<0'),
    ('Re(eps_c) = 4.4', r'\mathrm{Re}(\varepsilon_c)=4.4'),
    ('−Im(eps_c) = 0.3595', r'-\mathrm{Im}(\varepsilon_c)=0.3595'),
    ('α = 1.7945', r'\alpha=1.7945'),
    ('δ_s = 0.5573', r'\delta_s=0.5573'),
    ('n1 = 1.5 > n2 = 1', r'n_1=1.5>n_2=1'),
    ('arcsin(1/1.5) = 41.81', r'\arcsin(1/1.5)=41.81'),
    ('n2 = 3', r'n_2=3'),
    ('η2 = 502.3', r'\eta_2=502.3'),
    ('n1 = 1', r'n_1=1'),
    ('n2 = 1', r'n_2=1'),
    ('n1 = 1.5', r'n_1=1.5'),
    ('n2/n1', r'n_2/n_1'),
    ('η2/η1', r'\eta_2/\eta_1'),
    ('|Γ| = 1', r'|\Gamma|=1'),
    ('T = 0', r'T=0'),
    ('R + T = 1', r'R+T=1'),
    ('Γ = 0', r'\Gamma=0'),
    ('Γ = −۱', r'\Gamma=-1'),
    ('Γ = −1', r'\Gamma=-1'),
    ('τ = 0', r'\tau=0'),
    ('E_0 = ۱', r'E_0=1'),
    ('sigma = 0', r'\sigma=0'),
    ('sigma1 = 0', r'\sigma_1=0'),
    ('6e-16', r'6\times10^{-16}'),
    ('۱۰⁴', r'10^{4}'),
    ('۱۰⁹', r'10^{9}'),
    ('λ1/2', r'\lambda_1/2'),
    ('tan δ', r'\tan\delta'),
    ('k_z1', r'k_{z1}'),
    ('k_z', r'k_z'),
    ('k_x', r'k_x'),
    ('θ_i', r'\theta_i'),
    ('θ_t', r'\theta_t'),
    ('θ_r', r'\theta_r'),
    ('θ_B', r'\theta_B'),
    ('θ_c', r'\theta_c'),
    ('δ_s', r'\delta_s'),
    ('eps_c', r'\varepsilon_c'),
    ('eps_r', r'\varepsilon_r'),
    ('mu_r', r'\mu_r'),
    ('η0', r'\eta_0'),
    ('η1', r'\eta_1'),
    ('η2', r'\eta_2'),
    ('ε0', r'\varepsilon_0'),
    ('n1', r'n_1'),
    ('n2', r'n_2'),
    ('λ1', r'\lambda_1'),
]

SYMBOLS = {
    'Γ': r'\Gamma', 'τ': r'\tau', 'θ': r'\theta', 'η': r'\eta', 'α': r'\alpha',
    'δ': r'\delta', 'λ': r'\lambda', 'σ': r'\sigma', 'ω': r'\omega',
    'ε': r'\varepsilon', 'μ': r'\mu', 'ρ': r'\rho', 'φ': r'\varphi',
    'Δ': r'\Delta', 'Σ': r'\Sigma',
    '√': r'\surd', '∠': r'\angle', '−': r'-', '±': r'\pm', '∝': r'\propto',
    '·': r'\cdot', '×': r'\times',
    '₀': r'_0', '₁': r'_1', '₂': r'_2',
    '⁰': r'^0', '¹': r'^1', '²': r'^2', '⁴': r'^4', '⁶': r'^6', '⁹': r'^9',
    '⁻': r'^-',
}

# GUI / file identifiers stay as monospace Latin, not math
CODE_IDS = ['run_lab', 'test_core', 'smoke_gui', 'fuzz_probe', 'gen_report_figures',
            'gen_guide_figures', 'build_guide_tex', 'compile_guide_tex',
            'em_constants', 'em_defaults', 'em_solve', 'em_fields',
            'em_standing_wave', 'em_angle_sweep', 'EM_VirtualLab',
            'sigma1', 'sigma2', 'sigma', 'README.md', 'VALIDATION.md',
            'THEORY_MAP.md', 'STATUS.md', 'CONTRACT.md']


def texify(s):
    """Persian prose -> LaTeX, with every technical symbol in math mode.

    Formula and symbol replacements are stashed as placeholders BEFORE the
    LaTeX escaping pass, so the inserted math is never escaped, and restored
    afterwards.  Longest patterns first so full formulas win over single
    symbols.
    """
    store = []

    def put(latex, math=True):
        # placeholders live in the Unicode private-use area: they contain no
        # digits or Latin letters, so the Latin-run pass below cannot corrupt
        # them (a numeric placeholder would be swallowed by that regex).
        store.append(('$%s$' % latex) if math else latex)
        return '\ue000' + chr(0xE001 + len(store) - 1) + '\ue000'

    for pat, latex in FORMULAS:
        if pat in s:
            s = s.replace(pat, put(latex))
    for ch, latex in SYMBOLS.items():
        if ch in s:
            s = s.replace(ch, put(latex))
    for ident in CODE_IDS:
        if ident in s:
            s = s.replace(ident, put(r'\lr{\texttt{%s}}' % ident.replace('_', r'\_'),
                                     math=False))
    # B Nazanin lacks U+0654 (hamza above) but has U+06C0 (heh with hamza),
    # which is the same Persian letter - use it so "نسخهٔ" does not turn into
    # a rectangle.
    s = s.replace('ه\u0654', '\u06c0').replace('\u0654', '')
    # B Nazanin has no em-dash glyph either, so the dash must come from the
    # Latin font (a bare --- would still be missing in the Persian font).
    s = s.replace('—', put(r'\lr{---}', math=False))

    # B Nazanin has NO Latin letters: every Latin run must be typeset with the
    # Latin font through XePersian's \lr{}, otherwise XeTeX emits
    # "Missing character" and the PDF shows little rectangles.
    latin = re.compile(r"[A-Za-z][A-Za-z0-9\.\,\-\_\+\:/\(\)\[\]'\"]*"
                       r"(?:[ ]+[A-Za-z0-9][A-Za-z0-9\.\,\-\_\+\:/\(\)\[\]'\"]*)*")
    s = latin.sub(lambda m: put(r'\lr{%s}' % esc(m.group(0)), math=False), s)

    s = esc(s)
    for i, val in enumerate(store):
        s = s.replace('\ue000' + chr(0xE001 + i) + '\ue000', val)
    return s


def fa_num(n):
    """Keep the digits Latin (Times) - unambiguous next to the formulas."""
    return str(n)


L = []          # lines of the .tex file
def w(x=''):
    L.append(x)


def sec(title, label=None):
    w()
    w('\\section{%s}' % texify(title))
    if label:
        w('\\label{%s}' % label)


def sub(title):
    w()
    w('\\subsection{%s}' % texify(title))


def par(text):
    w()
    w(texify(text))


def items(lst):
    w('\\begin{itemize}[rightmargin=1.2em,itemsep=2pt,topsep=3pt,label={$\\bullet$}]')
    for it in lst:
        w('  \\item %s' % texify(it))
    w('\\end{itemize}')


def fig(name, caption, width='0.98\\textwidth'):
    w('\\begin{figure}[H]')
    w('  \\centering')
    # bare file name: \graphicspath already points at ../figures/
    w('  \\includegraphics[width=%s]{%s}' % (width, name))
    w('  \\caption{%s}' % texify(caption))
    w('\\end{figure}')


def table(caption, header, rows, colspec=None, small=True, label=None):
    n = len(header)
    if colspec is None:
        colspec = '|' + '|'.join(['p{%scm}' % round(16.4 / n, 1)] * n) + '|'
    w('\\begin{table}[H]')
    w('  \\centering')
    if small:
        w('  \\small')
    w('  \\caption{%s}' % texify(caption))
    if label:
        w('  \\label{%s}' % label)
    w('  \\begin{tabular}{%s}' % colspec)
    w('    \\hline')
    w('    ' + ' & '.join('\\textbf{%s}' % texify(h) for h in header) + ' \\\\')
    w('    \\hline')
    for r in rows:
        w('    ' + ' & '.join(texify(str(c)) for c in r) + ' \\\\')
        w('    \\hline')
    w('  \\end{tabular}')
    w('\\end{table}')


# ------------------------------------------------------------------- preamble
w(r'\documentclass[12pt,a4paper]{article}')
w(r'\usepackage{amsmath,amssymb}')
w(r'\usepackage{graphicx}')
w(r'\usepackage{booktabs}')
w(r'\usepackage{longtable}')
w(r'\usepackage{array}')
w(r'\usepackage{tabularx}')
w(r'\usepackage{float}')
w(r'\usepackage{caption}')
w(r'\usepackage{xcolor}')
w(r'\usepackage{geometry}')
w(r'\geometry{a4paper,top=2.2cm,bottom=2.2cm,left=1.8cm,right=1.8cm}')
w(r'\usepackage{fancyhdr}')
w(r'\usepackage{enumitem}')
w(r'\usepackage{titlesec}')
w(r'\usepackage[hidelinks]{hyperref}')
w(r'\usepackage{xepersian}')
w()
w(r'% ---- fonts: B Nazanin for Persian, Times New Roman for Latin ------------')
w(r'\settextfont[Scale=1.10]{B Nazanin}')
w(r'\setlatintextfont[Scale=1.00]{Times New Roman}')
w(r'\setdigitfont[Scale=1.00]{Times New Roman}')
w()
w(r'% caption setup must come AFTER xepersian: bidi resets it otherwise')
w(r'\captionsetup{font=small,labelfont=bf,skip=6pt,justification=justified,singlelinecheck=false}')
w(r'\captionsetup[figure]{position=below}')
w(r'\captionsetup[table]{position=above}')
w()
w(r'\linespread{1.35}')
w(r'\setlength{\parindent}{0pt}')
w(r'\setlength{\parskip}{5pt}')
w(r'\titleformat{\section}{\Large\bfseries\color{blue!35!black}}{\thesection}{0.6em}{}')
w(r'\titleformat{\subsection}{\large\bfseries\color{blue!25!black}}{\thesubsection}{0.5em}{}')
w(r'\pagestyle{fancy}')
w(r'\fancyhf{}')
w(r'\fancyfoot[C]{\thepage}')
w(r'\fancyhead[R]{\small آزمایشگاه مجازی امواج الکترومغناطیسی}')
w(r'\renewcommand{\headrulewidth}{0.4pt}')
w(r'\renewcommand{\figurename}{شکل}')
w(r'\renewcommand{\tablename}{جدول}')
w(r'\renewcommand{\contentsname}{فهرست مطالب}')
w(r'\renewcommand{\listfigurename}{فهرست شکل‌ها}')
w(r'\DeclareGraphicsExtensions{.png,.pdf,.jpg}')
w(r'\graphicspath{{../figures/}{figures/}{./}}')   # compiled from docs/
w()
w(r'\begin{document}')
w()

# ------------------------------------------------------------------ title page
w(r'\begin{titlepage}')
w(r'  \centering')
w(r'  \vspace*{2.5cm}')
w(r'  {\Huge\bfseries آزمایشگاه مجازی امواج الکترومغناطیسی\par}')
w(r'  \vspace{0.6cm}')
w(r'  {\LARGE\bfseries \lr{EM Virtual Lab}\par}')
w(r'  \vspace{1.6cm}')
w(r'  {\Large راهنمای کاربر و توضیح تمام بخش‌های برنامه\par}')
w(r'  \vspace{0.5cm}')
w(r'  {\large برخورد موج تخت الکترومغناطیسی با مرز دو محیط\par}')
w(r'  \vspace{2.2cm}')
w(r'  {\large درس: میدان‌ها و امواج\par}')
w(r'  \vspace{0.4cm}')
w(r'  {\large پیاده‌سازی: \lr{MATLAB} (نسخهٔ \lr{R2021a} یا جدیدتر، بدون جعبه‌ابزار)\par}')
w(r'  \vspace{2.0cm}')
w(r'  \begin{tabular}{p{6cm}p{6cm}}')
w(r'    \hline')
w(r'    نام دانشجو: & شمارهٔ دانشجویی: \\[0.9cm]')
w(r'    \hline')
w(r'    تاریخ: & امضا: \\[0.9cm]')
w(r'    \hline')
w(r'  \end{tabular}')
w(r'  \vfill')
w(r'  {\small نسخۀ سند ۱ \lr{---} آبان ۱۴۰۵\par}')
w(r'\end{titlepage}')
w()

# -------------------------------------------------------------- front matter
w(r'\tableofcontents')
w(r'\newpage')
w(r'\listoffigures')
w(r'\newpage')

# -------------------------------------------------------------------- section 1
sec('این برنامه چه می‌کند')
par('این برنامه یک آزمایشگاه مجازی تعاملی است: موج تخت الکترومغناطیسی به مرز میان دو '
    'محیط می‌تابد و برنامه میدان‌های الکتریکی و مغناطیسی، ضرایب بازتاب و عبور، موج ایستا، '
    'موج میرا در بازتاب کلی و رفتار رسانای کامل را نشان می‌دهد. همهٔ اعداد از روابط درسی '
    'محاسبه می‌شوند و در تب «نتایج و تئوری» هم عدد و هم فرمول نمایش داده می‌شود.')
par('قراردادها: محیط ۱ در z < 0 و محیط ۲ در z > 0؛ صفحهٔ برخورد x-z و y عمود بر آن؛ '
    'دامنهٔ میدان فرودی E_0 = ۱ ولت بر متر؛ وابستگی زمانی به شکل exp(+jωt) و بنابراین '
    'فازورها به شکل exp(-j k·r). برای اینکه محیط ۱ در تصویرها بالا دیده شود، محور z '
    'معکوس رسم می‌شود.')
par('همهٔ خواسته‌های پروژه (R1 تا R12) در برنامه پوشش داده شده‌اند؛ نگاشت هر مورد به محل '
    'دقیق آن در برنامه در فایل README.md آمده است.')

# -------------------------------------------------------------------- section 2
sec('اجرای برنامه و آزمون‌ها')
par('سه گام اجرا:')
w(r'\begin{latin}')
w(r'\begin{verbatim}')
w(r'cd path\to\EM_VirtualLab')
w(r'run_lab')
w(r'\end{verbatim}')
w(r'\end{latin}')
par('پنجرهٔ برنامه با پنج تب باز می‌شود: Media، Field Animation، Standing Wave، '
    'Coefficients vs Angle و Results and Theory. پیشنهاد می‌شود ابتدا در تب Media '
    'محیط‌ها را تنظیم کنید و بعد به تب‌های دیگر بروید.')
par('آزمون‌های صحت (اختیاری، ولی برای اطمینان از درستی نتایج توصیه می‌شود):')
w(r'\begin{latin}')
w(r'\begin{verbatim}')
w(r'cd tests')
w(r'test_core        % T1..T12 physics of the core solver')
w(r'smoke_gui        % 49 GUI checks, headless')
w(r'fuzz_probe       % sweeps 106 states looking for numerical defects')
w(r'\end{verbatim}')
w(r'\end{latin}')
par('نکتهٔ مهم: اگر فایل‌های برنامه را تغییر دادید، پنجرهٔ باز را ببندید و برنامه را دوباره '
    'اجرا کنید؛ متلب نسخهٔ قدیمی فایل را در حافظه نگه می‌دارد. برای بستن پنجرهٔ گیرکرده '
    'در پنجرهٔ فرمان متلب بنویسید:')
w(r'\begin{latin}')
w(r'\begin{verbatim}')
w(r"delete(findall(groot,'Type','figure'))")
w(r'\end{verbatim}')
w(r'\end{latin}')

# -------------------------------------------------------------------- section 3
sec('ساختار پوشه‌ها و فایل‌ها')
table('ساختار پروژه', ['مسیر', 'توضیح'], [
    ['run_lab.m', 'دستور اجرای برنامه'],
    ['core/em_constants.m', 'ثابت‌های فیزیکی (تنها جای تعریف آن‌ها)'],
    ['core/em_defaults.m', 'مقادیر پیش‌فرض و تمام اعتبارسنجی ورودی‌ها'],
    ['core/em_solve.m', 'اسنل، ضرایب فرنل، بروستر، بحرانی، PEC و محیط اتلافی'],
    ['core/em_fields.m', 'فازورهای سه موج و میدان کل'],
    ['core/em_standing_wave.m', 'پوش موج ایستا، گره و شکم، SWR، جریان و بار سطحی'],
    ['core/em_angle_sweep.m', 'ضرایب برحسب زاویه برای دو قطبش'],
    ['gui/EM_VirtualLab.m', 'کل رابط گرافیکی'],
    ['tests/', 'آزمون‌ها، تولید شکل‌ها و اسکرین‌شات‌ها'],
    ['docs/', 'قرارداد، وضعیت، نقشهٔ نظری، راهنما، گزارش و همین سند'],
    ['figures/', 'شکل‌ها و تصاویر رابط گرافیکی'],
], colspec='|p{5.2cm}|p{11.2cm}|')

# -------------------------------------------------------------------- section 4
sec('تب Media — شش ثابت محیط و شش حالت نمونه')
par('در این تب هر محیط با ثابت‌های الکترومغناطیسی خود تعریف می‌شود. برای هر محیط سه '
    'کادر وجود دارد: گذردهی نسبی eps_r، تراوایی نسبی mu_r و رسانندگی sigma برحسب '
    'زیمنس بر متر. مقدار sigma = 0 یعنی محیط بدون اتلاف.')
table('رنج مجاز ورودی‌ها', ['کمیت', 'معنا', 'رنج مجاز', 'پیش‌فرض'], [
    ['eps_r', 'گذردهی نسبی', 'صفر تا ۱۰⁴', 'محیط ۱: ۱ — محیط ۲: ۲٫۲۵'],
    ['mu_r', 'تراوایی نسبی', 'صفر تا ۱۰⁴', '۱'],
    ['sigma', 'رسانندگی', '۰ تا ۱۰⁹ S/m', '۰'],
    ['f', 'بسامد', '۱ مگاهرتز تا ۱۰۰ گیگاهرتز', '۱ گیگاهرتز'],
    ['θ_i', 'زاویهٔ فرود', '۰ تا ۸۹٫۹ درجه', '۰'],
], colspec='|p{2.2cm}|p{4.4cm}|p{5.2cm}|p{4.6cm}|')
par('سه کنترل کمکی: منوی «مادهٔ آماده» برای پرکردن سریع محیط ۲ (هوا، شیشه، تفلون، آب، '
    'FR-4 با اتلاف، آب دریا و فریت مغناطیسی)؛ دکمهٔ «Swap media» برای جابه‌جایی دو محیط '
    '(راه رسیدن به بازتاب کلی)؛ و منوی «Simulation mode» برای انتخاب دی‌الکتریک یا '
    'رسانای کامل برای محیط ۲.')
par('کادر گزارش پایین تب، برای هر محیط مقدارهای محاسبه‌شده را نشان می‌دهد: گذردهی مختلط '
    'eps_c، ضریب شکست n، امپدانس ذاتی η، طول موج λ، ثابت تضعیف α و در محیط اتلافی '
    'تانژانت اتلاف tan δ و عمق پوست δ_s؛ و در پایان نسبت n2/n1 و η2/η1 و زاویهٔ بحرانی یا '
    'بروستر در صورت وجود. با این کادر می‌توانید فوراً بررسی کنید که ورودی‌ها همان چیزی را '
    'می‌دهند که از تئوری انتظار دارید.')

sub('حالت ۱ — هوا به شیشه (دی‌الکتریک بدون اتلاف)')
par('حالت پیش‌فرض: محیط ۱ هوا و محیط ۲ شیشه با eps_r = 2.25. ضریب شکست محیط ۲ برابر ۱٫۵ '
    'و امپدانس آن ۲۵۱٫۱۵ اهم می‌شود. زاویهٔ بروستر برای قطبش TM برابر ۵۶٫۳۱ درجه است، ولی '
    'زاویهٔ بحرانی وجود ندارد چون n1 < n2.')
fig('guide_media_default.png',
    'تب Media در حالت هوا به شیشه: شش کادر ثابت‌ها، منوی مادهٔ آماده، دکمهٔ جابه‌جایی '
    'محیط‌ها و کادر گزارش.')

sub('حالت ۲ — شیشه به هوا پس از جابه‌جایی: زاویهٔ بحرانی ظاهر می‌شود')
par('با زدن دکمهٔ «Swap media» مقادیر دو محیط جابه‌جا می‌شوند: محیط ۱ شیشه و محیط ۲ هوا. '
    'اکنون n1 = 1.5 > n2 = 1 و زاویهٔ بحرانی برابر arcsin(1/1.5) = 41.81 درجه است؛ دکمهٔ '
    '«Go to critical angle» روشن می‌شود و در کادر گزارش مقدار زاویهٔ بحرانی نوشته می‌شود. '
    'برای زاویه‌های بزرگ‌تر از θ_c بازتاب کلی رخ می‌دهد: |Γ| = 1 و T = 0.')
fig('guide_media_tir.png',
    'همان تب پس از جابه‌جایی محیط‌ها: n1 = 1.5 و n2 = 1 و زاویهٔ بحرانی ۴۱٫۸۱ درجه.')

sub('حالت ۳ — محیط ۲ با اتلاف (FR-4 با sigma = 0.02 S/m)')
par('با مثبت‌شدن رسانندگی، محیط اتلافی می‌شود و برنامه با گذردهی مختلط کار می‌کند: '
    'eps_c = eps_r − jσ/(ωε0). برای FR-4 در ۱ گیگاهرتز: Re(eps_c) = 4.4، '
    '−Im(eps_c) = 0.3595، تانژانت اتلاف 0.0817، ثابت تضعیف α = 1.7945 بر متر و عمق پوست '
    'δ_s = 0.5573 متر. موج عبوری به‌صورت exp(−αz) میرا می‌شود و توان آن با exp(−۲αz) '
    'کاهش می‌یابد. در مرز همچنان R + T = 1 برقرار است، چون اتلاف درون محیط رخ می‌دهد نه '
    'روی مرز. محیط اتلافی بازتاب کلی واقعی و زاویهٔ بروستر دقیق ندارد (برنامه «none» '
    'گزارش می‌کند).')
fig('guide_media_lossy.png',
    'تب Media برای FR-4 با اتلاف: تانژانت اتلاف و عمق پوست در کادر گزارش دیده می‌شود و '
    'گذردهی و ضریب شکست به‌صورت مختلط نمایش داده می‌شوند.')

sub('حالت ۴ — اتلاف شدید: آب دریا با sigma = 4 S/m')
par('آب دریا با eps_r = 81 و σ = 4 S/m نمونهٔ یک محیط بسیار اتلافی است: تانژانت اتلاف '
    'حدود ۰٫۸۹ و عمق پوست چند سانتی‌متر می‌شود، یعنی موج عملاً در لایهٔ نازکی نزدیک سطح '
    'جذب می‌شود. این حالت تفاوت «محیط اتلافی» و «بازتاب کلی» را روشن می‌کند: در بازتاب '
    'کلی هیچ توانی وارد محیط ۲ نمی‌شود، ولی در محیط اتلافی توان وارد می‌شود و درون آن '
    'جذب می‌گردد.')
fig('guide_media_sea.png', 'آب دریا در ۱ گیگاهرتز: تانژانت اتلاف بزرگ و عمق پوست کوچک.')

sub('حالت ۵ — محیط مغناطیسی با mu_r = 4: بروستر به قطبش TE می‌رود')
par('با بزرگ‌تر شدن تراوایی نسبی محیط ۲، روابط n = √(eps_r·mu_r) و η = η0√(mu_r/eps_r) '
    'تغییر می‌کنند و جای زاویهٔ بروستر عوض می‌شود. برای eps_r = 2.25 و mu_r = 4: '
    'n2 = 3 و η2 = 502.3 اهم. در این حالت زاویهٔ بروستر برای قطبش TE در ۴۳٫۰۹ درجه وجود '
    'دارد و برای TM وجود ندارد — برعکس حالت غیرمغناطیسی که فقط TM زاویهٔ بروستر دارد. '
    'برچسب دکمهٔ بروستر همین وضعیت را نشان می‌دهد.')
fig('guide_media_magnetic.png',
    'محیط ۲ مغناطیسی با mu_r = 4: n2 = 3 و η2 = 502.3 اهم و یادآوری زاویهٔ بروستر '
    'قطبش TE.')
table('فرمول‌های کلیدی محیط', ['کمیت', 'رابطه'], [
    ['ضریب شکست', 'n = √(eps_r·mu_r)'],
    ['امپدانس ذاتی', 'η = η0 √(mu_r/eps_r)'],
    ['گذردهی مختلط', 'eps_c = eps_r − jσ/(ωε0)'],
    ['تانژانت اتلاف', 'tan δ = σ/(ωε0 eps_r)'],
    ['ثابت تضعیف و عمق پوست', 'α = −Im(k_z) ، δ_s = 1/α'],
    ['میرایی میدان و توان', '|E| ∝ exp(−αz) ، توان ∝ exp(−۲αz)'],
], colspec='|p{6.2cm}|p{10.2cm}|')

sub('حالت ۶ — رسانای کامل (PEC)')
par('با انتخاب «Perfect conductor (PEC)» از منوی Simulation mode، محیط ۲ رسانای کامل '
    'می‌شود: کادرهای محیط ۲ غیرفعال می‌شوند، Γ = −۱ و τ = ۰، میدان در z > 0 صفر است و '
    'پوش میدان الکتریکی در محیط ۱ به شکل ۲|sin(k_z1 z)| با گره روی سطح ظاهر می‌شود. '
    'برنامه جریان سطحی |J_s| = ۲|H_i|cosθ_i برای TE یا |J_s| = ۲|H_i| برای TM و بار '
    'سطحی ρ_s = ۲ε0 eps_r sinθ_i در قطبش TM را نیز گزارش می‌کند.')
fig('guide_media_pec.png', 'حالت PEC: کادرهای محیط ۲ غیرفعال و میدان عبوری صفر است.')

# -------------------------------------------------------------------- section 5
sec('تب Field Animation — نقشه‌های میدان و انیمیشن')
par('در این تب دو نقشهٔ رنگی کنار هم رسم می‌شود: میدان الکتریکی در چپ و میدان مغناطیسی '
    'در راست. محور z معکوس است تا محیط ۱ بالا و محیط ۲ پایین دیده شود. مرز z = 0 با خط '
    'مشکی و نرمال با خط‌چین نشان داده می‌شود و نام هر محیط روی تصویر نوشته شده است.')
par('نوار ابزار بالای تب سه چک‌باکس Incident و Reflected و Transmitted دارد (اگر هر سه '
    'تیک داشته باشند میدان کل رسم می‌شود)، گزینهٔ افزودن بردارهای میدان، منوهای انتخاب '
    'مؤلفهٔ رسم‌شده در هر نقشه و کادر اندازهٔ پنجرهٔ نمایش برحسب طول موج فضای آزاد.')
par('بالای نقشه‌ها یک بلوک متنی جهت‌های انتشار و زاویه‌ها را گزارش می‌کند (در PEC عبارت '
    '«no transmitted wave» و در بازتاب کلی «evanescent» همراه با α و δ) و زیر نقشه‌ها '
    'نوار وضعیت سه‌خطی است: فاز و بسامد و طول موج و رژیم؛ سپس θ_i و θ_r و θ_t؛ و در خط '
    'سوم بیشینهٔ همان مؤلفه‌هایی که رسم شده‌اند.')
fig('fig6_gui_fields_dielectric.png',
    'تب Field Animation در حالت هوا به شیشه با فرود عمودی و قطبش TE؛ مؤلفه‌های E_y و H_x '
    'رسم شده‌اند.')
fig('fig6_gui_fields_tir.png',
    'بازتاب کلی (شیشه به هوا، ۶۰ درجه): میدان میرا در محیط ۲ و گزارش α و δ در بلوک متن.')
fig('guide_field_lossy.png',
    'محیط ۲ اتلافی (FR-4): موج عبوری به‌سرعت میرا می‌شود و برچسب محیط ۲ مقدارهای '
    'eps_r و mu_r و sigma و ضریب شکست مختلط را نشان می‌دهد.')
fig('fig6_gui_fields_pec_tm.png',
    'PEC با قطبش TM: مؤلفه‌های غالب E_x و H_y هستند و نوار وضعیت بیشینهٔ همان دو مؤلفه '
    'را گزارش می‌کند.')

# -------------------------------------------------------------------- section 6
sec('تب Standing Wave — موج ایستا، گره و شکم')
par('دو محور، پوش میدان (خط پر مشکی) و مقدار لحظه‌ای (خط آبی) را برحسب z نشان می‌دهند؛ '
    'خط نقطه‌چین مرز، دایرهٔ قرمز گره‌ها و مربع سبز شکم‌ها هستند. پوش، اندازهٔ فازور '
    'میدان است و در محیط ۱ بدون اتلاف دقیقاً همان رابطهٔ کتاب |1 ± Γ exp(2j k_z1 z)| '
    'می‌شود. خط آبی مقدار واقعی میدان در لحظهٔ جاری است و همیشه داخل پوش می‌ماند.')
items([
    'در محیط ۱ موج ایستای جزئی دیده می‌شود و نسبت موج ایستا SWR = (۱+|Γ|)/(۱−|Γ|) '
    'گزارش می‌شود.',
    'در محیط ۲ موج عبوری رسم می‌شود: پوش ثابت برای محیط بدون اتلاف و کاهش نمایی در '
    'بازتاب کلی یا محیط اتلافی.',
    'جدول زیر نمودارها مکان چند گره و شکم اول را برحسب متر و برحسب λ1 می‌دهد.',
    'در حالت PEC گره‌های میدان الکتریکی روی سطح و در فاصله‌های λ1/2 قرار دارند و SWR '
    'بی‌نهایت می‌شود.',
    'اگر محیط ۱ اتلافی باشد موج ایستای متناوب تشکیل نمی‌شود و SWR تعریف‌نشده گزارش می‌شود.',
])
fig('fig6_gui_standing_pec.png',
    'حالت PEC: پوش ۲|sin(k_z1 z)|، گره‌ها روی سطح و در فاصله‌های λ1/2، SWR بی‌نهایت و '
    'گزارش جریان سطحی.')
fig('guide_standing_lossy.png',
    'محیط ۲ اتلافی: پوش درون محیط ۲ کاهش نمایی دارد و عمق پوست گزارش می‌شود.')

# -------------------------------------------------------------------- section 7
sec('تب Coefficients vs Angle — ضرایب برحسب زاویه')
par('چهار نمودار، اندازهٔ Γ، فاز Γ، اندازهٔ τ و فاز τ را برحسب زاویهٔ فرود از ۰ تا ۸۹٫۹ '
    'درجه نشان می‌دهند؛ قطبش TE با خط پر و TM با خط‌چین و قطبش انتخاب‌شده ضخیم‌تر است. '
    'خط عمودی سبز زاویهٔ بروستر و خط بنفش زاویهٔ بحرانی را علامت می‌زند و خط مشکی زاویهٔ '
    'جاری را نشان می‌دهد. با منوی بالای تب می‌توان به‌جای دامنه، توان‌های R و T را دید. '
    'در جایی که دامنه صفر است خط فاز شکسته می‌شود چون فاز در آن نقطه تعریف نشده است.')
fig('fig6_gui_coefficients_brewster_tm.png',
    'قطبش TM: در زاویهٔ بروستر ۵۶٫۳۱ درجه اندازهٔ Γ به صفر می‌رسد.')
fig('fig6_gui_coefficients_tir.png',
    'شیشه به هوا: پس از زاویهٔ بحرانی ۴۱٫۸۱ درجه اندازهٔ Γ برای هر دو قطبش به ۱ می‌رسد و '
    'T صفر می‌شود.')
fig('fig3_power_balance.png', 'تأیید R + T = 1 در هر دو جهت انتشار.')

# -------------------------------------------------------------------- section 8
sec('تب Results and Theory — نتایج عددی و روابط')
par('ستون چپ پنل متنی مونواسپیس با بلوک‌های پارامترها، محیط‌ها، هندسه، ضرایب، نتایج موج '
    'ایستا و پارامترهای محاسباتی است. ستون راست همان روابط را به‌صورت فرمول نمایش می‌دهد '
    'تا هنگام ارائهٔ شفاهی بتوانید هر عدد را به رابطهٔ آن نسبت دهید.')
fig('fig6_gui_results.png', 'تب Results and Theory: پنل اعداد و پنل فرمول‌ها.')
fig('guide_results_lossy.png',
    'همان تب برای محیط اتلافی: بلوک‌های گذردهی مختلط، ثابت تضعیف، تانژانت اتلاف و عمق '
    'پوست به اعداد اضافه می‌شوند.')

# -------------------------------------------------------------------- section 9
sec('جدول کامل کنترل‌ها')
table('کنترل‌های برنامه', ['کنترل', 'محل', 'کار'], [
    ['Simulation mode', 'پنل چپ', 'انتخاب محیط ۲: دی‌الکتریک یا رسانای کامل'],
    ['خلاصهٔ محیط‌ها', 'پنل چپ', 'نمایش n1 و n2 و η1 و η2 و وضعیت اتلاف یا مغناطیسی'],
    ['Polarization', 'پنل چپ', 'انتخاب قطبش افقی (TE) یا عمودی (TM)'],
    ['Frequency', 'پنل چپ', 'بسامد با واحد مگاهرتز یا گیگاهرتز'],
    ['Incidence angle', 'پنل چپ', 'زاویهٔ فرود با کادر عددی و لغزنده'],
    ['Normal incidence', 'پنل چپ', 'تنظیم زاویه روی صفر درجه'],
    ['Brewster / critical', 'پنل چپ', 'پرش به زاویهٔ بروستر یا بحرانی، اگر وجود داشته باشد'],
    ['Play / Pause', 'پنل چپ', 'شروع و توقف انیمیشن'],
    ['Speed و Phase', 'پنل چپ', 'سرعت انیمیشن و فاز لحظه‌ای'],
    ['Presets', 'پنل چپ', 'ده سناریوی آماده'],
    ['Reset to defaults', 'پنل چپ', 'بازگرداندن همهٔ مقادیر به حالت اولیه'],
    ['eps_r و mu_r و sigma', 'تب Media', 'شش ثابت محیط ۱ و ۲'],
    ['Quick material', 'تب Media', 'پرکردن سریع محیط ۲ با مادهٔ آماده'],
    ['Swap media 1<->2', 'تب Media', 'جابه‌جایی دو محیط برای رسیدن به بازتاب کلی'],
    ['Incident و Reflected و Transmitted', 'نوار ابزار تب اول', 'انتخاب موج‌های نمایش‌داده‌شده'],
    ['E map و H map', 'نوار ابزار تب اول', 'انتخاب مؤلفهٔ رسم‌شده در هر نقشه'],
    ['Window', 'نوار ابزار تب اول', 'اندازهٔ پنجرهٔ نمایش برحسب طول موج'],
    ['R و T یا اندازهٔ ضرایب', 'تب ضرایب', 'تغییر کمیت رسم‌شده در چهار نمودار'],
], colspec='|p{5.0cm}|p{3.6cm}|p{7.8cm}|')
par('چرا بعضی دکمه‌ها غیرفعال‌اند؟ برچسب خود دکمه دلیل را می‌گوید. زاویهٔ بحرانی تنها با '
    'دو محیط بدون اتلاف و شرط n1 > n2 وجود دارد؛ برای رسیدن به آن دکمهٔ جابه‌جایی '
    'محیط‌ها را بزنید. زاویهٔ بروستر در محیط بدون اتلاف و غیرمغناطیسی فقط برای قطبش TM '
    'وجود دارد و در محیط مغناطیسی ممکن است به قطبش TE منتقل شود. نگه‌داشتن نشانگر روی '
    'دکمه همین توضیح را نشان می‌دهد.')

# ------------------------------------------------------------------- section 10
sec('روابط فیزیکی که برنامه حل می‌کند')
table('روابط اصلی', ['کمیت', 'رابطه'], [
    ['قانون اسنل', 'n1 sin θ_i = n2 sin θ_t'],
    ['پایستگی عدد موج مماسی', 'k_x = k1 sin θ_i = k2 sin θ_t'],
    ['قطبش TE', 'Γ = (η2 cosθ_i − η1 cosθ_t)/(η2 cosθ_i + η1 cosθ_t) ، τ = 1 + Γ'],
    ['قطبش TM', 'Γ = (η2 cosθ_t − η1 cosθ_i)/(η2 cosθ_t + η1 cosθ_i) ، 1 + Γ = τ cosθ_t/cosθ_i'],
    ['توان', 'R = |Γ|² ، T = |τ|²(η1/η2) Re(cosθ_t)/cosθ_i ، R + T = 1'],
    ['زاویهٔ بروستر', 'θ_B = arctan(n2/n1) برای TM در محیط بدون اتلاف و غیرمغناطیسی'],
    ['زاویهٔ بحرانی', 'θ_c = arcsin(n2/n1) با شرط n1 > n2'],
    ['بازتاب کلی', 'cos θ_t = −j√((n1 sinθ_i/n2)² − 1)'],
    ['پوش موج ایستا', '|E_y| = |1 + Γ exp(2j k_z1 z)|'],
    ['نسبت موج ایستا', 'SWR = (1 + |Γ|)/(1 − |Γ|)'],
    ['رسانای کامل', 'Γ = −1 ، τ = 0 ، |J_s| = 2|H_i| cosθ_i (TE) یا 2|H_i| (TM)'],
], colspec='|p{4.6cm}|p{11.8cm}|')

# ------------------------------------------------------------------- section 11
sec('اعتبارسنجی: مقایسهٔ تحلیلی و عددی')
par('هر ردیف جدول زیر دو بار محاسبه شده است: یک بار از فرمول تحلیلی و یک بار از هستهٔ '
    'محاسباتی برنامه. ستون آخر را با محاسبهٔ دستی خودتان پر کنید. جدول کامل با ۳۷ ردیف '
    'در فایل docs/VALIDATION.md موجود است.')
rows = []
try:
    with open(os.path.join(DOCS, 'VALIDATION.md'), encoding='utf-8') as fh:
        for line in fh:
            if line.startswith('| ') and '---' not in line and 'analytic' not in line:
                cols = [c.strip() for c in line.strip().strip('|').split('|')]
                if len(cols) >= 4 and cols[0].isdigit():
                    rows.append([cols[0], cols[1], cols[2], cols[3], ''])
except FileNotFoundError:
    pass

w(r'\begin{longtable}{|p{0.8cm}|p{6.4cm}|p{3.4cm}|p{3.4cm}|p{2.4cm}|}')
w(r'  \caption{مقایسهٔ مقادیر تحلیلی و محاسبه‌شده (ستون آخر برای محاسبهٔ دستی)}\label{tab:val}\\')
w(r'  \hline')
w(r'  \textbf{\#} & \textbf{کمیت} & \textbf{تحلیلی} & \textbf{محاسبهٔ برنامه} & \textbf{دستی} \\')
w(r'  \hline')
w(r'  \endfirsthead')
w(r'  \hline')
w(r'  \textbf{\#} & \textbf{کمیت} & \textbf{تحلیلی} & \textbf{محاسبهٔ برنامه} & \textbf{دستی} \\')
w(r'  \hline')
w(r'  \endhead')
for r_ in rows:
    # five columns: #, quantity, analytic, computed, (empty) hand calculation
    w('  %s & %s & %s & %s & %s \\\\' % tuple([texify(x) for x in r_]))
    w('  \\hline')
w(r'\end{longtable}')
par('آنچه با اجرای واقعی تأیید شده است: آزمون‌های test_core یعنی T1 تا T12 همه PASS '
    'شده‌اند؛ از جمله شرط‌های مرزی روی آرایه‌های میدان با خطای کمتر از 6e-16، برابری '
    'R + T = 1، پیوستگی مؤلفهٔ z بردار پوینتینگ، میدان میرای بازتاب کلی، محیط اتلافی و '
    'محیط مغناطیسی. آزمون خودکار رابط گرافیکی ۴۹ بررسی را بدون خطا گذرانده و پویش ۱۰۶ '
    'حالتی هیچ خطای عددی پیدا نکرده است. اجرای رابط به‌صورت خودکار و بدون نمایش انجام شده؛ '
    'لطفاً یک‌بار خودتان برنامه را باز کنید و ظاهر و انیمیشن را ببینید.')

# ------------------------------------------------------------------- section 12
sec('عیب‌یابی و پرسش‌های متداول')
table('مشکل‌ها و راه‌حل‌ها', ['مشکل', 'راه‌حل'], [
    ['پنجره بسته نمی‌شود یا پس از تغییر فایل‌ها خطا می‌دهد',
     'متلب نسخهٔ قدیمی فایل را در حافظه دارد؛ در پنجرهٔ فرمان '
     'delete(findall(groot,\'Type\',\'figure\')) را اجرا کنید و سپس run_lab.'],
    ['دکمهٔ زاویهٔ بحرانی غیرفعال است',
     'زاویهٔ بحرانی فقط با n1 > n2 و دو محیط بدون اتلاف وجود دارد. در تب Media '
     'دکمهٔ Swap media را بزنید یا از پیش‌تنظیم بازتاب کلی استفاده کنید.'],
    ['دکمهٔ بروستر غیرفعال است',
     'در محیط غیرمغناطیسی زاویهٔ بروستر فقط برای TM است؛ برچسب دکمه می‌گوید زاویه برای '
     'کدام قطبش وجود دارد. در محیط مغناطیسی ممکن است برعکس شود.'],
    ['در تب موج ایستا SWR تعریف‌نشده است',
     'محیط ۱ اتلافی است؛ برای دیدن SWR مقدار sigma1 را صفر کنید.'],
    ['زاویهٔ ۹۰ درجه پذیرفته نمی‌شود',
     'در فرود مماسی cos θ_i صفر می‌شود و روابط T و فاصلهٔ گره‌ها تکین می‌شوند؛ بیشینه '
     '۸۹٫۹ درجه است.'],
    ['گره‌ای در تب موج ایستا نمی‌بینم',
     'اگر دو محیط یکسان باشند Γ = 0 است و موج بازتابی وجود ندارد؛ همچنین فرم بستهٔ '
     'گره‌ها فقط برای محیط ۱ بدون اتلاف معتبر است.'],
    ['انیمیشن کند یا سریع است',
     'سرعت با لغزندهٔ Speed تنظیم می‌شود و مستقل از بسامد واقعی است؛ زمان نمایش عمداً '
     'کند شده است.'],
    ['eps_r کوچک‌تر از یک وارد کردم',
     'برنامه می‌پذیرد ولی n < 1 یعنی سرعت فاز بیش از سرعت نور و چنین دی‌الکتریک غیرفعالی '
     'وجود ندارد؛ فقط برای مطالعهٔ پارامتری است.'],
], colspec='|p{5.6cm}|p{10.8cm}|')

# ------------------------------------------------------------------- section 13
sec('محدودیت‌های مدل')
items([
    'محیط‌ها همسان‌گرد و غیرمغناطیسی یا مغناطیسی با mu_r حقیقی هستند؛ اتلاف مغناطیسی مدل '
    'نشده است.',
    'محیط اتلافی زاویهٔ بروستر دقیق و بازتاب کلی واقعی ندارد و برنامه «none» گزارش می‌کند.',
    'اگر محیط ۱ اتلافی باشد SWR تعریف‌نشده است و مکان گره‌ها فقط به‌صورت عددی یافت می‌شود.',
    'برخورد مایل دوبعدی است؛ نمای سه‌بعدی پرتو و بردار پوینتینگ پیاده‌سازی نشده است.',
    'فاز انیمیشن گامی ثابت در هر فریم دارد و متناسب با زمان واقعی نیست.',
    'در حالت |Γ| = 1 مقدار SWR بی‌نهایت گزارش می‌شود.',
])

# ------------------------------------------------------------------- section 14
sec('پیوست: پرسش‌های ارائهٔ شفاهی')
par('پاسخ کوتاه این پرسش‌ها در فایل docs/THEORY_MAP.md آمده است.')
items([
    'چرا برای قطبش TE زاویهٔ بروستر وجود ندارد؟',
    'چرا علامت Γ در قطبش TM در زاویهٔ بروستر تغییر می‌کند؟',
    'در بازتاب کلی فاز Γ چقدر است و آیا توانی عبور می‌کند؟',
    'چرا موج میرا با پایستگی انرژی تناقض ندارد؟',
    'چرا باید شاخهٔ Im(cos θ_t) < 0 انتخاب شود؟',
    'چرا برای رسانای کامل Γ = −1 و τ = 0 است و جریان سطحی از کجا می‌آید؟',
    'چرا عدد موج مماسی در مرز پایسته است؟',
    'گره‌های میدان برای TE و TM روی رسانای کامل کجا هستند؟',
    'چرا در رابطهٔ T ضریب (η1/η2) cosθ_t/cosθ_i ظاهر می‌شود؟',
    'فاز انیمیشن چه نسبتی با زمان واقعی دارد؟',
    'چرا محیط اتلافی بازتاب کلی و زاویهٔ بروستر دقیق ندارد؟',
    'چرا در محیط اتلافی همچنان R + T = 1 است؟',
    'چرا در محیط مغناطیسی زاویهٔ بروستر به قطبش TE منتقل می‌شود؟',
])

w()
w(r'\end{document}')

def glyph_safety(tex):
    """Make every character renderable by B Nazanin outside math/Latin runs.

    B Nazanin has no bullet, no '<'/'>', no '#', no Persian decimal separator
    (U+066B) and no hamza-above (U+0654).  Math spans and \\lr{...} runs are
    left untouched because they are typeset with other fonts.
    """
    out = []
    i = 0
    n = len(tex)
    while i < n:
        ch = tex[i]
        if ch == '$':                      # copy a whole math span verbatim
            j = tex.find('$', i + 1)
            j = n if j < 0 else j + 1
            out.append(tex[i:j]); i = j; continue
        if tex.startswith('\\lr{', i):     # copy a whole \lr{...} run
            depth = 0
            j = i + 3
            while j < n:
                if tex[j] == '{':
                    depth += 1
                elif tex[j] == '}':
                    depth -= 1
                    if depth == 0:
                        j += 1
                        break
                j += 1
            out.append(tex[i:j]); i = j; continue
        if ch == '\u0654':                 # hamza above -> dropped (heh handled below)
            i += 1; continue
        if ch == '\u066b':                 # Persian decimal separator -> period
            out.append('.'); i += 1; continue
        if ch == '\u2022':                 # bullet -> math
            out.append(r'$\bullet$'); i += 1; continue
        if ch == '<':
            out.append(r'$<$'); i += 1; continue
        if ch == '>':
            out.append(r'$>$'); i += 1; continue
        if tex.startswith('\\#', i):      # escaped hash -> Latin font
            out.append(r'\lr{\#}'); i += 2; continue
        out.append(ch); i += 1
    s = ''.join(out)
    return s.replace('ه\u0654', '\u06c0')


tex = '\n'.join(L) + '\n'
tex = glyph_safety(tex)
with open(TEX, 'w', encoding='utf-8') as fh:
    fh.write(tex)
print('TEX written:', TEX, len('\n'.join(L)), 'chars')
