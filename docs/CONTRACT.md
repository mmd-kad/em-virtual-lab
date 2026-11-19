# Interface Contract — EM Virtual Lab

**Source:** Section 4 of the implementation plan (frozen — do not edit without updating STATUS.md and notifying both lists).

---

## Repository Layout
```
EM_VirtualLab/
  run_lab.m                 % adds paths and launches the GUI
  core/
    em_defaults.m
    em_solve.m
    em_fields.m
    em_angle_sweep.m
    em_standing_wave.m
  gui/
    EM_VirtualLab.m         % programmatic uifigure app
  tests/
    test_core.m
    smoke_gui.m
    gen_report_figures.m
  docs/
    CONTRACT.md
    STATUS.md
    README.md
    THEORY_MAP.md
    USER_GUIDE.md
    REPORT_DRAFT.md
```

---

## Data Structures

### `P = em_defaults()`
Returns a struct with default parameters:
- `P.mode` — `'dielectric'` or `'pec'`
- `P.pol` — `'TE'` or `'TM'`
- `P.f_Hz` — frequency in Hz (default 1 GHz)
- `P.theta_i_deg` — incidence angle in degrees (default 0)
- `P.eps1` — relative permittivity of medium 1 (default 1)
- `P.eps2` — relative permittivity of medium 2 (default 2.25)
- `P.limits` — struct with validation ranges (used by GUI)

---

### `S = em_solve(P)`
**Input:** `P` (scalar or vector `theta_i_deg` for sweeps).

**Output struct `S` fields:**

| Category | Fields |
|----------|--------|
| **media** | `n1`, `n2`, `eta1`, `eta2`, `k0`, `k1`, `k2`, `lambda0`, `lambda1`, `lambda2`, `omega` |
| **geometry** | `theta_i_deg`, `theta_r_deg`, `theta_t_deg` (NaN for TIR/PEC), `sin_t`, `cos_t`, `kx`, `kz1`, `kz2` |
| **coeffs** | `Gamma`, `tau` (complex), `absGamma`, `phaseGamma_deg`, `abstau`, `phasetau_deg`, `R`, `T` |
| **special** | `theta_B_deg` (TM only, else NaN), `theta_c_deg` (NaN if none), `is_TIR`, `alpha`, `delta` |
| **regime** | `'normal'`, `'oblique'`, `'TIR'`, or `'PEC'` |

All arrays have the same length as `P.theta_i_deg`.

---

### `F = em_fields(S, X, Z)`
**Input:** `S` (scalar struct from `em_solve`), `X`, `Z` — meshgrid arrays in **meters**.

**Output struct `F` fields:**
- `F.Ei`, `F.Hi`, `F.Er`, `F.Hr`, `F.Et`, `F.Ht`, `F.E`, `F.H` — each a struct with complex array fields `.x`, `.y`, `.z`
- `F.in1` = `(Z < 0)` — logical mask for medium 1
- `F.in2` = `~F.in1` — logical mask for medium 2
- `F.E` and `F.H` are **total** fields (incident + reflected in medium 1, transmitted in medium 2; PEC: zero in medium 2)

Instantaneous field = `real(F * exp(1j * phi))` with `phi = omega * t`.

---

### `W = em_standing_wave(S, z)`
**Input:** `S` (scalar), `z` — vector in meters (typically `z <= 0` for medium 1).

**Output struct `W` fields:**
- `W.z` — input `z`
- `W.Eenv`, `W.Henv` — envelopes of the dominant field components
- `W.nodes`, `W.antinodes` — analytic positions (structs with `.E`, `.H` fields)
- `W.nodes_num`, `W.antinodes_num` — numeric local extrema
- `W.swr` — standing wave ratio
- `W.Js`, `W.rho_s` — PEC surface current and charge (TM only)

---

### `C = em_angle_sweep(P, theta_deg)`
**Input:** `P` (base params), `theta_deg` — vector of incidence angles.

**Output struct `C` fields:**
- `C.theta_deg` — copy of input
- `C.TE`, `C.TM` — each a struct with `Gamma`, `tau`, `R`, `T` (arrays matching `theta_deg`)
- `C.theta_B_deg` — Brewster angle (TM)
- `C.theta_c_deg` — Critical angle (NaN if none)

---

## Sign Convention (Section 3.4 / D5)
- Time dependence `exp(+j*omega*t)` → phasors vary as `exp(-j*k·r)`
- `Gamma` and `tau` are **E-field amplitude ratios** along the reference directions of Section 3.4 (Cheng/Hayt/Ulaby convention)
- `Gamma_TM = Gamma_TE` at normal incidence
- Student must confirm this matches course textbook; other books flip sign of `Gamma_TM`

---

## Coordinate System (D2)
- Interface at `z = 0`, medium 1 at `z < 0`, medium 2 at `z > 0`
- Plane of incidence = x-z plane, y perpendicular to it
- Plot with z axis reversed so medium 1 is drawn on top

---

## Polarization Naming (D4)
- Horizontal = TE (perpendicular, s): E parallel to interface, perpendicular to plane of incidence
- Vertical = TM (parallel, p): E lies in plane of incidence
- GUI shows both names
- At normal incidence: TE and TM give identical coefficients, differ only in E direction (y for TE, x for TM)

---

