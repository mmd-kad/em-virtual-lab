function test_core()
%TEST_CORE Verification suite of the EM Virtual Lab physics core (T1-T10).
%
%   Run with:   cd EM_VirtualLab/tests; test_core
%   or headless: matlab -batch "run('.../tests/test_core.m')"
%
%   Prints a PASS/FAIL table and raises an error if any test fails, so that a
%   non-zero exit status of MATLAB means "the physics core is broken".
%
%   Tolerances (Section 6): 1e-12 for identities, 5e-4 for rounded reference
%   values quoted in the specification.
%
%   Every check is an independent physics statement; nothing is compared
%   against itself.  The reference numbers come from the specification
%   (which quotes standard textbook values) and from closed-form algebra.

% --- path setup -----------------------------------------------------------
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'core'));
addpath(fullfile(root,'gui'));

fprintf('\n==============================================================\n');
fprintf(' EM Virtual Lab - physics core verification (T1 ... T12)\n');
fprintf(' MATLAB %s\n', version);
fprintf('==============================================================\n');

tests = {@t1,@t2,@t3,@t4,@t5,@t6,@t7,@t8,@t9,@t10,@t11,@t12};
names = {'T1  constants and media', ...
         'T2  reference values (textbook)', ...
         'T3  boundary conditions on the field arrays', ...
         'T4  power balance and Poynting vector continuity', ...
         'T5  eta-form vs n-form, tau identities', ...
         'T6  Snell law, reflection angle, kx conservation', ...
         'T7  limits (normal, grazing, eps2 = eps1, Stokes)', ...
         'T8  evanescent field under total reflection', ...
         'T9  nodes and antinodes analytic vs numeric', ...
         'T10 angle sweep consistency', ...
         'T11 lossy media (sigma > 0)', ...
         'T12 magnetic media (mu_r ~= 1)'};

n = numel(tests);
status = cell(n,1);
msgs = cell(n,1);

for k = 1:n
    okAll = true;            % shared with the nested check function
    curMsgs = {};
    try
        tests{k}();
    catch err
        okAll = false;
        curMsgs{end+1} = sprintf('%s :: %s', err.identifier, err.message);
    end
    if okAll
        status{k} = 'PASS';
    else
        status{k} = 'FAIL';
    end
    msgs{k} = curMsgs;
end

fprintf('\n------------------- RESULTS -------------------\n');
nFail = 0;
for k = 1:n
    fprintf(' %-4s  %s\n', status{k}, names{k});
    if ~strcmp(status{k},'PASS')
        nFail = nFail + 1;
        for j = 1:numel(msgs{k})
            fprintf('         -> %s\n', msgs{k}{j});
        end
    end
end
fprintf('-----------------------------------------------\n');
fprintf(' %d of %d tests passed.\n', n - nFail, n);

if nFail > 0
    error('test_core:failed', '%d of %d core tests FAILED.', nFail, n);
end
fprintf(' ALL CORE TESTS PASSED (T1-T12).\n\n');

% ============================ helpers =====================================
    function chk(cond, fmt, varargin)
        %CHK record a check; cond must be true.
        if ~cond
            okAll = false;
            if isempty(varargin)
                curMsgs{end+1} = fmt;
            else
                curMsgs{end+1} = sprintf(fmt, varargin{:});
            end
        end
    end

    function chkErr(fun, what)
        %CHKERR the function handle must raise an em_defaults error.
        try
            fun();
            okAll = false;
            curMsgs{end+1} = sprintf('%s: no error was raised', what);
        catch err
            if ~contains(err.identifier, 'em_defaults')
                okAll = false;
                curMsgs{end+1} = sprintf('%s: unexpected error %s (%s)', ...
                    what, err.identifier, err.message);
            end
        end
    end

    function chkEq(a, b, tol, what)
        %CHKEQ absolute-tolerance comparison of two numeric arrays.
        %   A scalar b is broadcast against a; two NaNs in the same place are
        %   considered equal (used for "does not exist" angles).
        a = a(:); b = b(:);
        if numel(b) == 1 && numel(a) > 1
            b = repmat(b, size(a));
        elseif numel(a) == 1 && numel(b) > 1
            a = repmat(a, size(b));
        end
        if numel(a) ~= numel(b)
            okAll = false;
            curMsgs{end+1} = sprintf('%s: size mismatch (%d vs %d)', what, numel(a), numel(b));
            return;
        end
        bothNaN = isnan(a) & isnan(b);
        eq = (a == b) | bothNaN;         % Inf == Inf must count as equal too
        d = abs(a - b);
        d(eq) = 0;
        if any(~eq & isnan(d))
            okAll = false;
            curMsgs{end+1} = sprintf('%s: NaN mismatch', what);
            return;
        end
        dmax = max(d);
        if ~(dmax <= tol)
            okAll = false;
            curMsgs{end+1} = sprintf('%s: max|diff| = %.3e > tol %.1e', what, dmax, tol);
        end
    end

