function P = em_defaults(varargin)
%EM_DEFAULTS Default parameters of the EM Virtual Lab, with input validation.
%
%   P = EM_DEFAULTS()            returns the default parameter struct.
%   P = EM_DEFAULTS(OVERRIDE)    merges the fields of the struct OVERRIDE into
%                                the defaults and VALIDATES the result.  This
%                                is the single validation entry point of the
%                                project: any bad input raises an error with a
%                                clear identifier and an informative message.
%
%   Media are described by their ELECTROMAGNETIC CONSTANTS, so the user can
%   change any of them directly in the GUI:
%     eps1, eps2      relative permittivity  eps_r            (0, 1e4]
%     mu1,  mu2       relative permeability  mu_r             (0, 1e4]
%     sigma1, sigma2  conductivity           sigma  [S/m]     [0, 1e9]
%   sigma > 0 makes the medium LOSSY: the core then works with the complex
%   permittivity eps_c = eps_r - j*sigma/(omega*eps0), a complex refractive
%   index and a complex impedance, and reports the attenuation constant and the
%   skin depth.  mu_r != 1 makes the medium MAGNETIC: n = sqrt(eps_r*mu_r) and
%   eta = eta0*sqrt(mu_r/eps_r).  With the defaults (mu = 1, sigma = 0) every
%   formula reduces exactly to the lossless non-magnetic case of the course.
%
%   Parameter fields
%     .mode        'dielectric' | 'pec'   medium 2 type
%     .pol         'TE' | 'TM'            TE = Horizontal (perpendicular)
%                                         TM = Vertical   (parallel)
%     .f_Hz        frequency [Hz]         (1e6 ... 1e11)
%     .theta_i_deg incidence angle [deg]  0 ... 89.9, may be a vector for
%                                         angle sweeps
%     .eps1 .mu1 .sigma1   medium 1 (incident side)
%     .eps2 .mu2 .sigma2   medium 2 (transmitted side)
%     .const       physical constants, see EM_CONSTANTS
%     .limits      validation ranges, used by the GUI to build controls
%     .view        visualisation / animation parameters (GUI only)
%
%   The physics is in EM_SOLVE; this file contains no physics.
%
%   See also EM_SOLVE, EM_CONSTANTS.

% --- 1. defaults -----------------------------------------------------------
P.mode = 'dielectric';       % medium 2
P.pol  = 'TE';               % TE = Horizontal, TM = Vertical
P.f_Hz = 1e9;                % 1 GHz, the reference frequency of the course
P.theta_i_deg = 0;           % normal incidence

P.eps1 = 1;                  % medium 1 = air
P.mu1  = 1;                  % non-magnetic
P.sigma1 = 0;                % lossless

P.eps2 = 2.25;               % medium 2 = glass (n = 1.5), a textbook example
P.mu2  = 1;
P.sigma2 = 0;

P.limits.eps        = [1e-6 1e4];    % allowed relative permittivity (D3: an
                                     % eps_r < 1 is not a physical passive
                                     % lossless dielectric, but it is accepted)
P.limits.mu         = [1e-6 1e4];    % allowed relative permeability
P.limits.sigma      = [0 1e9];       % allowed conductivity [S/m]
P.limits.theta_deg  = [0 89.9];      % 90 deg excluded: cos(theta) = 0
P.limits.f_Hz       = [1e6 1e11];    % 1 MHz ... 100 GHz
P.limits.win_lambda0= [0.5 20];      % spatial window in free-space wavelengths
P.limits.grid_pts   = [101 501];     % points per axis of the field map
P.limits.speed      = [0.1 5];       % animation speed multiplier

P.const = em_constants();

% Visualisation defaults (D6): the window is sized in free-space wavelengths
% so that changing the frequency only rescales the axes in metres.
P.view.win_x        = 3;             % total x extent = 3*lambda0
P.view.win_z        = 4;             % total z extent = 4*lambda0 (3 + 1)
P.view.Nx           = 241;
P.view.Nz           = 241;
P.view.show_incident    = true;
P.view.show_reflected   = true;
P.view.show_transmitted = true;
P.view.phi0         = 0;             % initial animation phase [rad]
P.view.dphi         = 2*pi/100;      % phase step per frame at speed 1x (3.8)
P.view.speed        = 1;             % 0.1 ... 5
P.view.e_comp       = '';            % '' = automatic per polarization
P.view.h_comp       = '';            % '' = automatic per polarization
P.view.quiver       = false;         % in-plane vector overlay (off by default)

% --- 2. merge user overrides ----------------------------------------------
if nargin > 0 && ~isempty(varargin{1})
    ov = varargin{1};
    if ~isstruct(ov) || numel(ov) ~= 1
        error('em_defaults:badOverride', ...
            'Override must be a single struct (got %s).', class(ov));
    end
    fn = fieldnames(ov);
    for k = 1:numel(fn)
        % struct merge, one level deep for .limits and .view
        if isfield(P, fn{k}) && isstruct(P.(fn{k})) && isstruct(ov.(fn{k}))
            sub = fieldnames(ov.(fn{k}));
            for j = 1:numel(sub)
                P.(fn{k}).(sub{j}) = ov.(fn{k}).(sub{j});
            end
        else
            P.(fn{k}) = ov.(fn{k});
        end
    end
end

% --- 3. validation --------------------------------------------------------
L = P.limits;

