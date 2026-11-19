# Project Status — EM Virtual Lab

**Last updated:** 2026-11-18 (feature round 2: lossy / magnetic media)
**CONTRACT.md version:** initial (Section 4 of the implementation plan), plus the
additions listed in the Deviation Log below.

---

## List A — Physics Core & Verification

| ID | Task | Status | Notes |
|----|------|--------|-------|
| A1 | `em_defaults` and input validation (eps in (0,100], theta in [0,89.9], f in [1e6,1e11]) | DONE | Bad input raises `em_defaults:*` errors; the 12 `chkErr` cases in T1 cover them |
| A2 | `em_solve`: Sections 3.1–3.3, 3.5, 3.6, vectorized over theta | DONE | Passes T1, T2, T5, T6, T7; extended to complex eps/mu (lossy + magnetic), T11/T12 |
| A3 | `em_fields`: Section 3.4, vectorized, no loops | DONE | Passes T3 (max jump 6e-16, incl. TIR) and T4 (Sz continuity) |
| A4 | `em_angle_sweep` | DONE | Passes T10 (sweep == single solve, exactly) |
| A5 | `em_standing_wave`: Section 3.7 + PEC surface current/charge | DONE | Passes T8, T9; PEC `Js` verified against `2/eta0`, `rho_s` against `2 eps0 sin(theta_i)` |
| A6 | `tests/test_core.m`: tests T1–T12, PASS/FAIL table, errors on failure | DONE | Executed in MATLAB R2024a: **12 of 12 PASS** (T11 lossy, T12 magnetic added) |
| A7 | `tests/gen_report_figures.m`: headless PNG (200 dpi) + markdown table analytic vs numeric | DONE | Wrote 19 PNGs into `figures/` and `docs/VALIDATION.md` (37 rows, incl. lossy and magnetic cases) |
| A8 | `docs/THEORY_MAP.md`: eq-to-function map + Section 9 answers | DONE | All 10 oral-defence answers + the verification map |

**SYNC-1 Gate:** A1–A5 pass → the GUI runs against the real core (no stubs
anywhere in the delivered tree).

---

## List B — GUI & Visualization

| ID | Task | Status | Notes |
|----|------|--------|-------|
| B1 | Layout skeleton: programmatic uifigure, uigridlayout, left panel, right tab group (Field Animation / Standing Wave / Coefficients vs Angle / Results and Theory) | DONE | `gui/EM_VirtualLab.m`, no `.mlapp`, base MATLAB only |
| B2 | Controls & validation (7.1): synced edit+slider, invalid input rejected w/ message + restore, mode-dependent enabling, presets, Reset | DONE | `uialert` on bad input, controls re-synced from the validated struct; Brewster/critical buttons enabled only when they apply |
| B3 | Animation engine: one timer, phase phi, Play/Pause, speed slider. Precompute phasor grids on parameter change; per-frame CData/UData/VData updates only. Stop/delete timer in CloseRequestFcn | DONE | Single `timer` (`BusyMode='drop'`, ~15 fps), deleted in `CloseRequestFcn`; per frame only `CData`/`UData`/`VData` change |
| B4 | Field Animation tab (7.2) | DONE | Two maps (E left, H right), z axis reversed, interface + medium labels, k arrows with angles, evanescent arrow in TIR, PEC shading, quiver overlay, fixed symmetric colour limits |
| B5 | Standing Wave tab (7.3) | DONE | Envelope + instantaneous curve, analytic node/antinode markers, table in m and lambda1 units, SWR, PEC `abs(Js)` and `rho_s` |
| B6 | Coefficients vs Angle tab (7.4) | DONE | 2x2 axes, TE/TM styles with the selected polarization thicker, theta_B and theta_c markers, current-angle marker, R/T toggle |
| B7 | Results and Theory tab (7.5) | DONE | Monospace numeric panel with units; formula panel in LaTeX with an automatic plain-text fallback |
| B8 | `tests/smoke_gui.m`: build app Visible off, loop presets × polarizations, 30 frames each, check errors/NaN, close, print SMOKE TEST PASSED. App exposes `EM_VirtualLab('selftest')` | DONE | Executed headless: **SMOKE TEST PASSED, 47 checks, 0 failures** — now also fires every widget callback and closes through the window's CloseRequestFcn |
| B9 | `docs/USER_GUIDE.md`: step-by-step per mode, Persian, with `[SCREENSHOT: ...]` placeholders | DONE | Persian guide with placeholders naming the real files in `figures/` |