## Media (D1, D3)
- Medium 1: air (`eps1 = 1`) by default; GUI has "Incidence from: Air / Dielectric"
- Medium 2: non-magnetic dielectric (`mu_r = 1`, `eps_r` input) or PEC
- Core accepts general `eps1`, `eps2`; `eps_r` in `(0, 100]`
- Note: `eps_r < 1` is not a physical passive lossless dielectric — documented in README/report

---

## Version
MATLAB R2021a or newer; base MATLAB only; no global variables; physical constants defined in one place.

---

## Addendum (implementation notes, 2026-11-18)

The interfaces above are unchanged; two items were added while implementing and
are recorded in `STATUS.md` → Deviation Log:

1. `core/em_constants.m` holds `c`, `mu0`, `eps0`, `eta0` — required by the rule
   "physical constants defined in one place" and impossible to satisfy without a
   global variable otherwise. `em_defaults` exposes them as `P.const`, so the
   GUI and the tests read the same numbers as the core.
2. Extra (purely additive) struct fields are documented in `STATUS.md`. The ones
   that matter for the GUI/tests are:
   - `S.P` (the validated parameter struct), `S.RplusT`, `S.vx`, `S.sin_i`,
     `S.cos_i`, `S.theta_i_rad`;
   - `F.E1/H1` and `F.E2/H2` = the medium-1 and medium-2 totals *before* masking
     (used by test T3 to evaluate the boundary conditions at `z = 0-`/`0+`) and
     `F.Sz`, `F.Sz1`, `F.Sz2` = z-component of the time-average Poynting vector;
   - `W.GE = Gamma`, `W.GH = -Gamma` = the reference coefficients of the E and H
     envelopes, `W.z2/Eenv2/Henv2` = the medium-2 envelope on the `z > 0` part of
     the input grid, `W.alpha`, `W.lambda1`, `W.cos_i`, `W.kz1`;
   - `C.absGamma_TE/TM`, `C.phaseGamma_TE/TM_deg`, `C.regimeTE/TM`, `C.STE/STM`.

`EM_VirtualLab('selftest')` is the GUI test entry required by B8; the app also
exposes a small API struct (`selectTab`, `renderPng`, `theoryMode`, `params`,
`solve`, `rendered`, `stepFrames`, `setPol`, `applyPreset`, `applyParams`) that
`tests/smoke_gui.m` and `tests/gen_report_figures.m` use.

---

## Addendum 2 (media as electromagnetic constants, 2026-11-18)

The parameter names `eps1`/`eps2` are unchanged, but each medium is now described
by **three** constants, and the GUI edits them directly (user request):

| field | meaning | validation |
|-------|---------|-----------|
| `P.eps1`, `P.eps2` | relative permittivity `eps_r` | `(0, 1e4]` |
| `P.mu1`,  `P.mu2`  | relative permeability `mu_r` | `(0, 1e4]` |
| `P.sigma1`, `P.sigma2` | conductivity [S/m] | `[0, 1e9]` |

`sigma > 0` makes a medium lossy: the core computes
`eps_c = eps_r - j*sigma/(omega*eps0)`, `n = sqrt(eps_c*mu_r)`,
`eta = eta0*sqrt(mu_r/eps_c)` (principal branch, `Re >= 0`),
`tan(delta) = sigma/(omega*eps0*eps_r)`, `alpha_k = -Im(k_k)` and the skin depth
`delta_s = 1/alpha_k`.  The regime string can now also be `'lossy'`.

Additional output fields: `S.eps1c S.eps2c S.mu1c S.mu2c S.eps1 S.eps2 S.mu1
S.mu2 S.sigma1 S.sigma2 S.att1 S.att2 S.skin1 S.skin2 S.tan_delta1
S.tan_delta2 S.lossless1 S.lossless2 S.is_magnetic S.theta_B_src`, and
`W.nodes_analytic` (false when medium 1 is lossy, in which case the analytic
node positions are empty and only the numeric extrema are returned; `W.swr` is
`NaN` for a lossy medium 1).

**Power fraction.** `S.T` is now computed as the exact ratio of time-average
Poynting components: `|tau|^2 Re(cos_t/eta2)/Re(cos_i/conj(eta1))` for TE and
`|tau|^2 Re(cos_t/conj(eta2))/Re(cos_i/conj(eta1))` for TM.  For real (lossless)
`eta` both reduce to the textbook `|tau|^2 (eta1/eta2) cos_t/cos_i`, so the
frozen reference values of Section 6 are unaffected; for a lossy half-space only
these forms keep `R + T = 1` exact (see `docs/STATUS.md`, deviation 9).

**Brewster angle.** `S.theta_B_deg` still carries the value for `P.pol`, and
`S.theta_B_src` says how it was obtained: `'analytic'` for the lossless
non-magnetic closed form `atan(n2/n1)` (TM only), `'numeric'` when it was found
by minimising `|Gamma|` (magnetic media, where it can be the TE angle), and
`'none'` when `|Gamma|` has no zero (lossy media).  `em_angle_sweep` exposes
`C.theta_B_TE_deg` and `C.theta_B_TM_deg` separately.

**Removed on the user's request:** the `k_i/k_r/k_t` arrow graphics on the Field
Animation maps.  `P.limits` and `P.view` keep their meaning; `P.view.quiver` now
defaults to `false`.
