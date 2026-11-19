# Project specification (physics and requirements)

This is the frozen specification the implementation was written against:
the requirements (R1-R12), the conventions (D1-D7), the full physics of
Section 3, the verification plan (T1-T10) and the GUI contract.  It is kept
in the repository so every number the app prints can be traced to a
formula without needing any external document.

---

EM Virtual Lab (MATLAB) - Agent Implementation Plan
Fields and Waves course project: interactive virtual lab for electromagnetic wave interaction with the boundary between two media. Written for the coding agent. The physics is specified in full so that every output can be checked against textbook theory.
0. Rules for the agent
• Deliver a working MATLAB GUI app, a verified physics core, tests and docs. Correctness against textbook theory matters more than looks or code size. The student must be able to explain and defend every formula and function, so keep the code simple, modular and commented.
• Do not stop to ask questions. For anything ambiguous use the defaults in Section 2 and list them in README.md under 'Assumptions'.
• You most likely cannot run a MATLAB GUI. Therefore: keep the physics core free of GUI code and compatible with GNU Octave (run the core tests there if available), write the GUI defensively, ship a smoke-test script the student can run, and never claim the GUI works unless it was executed. Finish with an honest list of what was executed and what was only written.
• Hard rules: code, comments, identifiers and GUI strings in English and ASCII only (no Persian or other non-ASCII characters in any .m file); programmatic uifigure app, no .mlapp files; base MATLAB only, R2021a or newer; no global variables; physical constants defined in one place.
1. Requirements (from the project statement)
• R1: medium 1 is air; medium 2 is a non-magnetic dielectric (mu_r = 1, eps_r is an input) or a perfect electric conductor (PEC).
• R2: normal and oblique incidence; the user enters incidence angle and frequency.
• R3: the user selects horizontal or vertical polarization.
• R4: show incident, reflected and transmitted waves, their E and H fields and their propagation directions.
• R5: show reflection and transmission coefficients (magnitude and phase) and plot them versus incidence angle.
• R6: PEC: show the standing wave and mark nodes and antinodes of the fields.
• R7: dielectric: show reflection and refraction angles and the fields in both media.
• R8: compute the Brewster angle and the critical angle (when they exist) and mark them on the plots.
• R9: total reflection: also show the evanescent field in medium 2.
• R10: field animation with pause and speed control.
• R11: show numeric results, physical formulas and computational parameters inside the GUI.
• R12: deliver runnable software, organized commented .m files, a short technical report (3-4 pages: formulas, GUI screenshots, sample results, comparison with analytic values), a user guide and a live demo.
2. Decisions and assumptions
• D1 One app on a shared core: a single GUI with a Mode selector (Dielectric / PEC) on top of the physics core in core/. Fallback if the GUI gets too heavy: two thin launchers (EM_Lab_Dielectric, EM_Lab_PEC) calling the same core.
• D2 Conventions: SI units; time dependence exp(+jomegat), so phasors vary as exp(-j*k.r); incident amplitude E0 = 1 V/m; degrees at API boundaries, radians inside. Geometry: interface at z = 0, medium 1 at z < 0, medium 2 at z > 0, plane of incidence = x-z plane, y perpendicular to it. Plot with the z axis reversed so that medium 1 is drawn on top.
• D3 Critical angle with air as medium 1: with eps1 = 1 a critical angle exists only if eps_r < 1, yet R8 and R9 require a critical angle and total reflection. Therefore the core accepts general eps1 and eps2, and the GUI has 'Incidence from: Air / Dielectric' (default Air; 'Dielectric' sets eps1 = eps_r, eps2 = 1, which makes total reflection reachable). eps_r is accepted in (0, 100]; show a note that eps_r < 1 is not a physical passive lossless dielectric. Document this in README and report.
• D4 Polarization naming: Horizontal = TE (perpendicular, s): E parallel to the interface and perpendicular to the plane of incidence. Vertical = TM (parallel, p): E lies in the plane of incidence. Show both names in the GUI. At normal incidence TE and TM give identical coefficients and differ only in the direction of E (y for TE, x for TM).
• D5 Sign convention: Gamma and tau are E-amplitude ratios along the reference directions of Section 3.4 (Cheng/Hayt/Ulaby convention), so Gamma_TM = Gamma_TE at normal incidence. The student must confirm this matches the course textbook; other books flip the sign of Gamma_TM (and the reflected E direction in TM).
• D6 Ranges: incidence angle 0 to 89.9 deg (90 excluded because cos = 0); frequency with a MHz/GHz dropdown (default 1 GHz); the spatial window is sized in free-space wavelengths (default 3 lambda0 in x, 4 lambda0 in z) so that changing the frequency changes the axes in meters.
• D7 Lossless, non-magnetic media only (conductivity is an optional extension).
3. Physics specification (single source of truth)
3.1 Media and constants
c = 299792458; mu0 = 4e-7*pi; eps0 = 1/(mu0*c^2); eta0 = mu0*c
omega = 2*pi*f; k0 = omega/c
n_k = sqrt(eps_k); eta_k = eta0/n_k; k_k = n_k*k0; lambda_k = c/(n_k*f)     % k = 1, 2
3.2 Snell's law with complex arithmetic
kx    = k1*sin(ti)                 % tangential wavenumber, identical in both media
sin_t = (n1/n2)*sin(ti)
cos_t = sqrt(1 - sin_t.^2 + 0j)
idx = imag(cos_t) > 0; cos_t(idx) = -cos_t(idx);   % total reflection: decaying branch
cos_i = cos(ti); kz1 = k1*cos_i; kz2 = k2*cos_t; theta_r = theta_i
theta_t = asin(sin_t) if sin_t <= 1; otherwise there is no real refraction angle
Total reflection (TIR) occurs when sin_t > 1. Then cos_t = -jsqrt(sin_t^2 - 1), alpha = -imag(kz2) = k0sqrt(n1^2*sin(ti)^2 - n2^2) in Np/m, and the penetration depth is delta = 1/alpha. The evanescent wave travels along +x with phase constant kx and decays along z. Use only kx, kz1 and kz2 inside exponentials, never theta_t.
3.3 Coefficients (E-field amplitude ratios)
TE:  Gamma = (eta2*cos_i - eta1*cos_t) / (eta2*cos_i + eta1*cos_t)
     tau   = 2*eta2*cos_i / (eta2*cos_i + eta1*cos_t) = 1 + Gamma
