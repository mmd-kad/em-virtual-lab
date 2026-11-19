# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-11-19

First public release.

### Added
- Physics core (`core/`): Snell's law with the correct complex square-root
  branch, Fresnel coefficients for TE and TM, Brewster and critical angles,
  total internal reflection with the evanescent field, perfect-conductor
  boundary conditions with surface current and charge, standing-wave envelopes,
  nodes/antinodes and SWR.
- Lossy media (`sigma > 0`): complex permittivity, complex index and impedance,
  loss tangent, attenuation constant and skin depth.
- Magnetic media (`mu_r != 1`): `n = sqrt(eps_r*mu_r)`, `eta = eta0*sqrt(mu_r/eps_r)`,
  and the Brewster angle found by minimising `|Gamma|` (it can move to TE).
- Programmatic `uifigure` GUI with five tabs (Media, Field Animation, Standing
  Wave, Coefficients vs Angle, Results and Theory), ten presets, animation with
  pause and speed control, and a per-medium parameter panel.
- Verification: `tests/test_core.m` (T1-T12), `tests/smoke_gui.m` (49 headless
  checks including every widget callback and the window close path),
  `tests/fuzz_probe.m` (106-state sweep).
- Report figures and the analytic-vs-computed validation table
  (`tests/gen_report_figures.m`, `docs/VALIDATION.md`).
- Persian (RTL) PDF user guide built with XeLaTeX + XePersian, B Nazanin and
  Times New Roman, with a real table of contents, list of figures and 17 figures.
- English and Persian READMEs, specification, theory map, development log.

### Fixed (during development, see `docs/STATUS.md`)
- Transmitted power fraction needed `conj(eta2)` for TM but not TE; only the
  correct pair keeps `R + T = 1` exact for lossy media.
- Field composition used mask multiplication, so a strongly lossy medium gave
  `Inf * 0 = NaN` across the map; replaced with logical indexing.
- Standing-wave "instantaneous" curves omitted the propagating factor
  `exp(-j*kz1*z)` and were therefore not the physical field; they are now taken
  from the same phasors as the animation.
- Clamping shifted `sigma = 0` to `1e-9`, silently making every medium lossy.
- Callbacks registered as anonymous wrappers broke after an on-disk edit and
  could leave the window unclosable; all callbacks are direct nested handles.
- Guide PDF: B Nazanin has no Latin glyphs, so every English word rendered as a
  rectangle; all Latin runs now use `\lr{}` and all symbols use math mode
  (1934 missing-glyph warnings -> 0).

[1.0.0]: https://github.com/mmd-kad/em-virtual-lab/releases/tag/v1.0.0