**Dependency:** B4–B7 use the real core (A2–A5); the combination is exercised by
the smoke test, which walks every preset and both polarizations.

---

## Phase 3 — Integration

| ID | Task | Status | Notes |
|----|------|--------|-------|
| SYNC-2 | Run `tests/test_core.m` and `tests/smoke_gui.m`, fix failures | DONE | Both pass in MATLAB R2024a (see README section 5) |
| README.md | How to run in 3 steps, min MATLAB version, assumptions (D1–D7), limitations, R1–R12 traceability table | DONE | Also lists what was executed vs only written |
| `docs/REPORT_DRAFT.md` | Persian, 3–4 pages: objective, theory (Sec 3), software design, user guide, validation table (>=6 cases), figures, limitations, screenshot placeholders | DONE | Validation rows cross-referenced with `docs/VALIDATION.md` |
| Stretch | 3D ray view, Poynting vector arrows, GIF export | NOT DONE | Deliberately skipped (the spec allows it only if everything else passes); documented as a limitation in README section 6 |

---

## Deviation Log

*Each worker ticks its items and adds a one-line note on any deviation from CONTRACT.md here.*

1. **`core/em_constants.m` added** — not in the contract's file list, but the
   contract also demands "physical constants defined in one place"; a dedicated
   function is the only way to do that without a global variable or duplicated
   literals. `em_defaults` exposes them as `P.const`.
2. **Additive struct fields** (nothing the contract requires was changed):
   `em_solve` adds `sin_i`, `cos_i`, `theta_i_rad`, `RplusT`, `vx`, `P`;
   `em_fields` adds `E1/H1`, `E2/H2` (unmasked totals), `Sz`, `Sz1`, `Sz2`,
   `wave`, `S`; `em_standing_wave` adds `GE`, `GH`, `alpha`, `z2/Eenv2/Henv2`,
   `lambda1`, `cos_i`, `kz1`; `em_angle_sweep` adds `absGamma_TE/TM`,
   `phaseGamma_TE/TM_deg`, `regimeTE/TM`, `STE/STM`.
3. **Standing-wave envelope convention** — the contract quotes `abs(Ey)` for TE
   and `eta1*abs(Hy)` for TM; the code returns the physical envelopes of the
   dominant components (TE: `|Ey|`, `|Hx|`; TM: `|Ex|`, `|Hy|`) *and* the two
   reference coefficients `W.GE = Gamma`, `W.GH = -Gamma`. Using `-Gamma` for the
   H envelope makes the Section 3.7 node/antinode rule hold for both
   polarizations simultaneously and reproduces the PEC result exactly.
4. **`P.view` extras** (`win_x`, `phi0`, `e_comp`, `h_comp`) were added for the
   GUI; `em_defaults` validates window size, grid size, speed and the dphi step
   (e.g. `Nx = 77` is rejected), as the contract requires.
5. **GUI API** — `gui/EM_VirtualLab.m` exposes `EM_VirtualLab('selftest')` as
   required by B8, plus `selectTab`, `renderPng`, `theoryMode`, `params`,
   `solve`, `rendered`, `stepFrames`, `setPol`, `applyPreset`, `applyParams`
   through a small API struct used by `smoke_gui.m` and `gen_report_figures.m`.
6. **Test-suite corrections found while running** (kept here because they are
   physics lessons, not cosmetics): T7's first version asserted that the
   evanescent track is *faster* than `c`; it is not — under total reflection
   `vx = c/(n1 sin theta_i) < c/n2`, and the corrected test asserts that. The
   grazing check now allows for the `O(cos theta_i)` approach, and `chkEq`
   treats `Inf = Inf` / `NaN = NaN` as equal (PEC SWR, "angle does not exist").
   One real core bug was found this way: the phase-velocity-along-x array was
   assigned with a length-mismatched mask and threw for vector angles.