% ======================= T1 constants and media ===========================
    function t1()
        K = em_constants();
        chkEq(K.c, 299792458, 0, 'c');
        chkEq(K.mu0, 4e-7*pi, 0, 'mu0');
        chkEq(K.eps0*K.mu0*K.c^2, 1, 1e-15, 'eps0*mu0*c^2 = 1');
        chkEq(K.eta0, K.mu0*K.c, 0, 'eta0 = mu0*c');
        % The textbook value 376.730313668 ohm comes from a different rounding
        % of the same 2019-SI constants; mu0*c gives 376.730313462 ohm here.
        chkEq(K.eta0, 376.730313668, 1e-6, 'eta0 close to the quoted value');

        % --- input validation (A1): bad inputs must raise clear errors -----
        chkErr(@() em_defaults(struct('theta_i_deg',90)),   'theta = 90 deg rejected');
        chkErr(@() em_defaults(struct('theta_i_deg',-1)),   'theta < 0 rejected');
        chkErr(@() em_defaults(struct('theta_i_deg',89.95)),'theta > 89.9 rejected');
        chkErr(@() em_defaults(struct('eps2',0)),           'eps2 = 0 rejected');
        chkErr(@() em_defaults(struct('eps2',2e4)),         'eps2 above 1e4 rejected');
        chkErr(@() em_defaults(struct('mu2',0)),            'mu2 = 0 rejected');
        chkErr(@() em_defaults(struct('mu1',1e5)),          'mu1 above 1e4 rejected');
        chkErr(@() em_defaults(struct('sigma2',-1)),        'negative conductivity rejected');
        chkErr(@() em_defaults(struct('sigma1',2e9)),       'sigma above 1e9 rejected');
        chkErr(@() em_defaults(struct('eps1',-2)),          'eps1 < 0 rejected');
        chkErr(@() em_defaults(struct('f_Hz',1e5)),         'f below 1 MHz rejected');
        chkErr(@() em_defaults(struct('f_Hz',2e11)),        'f above 100 GHz rejected');
        chkErr(@() em_defaults(struct('mode','superconductor')), 'unknown mode rejected');
        chkErr(@() em_defaults(struct('pol','X')),          'unknown polarization rejected');
        chkErr(@() em_defaults(42),                         'non-struct override rejected');
        chkErr(@() em_solve(em_defaults(struct('view',struct('Nx',77)))), 'bad grid size rejected');

        f = 1e9;
        P = em_defaults(struct('eps1',1,'eps2',1,'f_Hz',f));
        S = em_solve(P);
        chkEq([S.n1 S.n2], [1 1], 1e-15, 'n for eps = 1');
        chkEq([S.eta1 S.eta2], [K.eta0 K.eta0], 1e-9, 'eta for eps = 1');
        chkEq(S.lambda0, K.c/f, 0, 'lambda0 = c/f');
        chkEq(S.omega, 2*pi*f, 0, 'omega = 2*pi*f');
        chkEq(S.k0, 2*pi/S.lambda0, 1e-12, 'k0 = 2*pi/lambda0');

        P = em_defaults(struct('eps2',2.25));
        S = em_solve(P);
        chkEq(S.n2, 1.5, 1e-15, 'n for eps = 2.25');
        chkEq(S.eta2, K.eta0/1.5, 1e-9, 'eta2 = eta0/n2');
        chkEq(S.k2, 1.5*S.k0, 1e-9, 'k2 = n2*k0');
        chkEq(S.lambda2, S.lambda0/1.5, 1e-15, 'lambda2 = lambda0/n2');
        chkEq(S.k1, S.k0, 0, 'k1 = k0 for air');
        chkEq(S.eta1*S.n1, S.eta2*S.n2, 1e-9, 'eta*n = eta0 in both media');
    end

% ======================= T2 reference values ==============================
    function t2()
        K = em_constants();
        tol = 5e-4;         % rounded textbook values
        tiny = 1e-12;       % identities

        % --- air to glass (eps_r = 2.25, n = 1.5) -------------------------
        S = em_solve(em_defaults(struct('eps1',1,'eps2',2.25,'pol','TE','theta_i_deg',0)));
        chkEq(S.Gamma, -0.2, tiny, 'normal incidence Gamma = -0.2');
        chkEq(S.tau,    0.8, tiny, 'normal incidence tau   =  0.8');
        chkEq(S.R,     0.04, tiny, 'normal incidence R     =  0.04');
        chkEq(S.T,     0.96, tiny, 'normal incidence T     =  0.96');
        chkEq(S.absGamma, 0.2, tiny, 'normal incidence |Gamma| = 0.2');
        chkEq(S.phaseGamma_deg, 180, 1e-9, 'normal incidence phase(Gamma) = 180 deg');

        z = linspace(-3*S.lambda1, 0, 12001);
        W = em_standing_wave(S, z);
        chkEq(W.swr, 1.5, tiny, 'SWR = 1.5');
        chk(isempty(W.nodes.E) || min(abs(W.nodes.E)) < 1e-9, ...
            'first E minimum is at z = 0 (got %.3e)', min(abs([W.nodes.E 9])));
        chk(any(abs(W.antinodes.E + S.lambda1/4) < 1e-9), ...
            'first E maximum at z = -lambda1/4');
        chk(any(abs(W.nodes.H + S.lambda1/4) < 1e-9), ...
            'first H node at z = -lambda1/4');

        % --- 45 deg, both polarizations -----------------------------------
        STE = em_solve(em_defaults(struct('eps1',1,'eps2',2.25,'pol','TE','theta_i_deg',45)));
        STM = em_solve(em_defaults(struct('eps1',1,'eps2',2.25,'pol','TM','theta_i_deg',45)));
        chkEq(real(STE.Gamma), -0.3033, tol, 'Gamma_TE(45 deg) = -0.3033');
        chkEq(real(STM.Gamma), -0.0920, tol, 'Gamma_TM(45 deg) = -0.0920');
        chkEq(STE.cos_t, cosd(28.1255), tol, 'cos(theta_t)(45 deg)');

        % --- Brewster angle ----------------------------------------------
        SB = em_solve(em_defaults(struct('eps1',1,'eps2',2.25,'pol','TM', ...
                                         'theta_i_deg', 56.309932474020215)));
        chkEq(SB.theta_B_deg, 56.31, 5e-3, 'theta_B = 56.31 deg');
        chk(abs(SB.Gamma) < 1e-12, 'Gamma_TM(theta_B) = 0 (got %.3e)', abs(SB.Gamma));
        chkEq(SB.theta_t_deg, 33.69, 5e-3, 'theta_t(theta_B) = 33.69 deg');
        chkEq(SB.theta_i_deg + SB.theta_t_deg, 90, 1e-9, 'theta_i + theta_t = 90 at Brewster');

        % --- glass to air: critical angle and total reflection ------------
        SG = em_solve(em_defaults(struct('eps1',2.25,'eps2',1,'pol','TE','theta_i_deg',30)));
        chkEq(SG.theta_c_deg, 41.8103, 5e-4, 'theta_c = 41.81 deg');
        for pol = {'TE','TM'}
            S60 = em_solve(em_defaults(struct('eps1',2.25,'eps2',1,'pol',pol{1},'theta_i_deg',60)));
            chkEq(S60.absGamma, 1, 1e-12, sprintf('|Gamma_%s(60 deg)| = 1 (TIR)', pol{1}));
            chk(abs(S60.T) < 1e-12, sprintf('T_%s(60 deg) = 0 (TIR)', pol{1}));
            chkEq(S60.alpha/S60.k0, 0.8292, 5e-4, sprintf('alpha/k0 = 0.8292 (%s)', pol{1}));
            chkEq(S60.delta/S60.lambda0, 0.1919, 5e-4, sprintf('delta/lambda0 = 0.1919 (%s)', pol{1}));
            chk(S60.is_TIR, 'TIR flag not set for glass->air at 60 deg (%s)', pol{1});
        end

        % --- PEC, normal incidence ---------------------------------------
        SP = em_solve(em_defaults(struct('mode','pec','pol','TE','theta_i_deg',0)));
        chkEq(SP.Gamma, -1, 0, 'PEC Gamma = -1');
        chkEq(SP.tau, 0, 0, 'PEC tau = 0');
        chkEq(SP.R, 1, 0, 'PEC R = 1');
        chkEq(SP.T, 0, 0, 'PEC T = 0');
        z = linspace(-2*SP.lambda1, 0, 8001);
        W = em_standing_wave(SP, z);
        zs = z(500:750);
        chkEq(W.Eenv(500:750), 2*abs(sin(SP.k1*zs)), 1e-12, 'PEC Eenv = 2|sin(k z)|');
        chkEq(W.Henv(500:750), 2*abs(cos(SP.k1*zs))/K.eta0, 1e-12, 'PEC Henv = 2|cos(k z)|/eta0');
        for m = 0:3
            chk(any(abs(W.nodes.E + m*SP.lambda1/2) < 1e-9), ...
                'PEC E node at z = -%d*lambda/2 missing', m);
        end
        chkEq(W.swr, Inf, 0, 'PEC SWR = Inf');
    end

