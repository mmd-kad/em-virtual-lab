function S = em_solve(P)
%EM_SOLVE Solve the plane-wave reflection/transmission problem at a planar
%   interface, for two media described by their electromagnetic constants
%   (eps_r, mu_r, sigma).  Sections 3.1-3.3, 3.5 and 3.6 of the specification,
%   extended to lossy (sigma > 0) and magnetic (mu_r ~= 1) media.
%
%   S = EM_SOLVE(P)   P is a parameter struct (see EM_DEFAULTS).  P.theta_i_deg
%   may be a VECTOR: every output field of S is then a row vector of the same
%   length (this is how the coefficient-vs-angle sweeps are produced).
%
%   Geometry (D2):  interface at z = 0, medium 1 at z < 0, medium 2 at z > 0,
%   plane of incidence = x-z plane, y perpendicular to it.
%   Time dependence exp(+j*omega*t)  =>  phasors vary as exp(-j*k.r).
%   Incident electric-field amplitude E0 = 1 V/m (all coefficients are ratios,
%   so this normalization never changes Gamma, tau, R or T).
%
%   Lossy media (sigma > 0): the complex relative permittivity
%       eps_c = eps_r - j*sigma/(omega*eps0)
%   gives a complex refractive index n = sqrt(eps_c*mu_r) and a complex
%   impedance eta = eta0*sqrt(mu_r/eps_c).  All Fresnel formulas below are kept
%   unchanged (they are algebraic in eta and cos(theta)), the transmitted wave
%   decays as exp(-alpha*z) with alpha = -imag(kz2).  The transmitted power
%   fraction T is computed from the fields, so R + T = 1 exactly at the
%   interface (the absorbed power shows up as the decay of the transmitted
%   wave inside medium 2, not as a defect of the boundary condition).
%   Note: with a complex eta the TE form uses eta2 and the TM form conj(eta2);
%   for real (lossless) eta both reduce to (eta1/eta2)*cos(theta_t)/cos(theta_i).
%
%   Output fields of S
%     media     n1 n2 eta1 eta2 k0 k1 k2 lambda0 lambda1 lambda2 omega
%               eps1c eps2c eps1 eps2 mu1 mu2 sigma1 sigma2
%               att1 att2 skin1 skin2 tan_delta1 tan_delta2
%               lossless1 lossless2 is_magnetic
%     geometry  theta_i_deg theta_r_deg theta_t_deg sin_i cos_i sin_t cos_t
%               kx kz1 kz2
%     coeffs    Gamma tau absGamma phaseGamma_deg abstau phasetau_deg R T
%               RplusT Aabs
%     special   theta_B_deg theta_B_src theta_c_deg is_TIR alpha delta vx
%     regime    'normal' | 'oblique' | 'TIR' | 'lossy' | 'PEC'  (cell if vector)
%     misc      pol mode is_PEC P
%
%   Sign convention (D5, Cheng/Hayt/Ulaby): Gamma and tau are E-field amplitude
%   ratios measured along the reference directions of Section 3.4, so that
%   Gamma_TE = Gamma_TM at normal incidence.  Other textbooks flip the sign of
%   the reflected E field for TM.
%
%   See also EM_DEFAULTS, EM_FIELDS, EM_ANGLE_SWEEP, EM_STANDING_WAVE.

% --- 0. defaults + validation ---------------------------------------------
P = em_defaults(P);
K = P.const;

theta = P.theta_i_deg(:).';            % row vector, deg
nth   = numel(theta);
ti    = deg2rad(theta);                % radians INSIDE the core (D2)
ci    = cos(ti);
si    = sin(ti);

omega   = 2*pi*P.f_Hz;
k0      = omega/K.c;
lambda0 = K.c/P.f_Hz;

isPEC     = strcmp(P.mode,'pec');
lossless1 = (P.sigma1 == 0);
lossless2 = (P.sigma2 == 0);