TM:  Gamma = (eta2*cos_t - eta1*cos_i) / (eta2*cos_t + eta1*cos_i)
     tau   = 2*eta2*cos_i / (eta2*cos_t + eta1*cos_i);   1 + Gamma = tau*cos_t/cos_i
n-form (must agree): TE (n1*cos_i - n2*cos_t)/(n1*cos_i + n2*cos_t);  TM (n1*cos_t - n2*cos_i)/(n1*cos_t + n2*cos_i)
Power: R = abs(Gamma)^2;  T = abs(tau)^2*(eta1/eta2)*real(cos_t)/cos_i;  R + T = 1
3.4 Field phasors (use exactly these; they satisfy the boundary conditions)
fi = exp(-1j*(kx*x + kz1*z));  fr = exp(-1j*(kx*x - kz1*z));  ft = exp(-1j*(kx*x + kz2*z))
Vectors are [x y z] components.
TE:  Ei = [0 1 0]*fi              Hi = (1/eta1)*[-cos_i 0 sin_i]*fi
     Er = [0 Gamma 0]*fr          Hr = (Gamma/eta1)*[cos_i 0 sin_i]*fr
     Et = [0 tau 0]*ft            Ht = (tau/eta2)*[-cos_t 0 sin_t]*ft
TM:  Hi = (1/eta1)*[0 1 0]*fi     Ei = [cos_i 0 -sin_i]*fi
     Hr = -(Gamma/eta1)*[0 1 0]*fr    Er = Gamma*[cos_i 0 sin_i]*fr
     Ht = (tau/eta2)*[0 1 0]*ft       Et = tau*[cos_t 0 -sin_t]*ft
