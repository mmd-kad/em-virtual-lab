# THEORY MAP — every formula of the specification, and where it lives in the code

This file is the bridge between the physics of Section 3 of `SPECIFICATION.md` and the
MATLAB code. It exists so that every number the app prints can be defended
orally: for each equation you get **the formula, the file/function that
implements it, and the physical meaning**. The last section answers the ten
oral-defence questions of Section 9.

Conventions used everywhere (D2/D5 of the contract):

* time dependence `exp(+j*omega*t)` → phasors vary as `exp(-j*k·r)`, so a wave
  travelling in `+z` is `exp(-j k_z z)`;
* interface at `z = 0`, medium 1 at `z < 0`, medium 2 at `z > 0`;
* plane of incidence = `x–z` plane, `y` perpendicular to it;
* incident amplitude `E0 = 1 V/m` (all coefficients are ratios, so this
  normalisation never affects Γ, τ, R or T);
* degrees at the API boundary, radians inside the core;
* TE ≡ Horizontal ≡ perpendicular ≡ *s*; TM ≡ Vertical ≡ parallel ≡ *p*.

---

## 1. Equation → function

| Spec | Equation / quantity | Implemented in | Physical meaning |
|------|--------------------|----------------|------------------|
| 3.1 | `c, mu0, eps0 = 1/(mu0 c^2), eta0 = mu0 c` | `core/em_constants.m` | the only place constants are defined; `eps0` and `eta0` are *derived*, never typed in twice |
| 3.1 | `omega = 2 pi f`, `k0 = omega/c`, `n_k = sqrt(eps_k)`, `eta_k = eta0/n_k`, `k_k = n_k k0`, `lambda_k = c/(n_k f)` | `core/em_solve.m` (block “media”) | plane-wave parameters in each medium; non-magnetic (`mu_r = 1`) so `n = sqrt(eps_r)` and `eta = eta0/n` |
| 3.2 | `sin(theta_t) = (n1/n2) sin(theta_i)` | `em_solve` (Snell block) | Snell's law; real even under total reflection, where only `cos(theta_t)` becomes imaginary |
| 3.2 | `cos(theta_t) = sqrt(1 - sin^2(theta_t))` with the branch `imag(cos_t) < 0` | `em_solve` (`cos_t`, `neg` lines) | **the** pitfall of the project: this branch makes the transmitted field decay into `+z` under total reflection instead of growing without bound |
| 3.2 | `kx = k1 sin(theta_i)`, `kz1 = k1 cos(theta_i)`, `kz2 = k2 cos(theta_t)` | `em_solve` | the three wave numbers that appear *inside the exponentials*; `theta_t` is never used in an exponential |
| 3.2 | `theta_r = theta_i`; `theta_t = asin(sin_t)` when real, else “no real angle” | `em_solve` | law of reflection; the refraction angle exists only when `sin(theta_t) <= 1` |
| 3.3 | TE: `Gamma = (eta2 ci - eta1 ct)/(eta2 ci + eta1 ct)`, `tau = 1 + Gamma` | `em_solve` (`denTE`, `Gamma_TE`, `tau_TE`) | amplitude reflection/transmission of the field component parallel to the interface |
| 3.3 | TM: `Gamma = (eta2 ct - eta1 ci)/(eta2 ct + eta1 ci)`, `1 + Gamma = tau ct/ci` | `em_solve` (`denTM`, `Gamma_TM`, `tau_TM`) | same for the component in the plane of incidence; note the sign convention of D5 |
| 3.3 | n-form of Γ (`n1 ci - n2 ct` etc.) | checked by test **T5** | proves the impedance form and the refractive-index form are algebraically the same; either may be quoted in the report |
| 3.3 | `R = |Gamma|^2`, `T = |tau|^2 (eta1/eta2) Re(cos_t)/cos_i`, `R + T = 1` | `em_solve` (power block) | power balance; `R + T = 1` is verified numerically in test **T4** and shown live in the Coefficients tab |
| 3.4 | `fi = exp(-j(kx x + kz1 z))`, `fr = exp(-j(kx x - kz1 z))`, `ft = exp(-j(kx x + kz2 z))` | `core/em_fields.m` | the three phasors; the sign of the `z` term is what makes `fr` travel towards `-z` |
| 3.4 | TE vectors `Ei, Hi, Er, Hr, Et, Ht` | `em_fields` (TE branch) | `E` along `y`; `H` completed by `(1/eta) k × E` with the correct signs |
| 3.4 | TM vectors `Hi, Ei, Hr, Er, Ht, Et` | `em_fields` (TM branch) | `H` along `y`; `E` in the plane of incidence |
| 3.4 | total field = incident + reflected in medium 1, transmitted in medium 2 | `em_fields` (`E1`, `E2`, `E`, masks `in1`,`in2`) | boundary conditions hold by construction — verified at machine precision in test **T3** |
| 3.4 | instantaneous field `real(F exp(j phi))` | `gui/EM_VirtualLab.m`, `renderFrame` | the animation renders `re(phasor) cos(phi) - im(phasor) sin(phi)` with cached phasors |
| 3.5 | Brewster `theta_B = atan(n2/n1)` (TM only) | `em_solve` (special-angle block) | angle at which `Gamma_TM = 0` because `theta_i + theta_t = 90 deg`; for TE no such angle exists (see Q1) |
| 3.5 | critical `theta_c = asin(n2/n1)` if `n1 > n2` | `em_solve` | angle beyond which `sin(theta_t) > 1`: total reflection, `|Gamma| = 1`, `T = 0` |
| 3.6 | PEC: `eta2 → 0`, `Gamma = -1`, `tau = 0`, `R = 1`, `T = 0`, no field for `z > 0` | `em_solve` (PEC branch) + `em_fields` (zero `Et/Ht`) | tangential E must vanish on a perfect conductor; no division by `eta2 = 0` is ever performed |
| 3.6 | surface current `|Js| = 2|Hi| cos(theta_i)` (TE), `2|Hi|` (TM); charge `rho_s = 2 eps0 sin(theta_i)` (TM) | `core/em_standing_wave.m` (`W.Js`, `W.rho_s`) | the discontinuity of the tangential H is carried by the surface current; the normal D is carried by the surface charge |
| 3.7 | `|Ey| = |1 + Gamma e^{+2j kz1 z}|` (TE), `eta1|Hy| = |1 - Gamma e^{+2j kz1 z}|` (TM) | `em_standing_wave` (`eE`, `eH`, scale factors `cE`, `cH`) | partial standing wave: incident and reflected waves interfere in medium 1 |
| 3.7 | maxima/minima where `angle(G) + 2 kz1 z = 2 pi m` / `(2m+1) pi`, `SWR = (1+|G|)/(1-|G|)` | `em_standing_wave` (`nodes`, `antinodes`, `swr`) | the reflected wave shifts the pattern by `angle(G)`; `SWR = Inf` when `|G| = 1` |
| 3.7 | PEC rule: nodes at `z = -m lambda1/(2 cos(theta_i))`, antinodes half a period away; pattern travels along `x` with `c/(n1 sin(theta_i))` | `em_standing_wave` + `em_solve` (`vx`) | follows from `G_E = Gamma = -1`; the standing pattern is not stationary, it slides along the interface |
| 3.8 | animation phase step, speed slider 0.1×–5× | `gui/EM_VirtualLab.m` (`P.view.dphi`, `onTick`, `onSpeedChanged`) | the animation advances `phi` by a fixed increment per frame, independent of `f` (see Q10) |
| ext | `eps_c = eps_r - j*sigma/(omega*eps0)` (complex permittivity of a lossy medium) | `em_solve.m`, `matpar` | conductivity is a loss current in phase with E; it appears as a negative imaginary part of the permittivity. `sigma = 0` gives back the real `eps_r` of the course |
| ext | `n = sqrt(eps_c*mu_r)`, `eta = eta0*sqrt(mu_r/eps_c)` (branch `Re >= 0`) | `matpar`, `principal` | the refractive index and the wave impedance of a lossy/magnetic medium; the square-root branch is fixed so that `n' > 0` (propagation) and `n'' < 0` (decay) |
| ext | `tan(delta) = sigma/(omega*eps0*eps_r)`, `alpha = -Im(k)`, `delta_s = 1/alpha` | `em_solve` (`tan_delta1/2`, `att1/2`, `skin1/2`) | loss tangent, attenuation constant and skin depth of each medium; inside the medium `|E| ~ exp(-alpha z)` and the power `~ exp(-2 alpha z)` |
| ext | transmitted power `T`: `\|tau\|^2 Re(cos_t/eta2)/Re(cos_i/conj(eta1))` (TE), `\|tau\|^2 Re(cos_t/conj(eta2))/Re(cos_i/conj(eta1))` (TM) | `em_solve` (power block) | the exact ratio of the time-average Poynting components; for real (lossless) `eta` both collapse to `\|tau\|^2 (eta1/eta2) cos_t/cos_i`, and this is what keeps `R + T = 1` exact for a lossy half-space (see Q13) |
| ext | Brewster angle for `mu1 != mu2` or lossy media: minimise `\|Gamma(theta)\|` (coarse scan + `fminbnd`), report it only if the minimum reaches zero | `em_solve`, `brewster_angle` | with magnetic media the closed form `atan(n2/n1)` is invalid and *TE* can have the Brewster angle instead of TM; a lossy medium never reaches zero, so it reports "none" |
| — | coefficient curves versus angle | `core/em_angle_sweep.m` | calls `em_solve` twice (TE and TM) on a vector of angles; consistency with a single solve is proved by test **T10** |