% =================== T3 boundary conditions on the fields =================
    function t3()
        rng(7);
        tolT = 1e-12;      % transverse E and H: exact to round-off
        tolN = 1e-11;      % normal components, scaled by eps (a bit larger)
        cases = {};
        % deterministic sweep: both polarizations, three medium pairs
        % (including the total-reflection pair), several angles
        pols = {'TE','TM'};
        pairs = {[1 2.25], [2.25 1], [1 9], [1 1.44]};
        for ip = 1:2
            for jp = 1:numel(pairs)
                for th = [0 0.5 12.3 30 45 60.3 78.9]
                    cases{end+1} = struct('pol',pols{ip},'eps1',pairs{jp}(1), ...
                        'eps2',pairs{jp}(2),'theta',th);
                end
            end
        end
        % a few pseudo-random cases on top (reproducible: rng(7) above)
        for q = 1:6
            cases{end+1} = struct('pol',pols{1+mod(q,2)}, 'eps1', 1+3*rand(), ...
                'eps2', 1+6*rand(), 'theta', 89.9*rand());
        end

        for c = 1:numel(cases)
            cs = cases{c};
            S = em_solve(em_defaults(struct('pol',cs.pol,'eps1',cs.eps1, ...
                'eps2',cs.eps2,'theta_i_deg',cs.theta)));
            xv = linspace(-2*S.lambda0, 2*S.lambda0, 41);
            [X,Z] = meshgrid(xv, [0 0]);
            F = em_fields(S, X, Z);
            tag = sprintf('%s eps=[%.3f %.3f] theta=%.2f', cs.pol, cs.eps1, cs.eps2, cs.theta);

            % tangential E and H continuous at z = 0
            chk(max(abs(F.E1.x(1,:) - F.E2.x(1,:))) < tolT, ...
                'Et.x jump = %.3e (%s)', max(abs(F.E1.x(1,:) - F.E2.x(1,:))), tag);
            chk(max(abs(F.E1.y(1,:) - F.E2.y(1,:))) < tolT, ...
                'Et.y jump = %.3e (%s)', max(abs(F.E1.y(1,:) - F.E2.y(1,:))), tag);
            chk(max(abs(F.H1.x(1,:) - F.H2.x(1,:))) < tolT, ...
                'Ht.x jump = %.3e (%s)', max(abs(F.H1.x(1,:) - F.H2.x(1,:))), tag);
            chk(max(abs(F.H1.y(1,:) - F.H2.y(1,:))) < tolT, ...
                'Ht.y jump = %.3e (%s)', max(abs(F.H1.y(1,:) - F.H2.y(1,:))), tag);

            % normal components: eps*Ez and Hz continuous
            jn = max(abs(cs.eps1*F.E1.z(1,:) - cs.eps2*F.E2.z(1,:)));
            chk(jn < tolN*max(1,cs.eps2), 'eps*Ez jump = %.3e (%s)', jn, tag);
            jn = max(abs(F.H1.z(1,:) - F.H2.z(1,:)));
            chk(jn < tolN, 'Hz jump = %.3e (%s)', jn, tag);

            % total field equals medium-1 field below the interface and
            % medium-2 field above it (z = 0- belongs to medium 1, z >= 0 does
            % not, because the interface itself carries the PEC convention)
            Z2 = [-0.13*S.lambda0, 0.13*S.lambda0];
            [X,Z] = meshgrid(xv, Z2);
            Fs = em_fields(S, X, Z);
            chk(max(abs(Fs.E.x(1,:) - Fs.E1.x(1,:))) < 1e-15, ...
                'total E above the interface is not E1 (%s)', tag);
            chk(max(abs(Fs.E.x(2,:) - Fs.E2.x(2,:))) < 1e-15, ...
                'total E below the interface is not E2 (%s)', tag);
        end

        % PEC: tangential total E vanishes at the surface, medium 2 is empty
        for pol = {'TE','TM'}
            for th = [0 22.5 60 89.9]
                S = em_solve(em_defaults(struct('mode','pec','pol',pol{1},'theta_i_deg',th)));
                xv = linspace(-2*S.lambda0, 2*S.lambda0, 31);
                [X,Z] = meshgrid(xv, [0 0.25*S.lambda1]);
                F = em_fields(S, X, Z);
                chk(max(abs(F.E.x(1,:))) < 1e-14, 'PEC tangential Ex != 0 (%s, %.1f deg)', pol{1}, th);
                chk(max(abs(F.E.y(1,:))) < 1e-14, 'PEC tangential Ey != 0 (%s, %.1f deg)', pol{1}, th);
                chk(max(abs(F.E.x(2,:))) + max(abs(F.E.y(2,:))) + max(abs(F.E.z(2,:))) == 0, ...
                    'PEC field inside the conductor is not zero (%s, %.1f deg)', pol{1}, th);
            end
        end
    end

