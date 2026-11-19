function W = em_standing_wave(S, z)
%EM_STANDING_WAVE Standing-wave quantities along z at x = 0.  Section 3.7.
%
%   W = EM_STANDING_WAVE(S, z)
%     S : scalar struct from EM_SOLVE
%     z : vector in metres.  Values z < 0 are in medium 1 (the standing wave
%         region); values z > 0 are in medium 2 and give the transmitted
%         envelope, i.e. exp(-alpha*z) under total reflection.
%
%   Envelopes of the dominant components at x = 0
%     TE: dominant E = Ey, dominant H = Hx          TM: dominant E = Ex, H = Hy
%     |Ey| = |1 + Gamma*exp(+2j*kz1*z)|             (TE)
%     |Ex| = cos_i*|1 + Gamma*exp(+2j*kz1*z)|       (TM)
%     eta1*|Hy| = |1 - Gamma*exp(+2j*kz1*z)|        (TM, the clean one)
%
%   Writing the E-field envelope as |1 + G_E*exp(+2j*kz1*z)| with G_E = Gamma,
%   the H-field envelope is the SAME expression with G_H = -Gamma.  Therefore
%     * E maxima  where angle(G_E) + 2*kz1*z = 2*pi*m
%     * E minima  where angle(G_E) + 2*kz1*z = (2m+1)*pi
%     * H nodes   = E antinodes,  H antinodes = E nodes
%   which is the rule of Section 3.7 and reproduces the PEC result
%   (nodes at z = -m*lambda1/(2*cos_i), antinodes half a period away).
%
%   Output
%     W.z W.Eenv W.Henv            envelopes on the input z grid (V/m, A/m)
%     W.GE W.GH                    the two reference coefficients (Gamma, -Gamma)
%     W.nodes.E W.nodes.H          analytic node   positions (z <= 0)
%     W.antinodes.E W.antinodes.H  analytic antinode positions (z <= 0)
%     W.nodes_num.E W.nodes_num.H  numeric (grid) minima
%     W.antinodes_num.E W.antinodes_num.H  numeric (grid) maxima
%     W.swr                        standing wave ratio (Inf if |Gamma| = 1)
%     W.Js W.rho_s                 PEC surface current density [A/m] and
%                                  surface charge density [C/m^2] (TM only)
%     W.z2 W.Eenv2 W.Henv2         medium-2 envelope on the z > 0 part of z
%     W.delta                      penetration depth marker [m] (TIR), else Inf
%     W.lambda1 W.cos_i W.kz1      copies used by the GUI label
%
%   See also EM_SOLVE, EM_FIELDS.

if numel(S.theta_i_deg) ~= 1
    error('em_standing_wave:nonScalarS', ...
        'em_standing_wave needs a scalar solve struct (got %d angles).', ...
        numel(S.theta_i_deg));
end
z = z(:).';
ci = S.cos_i;
kz1 = S.kz1;
G = S.Gamma;

% --- envelopes in medium 1 -------------------------------------------------
zf = exp(2i*kz1*z);
eE = abs(1 + G.*zf);                 % |1 + Gamma exp(2j kz1 z)|
eH = abs(1 - G.*zf);                 % = |1 + (-Gamma) exp(2j kz1 z)|

if strcmp(S.pol,'TE')
    cE = 1;            % |Ey|
    cH = ci/S.eta1;    % |Hx| = (cos_i/eta1)*|1 - Gamma exp(...)|
else
    cE = ci;           % |Ex|
    cH = 1/S.eta1;     % |Hy|
end
% with a magnetic/lossy medium 1 the scale factors can be complex, so the
% physical envelopes use their magnitude
W.Eenv = abs(cE)*eE;
W.Henv = abs(cH)*eH;
W.GE = G;
W.GH = -G;

% --- medium 2 (transmitted) envelope --------------------------------------
in2 = z > 0;
W.z2 = z(in2);
if S.is_PEC
    W.Eenv2 = zeros(size(W.z2));
    W.Henv2 = zeros(size(W.z2));
    a = 0;