7. **Bug found from a user screenshot of the running app (PEC, TM, 49 deg):
   the Field Animation status line reported `max|E| = 0 V/m` and
   `max|H| = 0 A/m`.** Cause: the readout was hard-wired to the TE-dominant
   components `E_y`/`H_x`, which are identically zero in TM mode, where the
   plotted components are `E_x`/`H_y`. Fix: the status line now reports the
   maxima of the *selected* components (via `selInfo`/`compLabel`). Verified by
   reading the label back out of the running app: air->glass 45 deg TE gives
   `max|E_y| = 1.303` (= 1+|Gamma|), Brewster TM gives `max|E_x| = 0.5547`
   (= cos(theta_B)), PEC 45 deg TE gives `max|E_y| = 2`, PEC 45 deg TM gives
   `max|E_x| = 1.414` (= 2cos 45 deg) and `max|H_y| = 0.005309` (= 2/eta0 =
   |Js|). A TM-mode GUI screenshot (`figures/fig6_gui_fields_pec_tm.png`) was
   added to the generated set so the case stays covered by the report figures.

8. **Media are now entered directly (user request): the old single `eps_r` field
   and the 'Incidence from: Air / Dielectric' dropdown were replaced** by six
   inputs — `eps_r1, mu_r1, sigma1` and `eps_r2, mu_r2, sigma2` — plus a 'Quick
   material (medium 2)' dropdown and a 'Swap media 1 <-> 2' button (the way to
   reach total reflection with any pair). `em_defaults` validates
   `eps_r, mu_r in (0,1e4]` and `sigma in [0,1e9]` S/m. The core was extended to
   **complex permittivity/permeability**: `eps_c = eps_r - j*sigma/(omega*eps0)`,
   `n = sqrt(eps_c*mu_r)`, `eta = eta0*sqrt(mu_r/eps_c)`, loss tangent, `alpha`
   and skin depth; new regimes `lossy`; new presets 8-10 (FR-4, sea water,
   ferrite). Verified by the new tests **T11 and T12** and by 11 new rows in
   `docs/VALIDATION.md`.
9. **Power fraction T needed two forms.** With a complex `eta2` the transmitted
   time-average flux is `0.5|tau|^2 Re(cos_t/eta2)` for **TE** but
   `0.5|tau|^2 Re(cos_t/conj(eta2))` for **TM** (the `cos_t` factor sits on the
   E side only for TM). Both reduce to the textbook
   `|tau|^2 (eta1/eta2) cos_t/cos_i` for real `eta`, which is why the lossless
   tests T2-T10 were unaffected. Only the correct pair keeps `R + T = 1`
   exactly for a lossy half-space (verified to 1e-12 in both polarizations);
   the first version used the TE form for both and left a 4e-4 deficit. This is
   documented in `README.md` (limitations) and in the theory map.
10. **Brewster angle for magnetic media.** With `mu1 != mu2` the closed form
   `atan(n2/n1)` no longer applies, so `em_solve` now minimises `|Gamma|` with a
   coarse scan refined by `fminbnd` and reports the angle only if `|Gamma|`
   reaches zero (< 1e-6). For `eps_r = 2.25, mu_r = 4` this finds the **TE**
   Brewster angle at 43.0887 deg (closed form `cos^2 = 8/15`) while TM has none
   — the opposite of the non-magnetic case. A lossy medium never reaches zero,
   so it correctly reports "none".
11. **Bug found from a user screenshot, then two more from the new tests.**
   (a) The Field Animation status line hard-wired `E_y`/`H_x`, so in TM mode it
   printed `max|E| = 0`; it now reports the components actually plotted
   (verified: PEC/TM 45 deg -> `max|E_x| = 1.414` = 2cos45 and
   `max|H_y| = 0.005309` = 2/eta0 = |Js|).
   (b) `clampfld` shifted the lower limit by +1e-9, so `sigma = 0` silently
   became `1e-9 S/m` on any widget change: every medium turned "lossy" and
   `theta_t` became complex/NaN. Clamping no longer shifts limits.
   (c) The panel printed `theta_t = NaN deg` for lossy media; it now says
   "complex (attenuated medium)".