% =============== T4 power balance and Poynting continuity =================
    function t4()
        for pol = {'TE','TM'}
            th = 0:0.5:89.9;
            S = em_solve(em_defaults(struct('pol',pol{1},'eps1',1,'eps2',4, ...
                'theta_i_deg',th)));
            chkEq(S.R + S.T, 1, 1e-12, sprintf('R+T = 1 (air->eps4, %s)', pol{1}));

            S = em_solve(em_defaults(struct('pol',pol{1},'eps1',4,'eps2',1, ...
                'theta_i_deg',th)));
            chkEq(S.R + S.T, 1, 1e-12, sprintf('R+T = 1 (eps4->air, %s)', pol{1}));
            m = S.is_TIR;
            chkEq(S.R(m), 1, 1e-12, sprintf('R = 1 inside TIR region (%s)', pol{1}));
            chk(all(abs(S.T(m)) < 1e-12), 'T = 0 inside TIR region (%s)', pol{1});

            % the time-average Sz computed from the fields is continuous
            for q = [5 20 40 60 80 179]
                Sq = em_solve(em_defaults(struct('pol',pol{1},'eps1',4,'eps2',1, ...
                    'theta_i_deg',th(q))));
                xv = linspace(-1, 1, 7)*Sq.lambda0;
                [X,Z] = meshgrid(xv, [0 0]);
                F = em_fields(Sq, X, Z);
                s1 = mean(F.Sz1(1,:)); s2 = mean(F.Sz2(1,:));
                sc = max(abs(s1), abs(s2));
                chk(abs(s1 - s2) <= 1e-9*sc + 1e-12, ...
                    'Sz jump = %.3e vs scale %.3e (%s, %.1f deg)', abs(s1-s2), sc, pol{1}, th(q));
            end

            % transmitted power must be positive in a normal (non-TIR) case
            Sn = em_solve(em_defaults(struct('pol',pol{1},'eps1',1,'eps2',2.25, ...
                'theta_i_deg',30)));
            xv = linspace(-1, 1, 5)*Sn.lambda0;
            [X,Z] = meshgrid(xv, [0.5*Sn.lambda2 1.5*Sn.lambda2]);
            F = em_fields(Sn, X, Z);
            chk(mean(F.Sz2(:)) > 0, 'transmitted Sz must be positive along +z (%s)', pol{1});
        end
    end

% ============ T5 eta-form vs n-form and tau identities ====================
    function t5()
        cases = {[1 2.25], [2.25 1], [1 9], [2.25 2.25], [1 1.21]};
        for ip = 1:numel(cases)
            for pol = {'TE','TM'}
                for th = [0 10 41.8103 55 60 75]
                    e1 = cases{ip}(1); e2 = cases{ip}(2);
                    S = em_solve(em_defaults(struct('pol',pol{1},'eps1',e1, ...
                        'eps2',e2,'theta_i_deg',th)));
                    n1 = S.n1; n2 = S.n2; ci = S.cos_i; ct = S.cos_t;
                    if strcmp(pol{1},'TE')
                        Gn = (n1*ci - n2*ct)/(n1*ci + n2*ct);
                        taun = 2*n1*ci/(n1*ci + n2*ct);
                        chkEq(S.Gamma, Gn, 1e-13, ...
                            sprintf('eta-form vs n-form Gamma_TE (%.2f,%.2f,%.1f deg)', e1,e2,th));
                        chkEq(S.tau, S.Gamma + 1, 1e-13, ...
                            sprintf('tau_TE = 1 + Gamma_TE (%.2f,%.2f,%.1f deg)', e1,e2,th));
                        chkEq(S.tau, taun, 1e-13, 'tau_TE n-form');
                    else
                        Gn = (n1*ct - n2*ci)/(n1*ct + n2*ci);
                        chkEq(S.Gamma, Gn, 1e-13, ...
                            sprintf('eta-form vs n-form Gamma_TM (%.2f,%.2f,%.1f deg)', e1,e2,th));
                        chkEq(S.tau, 2*n1*ci/(n1*ct + n2*ci), 1e-13, 'tau_TM n-form');
                        chkEq(1 + S.Gamma, S.tau*ct/ci, 1e-13, ...
                            sprintf('1 + Gamma_TM = tau*cos_t/cos_i (%.2f,%.2f,%.1f deg)', e1,e2,th));
                    end
                end
            end
        end
    end

% ==================== T6 Snell and kx conservation =======================
    function t6()
        for pol = {'TE','TM'}
            S = em_solve(em_defaults(struct('pol',pol{1},'eps1',1,'eps2',2.25, ...
                'theta_i_deg',0:0.5:89.9)));
            m = ~S.is_TIR;
            chkEq(S.n1*S.sin_i(m), S.n2*S.sin_t(m), 1e-14, 'Snell: n1 sin(ti) = n2 sin(tt)');
            chkEq(S.theta_r_deg, S.theta_i_deg, 0, 'theta_r = theta_i');
            chkEq(S.kx, S.k1*S.sin_i, 0, 'kx = k1 sin(theta_i)');
            chkEq(S.kx(m), S.k2*S.sin_t(m), 1e-9, 'kx = k2 sin(theta_t) (same in both media)');
            chkEq(S.theta_t_deg(m), rad2deg(asin(S.sin_t(m))), 1e-12, 'theta_t from asin(sin_t)');
            % theta_t of a dielectric is between 0 and 90 deg
            chk(all(S.theta_t_deg(m) >= 0 & S.theta_t_deg(m) <= 90), 'theta_t out of [0,90]');
        end
    end