Total fields: medium 1 (z < 0) = incident + reflected; medium 2 (z >= 0) = transmitted; for a PEC the medium-2 fields are zero. Instantaneous field = real(Fexp(1jphi)) with phi = omega*t.
3.5 Special angles
• Brewster (TM only, mu1 = mu2): theta_B = atan(n2/n1); there Gamma_TM = 0 and theta_i + theta_t = 90 deg. TE has no Brewster angle.
• Critical (only if n1 > n2): theta_c = asin(n2/n1). For theta_i >= theta_c: abs(Gamma) = 1 for both polarizations and T = 0.
3.6 PEC
Medium 2 is a PEC (eta2 = 0): tau = 0, T = 0 (handle separately, never divide by eta2 = 0), Gamma_TE = Gamma_TM = -1 with the reference directions of 3.4 (tangential E_total = 0 at z = 0), no fields at z > 0. Surface current: abs(Js) = 2abs(Hi)cos_i (TE) or 2abs(Hi) (TM), with abs(Hi) = 1/eta1. Surface charge (TM only): abs(rho_s) = 2eps0*sin_i for E0 = 1.
3.7 Standing waves in medium 1 (z <= 0)
TE:  abs(Ey(z))      = abs(1 + Gamma*exp(+2j*kz1*z))
TM:  eta1*abs(Hy(z)) = abs(1 - Gamma*exp(+2j*kz1*z))     % Hy is the clean standing wave
G = Gamma for TE, G = -Gamma for TM:
  maxima where angle(G) + 2*kz1*z = 2*pi*m ;  minima where angle(G) + 2*kz1*z = (2m+1)*pi   (keep z <= 0)
SWR = (1 + abs(Gamma)) / (1 - abs(Gamma))      % infinite when abs(Gamma) = 1
PEC rule: components with a node at the surface (tangential E, normal H) have nodes at z = -mlambda1/(2cos_i) and antinodes at z = -(2m+1)lambda1/(4cos_i); components with an antinode at the surface (tangential H, normal E) are the reverse. The pattern travels along x with phase velocity c/(n1*sin_i).
3.8 Animation phase
phi advances by dphi per frame (default 2*pi/100 at speed 1x, speed slider 0.1x to 5x), independent of the real frequency; show the note 'time is slowed down' in the GUI.
4. Architecture and interface contract (freeze this first)
EM_VirtualLab/
  run_lab.m                 % adds paths and launches the GUI
  core/   em_defaults.m  em_solve.m  em_fields.m  em_angle_sweep.m  em_standing_wave.m
  gui/    EM_VirtualLab.m   (plus local functions or private/ helpers)
  tests/  test_core.m  smoke_gui.m  gen_report_figures.m
  docs/   CONTRACT.md  STATUS.md  README.md  THEORY_MAP.md  USER_GUIDE.md  REPORT_DRAFT.md
P = em_defaults()   % P.mode 'dielectric'/'pec'; P.pol 'TE'/'TM'; P.f_Hz; P.theta_i_deg; P.eps1 (=1); P.eps2; P.limits
S = em_solve(P)     % P.theta_i_deg may be a vector (sweeps). Fields of S:
  % media:    n1 n2 eta1 eta2 k0 k1 k2 lambda0 lambda1 lambda2 omega
  % geometry: theta_i_deg theta_r_deg theta_t_deg (NaN for TIR/PEC) sin_t cos_t kx kz1 kz2
  % coeffs:   Gamma tau (complex) absGamma phaseGamma_deg abstau phasetau_deg R T
  % special:  theta_B_deg (TM only, else NaN) theta_c_deg (NaN if none) is_TIR alpha delta
  % regime:   'normal' / 'oblique' / 'TIR' / 'PEC'
F = em_fields(S, X, Z)   % X, Z meshgrid arrays in meters, S scalar
  % F.Ei F.Hi F.Er F.Hr F.Et F.Ht F.E F.H : structs of complex arrays .x .y .z
  % F.in1 = (Z < 0), F.in2 = ~F.in1 ; F.E and F.H are the TOTAL fields (PEC: zero in medium 2)