12. **Callback robustness.** All 21 widget callbacks are registered as DIRECT
   nested-function handles (`@onEpsChanged`) instead of anonymous wrappers
   (`@(~,~) onEpsChanged()`). The wrappers made MATLAB fail to resolve the
   callback ("Unable to find function @(~,~)closeApp() within ...m") once the
   .m file had been edited while the GUI was open — which left the window
   unclosable. `getCallback(name)` exposes the handle map so the smoke test can
   fire every callback, and the selftest now closes the app through the window's
   own `CloseRequestFcn`. NOTE for the user: after any edit of
   `gui/EM_VirtualLab.m`, restart the app (the running session keeps the old
   parsed file); a stuck window can be removed with
   `delete(findall(groot,'Type','figure'))`.
13. **k-vector arrows removed on the user's request.** The Field Animation maps
   no longer draw arrows for `k_i, k_r, k_t`; a text block gives the propagation
   directions and angles, the status strip below the maps has three lines
   (phase/frequency/lambda0/regime, then theta_i/theta_r/theta_t, then the
   maxima of the plotted components), and the in-plane quiver overlay is now
   off by default.

14. **Left control panel overflowed (user report: the bottom buttons could not be
    reached and the panel did not scroll).** A `uigridlayout` inside a scrollable
    `uipanel` squeezes its 'fit' rows instead of scrolling, so adding the six
    medium inputs pushed Play/Pause, the presets and Reset out of sight. Fix:
    the six medium constants moved to their own **Media tab** (with a computed
    report box and the constants' explanation), the display settings (waves
    shown, quiver, E/H component dropdowns, window size) moved to a **toolbar at
    the top of the Field Animation tab**, and the left panel was compacted
    (row spacing 2 px, Frequency/angle buttons/maps on shared rows, shorter
    notes). Measured afterwards: the panel content is 781 px high inside a
    786 px panel, and the Play button sits at y = 419..442 px — everything is
    visible with no scrolling. The smoke test (47 checks) and all report
    screenshots were regenerated after the change.
15. **Persian docs were re-synced** after the layout change: the guide and the
    report now describe five tabs, the Media tab (not the old left-panel MEDIA
    block), and the Field Animation toolbar.

16. **The special-angle buttons now explain themselves (user report: "Go to
    critical angle" was greyed out and there was no way to know why).** The
    buttons are physically conditional — a critical angle needs two lossless
    media with n1 > n2, a Brewster angle needs the right polarization — so a
    bare disabled button is a dead end. Their labels now carry the state:
    `critical 41.81 deg` / `critical: needs n1 > n2` / `critical: n/a (PEC)` and
    `Brewster 56.31 deg` / `Brewster 56.31 deg for TM` (when only the other
    polarization has one, e.g. TE in the non-magnetic case or TM with
    `mu_r != 1`) / `Brewster: none here`, plus tooltips on all three buttons
    explaining the condition and pointing at *Swap media 1 <-> 2*. Verified by
    reading the states back out of the running app for seven configurations
    (air->glass TE/TM, glass->air TE/TM, magnetic TE/TM, PEC).

17. **Standing Wave tab: the instantaneous (blue) curve left the axes (user
    report).** Three defects behind one symptom:
    (a) the y-window was `[0, 1.15*max(envelope)]`, so the SIGNED instantaneous
    curve was clipped as soon as it went negative - it looked like the wave dove
    out of the box and came back. The window is now symmetric (`±1.15*max`) with
    a thin `y = 0` reference line;
    (b) for `z > 0` the plot showed the analytic continuation of the medium-1
    formula instead of the transmitted wave; it now draws the transmitted
    envelope (`|tau| exp(-alpha z)`, decaying under total reflection or in a
    lossy medium) and the transmitted instantaneous wave;
    (c) in PEC mode the medium-2 part was evaluated as `tau*exp(-j*kz2*z)` with
    `kz2 = NaN` (i.e. `0*NaN`) -> the whole curve became NaN. For a PEC the
    medium-2 field is now an exact zero.
    Also fixed: the H plot's title printed the E component (it said 'Ey' for
    both plots); it now names the component actually plotted (Hx for TE, Hy for
    TM). **The smoke test gained a permanent regression check** inside
    `checkRendered`: every point of the instantaneous standing-wave curve must
    be finite and inside its axes' YLim, and the axes must allow negative values
    - it caught the PEC `0*NaN` case immediately.