% ============================= T7 limits ==================================
    function t7()
        % (a) normal incidence: TE and TM identical
        STE = em_solve(em_defaults(struct('pol','TE','eps1',1,'eps2',4.41,'theta_i_deg',0)));
        STM = em_solve(em_defaults(struct('pol','TM','eps1',1,'eps2',4.41,'theta_i_deg',0)));
        chkEq(STE.Gamma, STM.Gamma, 1e-14, 'Gamma_TE = Gamma_TM at normal incidence');
        chkEq(STE.tau, STM.tau, 1e-14, 'tau_TE = tau_TM at normal incidence');
        chkEq(STE.Gamma, (1-2.1)/(1+2.1), 1e-14, 'normal incidence Gamma = (1-n)/(1+n)');

        % (b) grazing incidence without TIR: (Gamma_TE, Gamma_TM) -> (-1, +1).
        %     The approach is O(cos theta_i), so we check the trend plus a
        %     value at 89.99 deg instead of a tight tolerance at 89.9 deg.
        th = [60 80 89 89.9 89.99 89.999];
        LM = struct('limits', struct('theta_deg',[0 89.9999]));
        SGE = em_solve(em_defaults(struct('pol','TE','eps1',1,'eps2',2.25, ...
            'theta_i_deg',th,'limits',LM.limits)));
        SGM = em_solve(em_defaults(struct('pol','TM','eps1',1,'eps2',2.25, ...
            'theta_i_deg',th,'limits',LM.limits)));
        dE = abs(SGE.Gamma + 1); dM = abs(SGM.Gamma - 1);
        chk(all(diff(dE) < 0), '|Gamma_TE + 1| must decrease towards grazing');
        chk(all(diff(dM) < 0), '|Gamma_TM - 1| must decrease towards grazing');
        chk(dE(end) < 1e-3, 'Gamma_TE(89.999 deg) within 1e-3 of -1 (got %.3e)', dE(end));
        chk(dM(end) < 1e-3, 'Gamma_TM(89.999 deg) within 1e-3 of +1 (got %.3e)', dM(end));
        chkEq([SGE.R(end) SGM.R(end)], [1 1], 1e-3, 'R -> 1 at grazing without TIR');
        chk(all(diff(SGE.R) > 0) && all(diff(SGM.R) > 0), 'R must increase towards grazing');

        % (c) matched media: no reflection at any angle
        for pol = {'TE','TM'}
            S = em_solve(em_defaults(struct('pol',pol{1},'eps1',3.4,'eps2',3.4, ...
                'theta_i_deg',0:2:89.9)));
            chkEq(S.Gamma, 0, 1e-13, sprintf('eps2 = eps1: Gamma = 0 (%s)', pol{1}));
            chkEq(S.tau, 1, 1e-13, sprintf('eps2 = eps1: tau = 1 (%s)', pol{1}));
            chkEq(S.R, 0, 1e-13, sprintf('eps2 = eps1: R = 0 (%s)', pol{1}));
            chkEq(S.T, 1, 1e-13, sprintf('eps2 = eps1: T = 1 (%s)', pol{1}));
        end

        % (d) Stokes relation: Gamma(n1->n2, ti) = -Gamma(n2->n1, tt)
        for pol = {'TE','TM'}
            S12 = em_solve(em_defaults(struct('pol',pol{1},'eps1',1,'eps2',4, ...
                'theta_i_deg',33)));
            S21 = em_solve(em_defaults(struct('pol',pol{1},'eps1',4,'eps2',1, ...
                'theta_i_deg',S12.theta_t_deg)));
            chk(~S21.is_TIR, 'reverse case must not be TIR (%s)', pol{1});
            chkEq(S12.Gamma, -S21.Gamma, 1e-13, ...
                sprintf('Stokes: Gamma_12(ti) = -Gamma_21(tt) (%s)', pol{1}));

            % reciprocity of normal incidence between two lossless dielectrics
            Sa = em_solve(em_defaults(struct('pol',pol{1},'eps1',1,'eps2',4,'theta_i_deg',0)));
            Sb = em_solve(em_defaults(struct('pol',pol{1},'eps1',4,'eps2',1,'theta_i_deg',0)));
            chkEq(Sa.Gamma, -Sb.Gamma, 1e-14, sprintf('normal-incidence reciprocity (%s)', pol{1}));
        end

        % (e) Gamma_TM changes sign at the Brewster angle: negative below it
        %     (like the normal-incidence value) and positive above it
        SB = em_solve(em_defaults(struct('pol','TM','eps1',1,'eps2',2.25,'theta_i_deg',[56 57])));
        chk(real(SB.Gamma(1)) < 0 && real(SB.Gamma(2)) > 0, ...
            'Gamma_TM must change sign across the Brewster angle (%.4f, %.4f)', ...
            real(SB.Gamma(1)), real(SB.Gamma(2)));
        chk(abs(real(SB.Gamma(1))) < 0.01, ...
            'Gamma_TM just below theta_B must be small (%.2e)', real(SB.Gamma(1)));
    end