## 2. Verification map (what proves what)

| Test | Physics statement it proves |
|------|-----------------------------|
| T1 | constants are self-consistent (`eps0 mu0 c^2 = 1`, `eta0 = mu0 c`); media relations for `eps = 1` and `2.25`; all invalid inputs are rejected with a clear error |
| T2 | the textbook reference values: `Gamma = -0.2`, `tau = 0.8`, `R = 0.04`, `T = 0.96`, `SWR = 1.5`; `Gamma_TE(45°) = -0.3033`, `Gamma_TM(45°) = -0.0920`; `theta_B = 56.31°` with `Gamma_TM = 0` and `theta_i + theta_t = 90°`; `theta_c = 41.81°`; at 60° glass→air `|Gamma| = 1`, `T = 0`, `alpha = 0.8292 k0`, `delta = 0.1919 lambda0`; PEC `|E| = 2|sin(kz)|` with nodes at `z = -m lambda/2` |
| T3 | boundary conditions evaluated **on the computed field arrays**: tangential E and H continuous, `eps1 Ez1 = eps2 Ez2`, `Hz1 = Hz2` (max jump ≤ 6e-16), including total reflection and PEC |
| T4 | `R + T = 1` for both polarizations, `R = 1`, `T = 0` under total reflection, and the time-average Poynting `z` component is the same on both sides of the interface |
| T5 | η-form and n-form of Γ agree exactly; `tau_TE = 1 + Gamma_TE`; `1 + Gamma_TM = tau_TM cos_t/cos_i` |
| T6 | Snell's law, `theta_r = theta_i`, and `kx` identical in both media |
| T7 | limits: `Gamma_TE = Gamma_TM` at `theta = 0`; `(Gamma_TE, Gamma_TM) → (-1, +1)` at grazing without total reflection; `eps2 = eps1` gives `Gamma = 0`, `tau = 1` at all angles; Stokes relation `Gamma_12(theta_i) = -Gamma_21(theta_t)`; `Gamma_TM` changes sign at `theta_B` |
| T8 | the evanescent field: `imag(cos_t) < 0`, monotone decay for `z > 0`, `|E(z + delta)|/|E(z)| = exp(-1)`, `vx = omega/kx < c/n2`, and zero average power into medium 2 |
| T9 | analytic node/antinode positions agree with the numerically detected extrema within one grid step (PEC TE/TM at 0°, 30°, 60°; dielectric at normal incidence, oblique and total reflection) |
| T10 | the angle sweep equals a single solve at the same angle (exactly), and the glass→air sweep really contains the total-reflection region |
| T11 | lossy media: `eps_c` and `tan(delta)` against their definitions, `alpha` against the standard closed form `k0 sqrt(eps_r) sqrt((sqrt(1+tan^2 d)-1)/2)`, the `exp(-alpha z)` and `exp(-2 alpha z)` decay of field and power, `R + T = 1` at the interface for both polarizations, and the boundary conditions evaluated with the *complex* permittivity |
| T12 | magnetic media: `n` and `eta` from `eps_r, mu_r`, the normal-incidence `Gamma`, the TE Brewster angle against `cos^2(theta_B) = mu1(eps2 mu2/eps1 - mu1)/(mu2^2 - mu1^2)` (8/15 -> 43.0887 deg), no TM Brewster angle for that pair, and the analytic result restored when `mu1 = mu2` |