W = em_standing_wave(S, z)   % z = vector in meters
  % W.z W.Eenv W.Henv (envelopes of the dominant components) W.nodes W.antinodes (analytic; .E .H)
  % W.nodes_num W.antinodes_num (local extrema) W.swr W.Js W.rho_s (PEC)
C = em_angle_sweep(P, theta_deg)   % C.theta_deg; C.TE and C.TM each with Gamma tau R T; C.theta_B_deg; C.theta_c_deg
5. Work split: two parallel lists
Step S0 (lead): create the folder skeleton, docs/CONTRACT.md (copy of Section 4), docs/STATUS.md (both lists below as checkboxes; each worker ticks its items and adds a one-line note on any deviation) and stub functions that return correctly shaped structs with NaN values. After S0 the two lists run in parallel. File ownership: List A owns core/, tests/test_core.m and tests/gen_report_figures.m; List B owns gui/, run_lab.m and tests/smoke_gui.m. Never edit a file owned by the other list; request signature changes through CONTRACT.md. If your harness has no parallel workers, run List A first (it is the correctness-critical part), then List B.
LIST A - Physics core and verification
• A1 em_defaults and input validation (eps in (0,100], theta in [0,89.9], f in [1e6,1e11]). Done when bad input raises a clear error.
• A2 em_solve: Sections 3.1-3.3, 3.5, 3.6, vectorized over theta. Done when T1, T2, T5, T6, T7 pass.
• A3 em_fields: Section 3.4, vectorized, no loops. Done when T3 and T4 pass.
• A4 em_angle_sweep. Done when T10 passes.
• A5 em_standing_wave: Section 3.7 plus PEC surface current and charge. Done when T8 and T9 pass.
• A6 tests/test_core.m: tests T1-T10 (Section 6), prints a PASS/FAIL table, errors if any test fails.
• A7 tests/gen_report_figures.m: headless PNG figures (200 dpi) and a markdown table analytic vs numeric for the Section 6 cases: coefficient curves (air to glass; glass to air with the TIR region), PEC standing wave, evanescent decay.
• A8 docs/THEORY_MAP.md: for each equation of Section 3 the function that implements it and a short physical explanation, plus short answers to the Section 9 questions.
LIST B - GUI and visualization
• B1 Layout skeleton: programmatic uifigure with uigridlayout; left control panel; right tab group: Field Animation / Standing Wave / Coefficients vs Angle / Results and Theory. Runs against the stubs.
• B2 Controls and validation (7.1): synced edit field and slider, invalid input rejected with a message and the previous value restored, mode-dependent enabling, presets, Reset.
• B3 Animation engine: one timer, phase phi, Play/Pause, speed slider. Precompute complex phasor grids when parameters change; each frame only updates CData / UData / VData / YData; stop and delete the timer in CloseRequestFcn.
• B4 Field Animation tab (7.2). B5 Standing Wave tab (7.3). B6 Coefficients tab (7.4). B7 Results and Theory tab (7.5).
• B8 tests/smoke_gui.m: build the app with Visible off, loop over all presets and both polarizations, step 30 frames each, check for errors and NaN in displayed data, close the app, print SMOKE TEST PASSED. The app exposes a test entry such as EM_VirtualLab('selftest').
• B9 docs/USER_GUIDE.md: step-by-step guide per mode, drafted in Persian, with [SCREENSHOT: ...] placeholders.
Dependencies: B1-B3 need nothing from List A. B4-B7 need A2-A5; at SYNC-1 (A1-A5 pass) replace the stubs with the real core.
Phase 3 - Integration (lead)
SYNC-2: run tests/test_core.m and tests/smoke_gui.m, fix failures, write README.md and docs/REPORT_DRAFT.md (Section 8), go through Section 11. Stretch (only if everything passes): 3D ray view with oscillating E and H vectors along each ray, Poynting vector arrows, GIF export of the animation for the report.
6. Verification plan (tests/test_core.m)
Tolerance 1e-12 for identities, 5e-4 for rounded reference values.
• T1 Constants and media: n, eta, k, lambda for eps = 1 and 2.25.
• T2 Reference values. Air to glass (eps_r = 2.25, n = 1.5): normal incidence Gamma = -0.2, tau = 0.8, R = 0.04, T = 0.96, SWR = 1.5, abs(E) minimum at z = 0 and first maximum at z = -lambda1/4; at 45 deg Gamma_TE = -0.3033 and Gamma_TM = -0.0920; theta_B = 56.31 deg, Gamma_TM(theta_B) = 0, theta_t = 33.69 deg. Glass to air: theta_c = 41.81 deg; at 60 deg abs(Gamma) = 1 for both polarizations, T = 0, alpha = 0.8292k0, delta = 0.1919lambda0. PEC normal incidence: Gamma = -1, Eenv = 2abs(sin(kz)), E nodes at z = -m*lambda/2.
• T3 Boundary conditions evaluated on the FIELD arrays at z = 0- and 0+ (random theta, eps, polarization, including TIR): tangential E and H continuous, eps*Ez and Hz continuous (error < 1e-12); PEC: tangential E_total = 0.
• T4 Power: R + T = 1 (R = 1, T = 0 under TIR); the time-average Sz computed from the fields is equal on both sides of the interface.
• T5 The eta-form and n-form of Gamma agree; tau_TE = 1 + Gamma_TE; 1 + Gamma_TM = tau_TM*cos_t/cos_i.
• T6 Snell: n1sin(ti) = n2sin(tt) when not TIR; theta_r = theta_i; kx identical in both media.
• T7 Limits: Gamma_TE = Gamma_TM at theta = 0; (Gamma_TE, Gamma_TM) -> (-1, +1) as theta -> 90 deg without TIR; eps2 = eps1 gives Gamma = 0 and tau = 1 at all angles; Stokes relation Gamma(n1 to n2, ti) = -Gamma(n2 to n1, tt).
• T8 Evanescent field: imag(cos_t) < 0; abs(E) decays monotonically for z > 0 and abs(E(z+delta))/abs(E(z)) = exp(-1) within 1e-6.
• T9 Nodes and antinodes: analytic vs numeric positions agree within the grid step (PEC TE and TM at 3 angles; dielectric at normal incidence).
• T10 em_angle_sweep at one angle equals em_solve at that angle.
The student additionally checks 4-5 cases by hand (Section 8).
7. GUI specification
7.1 Controls (left panel)
• Mode: Dielectric / PEC. Incidence from: Air / Dielectric (dielectric mode only). eps_r edit field (shows n = sqrt(eps_r)). PEC mode disables eps_r and the direction switch.
• Polarization: Horizontal (TE) / Vertical (TM), with a one-line explanation under it.
• Frequency: number plus MHz/GHz dropdown. Incidence angle: edit field and slider (0 to 89.9 deg) and buttons 'Normal incidence', 'Go to Brewster', 'Go to critical' (each enabled only when it applies).
• Waves shown: checkboxes Incident, Reflected, Transmitted (all checked = total field). Window size in lambda0. Component dropdowns for the E and H maps.
• Animation: Play/Pause, speed slider, phase slider. Presets: air to glass normal; air to glass 45 deg TE; air to glass Brewster TM; glass to air 60 deg total reflection; PEC normal; PEC 45 deg TE; PEC 45 deg TM. Reset button.
7.2 Field Animation tab
• Two axes side by side, E field (left) and H field (right), z axis reversed (medium 1 on top). Each shows a signed color map of one component (the dropdown lists only the non-zero components for the chosen polarization plus the instantaneous magnitude; defaults E_y / H_x for TE and E_x / H_y for TM) with an optional quiver overlay of the in-plane vector. Diverging colormap with fixed symmetric color limits so colors do not flicker.
• Draw the interface line, the normal, region labels (Medium 1 air; Medium 2 with eps_r, or 'PEC (fields = 0)' with gray shading) and arrows for k_i, k_r, k_t labeled with theta_i, theta_r, theta_t. Under total reflection replace the k_t arrow by a dashed arrow along +x labeled 'evanescent: propagates along x, decays along z (alpha, delta)'.
• Grid: at least 10 points per smallest wavelength, 201 to 401 points per axis. Compute complex phasor grids once per parameter change; per frame compute only real(Fexp(1jphi)).
7.3 Standing Wave tab
• Instantaneous curve and envelope of the dominant E and H components versus z at x = 0 (TE: Ey and Hx; TM: Hy and Ex), node and antinode markers (analytic), a table of the first four positions in meters and in lambda units, and the SWR. Dielectric: partial standing wave in medium 1 and the transmitted wave in medium 2. Total reflection: envelope exp(-alpha*z) in medium 2 with the delta marker. PEC mode also shows abs(Js) and rho_s.
7.4 Coefficients vs Angle tab
• 2x2 axes: abs(Gamma), angle(Gamma), abs(tau), angle(tau) versus theta_i from 0 to 89.9 deg; TE and TM in different line styles (selected polarization thicker); vertical dotted lines with labels for theta_B (TM only) and theta_c; a marker at the current theta_i; phase in degrees, NaN where abs = 0; a toggle to show R and T instead. PEC mode: abs(Gamma) = 1, phase 180 deg, tau = 0.
7.5 Results and Theory tab
• Monospace numeric panel with units: f, omega, lambda0, n1, n2, eta1, eta2, k1, k2, lambda1, lambda2; theta_i, theta_r, theta_t or 'evanescent'; theta_B, theta_c or 'none'; Gamma and tau (magnitude, phase in degrees, rectangular form); R, T, R + T; SWR; first nodes and antinodes; alpha, delta and phase velocity along x (TIR); abs(Js), rho_s (PEC); regime label; computational parameters (grid size, window size, phase step).
• Formula panel: Snell, Fresnel (TE and TM), Brewster, critical angle and standing-wave relations, drawn as LaTeX text on an axes-off uiaxes (try/catch with a plain-text fallback).
7.6 Robustness
try/catch with uialert in every callback; no cla or object re-creation per frame; stop the timer on any parameter change and restart it if it was playing; handle theta = 0, theta = theta_B, theta = theta_c exactly, eps_r = 1 (no boundary) and eps_r < 1; target 15 fps or more with a 241 x 241 grid.
8. Deliverables
• Code: the tree of Section 4. README.md: how to run in three steps, minimum MATLAB version, assumptions (D1-D7), limitations, and a table 'requirement R1-R12 -> where it is shown'. Optional packaging by the student: applicationCompiler if MATLAB Compiler is available; otherwise present live with run_lab.
• docs/REPORT_DRAFT.md (Persian, 3-4 pages): objective; theory (Section 3); software design; user guide; validation table analytic vs numeric (at least 6 cases from gen_report_figures.m) with an empty column for the student's hand calculation; figures; limitations; placeholders for GUI screenshots.
• docs/THEORY_MAP.md and docs/USER_GUIDE.md as in A8 and B9.
9. Oral-defense questions (answer in THEORY_MAP.md)
1.  Why is there no Brewster angle for TE? 2) Why does Gamma_TM change sign at theta_B? 3) What is the phase of Gamma under total reflection, and is any energy transmitted? 4) Why does the evanescent wave not violate energy conservation? 5) Why must imag(cos_t) < 0 be chosen? 6) Why is Gamma = -1 and tau = 0 for a PEC, and where does the surface current come from? 7) Why is kx conserved across the interface? 8) Where are the nodes for TE and TM on a PEC? 9) Why does T need the factor (eta1/eta2)*cos_t/cos_i? 10) How is the animation phase related to real time?
10. Common pitfalls
• Wrong sqrt branch for cos_t under total reflection (field grows exponentially). Mixed degrees and radians. theta_t used inside exponentials under total reflection. Missing impedance and cosine factors in T. TM sign convention inconsistent with the field unit vectors (T3 catches it). z axis pointing up so medium 1 appears at the bottom. Graphics objects re-created every frame. A timer that outlives the app. Non-ASCII characters in .m files. theta = 90 deg. A Brewster marker on the TE curve.
11. Definition of done
• tests/test_core.m all PASS; tests/smoke_gui.m PASSED (run by the student in MATLAB); every requirement R1-R12 demonstrably covered; no non-ASCII characters in .m files; STATUS.md fully ticked; the final message lists what was executed and what was only written.