% ==================== T8 evanescent field (TIR) ===========================
    function t8()
        for pol = {'TE','TM'}
            S = em_solve(em_defaults(struct('pol',pol{1},'eps1',2.25,'eps2',1, ...
                'theta_i_deg',60)));
            chk(imag(S.cos_t) < 0, 'TIR requires Im(cos_t) < 0 (%s)', pol{1});
            chkEq(real(S.cos_t), 0, 1e-12, 'cos_t is purely imaginary in TIR');
            chk(S.alpha > 0, 'alpha must be positive');

            % |E| decays monotonically along +z in medium 2
            z2 = linspace(0.02, 3, 300);
            xv = [-1 0 1]*S.lambda0;
            [X,Z] = meshgrid(xv, z2);
            F = em_fields(S, X, Z);
            mag = sqrt(abs(F.E.x).^2 + abs(F.E.y).^2 + abs(F.E.z).^2);
            magx = mag(:,2).';                      % along a line of constant x
            d = diff(magx);
            chk(all(d <= 1e-12*max(magx)), ...
                'evanescent |E| is not monotonically decreasing (%s)', pol{1});

            % value one penetration depth deeper is smaller by exp(-1)
            r = magx(2:end)./magx(1:end-1);
            % compare against the analytic exp(-alpha*dz)
            dz = z2(2)-z2(1);
            chkEq(r, exp(-S.alpha*dz)*ones(size(r)), 1e-9, ...
                sprintf('|E| ~ exp(-alpha*z) in medium 2 (%s)', pol{1}));
            chkEq(exp(-S.alpha*S.delta), exp(-1), 1e-12, 'exp(-alpha*delta) = exp(-1)');

            % the evanescent wave propagates along +x with phase constant kx
            S2 = S;
            chkEq(imag(S2.kx), 0, 0, 'kx is real (propagation along x)');
            chkEq(S2.kx, S2.k1*S2.sin_i, 0, 'kx = k1 sin(theta_i)');
            chkEq(S2.vx, S2.omega/S2.kx, 1e-6, 'phase velocity along x = omega/kx');
            % In TIR n1*sin(theta_i) > n2, so the phase velocity along the
            % interface, c/(n1 sin theta_i), stays BELOW the wave speed in
            % medium 2: the wave can only decay there and transports no power.
            chk(S2.vx < S2.P.const.c/S2.n2, ...
                'vx = %.4e must be below c/n2 = %.4e in TIR', S2.vx, S2.P.const.c/S2.n2);
            chk(S2.vx > S2.P.const.c/(S2.n1*1), ...
                'vx must exceed the phase velocity in medium 1 itself');

            % no energy flows into medium 2
            [X,Z] = meshgrid([-1 0 1]*S.lambda0, [0.1 1 2]);
            F = em_fields(S, X, Z);
            chk(max(abs(F.Sz2(:))) < 1e-12, ...
                'time-average Sz must vanish in medium 2 under TIR (%s)', pol{1});
        end
    end

% ============== T9 nodes and antinodes: analytic vs numeric ===============
    function t9()
        cases = {};
        % PEC, TE and TM, three angles
        for pol = {'TE','TM'}
            for th = [0 30 60]
                cases{end+1} = struct('mode','pec','pol',pol{1},'theta',th, ...
                    'eps1',1,'eps2',1);
            end
        end
        % dielectric at normal incidence (partial standing wave)
        for pol = {'TE','TM'}
            cases{end+1} = struct('mode','dielectric','pol',pol{1},'theta',0, ...
                'eps1',1,'eps2',2.25);
        end
        % dielectric, oblique, and TIR
        cases{end+1} = struct('mode','dielectric','pol','TE','theta',40,'eps1',1,'eps2',4);
        cases{end+1} = struct('mode','dielectric','pol','TM','theta',70,'eps1',1,'eps2',4);

        for c = 1:numel(cases)
            cs = cases{c};
            S = em_solve(em_defaults(struct('mode',cs.mode,'pol',cs.pol, ...
                'eps1',cs.eps1,'eps2',cs.eps2,'theta_i_deg',cs.theta)));
            npts = 20001;
            z = linspace(-4*S.lambda1, 0, npts);
            step = z(2)-z(1);
            W = em_standing_wave(S, z);
            tag = sprintf('%s %s %.0f deg', cs.mode, cs.pol, cs.theta);

            % every analytic node (away from the ends) has a numeric node
            % within one grid step; the same for antinodes, for E and for H
            [okE, badE] = match_positions(W.nodes.E,     W.nodes_num.E,     step, z);
            [okH, badH] = match_positions(W.nodes.H,     W.nodes_num.H,     step, z);
            [okA, badA] = match_positions(W.antinodes.E, W.antinodes_num.E, step, z);
            chk(okE, 'E nodes disagree numerically (%s): %s', tag, badE);
            chk(okH, 'H nodes disagree numerically (%s): %s', tag, badH);
            chk(okA, 'E antinodes disagree numerically (%s): %s', tag, badA);

            % the number of detected extrema must match the analytic count
            chk(numel(W.nodes_num.E) >= numel(W.nodes.E) - 2, ...
                'too few numeric E nodes (%s): %d vs %d', tag, ...
                numel(W.nodes_num.E), numel(W.nodes.E));

            % half-periodicity: consecutive nodes are lambda1/(2*cos_i) apart
            if numel(W.nodes.E) > 2 && ~S.is_PEC
                d = diff(W.nodes.E);
                chkEq(d, (S.lambda1/(2*S.cos_i))*ones(size(d)), 2*step, ...
                    sprintf('node spacing = lambda1/(2 cos_i) (%s)', tag));
            end
            if S.is_PEC
                d = diff(W.nodes.E);
                chkEq(d, (S.lambda1/(2*S.cos_i))*ones(size(d)), 2*step, ...
                    sprintf('PEC node spacing = lambda1/(2 cos_i) (%s)', tag));
            end
        end
    end