% --- 1. media: complex permittivity, index, impedance, wave number (3.1) --
[e1c, m1c, n1, eta1, k1, lam1, att1] = matpar(P.eps1, P.mu1, P.sigma1, omega, k0, K);
if isPEC
    % A perfect electric conductor: eta2 -> 0 and no field for z > 0.  Never
    % divide by eta2 here.
    e2c = NaN; m2c = P.mu2; n2 = Inf; eta2 = 0; k2 = Inf; lam2 = 0; att2 = NaN;
    sin_t = nan(1,nth); cos_t = nan(1,nth);
    kx  = k1*si;
    kz1 = k1*ci;
    kz2 = nan(1,nth);
    theta_r_deg = theta;
    theta_t_deg = nan(1,nth);
    Gamma = -ones(1,nth);              % tangential E = 0 at the surface
    tau   = zeros(1,nth);
    is_TIR = false(1,nth);
    theta_B_deg = NaN; theta_B_src = 'none'; theta_c_deg = NaN;
    alpha = nan(1,nth); delta = nan(1,nth);
    vx = nan(1,nth);
else
    [e2c, m2c, n2, eta2, k2, lam2, att2] = matpar(P.eps2, P.mu2, P.sigma2, omega, k0, K);

    % --- 2. Snell's law with complex arithmetic (3.2) ---------------------
    sin_t = (n1/n2)*si;                        % real even in TIR
    [cos_t, kz2] = snell_cos(n1, n2, si, k2);  % branch: transmit +z, decay +z
    kx  = k1*si;
    kz1 = k1*ci;
    theta_r_deg = theta;                       % theta_r = theta_i
    theta_t_deg = nan(1,nth);
    real_refr = (abs(imag(sin_t)) < 1e-14*max(1,abs(sin_t))) & (real(sin_t) <= 1);
    theta_t_deg(real_refr) = rad2deg(asin(real(sin_t(real_refr))));
    % total reflection: cos(theta_t) is purely imaginary AND the field decays
    is_TIR = (abs(real(cos_t)) <= 1e-12.*max(1,abs(cos_t))) & (imag(cos_t) < 0);

    % --- 3. Fresnel coefficients, eta-form (3.3) -------------------------
    [Gamma, tau] = fresnel(P.pol, ci, cos_t, eta1, eta2);

    % --- 4. special angles (3.5) -----------------------------------------
    if lossless1 && lossless2 && real(n1) > real(n2)
        theta_c_deg = rad2deg(asin(real(n2)/real(n1)));
    else
        theta_c_deg = NaN;
    end
    muSame = (P.mu1 == P.mu2);
    [theta_B_deg, theta_B_src] = brewster_angle(n1, n2, k2, eta1, eta2, P.pol, ...
        lossless1 && lossless2, muSame);

    % --- 5. z-decay in medium 2, penetration depth (3.2) ----------------
    % alpha is the decay rate of |E| along +z: it equals the textbook
    % evanescent constant under total reflection and the medium attenuation
    % for a lossy half-space.
    alpha = -imag(kz2);
    delta = inf(1,nth);
    nz = alpha > 0;
    delta(nz) = 1./alpha(nz);
    vx = inf(1,nth);
    mm = si > 0;                              % kx = 0 at normal incidence
    vx(mm) = real(omega./kx(mm));
end

% --- 6. power (3.3) -------------------------------------------------------
% R is |Gamma|^2.  T is the ratio of the time-average Poynting component
% normal to the interface:  T = |tau|^2 * Re(cos_t/eta2) / Re(cos_i/eta1).
% For real eta and cos_t this reduces to |tau|^2 (eta1/eta2) cos_t/cos_i.
R = abs(Gamma).^2;
if isPEC
    T = zeros(1,nth);
elseif strcmp(P.pol,'TE')
    % TE: the tangential E is the whole transmitted amplitude, so the
    % transmitted flux is 0.5*|tau|^2*Re(cos_t/eta2)
    T = abs(tau).^2 .* real(cos_t./eta2) ./ real(ci./conj(eta1));
