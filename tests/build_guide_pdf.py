#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Build the Persian (RTL) PDF user guide for EM Virtual Lab.

Creates docs/EM_VirtualLab_UserGuide_FA.docx with python-docx and exports it to
docs/EM_VirtualLab_UserGuide_FA.pdf through Microsoft Word (COM).

Run:  python build_guide_pdf.py
"""
import os
import re
import glob

from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FIGS = os.path.join(ROOT, 'figures')
DOCS = os.path.join(ROOT, 'docs')
FONT = 'B Nazanin'          # complex-script (Persian) face
LATIN = 'Times New Roman'    # Latin letters, digits and code


# --------------------------------------------------------------------------
# RTL helpers
# --------------------------------------------------------------------------
def _pPr(p):
    return p._p.get_or_add_pPr()


def rtl_par(doc, text='', size=12.5, bold=False, style=None, align='right',
            space_after=6, color=None, italic=False):
    """Paragraph with Hebrew/Persian paragraph direction (w:bidi) + RTL runs."""
    p = doc.add_paragraph(style=style)
    pPr = _pPr(p)
    pPr.append(OxmlElement('w:bidi'))
    p.alignment = {'right': WD_ALIGN_PARAGRAPH.RIGHT,
                   'center': WD_ALIGN_PARAGRAPH.CENTER,
                   'left': WD_ALIGN_PARAGRAPH.LEFT,
                   'justify': WD_ALIGN_PARAGRAPH.JUSTIFY}[align]
    p.paragraph_format.space_after = Pt(space_after)
    if text:
        r = p.add_run(text)
        r.font.size = Pt(size)
        r.bold = bold
        r.italic = italic
        r.font.name = LATIN
        if color:
            r.font.color.rgb = RGBColor(*color)
        rPr = r._element.get_or_add_rPr()
        rPr.append(OxmlElement('w:rtl'))
        rPr.rFonts.set(qn('w:cs'), FONT)
        rPr.rFonts.set(qn('w:ascii'), LATIN)
        rPr.rFonts.set(qn('w:hAnsi'), LATIN)
    return p


def heading(doc, text, level=1, new_page=True):
    # built-in Heading styles: required for a real (numbered) table of contents
    size = {1: 18, 2: 14.5, 3: 13}[level]
    p = doc.add_paragraph(style='Heading %d' % level)
    pPr = p._p.get_or_add_pPr()
    pPr.append(OxmlElement('w:bidi'))
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run(text)
    r.font.size = Pt(size)
    r.bold = True
    r.font.color.rgb = RGBColor(0x1F, 0x3B, 0x63)
    r.font.name = LATIN
    rPr = r._element.get_or_add_rPr()
    rPr.append(OxmlElement('w:rtl'))
    rPr.rFonts.set(qn('w:cs'), FONT)
    rPr.rFonts.set(qn('w:ascii'), LATIN)
    rPr.rFonts.set(qn('w:hAnsi'), LATIN)
    if level == 1 and new_page:
        # structural page break: a manual add_page_break() emits an extra empty
        # page whenever the previous section already ended at a page boundary
        p.paragraph_format.page_break_before = True
    # keep headings with the following paragraph when possible
    pPr = _pPr(p)
    ka = OxmlElement('w:keepNext')
    pPr.append(ka)
    return p


def bullets(doc, items, size=10.5):
    for it in items:
        p = rtl_par(doc, '•  ' + it, size=size, space_after=3)
        p.paragraph_format.right_indent = Cm(0.4)


def code_line(doc, text, size=9.5):
    p = rtl_par(doc, text, size=size, align='left', space_after=2)
    for r in p.runs:
        r.font.name = 'Consolas'
        rPr = r._element.get_or_add_rPr()
        rPr.rFonts.set(qn('w:cs'), 'Consolas')
    return p


def table(doc, header, rows, widths=None, size=11, header_fill='DCE6F1'):
    t = doc.add_table(rows=1, cols=len(header))
    t.style = 'Table Grid'
    tblPr = t._tbl.tblPr
    bidi = OxmlElement('w:bidiVisual')          # RTL column order
    tblPr.append(bidi)
    hdr = t.rows[0].cells
    for i, h in enumerate(header):
        hdr[i].text = ''
        p = hdr[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(h)
        r.bold = True
        r.font.size = Pt(size)
        r.font.name = LATIN
        rPr = r._element.get_or_add_rPr()
        rPr.append(OxmlElement('w:rtl'))
        rPr.rFonts.set(qn('w:cs'), FONT)
        rPr.rFonts.set(qn('w:ascii'), LATIN)
        rPr.rFonts.set(qn('w:hAnsi'), LATIN)
        shd = OxmlElement('w:shd')
        shd.set(qn('w:fill'), header_fill)
        hdr[i]._tc.get_or_add_tcPr().append(shd)
    for row in rows:
        cells = t.add_row().cells
        for i, v in enumerate(row):
            cells[i].text = ''
            p = cells[i].paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.RIGHT if i == 0 else WD_ALIGN_PARAGRAPH.CENTER
            r = p.add_run(str(v))
            r.font.size = Pt(size)
            r.font.name = LATIN
            rPr = r._element.get_or_add_rPr()
            rPr.append(OxmlElement('w:rtl'))
            rPr.rFonts.set(qn('w:cs'), FONT)
            rPr.rFonts.set(qn('w:ascii'), LATIN)
            rPr.rFonts.set(qn('w:hAnsi'), LATIN)
    if widths:
        for i, w in enumerate(widths):
            for row in t.rows:
                row.cells[i].width = Cm(w)
    rtl_par(doc, '', space_after=4)
    return t


def figure(doc, name, caption, width_cm=15.5, number=None):
    """Image with an auto-numbered caption (SEQ Figure) in the Caption style."""
    path = os.path.join(FIGS, name)
    if not os.path.exists(path):
        rtl_par(doc, f'[missing figure: {name}]', size=9, color=(0xAA, 0x00, 0x00))
        return
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(path, width=Cm(width_cm))

    cp = doc.add_paragraph(style='Caption')
    pPr = cp._p.get_or_add_pPr()
    pPr.append(OxmlElement('w:bidi'))
    cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cp.paragraph_format.space_after = Pt(12)

    def _run(text, bold=False, italic=False, size=11):
        r = cp.add_run(text)
        r.bold = bold
        r.italic = italic
        r.font.size = Pt(size)
        r.font.name = LATIN
        rPr = r._element.get_or_add_rPr()
        rPr.append(OxmlElement('w:rtl'))
        rPr.rFonts.set(qn('w:cs'), FONT)
        rPr.rFonts.set(qn('w:ascii'), LATIN)
        rPr.rFonts.set(qn('w:hAnsi'), LATIN)
        return r

    _run('شکل ', bold=True)
    r = cp.add_run()
    e = OxmlElement('w:fldChar')          # begin
    e.set(qn('w:fldCharType'), 'begin')
    r._r.append(e)
    it = OxmlElement('w:instrText')       # SEQ Figure
    it.set(qn('xml:space'), 'preserve')
    it.text = ' SEQ Figure \\* ARABIC '
    r._r.append(it)
    e = OxmlElement('w:fldChar')          # separate
    e.set(qn('w:fldCharType'), 'separate')
    r._r.append(e)
    num = cp.add_run('?')                 # cached result, updated by Word
    num.font.size = Pt(11)
    e = OxmlElement('w:fldChar')          # end
    e.set(qn('w:fldCharType'), 'end')
    r._r.append(e)
    r.font.size = Pt(11)
    r.font.name = LATIN
    _run(' — ' + caption)


def _field(doc, instruction, placeholder='برای به‌روزرسانی کلید F9 را بزنید'):
    """Insert a Word field (TOC / SEQ / PAGE ...)."""
    p = doc.add_paragraph()
    pPr = p._p.get_or_add_pPr()
    pPr.append(OxmlElement('w:bidi'))
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    r = p.add_run()
    e = OxmlElement('w:fldChar')          # 1) begin
    e.set(qn('w:fldCharType'), 'begin')
    r._r.append(e)
    it = OxmlElement('w:instrText')       # 2) instruction
    it.set(qn('xml:space'), 'preserve')
    it.text = instruction
    r._r.append(it)
    e = OxmlElement('w:fldChar')          # 3) separate -> cached result follows
    e.set(qn('w:fldCharType'), 'separate')
    r._r.append(e)
    if placeholder:
        r2 = p.add_run(placeholder)
        r2.font.size = Pt(10)
        r2.font.name = FONT
        rPr = r2._element.get_or_add_rPr()
        rPr.append(OxmlElement('w:rtl'))
        rPr.rFonts.set(qn('w:cs'), FONT)
    e = OxmlElement('w:fldChar')
    e.set(qn('w:fldCharType'), 'end')
    r._r.append(e)
    return p


def toc(doc):
    _field(doc, ' TOC \\o "1-3" \\h \\z \\u ')


def list_of_figures(doc):
    _field(doc, ' TOC \\h \\z \\c "Figure" ')


def page_break(doc):
    doc.add_page_break()


def add_page_numbers(section):
    p = section.footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run()
    for el, attr in (('w:fldChar', {'w:fldCharType': 'begin'}),):
        e = OxmlElement(el)
        for k, v in attr.items():
            e.set(qn(k), v)
        r._r.append(e)
    it = OxmlElement('w:instrText')
    it.set(qn('xml:space'), 'preserve')
    it.text = ' PAGE '
    r._r.append(it)
    e = OxmlElement('w:fldChar')
    e.set(qn('w:fldCharType'), 'end')
    r._r.append(e)
    r.font.size = Pt(9)
    r.font.name = FONT


# --------------------------------------------------------------------------
# document
# --------------------------------------------------------------------------
doc = Document()
sec = doc.sections[0]
sec.page_width, sec.page_height = Cm(21.0), Cm(29.7)          # A4
sec.top_margin = sec.bottom_margin = Cm(2.0)
sec.left_margin = sec.right_margin = Cm(1.8)
sec._sectPr.append(OxmlElement('w:bidi'))                     # RTL section
add_page_numbers(sec)

st = doc.styles['Normal']
st.font.name = LATIN
st.font.size = Pt(12.5)
st.element.rPr.rFonts.set(qn('w:cs'), FONT)
st.element.rPr.rFonts.set(qn('w:ascii'), LATIN)
st.element.rPr.rFonts.set(qn('w:hAnsi'), LATIN)

# ---------------------------------------------------------------- cover page
rtl_par(doc, '', space_after=60)
rtl_par(doc, 'آزمایشگاه مجازی امواج الکترومغناطیسی', size=26, bold=True,
        align='center', space_after=4, color=(0x1F, 0x3B, 0x63))
rtl_par(doc, 'EM Virtual Lab', size=16, bold=True, align='center',
        space_after=24, color=(0x44, 0x66, 0x99))
rtl_par(doc, 'راهنمای کاربر و توضیح تمام بخش‌های برنامه', size=15,
        align='center', space_after=6)
rtl_par(doc, 'برخورد موج تخت الکترومغناطیسی با مرز دو محیط', size=12,
        align='center', space_after=40)
rtl_par(doc, 'درس: میدان‌ها و امواج', size=12, align='center', space_after=4)
rtl_par(doc, 'پیاده‌سازی: MATLAB R2021a یا جدیدتر (بدون نیاز به هیچ جعبه‌ابزاری)',
        size=11, align='center', space_after=4)
rtl_par(doc, 'نسخهٔ سند: ۱ — آبان ۱۴۰۵', size=11, align='center', space_after=4)
rtl_par(doc, 'نام دانشجو: ......................        شمارهٔ دانشجویی: ......................',
        size=11, align='center', space_after=30)
rtl_par(doc, 'این سند همهٔ قابلیت‌های برنامه را گام‌به‌گام توضیح می‌دهد: '
            'تب‌ها، کنترل‌ها، ثابت‌های محیط، روابط فیزیکی، اعتبارسنجی و عیب‌یابی.',
        size=10.5, align='center', italic=True)

# ------------------------------------------------------------- table of contents
heading(doc, 'فهرست مطالب', 1)
bullets(doc, [
    '۱. این برنامه چه می‌کند',
    '۲. اجرای برنامه (سه گام) و نکات مهم',
    '۳. ساختار پوشه‌ها و فایل‌ها',
    '۴. تب Media — شش ثابت محیط و شش حالت نمونه (با تصویر و توضیح)',
    '۵. تب Field Animation — نقشه‌های میدان و انیمیشن',
    '۶. تب Standing Wave — موج ایستا، گره و شکم',
    '۷. تب Coefficients vs Angle — ضرایب برحسب زاویه',
    '۸. تب Results and Theory — نتایج عددی و روابط',
    '۹. جدول کامل کنترل‌ها',
    '۱۰. روابط فیزیکی که برنامه حل می‌کند',
    '۱۱. اعتبارسنجی: مقایسهٔ تحلیلی و عددی',
    '۱۲. عیب‌یابی و پرسش‌های متداول',
    '۱۳. محدودیت‌های مدل',
    '۱۴. پیوست: پرسش‌های ارائهٔ شفاهی',
], size=11)

# ------------------------------------------------------------------ section 1
heading(doc, '۱. این برنامه چه می‌کند', 1)
rtl_par(doc, 'این برنامه یک آزمایشگاه مجازی تعاملی است: موج تخت الکترومغناطیسی '
             'به مرز میان دو محیط می‌تابد و برنامه میدان‌های الکتریکی و مغناطیسی، '
             'ضرایب بازتاب و عبور، موج ایستا، موج میرا (در بازتاب کلی) و رفتار '
             'رسانای کامل را نشان می‌دهد. تمام اعداد برنامه از روابط درسی محاسبه '
             'می‌شوند و در تب «Results and Theory» هم عدد و هم فرمول نمایش داده می‌شود.',
        size=11)
rtl_par(doc, 'قراردادها: محیط ۱ در z < 0 و محیط ۲ در z > 0؛ صفحهٔ برخورد x-z است و '
             'y عمود بر آن؛ میدان فرودی E₀ = ۱ ولت بر متر؛ وابستگی زمانی به شکل '
             'exp(+jωt) است، پس فازورها به شکل exp(−j k·r) تغییر می‌کنند. '
             'برای اینکه محیط ۱ در تصویرها بالا دیده شود، محور z معکوس رسم می‌شود.',
        size=10.5)
rtl_par(doc, 'خروجی‌های خواسته‌شدهٔ پروژه (R1 تا R12) همه در برنامه دیده می‌شوند؛ '
             'نگاشت هر مورد به محل آن در سند و در برنامه در فایل README.md آمده است.',
        size=10.5)

# ------------------------------------------------------------------ section 2
heading(doc, '۲. اجرای برنامه (سه گام) و نکات مهم', 1)
bullets(doc, [
    'گام ۱: متلب نسخهٔ R2021a یا جدیدتر را باز کنید (هیچ جعبه‌ابزاری لازم نیست).',
    'گام ۲: در پنجرهٔ فرمان متلب به پوشهٔ پروژه بروید:',
], size=11)
code_line(doc, 'cd path\\to\\EM_VirtualLab')
bullets(doc, ['گام ۳: دستور زیر را اجرا کنید:'], size=11)
code_line(doc, 'run_lab')
rtl_par(doc, 'پنجرهٔ برنامه با پنج تب باز می‌شود: Media، Field Animation، Standing Wave، '
             'Coefficients vs Angle و Results and Theory. پیشنهاد می‌شود ابتدا در تب '
             'Media محیط‌ها را تنظیم کنید و سپس به تب‌های دیگر بروید.', size=10.5)
rtl_par(doc, 'اجرای آزمون‌های صحت (اختیاری ولی توصیه‌شده):', size=10.5, bold=True)
code_line(doc, 'cd tests')
code_line(doc, 'test_core        % آزمون‌های T1 تا T12 فیزیک هستهٔ محاسباتی')
code_line(doc, 'smoke_gui        % آزمون خودکار رابط گرافیکی (۴۹ بررسی)')
code_line(doc, 'fuzz_probe       % پویش ۱۰۶ حالت برای یافتن خطاهای پنهان')
rtl_par(doc, 'نکتهٔ مهم: اگر فایل‌های برنامه (gui/EM_VirtualLab.m) را تغییر دادید، '
             'پنجرهٔ باز را ببندید و برنامه را دوباره اجرا کنید؛ متلب نسخهٔ قدیمی '
             'فایل را در حافظه نگه می‌دارد. برای بستن پنجرهٔ گیرکرده، در پنجرهٔ '
             'فرمان متلب این دستور را اجرا کنید:', size=10.5)
code_line(doc, "delete(findall(groot,'Type','figure'))")

# ------------------------------------------------------------------ section 3
heading(doc, '۳. ساختار پوشه‌ها و فایل‌ها', 1)
table(doc, ['مسیر', 'توضیح'], [
    ['run_lab.m', 'دستور اجرای برنامه (مسیرها را اضافه می‌کند و پنجره را باز می‌کند)'],
    ['core/em_constants.m', 'ثابت‌های فیزیکی c، μ₀، ε₀ و η₀ (تنها جای تعریف آن‌ها)'],
    ['core/em_defaults.m', 'مقادیر پیش‌فرض و تمام اعتبارسنجی ورودی‌ها'],
    ['core/em_solve.m', 'قانون اسنل، ضرایب فرنل (TE و TM)، بروستر، بحرانی، PEC و محیط اتلافی'],
    ['core/em_fields.m', 'فازورهای موج فرودی، بازتابی و عبوری و میدان کل'],
    ['core/em_standing_wave.m', 'پوش موج ایستا، گره و شکم، SWR و جریان و بار سطحی PEC'],
    ['core/em_angle_sweep.m', 'ضرایب برحسب زاویه برای دو قطبش'],
    ['gui/EM_VirtualLab.m', 'کل رابط گرافیکی (بدون فایل .mlapp)'],
    ['tests/', 'آزمون‌ها و تولید شکل‌ها و اسکرین‌شات‌ها'],
    ['docs/', 'قرارداد، وضعیت، نقشهٔ نظری، راهنما و گزارش'],
    ['figures/', 'شکل‌ها و تصاویر رابط گرافیکی'],
], widths=[5.0, 10.5])

# ------------------------------------------------------------------ section 4
heading(doc, '۴. تب Media — شش ثابت محیط و شش حالت نمونه', 1)
rtl_par(doc, 'در این تب هر محیط را با ثابت‌های الکترومغناطیسی آن تعریف می‌کنید. '
             'برای هر محیط سه کادر وجود دارد:', size=11)
bullets(doc, [
    'eps_r — گذردهی نسبی (برای هوا ۱، شیشه ۲٫۲۵، آب ۸۱)',
    'mu_r — تراوایی نسبی (برای همهٔ مواد غیرمغناطیسی ۱)',
    'sigma — رسانندگی برحسب زیمنس بر متر (S/m)؛ صفر یعنی محیط بدون اتلاف',
], size=10.5)
table(doc, ['کمیت', 'معنای فیزیکی', 'رنج مجاز', 'پیش‌فرض'], [
    ['eps_r', 'گذردهی نسبی', 'بزرگ‌تر از صفر تا ۱۰⁴', 'محیط ۱: ۱ — محیط ۲: ۲٫۲۵'],
    ['mu_r', 'تراوایی نسبی', 'بزرگ‌تر از صفر تا ۱۰⁴', '۱'],
    ['sigma', 'رسانندگی', 'از ۰ تا ۱۰⁹ S/m', '۰'],
    ['f', 'بسامد موج', '۱ مگاهرتز تا ۱۰۰ گیگاهرتز', '۱ گیگاهرتز'],
    ['θ_i', 'زاویهٔ فرود', '۰ تا ۸۹٫۹ درجه', '۰'],
], widths=[2.2, 5.6, 4.4, 3.3])
rtl_par(doc, 'سه کنترل کمکی:', size=10.5, bold=True)
bullets(doc, [
    'Quick material (medium 2) — پرکردن سریع محیط ۲ با یک مادهٔ آماده: هوا، شیشه، '
    'تفلون، آب، FR-4 (با اتلاف)، آب دریا (با اتلاف شدید) و فریت (مغناطیسی).',
    'Swap media 1 <-> 2 — جابه‌جایی دو محیط؛ ساده‌ترین راه رسیدن به بازتاب کلی '
    '(وقتی ضریب شکست محیط ۱ بزرگ‌تر از محیط ۲ شود).',
    'Simulation mode — انتخاب دی‌الکتریک یا رسانای کامل (PEC) برای محیط ۲؛ در حالت '
    'PEC کادرهای محیط ۲ غیرفعال می‌شوند چون میدان درون رسانا صفر است.',
], size=10.5)
rtl_par(doc, 'کادر گزارش محاسباتی (پایین تب) برای هر محیط مقادیر محاسبه‌شده را نشان '
             'می‌دهد: گذردهی مختلط eps_c، ضریب شکست n، امپدانس ذاتی η، طول موج λ، '
             'ثابت تضعیف α و — برای محیط با اتلاف — تانژانت اتلاف tan δ و عمق پوست δ_s. '
             'در انتها هم نسبت n₂/n₁ و η₂/η₁ و زاویهٔ بحرانی یا بروستر (در صورت وجود) '
             'گزارش می‌شود. با این کادر می‌توانید بلافاصله بررسی کنید که ورودی‌هایتان '
             'همان چیزی را می‌دهد که از تئوری انتظار دارید.', size=10.5)

heading(doc, '۴.۱ حالت ۱ — هوا به شیشه (دی‌الکتریک بدون اتلاف)', 2)
rtl_par(doc, 'حالت پیش‌فرض برنامه: محیط ۱ هوا (eps_r = ۱، mu_r = ۱، sigma = ۰) و '
             'محیط ۲ شیشه با eps_r = ۲٫۲۵. ضریب شکست محیط ۲ برابر ۱٫۵ و امپدانس آن '
             '۲۵۱٫۱۵ اهم می‌شود. در این حالت برنامه زاویهٔ بروستر را برای قطبش TM '
             'حسابه می‌کند (۵۶٫۳۱ درجه) ولی زاویهٔ بحرانی وجود ندارد، چون n₁ < n₂.', size=10.5)
figure(doc, 'guide_media_default.png',
       'تصویر ۱ — تب Media در حالت هوا به شیشه: شش کادر ثابت‌ها، منوی مادهٔ آماده، '
       'دکمهٔ جابه‌جایی محیط‌ها و کادر گزارش (n₁ = ۱، n₂ = ۱٫۵، η₂ = ۲۵۱٫۱۵ اهم).')

heading(doc, '۴.۲ حالت ۲ — شیشه به هوا (پس از Swap): زاویهٔ بحرانی ظاهر می‌شود', 2)
rtl_par(doc, 'با زدن دکمهٔ «Swap media 1 <-> 2» مقادیر دو محیط جابه‌جا می‌شوند: محیط ۱ '
             'شیشه و محیط ۲ هوا. حالا n₁ = ۱٫۵ > n₂ = ۱ و زاویهٔ بحرانی '
             'θ_c = arcsin(۱/۱٫۵) = ۴۱٫۸۱ درجه به‌وجود می‌آید؛ دکمهٔ «Go to critical angle» '
             'روشن می‌شود و در کادر گزارش مقدار زاویهٔ بحرانی نوشته می‌شود. برای '
             'زاویه‌های بزرگ‌تر از θ_c بازتاب کلی رخ می‌دهد: |Γ| = ۱ و T = ۰.', size=10.5)
figure(doc, 'guide_media_tir.png',
       'تصویر ۲ — همان تب پس از جابه‌جایی محیط‌ها: n₁ = ۱٫۵ و n₂ = ۱ و در گزارش، '
       'زاویهٔ بحرانی ۴۱٫۸۱ درجه دیده می‌شود.')

heading(doc, '۴.۳ حالت ۳ — محیط ۲ با اتلاف (FR-4، sigma = ۰٫۰۲ S/m)', 2)
rtl_par(doc, 'با مثبت‌شدن رسانندگی، محیط اتلافی می‌شود و برنامه با گذردهی مختلط کار '
             'می‌کند: eps_c = eps_r − jσ/(ωε₀). برای FR-4 در ۱ گیگاهرتز: '
             'Re(eps_c) = ۴٫۴، −Im(eps_c) = ۰٫۳۵۹۵، تانژانت اتلاف tan δ = ۰٫۰۸۱۷، '
             'ثابت تضعیف α = ۱٫۷۹۴۵ Np/m و عمق پوست δ_s = ۰٫۵۵۷۳ متر.', size=10.5)
bullets(doc, [
    'موج عبوری درون محیط ۲ به‌صورت exp(−αz) میرا می‌شود و توان آن با exp(−۲αz) کاهش می‌یابد.',
    'در مرز، همچنان R + T = ۱ برقرار است؛ اتلاف درون محیط رخ می‌دهد، نه روی مرز.',
    'محیط با اتلاف بازتاب کلی واقعی ندارد و زاویهٔ بروستر دقیق هم ندارد (|Γ| فقط '
    'کمینه می‌شود)؛ برنامه در این حالت «none» گزارش می‌کند.',
], size=10.5)
figure(doc, 'guide_media_lossy.png',
       'تصویر ۳ — تب Media برای FR-4 با اتلاف: در کادر گزارش تانژانت اتلاف و عمق پوست '
       'دیده می‌شود و دستگاه مختلط eps_c و n نمایش داده می‌شود.')

heading(doc, '۴.۴ حالت ۴ — اتلاف شدید (آب دریا، sigma = ۴ S/m)', 2)
rtl_par(doc, 'آب دریا با eps_r = ۸۱ و σ = ۴ S/m نمونهٔ یک محیط بسیار اتلافی است: '
             'تانژانت اتلاف حدود ۰٫۸۹ می‌شود و عمق پوست به چند سانتی‌متر می‌رسد؛ یعنی '
             'موج عملاً در لایهٔ نازکی نزدیک سطح جذب می‌شود. این حالت برای نشان‌دادن '
             'تفاوت «محیط با اتلاف» و «بازتاب کلی» بسیار گویا است: در بازتاب کلی '
             'هیچ توانی به محیط ۲ نمی‌رود، اما در محیط اتلافی توان وارد می‌شود و درون '
             'آن جذب می‌شود.', size=10.5)
figure(doc, 'guide_media_sea.png',
       'تصویر ۴ — آب دریا در ۱ گیگاهرتز: تانژانت اتلاف بزرگ و عمق پوست کوچک.')

heading(doc, '۴.۵ حالت ۵ — محیط مغناطیسی (mu_r = ۴): بروستر به قطبش TE می‌رود', 2)
rtl_par(doc, 'اگر تراوایی نسبی محیط ۲ را از ۱ بزرگ‌تر کنید، رابطهٔ n = √(eps_r·mu_r) و '
             'η = η₀√(mu_r/eps_r) تغییر می‌کند و رفتار زاویهٔ بروستر جابه‌جا می‌شود. '
             'برای eps_r = ۲٫۲۵ و mu_r = ۴: n₂ = ۳ و η₂ = ۵۰۲٫۳ اهم. در این حالت '
             'زاویهٔ بروستر برای قطبش TE در ۴۳٫۰۹ درجه وجود دارد و برای TM وجود ندارد '
             '(برعکس حالت غیرمغناطیسی که فقط TM زاویهٔ بروستر دارد). دکمهٔ بروستر '
             'برچسب خود را با همین وضعیت نشان می‌دهد.', size=10.5)
figure(doc, 'guide_media_magnetic.png',
       'تصویر ۵ — محیط ۲ مغناطیسی (mu_r = ۴): kادر گزارش n₂ = ۳ و η₂ = ۵۰۲٫۳ اهم و '
       'یادآوری زاویهٔ بروستر قطبش TE.')

heading(doc, '۴.۶ حالت ۶ — رسانای کامل (PEC)', 2)
rtl_par(doc, 'با انتخاب «Perfect conductor (PEC)» از منوی Simulation mode، محیط ۲ '
             'رسانای کامل می‌شود: کادرهای eps_r، mu_r و sigma محیط ۲ و منوی مادهٔ آماده '
             'غیرفعال می‌شوند، Γ = −۱ و τ = ۰ می‌شود، میدان در z > 0 صفر است و پوش '
             'میدان الکتریکی در محیط ۱ به شکل ۲|sin(kz₁z)| با گره روی سطح ظاهر '
             'می‌شود. برنامه جریان سطحی |J_s| = ۲|H_i|cosθ (برای TE) یا ۲|H_i| (برای TM) '
             'و بار سطحی ρ_s = ۲ε₀ε_r sinθ (فقط TM) را هم گزارش می‌کند.', size=10.5)
figure(doc, 'guide_media_pec.png',
       'تصویر ۶ — حالت PEC: کادرهای محیط ۲ غیرفعال شده‌اند و در گزارش نوشته شده '
       'است که میدان عبوری وجود ندارد.')

# ------------------------------------------------------------------ section 5
heading(doc, '۵. تب Field Animation — نقشه‌های میدان و انیمیشن', 1)
rtl_par(doc, 'در این تب دو نقشهٔ رنگی کنار هم رسم می‌شود: میدان الکتریکی (چپ) و میدان '
             'مغناطیسی (راست). محور z معکوس است تا محیط ۱ (سمت فرود) بالا و محیط ۲ '
             'پایین دیده شود. مرز z = 0 با خط مشکی و نرمال با خط‌چین نشان داده شده و '
             'نام هر محیط روی تصویر نوشته می‌شود.', size=10.5)
rtl_par(doc, 'نوار ابزار بالای تب:', size=10.5, bold=True)
bullets(doc, [
    'سه چک‌باکس Incident / Reflected / Transmitted — انتخاب اینکه کدام موج‌ها در نقشه '
    'دیده شوند. اگر هر سه تیک داشته باشند میدان کل رسم می‌شود.',
    'field vectors (quiver) — افزودن فلش‌های کوچک مؤلفه‌های درون‌صفحه‌ای میدان.',
    'E map و H map — انتخاب مؤلفه‌ای که با نقشهٔ رنگی نمایش داده می‌شود (برای هر قطبش '
    'فقط مؤلفه‌های ناصفر و اندازهٔ لحظه‌ای فهرست می‌شوند) و Window [lambda0] — اندازهٔ '
    'پنجرهٔ نمایش برحسب طول موج فضای آزاد.',
], size=10.5)
rtl_par(doc, 'بالای نقشه‌ها یک بلوک متنی جهت‌های انتشار را گزارش می‌کند (زاویهٔ فرود، '
             'بازتاب و شکست؛ در PEC عبارت «no transmitted wave» و در بازتاب کلی '
             '«evanescent» با α و δ) و زیر نقشه‌ها نوار وضعیت سه‌خطی قرار دارد: '
             'فاز/بسامد/λ₀ و رژیم، سپس θ_i و θ_r و θ_t، و در خط سوم بیشینهٔ همان '
             'مؤلفه‌هایی که رسم شده‌اند.', size=10.5)
figure(doc, 'fig6_gui_fields_dielectric.png',
       'تصویر ۷ — تب Field Animation در حالت هوا به شیشه، فرود عمودی و قطبش TE: '
       'مؤلفه‌های E_y و H_x رسم شده‌اند.')
figure(doc, 'fig6_gui_fields_tir.png',
       'تصویر ۸ — بازتاب کلی (شیشه به هوا، ۶۰ درجه): در محیط ۲ میدان میرا دیده می‌شود '
       'و بلوک متن α و δ را گزارش می‌کند.')
figure(doc, 'guide_field_lossy.png',
       'تصویر ۹ — محیط ۲ با اتلاف (FR-4): موج عبوری به‌سرعت میرا می‌شود؛ برچسب محیط ۲ '
       'مقادیر eps_r، mu_r و sigma و ضریب شکست مختلط را نشان می‌دهد.')
figure(doc, 'fig6_gui_fields_pec_tm.png',
       'تصویر ۱۰ — PEC با قطبش TM: مؤلفه‌های غالب E_x و H_y هستند و نوار وضعیت '
       'بیشینهٔ همین دو مؤلفه را گزارش می‌کند (max |E_x| = ۱٫۴۱۴ و max |H_y| = ۰٫۰۰۵۳۱).')

# ------------------------------------------------------------------ section 6
heading(doc, '۶. تب Standing Wave — موج ایستا، گره و شکم', 1)
rtl_par(doc, 'دو محور، پوش میدان (خط پُر مشکی) و مقدار لحظه‌ای (خط آبی) را برحسب z '
             'نشان می‌دهند؛ خط نقطه‌چین محل مرز، دایرهٔ قرمز گره‌ها و مربع سبز شکم‌ها '
             'هستند. پوش، اندازهٔ فازور میدان است و در محیط ۱ بدون اتلاف دقیقاً همان '
             'رابطهٔ کتاب |۱ ± Γ exp(۲j k_z۱ z)| می‌شود؛ خط آبی مقدار واقعی میدان در '
             'لحظهٔ جاری است (همان میدانی که در تب انیمیشن رسم می‌شود) و همیشه داخل '
             'پوش می‌ماند.', size=10.5)
bullets(doc, [
    'در محیط ۱ (z < 0) موج ایستای جزئی دیده می‌شود: پوش بین کمینه و بیشینه نوسان می‌کند '
    'و نسبت موج ایستا SWR = (۱+|Γ|)/(۱−|Γ|) در پنل کنار نمودار گزارش می‌شود.',
    'در محیط ۲ (z > 0) موج عبوری رسم می‌شود: برای محیط بدون اتلاف پوش ثابت است، و در '
    'بازتاب کلی یا محیط اتلافی به‌صورت نمایی کاهش می‌یابد.',
    'جدول زیر نمودارها مکان چند گره و شکم اول را هم برحسب متر و هم برحسب λ₁ می‌دهد.',
    'در حالت PEC گره‌ها روی سطح و در فاصله‌های λ₁/۲ قرار دارند و SWR بی‌نهایت می‌شود.',
    'اگر محیط ۱ خودش اتلافی باشد، موج ایستای متناوب تشکیل نمی‌شود؛ برنامه به‌جای '
    'عدد می‌نویسد که SWR تعریف‌نشده است.',
], size=10.5)
figure(doc, 'fig6_gui_standing_pec.png',
       'تصویر ۱۱ — حالت PEC: پوش ۲|sin(k₁z)|، گره‌ها روی سطح و در فاصله‌های λ₁/۲، '
       'SWR بی‌نهایت و گزارش |J_s|.')
figure(doc, 'guide_standing_lossy.png',
       'تصویر ۱۲ — محیط ۲ با اتلاف: پوش درون محیط ۲ نمایی کاهش می‌یابد و عمق پوست '
       'در پنل کنار گزارش می‌شود.')

# ------------------------------------------------------------------ section 7
heading(doc, '۷. تب Coefficients vs Angle — ضرایب برحسب زاویه', 1)
rtl_par(doc, 'چهار نمودار، |Γ|، فاز Γ، |τ| و فاز τ را برحسب زاویهٔ فرود از ۰ تا ۸۹٫۹ '
             'درجه نشان می‌دهند؛ قطبش TE با خط آبی پُر و TM با خط قرمز خط‌چین رسم '
             'می‌شود و قطبش انتخاب‌شده ضخیم‌تر است. خط عمودی سبز زاویهٔ بروستر و خط '
             'بنفش زاویهٔ بحرانی را علامت می‌زنند و خط مشکی زاویهٔ جاری را نشان می‌دهد. '
             'با منوی بالای تب می‌توان به‌جای دامنه، توان‌های R و T را دید. جایی که '
             'دامنه صفر است (بروستر) خط فاز شکسته می‌شود، چون فاز در آن نقطه تعریف '
             'نشده است.', size=10.5)
figure(doc, 'fig6_gui_coefficients_brewster_tm.png',
       'تصویر ۱۳ — قطبش TM: در زاویهٔ بروستر (۵۶٫۳۱ درجه) منحنی |Γ| به صفر می‌رسد و '
       'خط علامت‌گذار همان نقطه را نشان می‌دهد.')
figure(doc, 'fig6_gui_coefficients_tir.png',
       'تصویر ۱۴ — شیشه به هوا: بعد از زاویهٔ بحرانی ۴۱٫۸۱ درجه، |Γ| برای هر دو قطبش '
       'به ۱ می‌رسد و T صفر می‌شود.')
figure(doc, 'fig3_power_balance.png',
       'تصویر ۱۵ — تأیید R + T = ۱: در هر دو جهت انتشار مجموع توان‌ها روی خط یک می‌ماند.')

# ------------------------------------------------------------------ section 8
heading(doc, '۸. تب Results and Theory — نتایج عددی و روابط', 1)
rtl_par(doc, 'ستون چپ این تب یک پنل متنی مونواسپیس با بلوک‌های پارامترها، محیط‌ها '
             '(eps_r، mu_r، sigma، eps_c، n، η، λ، α، تانژانت اتلاف و عمق پوست)، '
             'هندسه (θ_i، θ_r، θ_t، k_x، k_z۱، k_z۲)، ضرایب (Γ، τ، R، T و R + T)، '
             'نتایج موج ایستا (SWR و مکان گره‌ها) و پارامترهای محاسباتی (اندازهٔ شبکه، '
             'پنجره و گام فاز) است. ستون راست همان روابط را به‌صورت فرمول‌های ریاضی '
             'نمایش می‌دهد تا هنگام ارائهٔ شفاهی بتوانید هر عدد را به رابطهٔ آن نسبت دهید.',
        size=10.5)
figure(doc, 'fig6_gui_results.png',
       'تصویر ۱۶ — تب Results and Theory: پنل اعداد (چپ) و پنل فرمول‌ها (راست).')
figure(doc, 'guide_results_lossy.png',
       'تصویر ۱۷ — همان تب برای محیط با اتلاف: بلوک‌های eps_c، α، تانژانت اتلاف و '
       'عمق پوست به اعداد اضافه می‌شوند.')

# ------------------------------------------------------------------ section 9
heading(doc, '۹. جدول کامل کنترل‌ها', 1)
table(doc, ['کنترل', 'محل', 'کار'], [
    ['Simulation mode', 'پنل چپ', 'انتخاب محیط ۲: دی‌الکتریک یا رسانای کامل (PEC)'],
    ['خلاصهٔ محیط‌ها', 'پنل چپ', 'نمایش n₁، n₂، η₁، η₂ و وضعیت اتلاف/مغناطیسی'],
    ['Polarization', 'پنل چپ', 'انتخاب قطبش افقی (TE) یا عمودی (TM)'],
    ['Frequency + واحد', 'پنل چپ', 'بسامد موج با واحد MHz یا GHz'],
    ['Incidence angle', 'پنل چپ', 'زاویهٔ فرود با کادر عددی و لغزنده'],
    ['Normal incidence', 'پنل چپ', 'تنظیم زاویه روی صفر درجه'],
    ['Brewster / critical', 'پنل چپ', 'پرش به زاویهٔ بروستر یا بحرانی (اگر وجود داشته باشد)'],
    ['Play / Pause', 'پنل چپ', 'شروع و توقف انیمیشن میدان‌ها'],
    ['Speed و Phase', 'پنل چپ', 'سرعت انیمیشن (۰٫۱ تا ۵ برابر) و فاز لحظه‌ای'],
    ['Presets', 'پنل چپ', 'ده سناریوی آماده (شیشه، بازتاب کلی، PEC، اتلافی، مغناطیسی)'],
    ['Reset to defaults', 'پنل چپ', 'بازگرداندن همهٔ مقادیر به حالت اولیه'],
    ['eps_r / mu_r / sigma', 'تب Media', 'ثابت‌های محیط ۱ و ۲ (شش ورودی)'],
    ['Quick material', 'تب Media', 'پرکردن سریع محیط ۲ با یک مادهٔ آماده'],
    ['Swap media 1 <-> 2', 'تب Media', 'جابه‌جایی دو محیط (برای رسیدن به بازتاب کلی)'],
    ['Incident/Reflected/Transmitted', 'نوار ابزار تب اول', 'انتخاب موج‌های نمایش‌داده‌شده'],
    ['E map / H map', 'نوار ابزار تب اول', 'انتخاب مؤلفهٔ رسم‌شده در هر نقشه'],
    ['Window [lambda0]', 'نوار ابزار تب اول', 'اندازهٔ پنجرهٔ نمایش در واحد طول موج'],
    ['|Gamma| و |tau| یا R و T', 'تب ضرایب', 'تغییر کمیت رسم‌شده در چهار نمودار'],
], widths=[4.6, 3.4, 7.5], size=9)
rtl_par(doc, 'چرا بعضی دکمه‌ها غیرفعال‌اند؟ برچسب خود دکمه دلیل را می‌گوید: زاویهٔ '
             'بحرانی فقط وقتی وجود دارد که هر دو محیط بدون اتلاف باشند و n₁ > n₂ '
             '(برای رسیدن به آن دکمهٔ Swap media را بزنید)؛ زاویهٔ بروستر برای محیط '
             'بدون اتلاف و غیرمغناطیسی فقط در قطبش TM وجود دارد و در محیط مغناطیسی '
             'ممکن است به قطبش TE منتقل شود. با نگه‌داشتن نشانگر روی دکمه، راهنمای '
             'شناور همین توضیح را نشان می‌دهد.', size=10)

# ------------------------------------------------------------------ section 10
heading(doc, '۱۰. روابط فیزیکی که برنامه حل می‌کند', 1)
table(doc, ['کمیت', 'رابطه', 'توضیح'], [
    ['ضریب شکست و امپدانس', 'n = √(eps_r·mu_r) ، η = η₀√(mu_r/eps_r)',
     'برای محیط بدون اتلاف؛ با رسانندگی، n و η مختلط می‌شوند'],
    ['محیط اتلافی', 'eps_c = eps_r − jσ/(ωε₀)', 'رسانندگی به‌صورت بخش موهومی گذردهی ظاهر می‌شود'],
    ['تانژانت اتلاف', 'tan δ = σ/(ωε₀eps_r)', 'معیار «چقدر اتلافی» بودن محیط'],
    ['ثابت تضعیف و عمق پوست', 'α = −Im(k_z) ، δ_s = ۱/α',
     'موج به‌صورت exp(−αz) و توان به‌صورت exp(−۲αz) میرا می‌شود'],
    ['قانون اسنل', 'n₁ sin θ_i = n₂ sin θ_t', 'و k_x = k₁ sin θ_i = k₂ sin θ_t در دو محیط یکسان است'],
    ['قطبش TE (افقی)', 'Γ = (η₂cosθ_i − η₁cosθ_t)/(η₂cosθ_i + η₁cosθ_t) ، τ = ۱ + Γ',
     'میدان الکتریکی موازی سطح مشترک است'],
    ['قطبش TM (عمودی)', 'Γ = (η₂cosθ_t − η₁cosθ_i)/(η₂cosθ_t + η₁cosθ_i) ، ۱ + Γ = τ cosθ_t/cosθ_i',
     'میدان الکتریکی در صفحهٔ برخورد است'],
    ['توان', 'R = |Γ|² ، T = |τ|²(η₁/η₂)Re(cosθ_t)/cosθ_i ، R + T = ۱',
     'در مرز، توان کل پایسته است؛ اتلاف درون محیط رخ می‌دهد'],
    ['زاویهٔ بروستر', 'θ_B = arctan(n₂/n₁) (فقط TM، محیط بدون اتلاف و غیرمغناطیسی)',
     'زاویه‌ای که بازتاب صفر می‌شود؛ در محیط مغناطیسی ممکن است TE باشد'],
    ['زاویهٔ بحرانی', 'θ_c = arcsin(n₂/n₁) با شرط n₁ > n₂',
     'آغاز بازتاب کلی: |Γ| = ۱ و T = ۰'],
    ['بازتاب کلی', 'cos θ_t = −j√((n₁sinθ_i/n₂)² − ۱)',
     'شاخهٔ درست ریشه؛ میدان در محیط ۲ میرا می‌شود، نه رشدکننده'],
    ['موج ایستا', '|E_y| = |۱ + Γ e^{۲jk_z۱z}| ، SWR = (۱+|Γ|)/(۱−|Γ|)',
     'گره‌ها در ∠G + ۲k_z۱z = (۲m+۱)π و شکم‌ها در ۲mπ'],
    ['رسانای کامل (PEC)', 'Γ = −۱ ، τ = ۰ ، |J_s| = ۲|H_i|cosθ_i (TE) یا ۲|H_i| (TM)',
     'میدان مماسی روی سطح صفر است و جریان سطحی آن را برقرار می‌کند'],
], widths=[3.4, 6.6, 5.5], size=8.5)

# ------------------------------------------------------------------ section 11
heading(doc, '۱۱. اعتبارسنجی: مقایسهٔ تحلیلی و عددی', 1)
rtl_par(doc, 'هر ردیف جدول زیر دو بار محاسبه شده است: یک بار از فرمول تحلیلی و یک بار '
             'از هستهٔ محاسباتی برنامه. ستون آخر را خودتان با محاسبهٔ دستی پر کنید '
             '(هدف تمرین هم همین است). جدول کامل با ۳۷ ردیف در فایل '
             'docs/VALIDATION.md موجود است.', size=10.5)

rows = []
try:
    with open(os.path.join(DOCS, 'VALIDATION.md'), encoding='utf-8') as fh:
        for line in fh:
            if line.startswith('| ') and '---' not in line and 'analytic' not in line:
                cols = [c.strip() for c in line.strip().strip('|').split('|')]
                if len(cols) >= 4 and cols[0].isdigit():
                    rows.append([cols[0], cols[1][:44], cols[2][:20], cols[3][:20], ''])
except FileNotFoundError:
    pass
table(doc, ['#', 'کمیت', 'تحلیلی', 'محاسبهٔ برنامه', 'محاسبهٔ دستی'],
      rows if rows else [['-', 'جدول اعتبارسنجی یافت نشد', '-', '-', '']],
      widths=[1.0, 7.0, 3.0, 3.0, 2.5], size=8)
rtl_par(doc, 'آنچه با اجرای واقعی تأیید شده است: آزمون‌های test_core (T1 تا T12) همه '
             'PASS شده‌اند — از جمله شرط‌های مرزی روی آرایه‌های میدان با خطای کمتر از '
             '۶×۱۰⁻¹⁶، برابری R + T = ۱، پیوستگی بردار پوینتینگ، میدان میرای بازتاب '
             'کلی، محیط اتلافی و محیط مغناطیسی. آزمون خودکار رابط گرافیکی (smoke_gui) '
             '۴۹ بررسی را بدون خطا گذرانده و پویش ۱۰۶ حالتی (fuzz_probe) هیچ خطای '
             'عددی پیدا نکرده است. اجرای گرافیکی به‌صورت خودکار (بدون نمایش) انجام شده '
             'است؛ لطفاً یک‌بار خودتان برنامه را باز کنید و ظاهر و انیمیشن را ببینید.',
        size=10)

# ------------------------------------------------------------------ section 12
heading(doc, '۱۲. عیب‌یابی و پرسش‌های متداول', 1)
table(doc, ['مشکل', 'راه‌حل'], [
    ['پنجره بسته نمی‌شود یا بعد از تغییر فایل‌ها خطا می‌دهد',
     'متلب نسخهٔ قدیمی فایل را در حافظه دارد. در پنجرهٔ فرمان بنویسید '
     'delete(findall(groot,\'Type\',\'figure\')) و سپس run_lab را دوباره اجرا کنید.'],
    ['دکمهٔ زاویهٔ بحرانی غیرفعال است',
     'زاویهٔ بحرانی فقط با n₁ > n₂ و دو محیط بدون اتلاف وجود دارد. در تب Media '
     'دکمهٔ Swap media را بزنید (شیشه به هوا) یا از پیش‌تنظیم بازتاب کلی استفاده کنید.'],
    ['دکمهٔ بروستر غیرفعال است یا زاویه‌ای نشان نمی‌دهد',
     'در محیط غیرمغناطیسی زاویهٔ بروستر فقط برای قطبش TM وجود دارد؛ برچسب دکمه '
     'می‌گوید زاویه برای کدام قطبش است. در محیط مغناطیسی ممکن است برعکس شود.'],
    ['در تب موج ایستا عدد SWR به‌جای مقدار، «تعریف‌نشده» است',
     'محیط ۱ اتلافی است (sigma1 > 0)؛ در این حالت موج ایستای متناوب تشکیل نمی‌شود. '
     'برای دیدن SWR مقدار sigma1 را صفر کنید.'],
    ['زاویهٔ ۹۰ درجه پذیرفته نمی‌شود',
     'در فرود مماسی cos θ_i صفر می‌شود و روابط T و فاصلهٔ گره‌ها تکین می‌شوند؛ '
     'بیشینهٔ مجاز ۸۹٫۹ درجه است.'],
    ['هیچ گره‌ای در تب موج ایستا نمی‌بینم',
     'اگر دو محیط یکسان باشند (Γ = ۰) موج بازتابی وجود ندارد و گره‌ای تشکیل نمی‌شود. '
     'همچنین گره‌ها فقط برای محیط ۱ بدون اتلاف به‌صورت فرم بسته محاسبه می‌شوند.'],
    ['انیمیشن کند یا سریع است',
     'سرعت انیمیشن با لغزندهٔ Speed تنظیم می‌شود و مستقل از بسامد واقعی است؛ '
     'زمان نمایش عمداً کند شده است (در ۱ گیگاهرتز دورهٔ واقعی یک نانوثانیه است).'],
    ['عدد eps_r کوچک‌تر از یک را وارد کردم',
     'برنامه آن را می‌پذیرد ولی n < 1 یعنی سرعت فاز بزرگ‌تر از سرعت نور؛ چنین '
     'دی‌الکتریک غیرفعال و بی‌اتلافی وجود ندارد و فقط برای مطالعهٔ پارامتری است.'],
], widths=[5.2, 10.3], size=9)

# ------------------------------------------------------------------ section 13
heading(doc, '۱۳. محدودیت‌های مدل', 1)
bullets(doc, [
    'محیط‌ها همسان‌گرد، بی‌اتلاف یا اتلافی با رسانندگی ساده و غیرمغناطیسی یا مغناطیسی '
    'با mu_r حقیقی هستند؛ اتلاف مغناطیسی (mu_r مختلط) مدل نشده است.',
    'محیط با اتلاف زاویهٔ بروستر دقیق و بازتاب کلی واقعی ندارد؛ برنامه «none» گزارش می‌کند.',
    'اگر محیط ۱ اتلافی باشد، SWR تعریف‌نشده است و مکان گره‌ها فقط به‌صورت عددی یافت می‌شود.',
    'برخورد مایل دوبعدی است (صفحهٔ x-z)؛ نمای سه‌بعدی پرتو و بردار پوینتینگ پیاده‌سازی نشده است.',
    'فاز انیمیشن گامی ثابت در هر فریم دارد و با زمان واقعی متناسب نیست (نمایش آهسته).',
    'در |Γ| = ۱ مقدار SWR بی‌نهایت گزارش می‌شود.',
], size=10.5)

# ------------------------------------------------------------------ section 14
heading(doc, '۱۴. پیوست: پرسش‌های ارائهٔ شفاهی', 1)
rtl_par(doc, 'پاسخ کوتاه این پرسش‌ها در فایل docs/THEORY_MAP.md آمده است؛ برای ارائهٔ '
             'شفاهی بهتر است هرکدام را با اعداد همین برنامه پاسخ دهید.', size=10.5)
bullets(doc, [
    'چرا برای قطبش TE زاویهٔ بروستر وجود ندارد؟',
    'چرا علامت Γ_TM در زاویهٔ بروستر تغییر می‌کند؟',
    'در بازتاب کلی فاز Γ چقدر است و آیا توانی عبور می‌کند؟',
    'چرا موج میرا با پایستگی انرژی تناقض ندارد؟',
    'چرا باید شاخهٔ Im(cos θ_t) < 0 انتخاب شود؟',
    'چرا برای رسانای کامل Γ = −۱ و τ = ۰ است و جریان سطحی از کجا می‌آید؟',
    'چرا k_x در مرز پایسته است؟',
    'گره‌های میدان برای TE و TM روی رسانای کامل کجا هستند؟',
    'چرا در رابطهٔ T ضریب (η₁/η₂)·cosθ_t/cosθ_i ظاهر می‌شود؟',
    'فاز انیمیشن چه نسبتی با زمان واقعی دارد؟',
    'چرا محیط با اتلاف بازتاب کلی و زاویهٔ بروستر دقیق ندارد؟',
    'چرا در محیط با اتلاف همچنان R + T = ۱ است؟',
    'چرا در محیط مغناطیسی زاویهٔ بروستر به قطبش TE منتقل می‌شود؟',
], size=10.5)

# --------------------------------------------------------------------------
out_docx = os.path.join(DOCS, 'EM_VirtualLab_UserGuide_FA_word.docx')
doc.save(out_docx)
print('DOCX written:', out_docx, os.path.getsize(out_docx), 'bytes')
print('paragraphs:', len(doc.paragraphs), 'tables:', len(doc.tables))

# ---- export to PDF through Word (COM) ------------------------------------
out_pdf = os.path.join(DOCS, 'EM_VirtualLab_UserGuide_FA_word.pdf')
if os.path.exists(out_pdf):
    os.remove(out_pdf)
import win32com.client as win32
word = win32.Dispatch('Word.Application')
word.Visible = False
try:
    d = word.Documents.Open(out_docx)
    # populate the TOC / list of figures / caption numbers before exporting
    for f in list(d.Fields):
        try:
            f.Update()
        except Exception:
            pass
    for tc in list(d.TablesOfContents):
        tc.Update()
    for toc in list(d.TablesOfFigures):
        toc.Update()
    d.Repaginate()
    d.ExportAsFixedFormat(OutputFileName=out_pdf, ExportFormat=17)  # wdExportFormatPDF
    pages = d.ComputeStatistics(2)                                  # wdStatisticPages
    d.Close(False)
    print('PDF written:', out_pdf, os.path.getsize(out_pdf), 'bytes,', pages, 'pages')
finally:
    word.Quit()