18. **Systematic bug hunt (after the user asked to focus on bugs).** A new
    diagnostic `tests/fuzz_probe.m` walks **106 states** (medium pairs including
    n<1, 1e4, 1e-3, magnetic, lossy, huge sigma, PEC with lossy/magnetic
    medium 1; eight angles in TE/TM both directions; four frequencies; all ten
    presets × both polarizations; all eight material entries; three swaps; every
    component-dropdown item; speed/window extremes; quiver on/off; and each
    single-wave display mode) and asserts that **every graphics object in the
    figure** holds finite data, that no axes/limits/clim is non-finite, that no
    table cell or user-visible string contains a literal `NaN`, and that no
    `Inf` appears in any plotted data. The first run found **six real defects**,
    all fixed:

    1. `em_fields` `maskfield` (and the `Sz` composition, and the wave selection
       in `buildCache`) built the total field as `a.*mask + b.*~mask`. For a
       strongly lossy medium 2 the analytic continuation of the transmitted wave
       is `Inf` for `z < 0`, so `Inf*0 = NaN` poisoned the whole field map
       (`Image.CData` contained NaN with `sigma2 = 1e6`). All three now use
       logical INDEXING instead of mask multiplication.
    2. The standing-wave table could show a literal `NaN`: the analytic node
       filter carries a tiny tolerance, so a node can sit a hair outside the
       plotted grid and `interp1` returned NaN. New `envAt()` helper clamps the
       position into the range and guards the result; markers and table both use
       it, and positions outside the window are dropped.
    3. A chart title literally read 'phase, NaN where the amplitude is zero' -
       now 'phase (line breaks where the amplitude is zero)'.
    4. The direction text on the animation axes printed `theta_t = NaN deg` for
       a lossy medium (no real refraction angle); it now prints
       'k_t has no real angle (sin(theta_t) = ..., attenuated medium)'.
    5. The standing-wave text box printed `angle(Gamma) = NaN` whenever
       `|Gamma| = 0` (identical media, or exactly at the Brewster angle); it now
       uses the same 'undefined' formatter as the results panel.
    6. Typing the minimum window (0.5 lambda0) was REJECTED as invalid input,
       because the GUI derives `win_x = 0.75*win_z = 0.375`, below the legal
       minimum 0.5. The derived value is now clamped to the legal range.
    Also fixed: `kz1` and `J_ s` were printed with a plain `%g`, which silently
    drops the imaginary part for a lossy medium 1; both go through `fmtnum`.

19. **New regression checks kept in the shipped suite.** `checkRendered` (used by
    `smoke_gui`) now additionally asserts that the signed instantaneous
    standing-wave curve is finite and stays inside its axes with symmetric
    limits - it caught the PEC `0*NaN` case at once. The callback smoke loop now
    fires 23 callbacks (including the material and swap-media handlers) and the
    suite runs **49 checks**.

20. **Lesson recorded:** patch with EXACT unique anchors. A fuzzy match on a
    callback list turned `'onGoCritical'` into `'onCritical'` and the smoke test
    immediately reported `Unknown callback 'onCritical'` - which is exactly the
    value of firing every registered callback in the test.