else
    % TM: cos(theta_t) multiplies the E side, so the flux is
    % 0.5*|tau|^2*Re(cos_t/conj(eta2)).  For real (lossless) eta the two forms
    % are identical and reduce to |tau|^2 (eta1/eta2) cos_t/cos_i; for a lossy
    % half-space only these forms keep R + T = 1 exactly (verified to 1e-12).
    T = abs(tau).^2 .* real(cos_t./conj(eta2)) ./ real(ci./conj(eta1));
end
Aabs = 1 - R - T;                        % absorbed fraction (0 if lossless)

absGamma = abs(Gamma);
abstau   = abs(tau);
phaseGamma_deg = rad2deg(angle(Gamma));
phasetau_deg   = rad2deg(angle(tau));
% The phase is meaningless where the amplitude vanishes (Brewster angle,
% PEC transmission): report NaN so that plots can break the line there.
phaseGamma_deg(absGamma < 1e-14) = NaN;
phasetau_deg(abstau < 1e-14)     = NaN;

% --- 7. regime -----------------------------------------------------------
regime = repmat({'oblique'},1,nth);
if isPEC
    regime = repmat({'PEC'},1,nth);
else
    for q = 1:nth
        if ~lossless1 || ~lossless2
            regime{q} = 'lossy';
        elseif is_TIR(q)
            regime{q} = 'TIR';
        elseif abs(theta(q)) < 1e-12
            regime{q} = 'normal';
        else
            regime{q} = 'oblique';
        end
    end
end

% --- 8. medium constants for display -------------------------------------
skin1 = Inf; skin2 = Inf;
if att1 > 0, skin1 = 1/att1; end
if isfinite(att2) && att2 > 0, skin2 = 1/att2; end
tan1 = P.sigma1/(omega*K.eps0*P.eps1);
tan2 = P.sigma2/(omega*K.eps0*P.eps2);

% --- 9. pack -------------------------------------------------------------
S.pol   = P.pol;
S.mode  = P.mode;
S.is_PEC = isPEC;
S.P     = P;

S.n1 = n1; S.n2 = n2;
S.eta1 = eta1; S.eta2 = eta2;
S.k0 = k0; S.k1 = k1; S.k2 = k2;
S.lambda0 = lambda0; S.lambda1 = lam1; S.lambda2 = lam2;
S.omega = omega;
S.eps1c = e1c; S.eps2c = e2c; S.mu1c = m1c; S.mu2c = m2c;
S.eps1 = P.eps1; S.eps2 = P.eps2; S.mu1 = P.mu1; S.mu2 = P.mu2;
S.sigma1 = P.sigma1; S.sigma2 = P.sigma2;
S.att1 = att1; S.att2 = att2;
S.skin1 = skin1; S.skin2 = skin2;
S.tan_delta1 = tan1; S.tan_delta2 = tan2;
S.lossless1 = lossless1; S.lossless2 = lossless2;
S.is_magnetic = (P.mu1 ~= 1) || (P.mu2 ~= 1);

S.theta_i_deg = theta;
S.theta_r_deg = theta_r_deg;
S.theta_t_deg = theta_t_deg;
S.theta_i_rad = ti;
S.sin_i = si; S.cos_i = ci;
S.sin_t = sin_t; S.cos_t = cos_t;
S.kx = kx; S.kz1 = kz1; S.kz2 = kz2;

S.Gamma = Gamma; S.tau = tau;
S.absGamma = absGamma; S.phaseGamma_deg = phaseGamma_deg;
S.abstau = abstau;     S.phasetau_deg = phasetau_deg;
S.R = R; S.T = T; S.RplusT = R + T; S.Aabs = Aabs;

S.theta_B_deg = theta_B_deg;
S.theta_B_src = theta_B_src;
S.theta_c_deg = theta_c_deg;
S.is_TIR = is_TIR;
S.alpha = alpha; S.delta = delta; S.vx = vx;

S.regime = regime;
end