else
    a = S.alpha;                       % 0 outside TIR
    if numel(a) > 1, a = a(1); end
    if ~isfinite(a), a = 0; end
    dec = exp(-a*W.z2);
    % NOTE: these are MAGNITUDES, so the impedance must be inside abs():
    % for a lossy medium 2 eta2 is complex and a bare '/S.eta2' made the
    % envelope complex, which MATLAB then silently plotted as its real part.
    if strcmp(S.pol,'TE')
        W.Eenv2 = abs(S.tau)*dec;                        % |Et.y|
        W.Henv2 = abs(S.tau*S.cos_t/S.eta2)*dec;         % |Ht.x|
    else
        W.Eenv2 = abs(S.tau*S.cos_t)*dec;                % |Et.x|
        W.Henv2 = abs(S.tau/S.eta2)*dec;                 % |Ht.y|
    end
end
W.alpha = a;

% --- analytic node / antinode positions (z <= 0 only) ---------------------
% The closed form  angle(G) + 2*kz1*z = (2m+1)*pi  presupposes a REAL kz1, i.e.
% a lossless medium 1.  If medium 1 is lossy the envelope is not periodic and
% only the numeric extrema are meaningful.
if abs(imag(kz1)) > 1e-12*max(1,abs(kz1))
    W.nodes.E = []; W.antinodes.E = []; W.nodes.H = []; W.antinodes.H = [];
    W.nodes_analytic = false;
else
W.nodes_analytic = true;
phiE = angle(G);
zmin = min(z);
if ~isfinite(zmin), zmin = -10*S.lambda1; end
nMax = ceil(2*abs(kz1)*abs(zmin)/pi) + 3;
m = 0:-1:-nMax;
zNodes = ((2*m + 1)*pi - phiE)/(2*kz1);     % E minima
zAntis = ( 2*m*pi      - phiE)/(2*kz1);     % E maxima
tol = 1e-9*max(1,abs(zmin));
zNodes = zNodes(zNodes <= tol & zNodes >= zmin - tol);
zAntis = zAntis(zAntis <= tol & zAntis >= zmin - tol);
W.nodes.E    = sort(zNodes);
W.antinodes.E = sort(zAntis);
W.nodes.H    = W.antinodes.E;      % H nodes are at the E antinodes
W.antinodes.H = W.nodes.E;
end

% --- numeric extrema on the given grid -----------------------------------
[mnE, mxE] = local_extrema(eE, z);
[mnH, mxH] = local_extrema(eH, z);
W.nodes_num.E      = mnE;
W.antinodes_num.E  = mxE;
W.nodes_num.H      = mnH;
W.antinodes_num.H  = mxH;

% --- SWR ------------------------------------------------------------------
ag = abs(G);
if ~S.lossless1
    W.swr = NaN;        % a lossy medium 1 gives no periodic standing wave
elseif ag >= 1
    W.swr = Inf;
else
    W.swr = (1 + ag)/(1 - ag);
end

% --- PEC surface current and charge (3.6) --------------------------------
if S.is_PEC
    Hi0 = 1/S.eta1;                        % |Hi| for E0 = 1 V/m
    if strcmp(S.pol,'TE')
        W.Js = 2*Hi0*ci;                   % 2*|Hi|*cos(theta_i)
        W.rho_s = NaN;                     % no normal E for TE
    else
        W.Js = 2*Hi0;                      % 2*|Hi|
        W.rho_s = 2*S.P.const.eps0*S.eps1*S.sin_i; % 2*eps0*eps_r1*sin(theta_i)
    end
else
    W.Js = 0;
    W.rho_s = 0;
end

W.delta = S.delta;
if numel(W.delta) > 1, W.delta = W.delta(1); end
W.lambda1 = S.lambda1;
W.cos_i = ci;
W.kz1 = kz1;
end

% -------------------------------------------------------------------------
function [zmn, zmx] = local_extrema(y, z)
%LOCAL_EXTREMA positions of the interior local minima / maxima of y(z).
%   Ties and flat regions are skipped, which is what we want for envelopes.
zmn = []; zmx = [];
if numel(z) < 3, return; end
y = y(:).'; z = z(:).';
d = diff(y);
s = sign(d);
s(abs(d) < 1e-14*max(1,max(abs(y)))) = 0;   % ignore numerical noise
i = find(s(1:end-1) < 0 & s(2:end) > 0);    % - -> + : local minimum
zmn = z(i + 1);
i = find(s(1:end-1) > 0 & s(2:end) < 0);    % + -> - : local maximum
zmx = z(i + 1);
end