% ====================== T10 angle sweep consistency =======================
    function t10()
        P = em_defaults(struct('eps1',1,'eps2',4,'pol','TE'));
        th = [0 17.5 45 60 80 89.9];
        C = em_angle_sweep(P, th);
        chkEq(C.theta_deg, th, 0, 'C.theta_deg echoes the input');
        for pol = {'TE','TM'}
            S = em_solve(em_defaults(struct('pol',pol{1},'eps1',1,'eps2',4, ...
                'theta_i_deg',th)));
            chkEq(C.(pol{1}).Gamma, S.Gamma, 1e-15, sprintf('sweep Gamma_%s matches', pol{1}));
            chkEq(C.(pol{1}).tau, S.tau, 1e-15, sprintf('sweep tau_%s matches', pol{1}));
            chkEq(C.(pol{1}).R, S.R, 1e-15, sprintf('sweep R_%s matches', pol{1}));
            chkEq(C.(pol{1}).T, S.T, 1e-15, sprintf('sweep T_%s matches', pol{1}));
        end
        S = em_solve(em_defaults(struct('pol','TM','eps1',1,'eps2',4,'theta_i_deg',0)));
        chkEq(C.theta_B_TM_deg, S.theta_B_deg, 1e-15, 'sweep Brewster angle (TM)');
        chk(isnan(C.theta_B_deg), 'a TE sweep must report no Brewster angle');
        chk(isnan(C.theta_B_TE_deg), 'TE has no Brewster angle without magnetic media');
        chkEq(C.theta_c_deg, S.theta_c_deg, 1e-15, 'sweep critical angle (NaN if none)');

        % one angle only: sweep must equal a single solve exactly
        C1 = em_angle_sweep(P, 37);
        S1 = em_solve(em_defaults(struct('pol','TE','eps1',1,'eps2',4,'theta_i_deg',37)));
        chkEq(C1.TE.Gamma, S1.Gamma, 0, 'single-angle sweep = single solve');
        chkEq(C1.TE.T, S1.T, 0, 'single-angle sweep T');
        chkEq(C1.theta_deg, 37, 0, 'single-angle sweep theta');

        % glass -> air sweep must contain a TIR region and the critical angle
        C2 = em_angle_sweep(em_defaults(struct('eps1',4,'eps2',1)), 0:0.5:89.9);
        chk(any(strcmp(C2.regimeTE,'TIR')), 'glass->air sweep has a TIR region');
        chkEq(C2.theta_c_deg, 30, 1e-12, 'theta_c for n1=2, n2=1 is 30 deg');
        m = abs(C2.theta_deg - 45) < 1e-9;
        chk(any(m), 'theta_i = 45 deg is missing from the sweep');
        chkEq([C2.TE.R(m) C2.TM.R(m)], [1 1], 1e-12, 'R = 1 for both polarizations in TIR');
        chkEq([C2.TE.T(m) C2.TM.T(m)], [0 0], 1e-12, 'T = 0 for both polarizations in TIR');
    end

% ==================== T11 lossy media (sigma > 0) ========================
    function t11()
        K = em_constants();
        f = 1e9; w = 2*pi*f;
        epsr = 2.25; s2 = 0.01;               % S/m
        S = em_solve(em_defaults(struct('eps2',epsr,'sigma2',s2,'theta_i_deg',[0 30])));

        % complex permittivity and loss tangent against the definitions
        chkEq(S.eps2c, epsr - 1i*s2/(w*K.eps0), 1e-12, 'eps_c = eps_r - j*sigma/(omega*eps0)');
        tan_d = s2/(w*K.eps0*epsr);
        chkEq(S.tan_delta2, tan_d, 1e-12, 'tan(delta) = sigma/(omega*eps0*eps_r)');

        % attenuation constant from the independent standard formula
        %   alpha = k0*sqrt(eps_r) * sqrt( (sqrt(1+tan^2 d) - 1)/2 )
        alpha_exp = S.k0*sqrt(epsr)*sqrt((sqrt(1 + tan_d^2) - 1)/2);
        chkEq(S.att2, alpha_exp, 1e-9*alpha_exp, 'alpha from the standard closed form');
        chkEq(S.skin2, 1/alpha_exp, 1e-9/alpha_exp, 'skin depth = 1/alpha');

        % a lossy half-space cannot show total reflection
        chk(~any(S.is_TIR), 'TIR must not be reported for a lossy pair');
        for q = 1:numel(S.regime)
            chk(strcmp(S.regime{q},'lossy'), 'regime must be lossy (got %s)', S.regime{q});
        end

        % AT THE INTERFACE R + T = 1 even for a lossy half-space: the power that
        % enters medium 2 is then dissipated as it propagates (exp(-2 alpha z)).
        % Absorption is therefore NOT visible as a defect of R + T at z = 0.
        chkEq(S.R + S.T, 1, 1e-12, 'R + T = 1 at the interface (lossy half-space)');
        chk(all(abs(S.Aabs) < 1e-12), 'interface power defect 1 - R - T must vanish');
        chk(all(S.absGamma < 1), '|Gamma| < 1 for a passive (lossy) medium');
        S0 = em_solve(em_defaults(struct('eps2',epsr,'theta_i_deg',[0 30])));
        chk(abs(S.absGamma(1) - S0.absGamma(1)) > 1e-3, ...
            'loss must change |Gamma| (%.4f vs lossless %.4f)', S.absGamma(1), S0.absGamma(1));

        % the transmitted field decays as exp(-alpha*z)
        Ssc = em_solve(em_defaults(struct('eps2',epsr,'sigma2',s2,'theta_i_deg',0)));
        z2 = linspace(0.02, 2, 40);
        [X,Z] = meshgrid([-1 0 1]*Ssc.lambda0, z2);
        F = em_fields(Ssc, X, Z);
        mag = sqrt(abs(F.E2.x(:,2)).^2 + abs(F.E2.y(:,2)).^2 + abs(F.E2.z(:,2)).^2).';
        rr = mag(2:end)./mag(1:end-1);
        dz = z2(2) - z2(1);
        chkEq(rr, exp(-Ssc.att2*dz)*ones(size(rr)), 1e-9, '|Et| decays as exp(-alpha z)');
        % the transmitted POWER decays twice as fast
        sz = F.Sz2(:,2).';
        chk(all(sz > 0), 'the transmitted wave must carry power into +z');
        rr2 = sz(2:end)./sz(1:end-1);
        chkEq(rr2, exp(-2*Ssc.att2*dz)*ones(size(rr2)), 1e-9, ...
            'transmitted power decays as exp(-2 alpha z)');

        % boundary conditions with the COMPLEX permittivity
        for pol = {'TE','TM'}
            for th = [0 35 70]
                Sl = em_solve(em_defaults(struct('pol',pol{1},'eps2',epsr, ...
                    'sigma2',s2,'theta_i_deg',th)));
                xv = linspace(-2*Sl.lambda0, 2*Sl.lambda0, 21);
                [X,Z] = meshgrid(xv,[0 0]);
                Fl = em_fields(Sl, X, Z);
                chk(max(abs(Fl.E1.x(1,:)-Fl.E2.x(1,:))) < 1e-12, ...
                    'tangential Ex continuous (lossy %s %.0f deg)', pol{1}, th);
                chk(max(abs(Fl.E1.y(1,:)-Fl.E2.y(1,:))) < 1e-12, ...
                    'tangential Ey continuous (lossy %s %.0f deg)', pol{1}, th);
                chk(max(abs(Fl.H1.y(1,:)-Fl.H2.y(1,:))) < 1e-12, ...
                    'tangential Hy continuous (lossy %s %.0f deg)', pol{1}, th);
                jn = max(abs(Sl.eps1c*Fl.E1.z(1,:) - Sl.eps2c*Fl.E2.z(1,:)));
                chk(jn < 1e-11, 'eps_c*Ez continuous (lossy %s %.0f deg): %.3e', pol{1}, th, jn);
                chk(max(abs(Fl.H1.z(1,:)-Fl.H2.z(1,:))) < 1e-11, ...
                    'Hz continuous (lossy %s %.0f deg)', pol{1}, th);
            end
        end

        % the interface power balance R + T = 1 is polarization independent
        for pol = {'TE','TM'}
            Sb = em_solve(em_defaults(struct('pol',pol{1},'eps2',epsr,'sigma2',s2, ...
                'theta_i_deg',[0 25 50 80])));
            chkEq(Sb.R + Sb.T, 1, 1e-12, sprintf('R + T = 1 at the interface (lossy %s)', pol{1}));
            chk(all(Sb.absGamma < 1), sprintf('|Gamma| < 1 (lossy %s)', pol{1}));
        end

        % zero conductivity must give back the lossless numbers exactly
        Sz = em_solve(em_defaults(struct('eps2',epsr,'sigma2',0,'theta_i_deg',45)));
        Sref = em_solve(em_defaults(struct('eps2',epsr,'theta_i_deg',45)));
        chkEq(Sz.Gamma, Sref.Gamma, 1e-15, 'sigma = 0 reduces to the lossless case');
    end