% =========================================================================
function [eps_c, mu_c, n, eta, k, lambda, att] = matpar(epsr, mur, sigma, omega, k0, K)
%MATPAR complex permittivity, index, impedance, wave number, wavelength and
%   attenuation constant of one medium.
eps_c  = epsr - 1i*sigma/(omega*K.eps0);    % complex relative permittivity
mu_c   = mur;                               % magnetic loss is not modelled
n      = principal(sqrt(eps_c*mu_c));       % Re(n) >= 0
eta    = principal(K.eta0*sqrt(mu_c/eps_c));% Re(eta) >= 0
k      = k0*n;
lambda = 2*pi/real(k);                      % wavelength = 2*pi/Re(k)
att    = -imag(k);                          % attenuation constant [Np/m]
end

function z = principal(z)
%PRINCIPAL pick the physically admissible square-root branch (Re >= 0)
if real(z) < 0
    z = -z;
end
end

function [cos_t, kz2] = snell_cos(n1, n2, si, k2)
%SNELL_COS cos(theta_t) and kz2 with the branch that propagates towards +z and
%   decays towards +z (the classic total-reflection pitfall).
sin_t = (n1/n2)*si;
cos_t = sqrt(1 - sin_t.^2 + 0i);
kz2   = k2*cos_t;
bad = (real(kz2) < 0) | (real(kz2) == 0 & imag(kz2) > 0);
cos_t(bad) = -cos_t(bad);
kz2(bad)   = -kz2(bad);
end

function [G, tau] = fresnel(pol, ci, ct, eta1, eta2)
%FRESNEL E-field amplitude reflection and transmission coefficients (3.3)
if strcmp(pol,'TE')
    den = eta2.*ci + eta1.*ct;
    G   = (eta2.*ci - eta1.*ct)./den;
    tau = (2*eta2.*ci)./den;
else
    den = eta2.*ct + eta1.*ci;
    G   = (eta2.*ct - eta1.*ci)./den;
    tau = (2*eta2.*ci)./den;
end
end

function [thB, src] = brewster_angle(n1, n2, k2, eta1, eta2, pol, losslessBoth, muSame)
%BREWSTER_ANGLE angle at which Gamma = 0, if it exists.
%   Lossless non-magnetic media: the closed form theta_B = atan(n2/n1) exists
%   for TM only (for TE, Gamma = 0 would require n1 = n2, i.e. no boundary).
%   Magnetic or lossy media: the angle is found by minimizing |Gamma|; if the
%   minimum is not zero (within 1e-6) no Brewster angle exists.
if losslessBoth && muSame
    if strcmp(pol,'TM')
        thB = rad2deg(atan(real(n2)/real(n1)));
        src = 'analytic';
    else
        thB = NaN;                    % TE has no Brewster angle here
        src = 'none';
    end
    return
end
% coarse scan, then refine the minimum: a 0.02 deg grid alone cannot hit the
% zero of |Gamma| closely enough to prove that the zero exists
th = 0.02:0.02:89.98;
si = sind(th);
ct = snell_cos(n1, n2, si, k2);
G  = fresnel(pol, cosd(th), ct, eta1, eta2);
[gmin, idx] = min(abs(G));
thB = NaN; src = 'none';
if idx > 1 && idx < numel(th) && gmin < 0.05
    lo = th(idx-1); hi = th(idx+1);
    fun = @(t) abs(gamma_at(t));
    thStar = fminbnd(fun, lo, hi);
    if fun(thStar) < 1e-6
        thB = thStar;
        src = 'numeric';
    end
    % a lossy medium has no exact Brewster angle: |Gamma| only has a minimum,
    % so the angle is deliberately reported as non-existent.
end

    function g = gamma_at(t)
        %GAMMA_AT |Gamma| at one incidence angle (used by fminbnd)
        [ct1, ~] = snell_cos(n1, n2, sind(t), k2);
        g = abs(fresnel(pol, cosd(t), ct1, eta1, eta2));
    end
end
