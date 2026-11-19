function F = em_fields(S, X, Z)
%EM_FIELDS Complex phasors of the incident, reflected, transmitted and total
%   fields on a grid.  Section 3.4 of the project specification.
%
%   F = EM_FIELDS(S, X, Z)
%     S : SCALAR struct produced by EM_SOLVE (one incidence angle)
%     X, Z : meshgrid arrays in METRES (X = Z = meshgrid(xvec, zvec))
%
%   Fields of F, each a struct with complex arrays .x .y .z of size(X)
%     Ei Hi  incident field in medium 1
%     Er Hr  reflected field in medium 1
%     Et Ht  transmitted field in medium 2 (zero for a PEC)
%     E1 H1  incident + reflected (medium-1 total, evaluated everywhere)
%     E2 H2  transmitted (medium-2 total, evaluated everywhere)
%     E  H   physical total field: E1 where z < 0, E2 where z >= 0
%     in1 = (Z < 0), in2 = ~in1
%     Sz, Sz1, Sz2  z-component of the time-average Poynting vector
%                      Sz = 0.5*real(Ex.*conj(Hy) - Ey.*conj(Hx))   [W/m^2]
%     wave  = 1 for incident, 2 for reflected, 3 for transmitted (per-cell
%             labels used by the GUI to draw with the correct attenuation)
%     S     copy of the input solve structure
%
%   Instantaneous field (D2):  E(x,z,t) = real( E_phasor * exp(+j*phi) ),
%   phi = omega*t.  The GUI precomputes the phasors once per parameter change
%   and only evaluates real(...) per animation frame.
%
%   IMPORTANT: only kx, kz1 and kz2 appear inside the exponentials.  Under
%   total reflection theta_t does not exist and cos_t is purely imaginary, so
%   using theta_t here would produce an exponentially GROWING field.
%
%   See also EM_SOLVE, EM_STANDING_WAVE.

if numel(S.theta_i_deg) ~= 1
    error('em_fields:nonScalarS', ...
        'em_fields needs a scalar solve struct (got %d angles).', numel(S.theta_i_deg));
end
if ~isequal(size(X), size(Z))
    error('em_fields:sizeMismatch', 'X and Z must have the same size.');
end

ci = S.cos_i; si = S.sin_i;
kx = S.kx; kz1 = S.kz1;
eta1 = S.eta1;

% --- phase factors (3.4) --------------------------------------------------
fi = exp(-1i*(kx*X + kz1*Z));           % incident,   +z propagation
fr = exp(-1i*(kx*X - kz1*Z));           % reflected,  -z propagation
isPEC = S.is_PEC;
if isPEC
    ft = zeros(size(X));
else
    ft = exp(-1i*(kx*X + S.kz2*Z));     % transmitted, +z (decaying in TIR)
end

Z0 = zeros(size(X));
G  = S.Gamma;
ta = S.tau;

if strcmp(S.pol,'TE')
    % --- TE / Horizontal (perpendicular): E along y ----------------------
    Ei = mkfield(Z0,        fi,                Z0);
    Hi = mkfield(-ci*fi/eta1, Z0,               si*fi/eta1);
    Er = mkfield(Z0,        G*fr,              Z0);
    Hr = mkfield(G*ci*fr/eta1, Z0,              G*si*fr/eta1);
    if isPEC
        Et = mkfield(Z0, Z0, Z0); Ht = mkfield(Z0, Z0, Z0);
    else
        Et = mkfield(Z0, ta*ft, Z0);
        Ht = mkfield(-ta*S.cos_t*ft/S.eta2, Z0, ta*S.sin_t*ft/S.eta2);
    end
else
    % --- TM / Vertical (parallel): E in the plane of incidence -----------
    Ei = mkfield(ci*fi,     Z0,                -si*fi);
    Hi = mkfield(Z0,        fi/eta1,            Z0);
    Er = mkfield(G*ci*fr,   Z0,                 G*si*fr);
    Hr = mkfield(Z0,       -G*fr/eta1,          Z0);
    if isPEC
        Et = mkfield(Z0, Z0, Z0); Ht = mkfield(Z0, Z0, Z0);
    else
        Et = mkfield(ta*S.cos_t*ft, Z0,  -ta*S.sin_t*ft);
        Ht = mkfield(Z0, ta*ft/S.eta2, Z0);
    end
end

% --- totals ---------------------------------------------------------------
E1 = addfield(Ei, Er);   H1 = addfield(Hi, Hr);
E2 = Et;                 H2 = Ht;          % Et/Ht are already zero for a PEC

in1 = (Z < 0);
in2 = ~in1;

F.Ei = Ei; F.Hi = Hi; F.Er = Er; F.Hr = Hr; F.Et = Et; F.Ht = Ht;
F.E1 = E1; F.H1 = H1; F.E2 = E2; F.H2 = H2;
F.in1 = in1; F.in2 = in2;
F.E = maskfield(E1, E2, in1);
F.H = maskfield(H1, H2, in1);

% --- time-average Poynting vector, z component ----------------------------
F.Sz1 = 0.5*real(E1.x.*conj(H1.y) - E1.y.*conj(H1.x));
F.Sz2 = 0.5*real(E2.x.*conj(H2.y) - E2.y.*conj(H2.x));
F.Sz  = zeros(size(X));
F.Sz(in1)  = F.Sz1(in1);
F.Sz(~in1) = F.Sz2(~in1);

F.wave = 3*ones(size(X));
F.wave(in1) = 0;
F.S = S;
end

% -------------------------------------------------------------------------
function f = mkfield(x, y, z)
%MKFIELD build a vector field struct from three component arrays
f = struct('x', x, 'y', y, 'z', z);
end

function f = addfield(a, b)
%ADDFIELD component-wise sum of two vector field structs
f = struct('x', a.x + b.x, 'y', a.y + b.y, 'z', a.z + b.z);
end

function f = maskfield(a, b, in1)
%MASKFIELD total field = a in medium 1, b in medium 2
%   Logical INDEXING, not multiplication by the mask: the analytic
%   continuation of the transmitted wave grows exponentially towards z < 0, so
%   a strongly lossy medium makes it Inf there - and Inf*0 is NaN, which would
%   poison the whole field map.
f = struct();
cf = {'x','y','z'};
for k = 1:3
    v = zeros(size(in1));
    va = a.(cf{k}); vb = b.(cf{k});
    v(in1)  = va(in1);
    v(~in1) = vb(~in1);
    f.(cf{k}) = v;
end
end