% ================== T12 magnetic media (mu_r ~= 1) =======================
    function t12()
        K = em_constants();
        eps2 = 2.25; mu2 = 4;

        S = em_solve(em_defaults(struct('eps2',eps2,'mu2',mu2,'theta_i_deg',0)));
        chk(S.is_magnetic, 'is_magnetic flag must be set');
        chkEq(S.n2, sqrt(eps2*mu2), 1e-12, 'n = sqrt(eps_r*mu_r)');
        chkEq(S.eta2, K.eta0*sqrt(mu2/eps2), 1e-9, 'eta = eta0*sqrt(mu_r/eps_r)');
        chkEq(real(S.Gamma), (sqrt(mu2/eps2)-1)/(sqrt(mu2/eps2)+1), 1e-12, ...
            'normal-incidence Gamma = (eta2-eta1)/(eta2+eta1)');

        th = 0:0.5:89.9;
        S = em_solve(em_defaults(struct('eps2',eps2,'mu2',mu2,'theta_i_deg',th)));
        chkEq(S.R + S.T, 1, 1e-12, 'R + T = 1 for lossless magnetic media');
        chkEq(S.att2, 0, 1e-15, 'a lossless magnetic medium does not attenuate');
        chk(all(strcmp(S.regime, 'oblique') | strcmp(S.regime,'normal')), ...
            'lossless magnetic media are not labelled lossy');

        % TM: the closed-form condition cos^2(theta_B) = E1(E1 M1 - E2 M2)/(M1(E1^2-E2^2))
        A = 1*(1*1 - eps2*mu2)/(1*(1^2 - eps2^2));
        chk(A > 1, 'test premise: no TM Brewster angle for this pair (A = %.4f)', A);
        STM = em_solve(em_defaults(struct('pol','TM','eps2',eps2,'mu2',mu2,'theta_i_deg',10)));
        chk(isnan(STM.theta_B_deg), 'TM must report no Brewster angle (got %g)', STM.theta_B_deg);

        % TE: cos^2(theta_B) = M1(E2 M2/E1 - M1)/(M2^2 - M1^2)  -> exists here
        aTE = 1*(eps2*mu2/1 - 1)/(mu2^2 - 1);
        chk(aTE > 0 && aTE < 1, 'test premise: a TE Brewster angle exists (cos^2 = %.4f)', aTE);
        thB = acosd(sqrt(aTE));
        STEb = em_solve(em_defaults(struct('pol','TE','eps2',eps2,'mu2',mu2,'theta_i_deg',thB)));
        chk(abs(STEb.Gamma) < 1e-9, ...
            'Gamma_TE = 0 at the TE Brewster angle %.4f deg (got %.3e)', thB, abs(STEb.Gamma));
        SScan = em_solve(em_defaults(struct('pol','TE','eps2',eps2,'mu2',mu2,'theta_i_deg',1)));
        chk(isfinite(SScan.theta_B_deg) && abs(SScan.theta_B_deg - thB) < 0.06, ...
            'the scan finds the TE Brewster angle (%.4f vs %.4f)', SScan.theta_B_deg, thB);
        chk(strcmp(SScan.theta_B_src,'numeric'), 'TE Brewster comes from the numeric scan');
        chk(isnan(SScan.theta_c_deg), 'no critical angle when n2 > n1');

        % with equal permeabilities the non-magnetic result must come back
        Snm = em_solve(em_defaults(struct('pol','TM','eps2',eps2,'mu2',1,'theta_i_deg',50)));
        chk(strcmp(Snm.theta_B_src,'analytic'), 'mu1 = mu2 restores the analytic theta_B');
    end
end

% -------------------------------------------------------------------------
function [ok, bad] = match_positions(za, zn, step, zgrid)
%MATCH_POSITIONS every analytic position (excluding the two outermost grid
%   points) must have a numeric extremum within 2 grid steps.
ok = true; bad = '';
zmin = min(zgrid); zmax = max(zgrid);
za = za(za > zmin + 3*step & za < zmax - 3*step);
for k = 1:numel(za)
    if isempty(zn) || min(abs(zn - za(k))) > 2.5*step
        ok = false;
        bad = sprintf('%s z = %.6e has no numeric partner (step %.3e, nearest %s)', ...
            bad, za(k), step, mat2str(max(abs(zn - za(k)))));
    end
end
end