Run them all with

```matlab
cd tests && test_core
```

## 3. Oral-defence questions (Section 9), answered

**Q1. Why is there no Brewster angle for TE?**
Because `Gamma_TE = 0` requires `eta2 cos(theta_i) = eta1 cos(theta_t)`. With
`mu1 = mu2 = mu0` this is `n1 cos(theta_i) = n2 cos(theta_t)`, and squaring it
together with Snell's law gives `n1^2 (1 - sin^2 theta_i) = n2^2 - n1^2 sin^2
theta_i`, i.e. `n1 = n2` — no boundary. Physically, for TE the electric field is
perpendicular to the plane of incidence and has no component along the
propagation direction, so the induced dipoles never radiate exactly along the
reflected direction with the right phase to cancel the reflection. For TM the
field drives dipoles *along* their axis, and when `theta_i + theta_t = 90°` that
radiation is directed exactly along the interface, so nothing is reflected. In
the app the *Go to Brewster* button and the `theta_B` marker are therefore
enabled/displayed for TM only (marking `theta_B` on the TE curve is a classic
mistake).

**Q2. Why does `Gamma_TM` change sign at `theta_B`?**
`Gamma_TM` is real here (lossless media). Below `theta_B` it is small and
negative, with the normal-incidence value `(eta2 - eta1)/(eta2 + eta1) < 0` for
`n2 > n1`; above `theta_B` it becomes small and positive and tends to `+1` at
grazing (T7 checks both the sign change and the limits). The zero in between is
the Brewster angle. Because of the sign convention of D5, other textbooks that
measure the reflected TM field along `-x` quote the opposite sign — the physical
statement (no reflected wave at `theta_B`) is the same.

**Q3. What is the phase of `Gamma` under total reflection, and is any energy
transmitted?**
`|Gamma| = 1` for both polarizations, so `Gamma = exp(j phi_R)`: the reflected
wave carries *all* the incident power, but with a phase that runs continuously
from 0 at `theta_c` to `pi` at grazing. That non-zero phase slope is what
produces the Goos–Hänchen lateral shift of a finite beam. No average energy is
transmitted: `T = |tau|^2 (eta1/eta2) Re(cos_t)/cos_i = 0` because
`Re(cos_t) = 0` (`cos_t` is purely imaginary), which the app shows as `T = 0`,
`R = 1` and is verified by tests T4 and T8.

**Q4. Why does the evanescent wave not violate energy conservation?**
It is a *reactive* (stored) field. The transmitted phasor is
`exp(-j kx x) exp(-alpha z)`: its amplitude decays with depth, its phase advances
along the interface, and the time-average Poynting component *perpendicular to
the interface* is exactly zero, so no real power crosses the boundary — T8
checks `max|Sz2| < 1e-12`. The instantaneous `Sz` oscillates in and out, which is
how energy is temporarily stored in the near field and returned to the reflected
wave. Consistently, the phase velocity along the interface,
`vx = omega/kx = c/(n1 sin theta_i)`, is smaller than the wave speed in medium 2
(`c/n2`), so the pattern cannot "run away" and radiate.

**Q5. Why must `imag(cos_t) < 0` be chosen?**
The field in medium 2 is `E ~ exp(-j kz2 z)` with `kz2 = k2 cos(theta_t)` and
`z > 0` pointing away from the source. If `cos(theta_t)` were `+j·sqrt(...)`,
then `exp(-j kz2 z) = exp(+alpha z)` would grow without bound with depth — an
inadmissible solution (infinite energy, no radiation condition). Choosing the
negative imaginary root gives `exp(-alpha z)`, a decaying (evanescent) field.
The code performs this branch flip explicitly (`neg = imag(cos_t) > 0; cos_t(neg)
= -cos_t(neg)` in `core/em_solve.m`) and test T8 asserts the sign and the decay.

**Q6. Why is `Gamma = -1` and `tau = 0` for a PEC, and where does the surface
current come from?**
Inside a perfect conductor `E = 0`, so the tangential E must vanish at the
surface: `Ei,tang + Er,tang = 0` — with the reference directions of Section 3.4
this is exactly `Gamma = -1` (both polarizations), and since no field can exist
inside, `tau = 0`, `R = 1`, `T = 0`. The incident field also drives a tangential
magnetic field, and the magnetic boundary condition `n × (H2 - H1) = Js` means
the discontinuity across the surface is carried by a surface current
`|Js| = 2|Hi| cos(theta_i) = 2cos(theta_i)/eta0` for TE and
`|Js| = 2|Hi| = 2/eta0` for TM (the app prints it, e.g. `0.005309 A/m` in air at
normal incidence). For TM there is additionally a normal E at the surface, so a
surface charge `rho_s = 2 eps0 sin(theta_i)` appears; TE has `rho_s = 0`.

**Q7. Why is `kx` conserved across the interface?**
Because the boundary conditions must hold for *every* `x` at `z = 0` and for all
times: the spatial dependence `exp(-j kx x)` and the time factor must match
term by term, otherwise the equality could not hold at all `x`. Hence
`kx = k1 sin(theta_i) = k2 sin(theta_t)`, which *is* Snell's law and explains why
the transmitted wave is bent (its total wave number changed, so its direction
must change). It also remains true under total reflection, where `kx` stays real
while `kz2` becomes imaginary — that real `kx` is what makes the evanescent wave
propagate along the interface.

**Q8. Where are the nodes for TE and TM on a PEC?**
The rule (Section 3.7) is: field components that have a node at the surface stay
nodal every half period, and components that have an antinode at the surface stay
anti-nodal every half period. On a PEC the *tangential* E (Ey for TE, Ex for TM)
and the *normal* H (Hz) vanish at `z = 0`, so they have nodes at
`z = -m lambda1/(2 cos(theta_i))`; the *tangential* H (Hx for TE, Hy for TM) and
the *normal* E (Ez, TM only) have antinodes at the surface and nodes half a
period away (at `z = -(2m+1) lambda1/(4 cos theta_i)`). The `/cos(theta_i)` is
the oblique-incidence correction: the effective wavelength along `z` is
`lambda1/cos(theta_i)`. Test T9 checks the analytic positions against the extrema
detected numerically on the grid, and the Standing Wave tab marks both.

**Q9. Why does `T` need the factor `(eta1/eta2) cos(theta_t)/cos(theta_i)`?**
Because `T` is defined as the ratio of *real power* crossing the interface
(per unit area of the interface), not of amplitudes. The time-average Poynting
vector of a plane wave is `|E|^2/(2 eta)` normal to its own propagation
direction, so its component normal to the interface is
`|E|^2 cos(theta)/(2 eta)`. With the incident and transmitted amplitudes `E0` and
`tau E0` this gives
`T = |tau|^2 (eta1/eta2) cos(theta_t)/cos(theta_i)` — the impedance ratio comes
from the different `eta`, the cosine ratio from the different beam cross-section
at the interface. Under total reflection `cos(theta_t)` is purely imaginary, so
the real part is zero and `T = 0`. Dropping either factor breaks `R + T = 1`,
which is why test T4 checks the identity for sweeps in both directions.

**Q10. How is the animation phase related to real time?**
The instantaneous field is `real{F exp(j phi)}` with `phi = omega t`. The app
advances `phi` by a fixed increment per frame (default `2 pi/100` at speed 1×,
i.e. 100 frames per optical period), so the k-th frame shows the field at
`t = phi/omega`. At 1 GHz the real period is 1 ns, which no display can show, so
the animation is deliberately a slow-motion stroboscope: the *speed slider*
changes the phase increment per frame (0.1×…5×), and it is independent of the
frequency, so the apparent motion looks the same for every `f`. The app states
this in the GUI ("animation time is slowed down"); the slider value and the
current `phi` are printed in the Field Animation status line and in the
Parameters panel.

**Q11. Why does a lossy medium have no exact Brewster angle, and no true total
reflection?**
Both effects require *real* cancellation. `Gamma_TM = 0` needs the numerator
`eta2 cos(theta_t) - eta1 cos(theta_i)` to vanish; with a complex `eta2` (and a
complex `cos(theta_t)`, because `sin(theta_t) = (n1/n2) sin(theta_i)` is then
complex) the numerator can at best be small — the best cancellation is a minimum
of `|Gamma|`, not a zero, which is why the app reports "none" for a lossy
medium. In the same way total reflection needs `|sin(theta_t)| > 1` with a real
`sin(theta_t)`; a lossy medium 2 always gives a complex `cos(theta_t)` with a
positive real part, so the transmitted wave keeps propagating (and decaying) and
`|Gamma| < 1` at every angle. The app labels such a case `lossy`.

**Q12. Why does `R + T = 1` still hold exactly at the interface for a lossy
half-space?**
Because the boundary itself has no thickness: nothing can be absorbed inside a
zero-thickness surface, so all the power that is not reflected must enter
medium 2. Formally, in a lossless medium 1 Poynting's theorem for time-harmonic
fields gives `div<S> = -0.5 omega Im(eps)|E|^2 = 0`, so the time-average
z-component of `<S>` is constant over medium 1 and equal, by continuity of the
tangential fields, to its value at `z = 0+`, i.e. to the transmitted flux. The
absorption then shows up *inside* medium 2, as the `exp(-2 alpha z)` decay of the
transmitted power — the app shows exactly that in the lossy preset, and T11
checks both statements (`R + T = 1` at the boundary and the decay with depth).
This is a nice counter-example to the intuition "loss means `R + T < 1`".

**Q13. Why do TE and TM need different conjugations in the transmitted power?**
Because the tangential field pair that forms `E x H*` is not the same in the two
polarizations. For TE the tangential E is the *whole* transmitted amplitude
(`Et.y = tau`) and the tangential H carries the `cos(theta_t)` factor
(`Ht.x = -tau cos_t/eta2`), so `Sz_t = -0.5 Re(Et.y conj(Ht.x))` yields
`0.5|tau|^2 Re(cos_t/eta2)`. For TM the `cos(theta_t)` sits on the E side
(`Et.x = tau cos_t`) while `Ht.y = tau/eta2`, so
`Sz_t = 0.5 Re(Et.x conj(Ht.y)) = 0.5|tau|^2 Re(cos_t/conj(eta2))`. For a real
(lossless) `eta` the two expressions coincide — which is why all the lossless
textbook results are unchanged — but with a complex `eta` only the correct pair
makes `R + T = 1` come out exactly (verified to 1e-12 for both polarizations).

**Q14. Why can a *magnetic* medium have a TE Brewster angle (and lose the TM
one)?**
The TM condition `Gamma_TM = 0` is `eta2 cos(theta_t) = eta1 cos(theta_i)`;
squaring it with Snell's law (`eps1 mu1 sin^2 theta_i = eps2 mu2 sin^2 theta_t`)
gives `cos^2(theta_B) = eps1(eps1 mu1 - eps2 mu2) / (mu1(eps1^2 - eps2^2))`. With
the non-magnetic values this reduces to `eps1/(eps1+eps2)` — always a valid
angle, which is the familiar TM Brewster angle. It is not always in `(0,1)`
though: for `eps1 = 1, eps2 = 2.25, mu1 = 1, mu2 = 4` it gives `1.969 > 1`, so no
TM angle exists. The TE condition `eta2 cos(theta_i) = eta1 cos(theta_t)` gives
instead `cos^2(theta_B) = mu1(eps2 mu2/eps1 - mu1)/(mu2^2 - mu1^2)`, which for
the same numbers is `8/15` — a perfectly good angle: 43.0887 deg. Physically, a
magnetic medium changes which field component "sees" the impedance mismatch, so
the polarization that can cancel the reflection swaps. With `mu1 = mu2` the
second expression has no solution and the usual TM-only rule returns, which is
what T12 checks (`theta_B_src = 'analytic'`).
