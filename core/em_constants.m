function C = em_constants()
%EM_CONSTANTS Physical constants (SI) used by the whole EM Virtual Lab core.
%
%   This is the single place where physical constants are defined.
%   Every core and GUI file obtains them from here (directly or through the
%   P.const field returned by em_defaults), so there are no global variables
%   and no duplicated magic numbers anywhere in the project.
%
%   Fields
%     c    - speed of light in vacuum [m/s], exact by SI definition
%     mu0  - vacuum permeability [H/m]
%     eps0 - vacuum permittivity [F/m], derived from mu0 and c
%     eta0 - intrinsic impedance of free space [ohm], derived from mu0 and c
%
%   See also EM_DEFAULTS, EM_SOLVE.

C.c    = 299792458;              % [m/s] exact (SI)
C.mu0  = 4e-7*pi;                % [H/m] exact (SI)
C.eps0 = 1/(C.mu0*C.c^2);        % [F/m] = 8.8541878128e-12
C.eta0 = C.mu0*C.c;              % [ohm] = 376.730313668
end
