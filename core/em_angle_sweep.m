function C = em_angle_sweep(P, theta_deg)
%EM_ANGLE_SWEEP Reflection and transmission coefficients versus incidence angle,
%   for BOTH polarizations, plus the special angles.  Section 7.4 of the spec.
%
%   C = EM_ANGLE_SWEEP(P, theta_deg)
%     P         : base parameter struct (its .pol field only selects which
%                 theta_B_deg is copied to the top level; both polarizations are
%                 always computed because the coefficient plot shows TE and TM)
%     theta_deg : vector of incidence angles [deg], e.g. 0:0.5:89.9
%
%   Output
%     C.theta_deg    copy of the input vector
%     C.TE, C.TM     structs with .Gamma .tau .R .T (row vectors)
%     C.absGamma_TE, C.absGamma_TM, C.phaseGamma_TE_deg, C.phaseGamma_TM_deg
%     C.theta_B_TE_deg, C.theta_B_TM_deg   Brewster angles (NaN if none)
%     C.theta_B_deg  the one that belongs to P.pol, C.theta_B_src 'analytic'|
%                    'numeric'|'none'
%     C.theta_c_deg  critical angle [deg], NaN when it does not exist
%     C.regimeTE, C.regimeTM  cell arrays ('normal'/'oblique'/'TIR'/'lossy'/'PEC')
%     C.STE, C.STM   the full solve structs (for convenience)
%
%   Note: for lossless non-magnetic media only TM has a Brewster angle; with
%   mu_r ~= 1 (or lossy media) the angle is found numerically and may exist for
%   TE instead (or for neither polarization).
%
%   See also EM_SOLVE.

if nargin < 2 || isempty(theta_deg)
    theta_deg = 0:0.5:89.9;
end
theta_deg = theta_deg(:).';

PTE = P; PTE.pol = 'TE'; PTE.theta_i_deg = theta_deg;
PTM = P; PTM.pol = 'TM'; PTM.theta_i_deg = theta_deg;

STE = em_solve(PTE);
STM = em_solve(PTM);

C.theta_deg = theta_deg;
C.TE = struct('Gamma', STE.Gamma, 'tau', STE.tau, 'R', STE.R, 'T', STE.T);
C.TM = struct('Gamma', STM.Gamma, 'tau', STM.tau, 'R', STM.R, 'T', STM.T);

C.absGamma_TE = STE.absGamma;
C.absGamma_TM = STM.absGamma;
C.phaseGamma_TE_deg = STE.phaseGamma_deg;
C.phaseGamma_TM_deg = STM.phaseGamma_deg;

C.theta_B_TE_deg = STE.theta_B_deg;
C.theta_B_TM_deg = STM.theta_B_deg;
if strcmp(upper(char(P.pol)),'TM')
    C.theta_B_deg = STM.theta_B_deg; C.theta_B_src = STM.theta_B_src;
else
    C.theta_B_deg = STE.theta_B_deg; C.theta_B_src = STE.theta_B_src;
end
C.theta_c_deg = STE.theta_c_deg;    % asin(n2/n1) when n1 > n2

C.regimeTE = STE.regime;
C.regimeTM = STM.regime;
C.STE = STE;
C.STM = STM;
end