21. **Standing Wave tab: the curves were not the physical field (user: "I think
    it still has a problem").** The user was right. The instantaneous (blue)
    curves were built from the *envelope factor* `(1 +- Gamma e^{2j kz1 z})`
    alone, dropping the propagating factor `e^{-j kz1 z}` that multiplies the
    real field: the envelope was right, but the curve drawn was off by up to
    **3x** from `real(Ey e^{j phi})` (measured against `em_fields`). Two further
    defects came out while fixing it:
    * `W.Henv2` was COMPLEX for a lossy medium 2 (`abs(tau*cos_t)/eta2` with
      `abs()` around the wrong part): sea water gave `0.004295 - 0.001631i`, and
      MATLAB silently plots only the real part - i.e. a ~6% wrong envelope with
      no warning at all. The envelopes are now true magnitudes.
    * the medium-2 envelope came from the analytic medium-1 formula continued
      past the interface; it is now the transmitted envelope.
    FIX: `updateStanding` caches the exact 1-D complex phasors of the dominant
    components along `x = 0` from **the same `em_fields` code the animation tab
    uses**, and every frame draws `real(phasor * exp(1j*phi))`. The envelope is
    `abs(phasor)` - identical to the textbook
    `|1 +- Gamma exp(2j kz1 z)|` whenever medium 1 is lossless, and correct for
    lossy/magnetic media, total reflection and a PEC as well. Measured
    afterwards: `max|curve - exact field| = 0.0` and `max|curve|/envelope =
    1.0000` for 7 presets x both polarizations.
    The scaling constants `scE`/`scH` and the piecewise medium-2 formula are
    gone, so there is now only ONE place that can be wrong.
22. **New permanent invariants in the smoke test:** the instantaneous curve must
    stay inside the envelope of its own phasor (pointwise), be finite, and fit
    inside symmetric axes; plus the complex-data check added to `fuzz_probe`
    (MATLAB plots the real part of complex data without any warning, so
    "is it finite?" was not enough).

23. **Persian PDF user guide delivered** (`docs/EM_VirtualLab_UserGuide_FA.pdf`,
    25 pages, 17 embedded figures, plus the editable `.docx`). Built with
    `python-docx` (real RTL: `w:bidi` paragraphs, `w:rtl` runs, `w:cs` = Tahoma,
    `w:bidiVisual` tables) and exported through **Microsoft Word COM**
    (`ExportAsFixedFormat`, wdExportFormatPDF) because no LaTeX/wkhtmltopdf/
    pandoc/Chromium is installed on this box; Word gives correct Persian
    shaping. Section 4 is the part the user asked for: the Media tab in SIX
    states (default air->glass, swapped glass->air with the critical angle,
    lossy FR-4, sea water, magnetic mu_r = 4, and PEC) - each with its own
    screenshot and the explanation of what to read in the report box.
    `tests/gen_guide_figures.m` produces those nine guide screenshots, and
    `tests/build_guide_pdf.py` rebuilds the document. Verified: 25 pages, no
    blank page (manual page breaks were replaced by `page_break_before` on the
    level-1 headings, which is what removed a stray empty page), all 17 images
    inside the margins, Persian text present on every page.

24. **Guide PDF: the rectangles and the layout mess - root cause and fix.**
    The user reported "small rectangles all through the text". Two independent
    causes were found by measurement, not guesswork:
    * **B Nazanin contains no Latin letters at all** (checked its cmap: 'A', 'a',
      'Z' absent; digits present). Every English word inside a Persian paragraph
      was therefore typeset with the Persian font -> XeTeX logged **1934
      "Missing character" warnings** and the PDF showed boxes. In the Word build
      the same characters silently fell back to Calibri / Cambria Math / Arial,
      which is the "mixed fonts" mess.
    * The formulas were written as **Unicode text** (θ, η, Γ, √, ₁, ₂, ⁴, −, •, —)
      with **zero math mode** in the .tex; B Nazanin has none of those glyphs.
    Fixes in `tests/build_guide_tex.py`:
    1. a `texify()` layer converts every formula and symbol to real LaTeX math
       (134 math spans) and wraps every Latin run in XePersian's `\lr{}` so it
       is typeset with Times New Roman;
    2. a `glyph_safety()` pass handles what the font still lacks: hamza-above
       U+0654 -> U+06C0, Persian decimal separator U+066B -> '.', bullets ->
       `$\bullet$`, '<'/'>' -> math, '\#' -> `\lr{\#}`, em dash -> `\lr{---}`;
    3. `caption` setup moved **after** `\usepackage{xepersian}` (bidi resets it
       otherwise) with `justification=justified,singlelinecheck=false`, so
       captions are full-width, flush RIGHT (RTL) under each figure;
    4. the Word builder now writes `*_FA_word.*` and can never overwrite the
       LaTeX PDF again (that overwrite is why the user was looking at the Word
       build in the first place).
    **Verified:** XeTeX "Missing character" warnings **1934 -> 0**; 0 tofu
    markers in the extracted text; 23 pages; 17 figures; real TOC with dot
    leaders and page numbers plus a list of figures; body text justified at
    both margins (right edge 544 pt, left edge 51 pt); captions flush right.
    New audit tool: `tests/check_guide_glyphs.py`.