if ~(ischar(P.mode) || isstring(P.mode))
    error('em_defaults:badMode', 'P.mode must be a char ''dielectric'' or ''pec''.');
end
P.mode = lower(char(P.mode));
if ~any(strcmp(P.mode, {'dielectric','pec'}))
    error('em_defaults:badMode', 'P.mode must be ''dielectric'' or ''pec'' (got ''%s'').', P.mode);
end

if ~(ischar(P.pol) || isstring(P.pol))
    error('em_defaults:badPol', 'P.pol must be a char ''TE'' or ''TM''.');
end
P.pol = upper(char(P.pol));
if ~any(strcmp(P.pol, {'TE','TM'}))
    error('em_defaults:badPol', 'P.pol must be ''TE'' or ''TM'' (got ''%s'').', P.pol);
end

if ~isnumeric(P.f_Hz) || ~isscalar(P.f_Hz) || ~isreal(P.f_Hz) || ~isfinite(P.f_Hz)
    error('em_defaults:badFreq', 'P.f_Hz must be a finite real scalar.');
end
if P.f_Hz < L.f_Hz(1) || P.f_Hz > L.f_Hz(2)
    error('em_defaults:freqRange', 'P.f_Hz = %g Hz is outside [%g, %g] Hz.', ...
        P.f_Hz, L.f_Hz(1), L.f_Hz(2));
end

if ~isnumeric(P.theta_i_deg) || ~isreal(P.theta_i_deg) || isempty(P.theta_i_deg) ...
        || any(~isfinite(P.theta_i_deg(:)))
    error('em_defaults:badTheta', 'P.theta_i_deg must be a non-empty finite real array.');
end
if any(P.theta_i_deg(:) < L.theta_deg(1)) || any(P.theta_i_deg(:) > L.theta_deg(2))
    error('em_defaults:thetaRange', ...
        'P.theta_i_deg must lie in [%g, %g] deg (90 deg has cos = 0 and is excluded).', ...
        L.theta_deg(1), L.theta_deg(2));
end

% --- the electromagnetic constants of both media --------------------------
for nm = {'eps1','mu1','eps2','mu2'}
    v = P.(nm{1});
    if ~isnumeric(v) || ~isscalar(v) || ~isreal(v) || ~isfinite(v) || v <= 0
        error(['em_defaults:bad' nm{1}], 'P.%s must be a finite positive real scalar.', nm{1});
    end
    lim = L.eps;
    if ~isempty(strfind(nm{1},'mu')), lim = L.mu; end %#ok<STREMP>
    if v < lim(1) || v > lim(2)
        error(['em_defaults:' nm{1} 'Range'], ...
            'P.%s = %g is outside (0, %g].', nm{1}, v, lim(2));
    end
end
for nm = {'sigma1','sigma2'}
    v = P.(nm{1});
    if ~isnumeric(v) || ~isscalar(v) || ~isreal(v) || ~isfinite(v) || v < 0
        error(['em_defaults:bad' nm{1}], ...
            'P.%s must be a finite non-negative real scalar [S/m].', nm{1});
    end
    if v > L.sigma(2)
        error(['em_defaults:' nm{1} 'Range'], ...
            'P.%s = %g S/m is outside [0, %g].', nm{1}, v, L.sigma(2));
    end
end

% view parameters
if ~isnumeric(P.view.win_x) || P.view.win_x < L.win_lambda0(1) || P.view.win_x > L.win_lambda0(2)
    error('em_defaults:badWinX', 'P.view.win_x must be in [%g, %g] lambda0.', ...
        L.win_lambda0(1), L.win_lambda0(2));
end
if ~isnumeric(P.view.win_z) || P.view.win_z < L.win_lambda0(1) || P.view.win_z > L.win_lambda0(2)
    error('em_defaults:badWinZ', 'P.view.win_z must be in [%g, %g] lambda0.', ...
        L.win_lambda0(1), L.win_lambda0(2));
end
if ~isnumeric(P.view.Nx) || P.view.Nx < L.grid_pts(1) || P.view.Nx > L.grid_pts(2) || P.view.Nx ~= round(P.view.Nx)
    error('em_defaults:badNx', 'P.view.Nx must be an integer in [%d, %d].', ...
        L.grid_pts(1), L.grid_pts(2));
end
if ~isnumeric(P.view.Nz) || P.view.Nz < L.grid_pts(1) || P.view.Nz > L.grid_pts(2) || P.view.Nz ~= round(P.view.Nz)
    error('em_defaults:badNz', 'P.view.Nz must be an integer in [%d, %d].', ...
        L.grid_pts(1), L.grid_pts(2));
end
if ~isnumeric(P.view.speed) || P.view.speed < L.speed(1) || P.view.speed > L.speed(2)
    error('em_defaults:badSpeed', 'P.view.speed must be in [%g, %g].', ...
        L.speed(1), L.speed(2));
end
if ~isnumeric(P.view.dphi) || ~isscalar(P.view.dphi) || ~isfinite(P.view.dphi)
    error('em_defaults:badDphi', 'P.view.dphi must be a finite scalar [rad].');
end
for nm = {'show_incident','show_reflected','show_transmitted','quiver'}
    if ~(islogical(P.view.(nm{1})) || (isnumeric(P.view.(nm{1})) && isscalar(P.view.(nm{1}))))
        error('em_defaults:badFlag', 'P.view.%s must be a logical scalar.', nm{1});
    end
    P.view.(nm{1}) = logical(P.view.(nm{1}));
end
end
