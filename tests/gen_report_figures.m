function gen_report_figures()
%GEN_REPORT_FIGURES Headless figures and validation tables for the report (A7).
%
%   Run with:   cd EM_VirtualLab/tests; gen_report_figures
%   or headless: matlab -batch "run('.../tests/gen_report_figures.m')"
%
%   Produces (into <project>/figures/):
%     fig1_coeff_air_glass.png     |Gamma| and |tau| vs theta_i, TE and TM,
%                                  with the Brewster angle marked
%     fig2_coeff_glass_air.png     |Gamma| vs theta_i for glass -> air with the
%                                  total-reflection region and theta_c marked
%     fig3_power_balance.png       R and T vs theta_i (R + T = 1)
%     fig4_pec_standing_wave.png   PEC standing wave, nodes and antinodes
%     fig5_evanescent.png          |E| decay in medium 2 under total reflection
%     fig6_gui_*.png               snapshots of the running application
%   and writes docs/VALIDATION.md, a markdown table in which every quantity is
%   computed twice: once from an INDEPENDENT closed-form expression written
%   out in this file, and once from the core (em_solve/em_fields/
%   em_standing_wave).  The empty last column is for the student's own hand
%   calculation.
%
%   Figures are 200 dpi PNGs; the GUI snapshots are captured with exportapp.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'core'));
addpath(fullfile(root,'gui'));

FIGDIR = fullfile(root,'figures');
if ~isfolder(FIGDIR), mkdir(FIGDIR); end
DOCDIR = fullfile(root,'docs');
if ~isfolder(DOCDIR), mkdir(DOCDIR); end

K = em_constants();
fprintf('\n=== gen_report_figures ===\n');
fprintf('output folder: %s\n', FIGDIR);

% ======================================================== fig 1: air->glass
P = em_defaults(struct('eps1',1,'eps2',2.25));
C = em_angle_sweep(P, 0:0.1:89.9);
fig = figure('Visible','off','Color','w','Position',[80 420 640 440]);
hold on; grid on; box on;
h1 = plot(C.theta_deg, C.absGamma_TE, 'b-','LineWidth',1.3);
h2 = plot(C.theta_deg, C.absGamma_TM, 'r--','LineWidth',1.3);
h3 = plot(C.theta_deg, abs(C.TE.tau), 'b:','LineWidth',1.0);
h4 = plot(C.theta_deg, abs(C.TM.tau), 'r-.','LineWidth',1.0);
plot([C.theta_B_deg C.theta_B_deg], [0 1], 'g-','LineWidth',1.0);
text(C.theta_B_deg+1, 0.9, sprintf('\\theta_B = %.2f deg (TM only)', C.theta_B_deg), ...
    'FontSize',9,'Color',[0 0.5 0]);
xlabel('\theta_i  [deg]'); ylabel('coefficient magnitude');
title(sprintf('Air (n=1) to glass (n=1.5), f = %.2f GHz', P.f_Hz/1e9));
legend([h1 h2 h3 h4], {'|\Gamma_{TE}|','|\Gamma_{TM}|','|\tau_{TE}|','|\tau_{TM}|'}, ...
    'Location','east'); ylim([0 1.05]);
set(gca,'FontSize',9);
print(fig,'-dpng','-r200',fullfile(FIGDIR,'fig1_coeff_air_glass.png'));
close(fig);

% ====================================================== fig 2: glass->air
P2 = em_defaults(struct('eps1',2.25,'eps2',1));
C2 = em_angle_sweep(P2, 0:0.1:89.9);
fig = figure('Visible','off','Color','w','Position',[80 420 640 440]);
hold on; grid on; box on;
patch([C2.theta_c_deg 89.9 89.9 C2.theta_c_deg],[0 0 1.05 1.05], ...
    [0.9 0.95 0.9],'EdgeColor','none');
h1 = plot(C2.theta_deg, C2.absGamma_TE, 'b-','LineWidth',1.3);
h2 = plot(C2.theta_deg, C2.absGamma_TM, 'r--','LineWidth',1.3);
h3 = plot(C2.theta_deg, C2.TE.T, 'b:','LineWidth',1.0);
plot([C2.theta_c_deg C2.theta_c_deg],[0 1.05],'m-','LineWidth',1.0);
text(C2.theta_c_deg+1, 0.45, sprintf('\\theta_c = %.2f deg', C2.theta_c_deg), ...
    'FontSize',9,'Color',[0.5 0 0.5]);
text(70, 0.12, 'total reflection:  |\Gamma| = 1,  T = 0', 'FontSize',9);
xlabel('\theta_i  [deg]'); ylabel('coefficient magnitude');
title('Glass (n = 1.5) to air (n = 1): critical angle and total reflection');
legend([h1 h2 h3], {'|\Gamma_{TE}|','|\Gamma_{TM}|','T_{TE}'},'Location','west');
ylim([0 1.05]); set(gca,'FontSize',9);
print(fig,'-dpng','-r200',fullfile(FIGDIR,'fig2_coeff_glass_air.png'));
close(fig);

% ==================================================== fig 3: R + T = 1
fig = figure('Visible','off','Color','w','Position',[80 420 900 380]);
subplot(1,2,1); hold on; grid on; box on;
h1 = plot(C.theta_deg, C.TE.R, 'b-','LineWidth',1.3);
h2 = plot(C.theta_deg, C.TE.T, 'b--','LineWidth',1.3);
h3 = plot(C.theta_deg, C.TE.R + C.TE.T, 'k:','LineWidth',1.6);
xlabel('\theta_i [deg]'); ylabel('power'); ylim([0 1.05]);
title('air to glass, TE'); legend([h1 h2 h3],{'R','T','R+T'},'Location','east');
subplot(1,2,2); hold on; grid on; box on;
plot(C2.theta_deg, C2.TM.R, 'r-','LineWidth',1.3);
plot(C2.theta_deg, C2.TM.T, 'r--','LineWidth',1.3);
plot(C2.theta_deg, C2.TM.R + C2.TM.T, 'k:','LineWidth',1.6);
xlabel('\theta_i [deg]'); ylabel('power'); ylim([0 1.05]);
title('glass to air, TM (R = 1 beyond \theta_c)');
set(gca,'FontSize',9);
print(fig,'-dpng','-r200',fullfile(FIGDIR,'fig3_power_balance.png'));
close(fig);

% ================================================ fig 4: PEC standing wave
SP = em_solve(em_defaults(struct('mode','pec','pol','TE','theta_i_deg',0)));
z = linspace(-2.5*SP.lambda1, 0.6*SP.lambda1, 3001);
W = em_standing_wave(SP, z);
fig = figure('Visible','off','Color','w','Position',[80 420 700 420]);
hold on; grid on; box on;
plot(z/SP.lambda1, 2*abs(sin(SP.k1*z)), 'r--','LineWidth',1.1);       % analytic
hEnv = plot(z/SP.lambda1, W.Eenv, 'b-','LineWidth',1.4);
plot(W.nodes.E/SP.lambda1, zeros(size(W.nodes.E)), 'ko','MarkerFaceColor','k','MarkerSize',5);
plot(W.antinodes.E/SP.lambda1, interp1(z, W.Eenv, W.antinodes.E,'nearest'), ...
    'gs','MarkerFaceColor','g','MarkerSize',6);
for m = 0:5
    plot([-m/2 -m/2],[0 2.1],'Color',[0.85 0.85 0.85],'LineWidth',0.6);
end
xlabel('z / \lambda_1'); ylabel('|E_y|  [V/m]');
title('PEC: standing wave, \Gamma = -1 (nodes: z = -m\lambda/2, antinodes half way)');
legend([hEnv],{'|E_y| = 2|sin(k z)|'},'Location','northwest');
set(gca,'FontSize',9); xlim([-2.5 0.6]);
print(fig,'-dpng','-r200',fullfile(FIGDIR,'fig4_pec_standing_wave.png'));
close(fig);

% ===================================================== fig 5: evanescent
% alpha = k0*sqrt(n1^2 sin^2(theta_i) - n2^2) does NOT depend on the
% polarization, so the TE and TM decay curves coincide exactly; the marker
% shows the penetration depth delta = 1/alpha where the amplitude is exp(-1).
for pol = {'TE','TM'}
    ST = em_solve(em_defaults(struct('pol',pol{1},'eps1',2.25,'eps2',1,'theta_i_deg',60)));
    STo = em_solve(em_defaults(struct('pol','TM','eps1',2.25,'eps2',1,'theta_i_deg',60)));
    z2 = linspace(0, 4*ST.delta, 400);
    fig = figure('Visible','off','Color','w','Position',[80 420 640 430]);
    hold on; grid on; box on;
    plot(z2/ST.lambda0, exp(-ST.alpha*z2), 'b-','LineWidth',1.5);
    plot(z2/ST.lambda0, exp(-STo.alpha*z2), 'r--','LineWidth',1.0);
    plot([ST.delta/ST.lambda0 ST.delta/ST.lambda0],[0 1],'k:','LineWidth',1.0);
    plot(ST.delta/ST.lambda0, exp(-1), 'ko','MarkerFaceColor','k','MarkerSize',6);
    text(ST.delta/ST.lambda0, exp(-1)+0.07, ...
        sprintf(' \\delta = %.4f \\lambda_0 = %.4g m', ST.delta/ST.lambda0, ST.delta), 'FontSize',9);
    xlabel('z / \\lambda_0   (medium 2)'); ylabel('|E_t(z)| / |E_t(0)|');
    title(sprintf('%s incident: evanescent field, glass to air at 60 deg, \\alpha = %.4f k_0', pol{1}, ST.alpha/ST.k0));
    legend({'decaying envelope', 'other polarization (identical)', '\\delta'}, 'Location','northeast');
    ylim([0 1.05]); set(gca,'FontSize',9);
    print(fig,'-dpng','-r200',fullfile(FIGDIR,sprintf('fig5_evanescent_%s.png',pol{1})));
    close(fig);
end

% how deep the field reaches, as a function of the incidence angle (TIR region)
St = em_angle_sweep(em_defaults(struct('eps1',2.25,'eps2',1)), 0:0.05:89.9);
m = St.STE.is_TIR;
th = St.theta_deg(m);
fig = figure('Visible','off','Color','w','Position',[80 420 640 430]);
hold on; grid on; box on;
plot(th, St.STE.alpha(m)/St.STE.k0, 'b-','LineWidth',1.4);
plot(th, St.STE.delta(m)/St.STE.lambda0, 'r-','LineWidth',1.4);
plot([St.theta_c_deg St.theta_c_deg],[0 3],'k:','LineWidth',1.0);
text(St.theta_c_deg+1, 2.6, sprintf('\\theta_c = %.2f deg', St.theta_c_deg), 'FontSize',9);
xlabel('\\theta_i  [deg]'); ylabel('\\alpha / k_0   and   \\delta / \\lambda_0');
title('Total reflection: penetration depth collapses as \\theta_i -> 90 deg');
legend({'\\alpha / k_0','\\delta / \\lambda_0'}, 'Location','east');
set(gca,'FontSize',9); ylim([0 3]);
print(fig,'-dpng','-r200',fullfile(FIGDIR,'fig5b_evanescent_angles.png'));
close(fig);

% ================================================= fig 6: GUI screenshots
try
    fprintf('building the app for the screenshots (this takes ~30 s) ...\n');
    app = EM_VirtualLab('start');
    shots = { ...
        3, 'Media',             'fig6_gui_media_tab.png'; ...
        1, 'Field Animation',   'fig6_gui_fields_dielectric.png'; ...
        4, 'Field Animation',   'fig6_gui_fields_tir.png'; ...
        5, 'Standing Wave',     'fig6_gui_standing_pec.png'; ...
        7, 'Field Animation',   'fig6_gui_fields_pec_tm.png'; ...
        3, 'Coefficients vs Angle','fig6_gui_coefficients_brewster_tm.png'; ...
        4, 'Coefficients vs Angle','fig6_gui_coefficients_tir.png'; ...
        1, 'Results and Theory', 'fig6_gui_results.png'; ...
        8, 'Field Animation',   'fig6_gui_fields_lossy.png'; ...
        8, 'Results and Theory', 'fig6_gui_results_lossy.png'; ...
        10, 'Field Animation',  'fig6_gui_fields_magnetic.png'};
    for k = 1:size(shots,1)
        app.setPreset(app.presetNames{shots{k,1}});
        app.selectTab(shots{k,2});
        app.renderPng(fullfile(FIGDIR, shots{k,3}));
        fprintf('  saved %s\n', shots{k,3});
    end
    fprintf('  formula panel interpreter used: %s\n', app.theoryMode());
    app.close();
catch err
    fprintf('  GUI screenshots skipped: %s (%s)\n', err.message, err.identifier);
end

% ================================================= validation table (md)
fprintf('computing the validation table ...\n');
rows = validate_table(K);
fid = fopen(fullfile(DOCDIR,'VALIDATION.md'),'w');
fprintf(fid,'# Validation: analytic theory vs the computed core\n\n');
fprintf(fid,'Every row is computed twice: the *analytic* column from a closed-form\n');
fprintf(fid,'expression written out independently in `tests/gen_report_figures.m`, the\n');
fprintf(fid,'*core* column from `core/em_solve.m`, `core/em_fields.m` and\n');
fprintf(fid,'`core/em_standing_wave.m`.  The last column is empty on purpose: fill it in\n');
fprintf(fid,'with your own hand calculation (the project asks for 4-5 hand checks).\n\n');
fprintf(fid,'| # | quantity | analytic (textbook formula) | core (MATLAB) | abs. difference | hand check |\n');
fprintf(fid,'|---|----------|-----------------------------|---------------|-----------------|------------|\n');
for k = 1:size(rows,1)
    fprintf(fid,'| %d | %s | %s | %s | %s | |\n', k, rows{k,1}, rows{k,2}, rows{k,3}, rows{k,4});
end
fprintf(fid,'\n_Generated by tests/gen_report_figures.m on %s._\n', datestr(now,'yyyy-mm-dd HH:MM'));
fclose(fid);
fprintf('wrote %s\n', fullfile(DOCDIR,'VALIDATION.md'));

% also show the table on screen
fprintf('\n%-46s %-16s %-16s %s\n','quantity','analytic','core','abs diff');
fprintf('%s\n',repmat('-',1,100));
for k = 1:size(rows,1)
    fprintf('%-46s %-16s %-16s %s\n', rows{k,1}, rows{k,2}, rows{k,3}, rows{k,4});
end
fprintf('\nGEN_REPORT_FIGURES OK - %d validation rows\n\n', size(rows,1));
end

% =========================================================================
function rows = validate_table(K)
%VALIDATE_TABLE analytic vs core for the reference cases of the spec.
%   The analytic column deliberately repeats the textbook formulas here
%   instead of calling the core, so that the comparison is meaningful.
rows = {};
add = @(name, an, co) push_row(name, an, co);
    function push_row(name, an, co)
        d = abs(an - co);
        rows(end+1,:) = {name, sprintf('%.10g',an), sprintf('%.10g',co), ...
            sprintf('%.3e',d)};
    end

% ---- case 1: air to glass, normal incidence ------------------------------
n1 = 1; n2 = 1.5;                       % independent numbers, not from the core
G_an = (n1-n2)/(n1+n2);                 % normal incidence amplitude reflection
tau_an = 2*n1/(n1+n2);
S = em_solve(em_defaults(struct('eps1',1,'eps2',2.25,'pol','TE','theta_i_deg',0)));
add('air->glass normal: Gamma', G_an, real(S.Gamma));
add('air->glass normal: tau', tau_an, real(S.tau));
add('air->glass normal: R', G_an^2, S.R);
add('air->glass normal: T', 1-G_an^2, S.T);
add('air->glass normal: SWR', (1+abs(G_an))/(1-abs(G_an)), ...
    (1+S.absGamma)/(1-S.absGamma));

% ---- case 2: 45 deg, TE and TM (independent Fresnel evaluation) ----------
ti = 45*pi/180; n2 = 1.5;
tt = asin(n1*sin(ti)/n2);               % Snell, computed here from scratch
Gte_an = (n1*cos(ti) - n2*cos(tt))/(n1*cos(ti) + n2*cos(tt));
Gtm_spec = (n1*cos(tt) - n2*cos(ti))/(n1*cos(tt) + n2*cos(ti)); % spec/Cheng sign
Gtm_other = (n2*cos(ti) - n1*cos(tt))/(n2*cos(ti) + n1*cos(tt)); % other books: opposite sign
STe = em_solve(em_defaults(struct('eps1',1,'eps2',2.25,'pol','TE','theta_i_deg',45)));
STm = em_solve(em_defaults(struct('eps1',1,'eps2',2.25,'pol','TM','theta_i_deg',45)));
add('air->glass 45 deg: Gamma_TE', Gte_an, real(STe.Gamma));
add('air->glass 45 deg: Gamma_TM (spec sign)', Gtm_spec, real(STm.Gamma));
add('air->glass 45 deg: Gamma_TM (other books, -x)', Gtm_other, -real(STm.Gamma));
add('air->glass 45 deg: theta_t [deg]', rad2deg(tt), STm.theta_t_deg);

% ---- case 3: Brewster angle ---------------------------------------------
tB_an = atan(n2/n1);
SB = em_solve(em_defaults(struct('eps1',1,'eps2',2.25,'pol','TM','theta_i_deg',rad2deg(tB_an))));
add('air->glass: theta_B [deg]', rad2deg(tB_an), SB.theta_B_deg);
add('air->glass: |Gamma_TM(theta_B)|', 0, abs(SB.Gamma));
add('air->glass: theta_t(theta_B) [deg]', 90 - rad2deg(tB_an), SB.theta_t_deg);

% ---- case 4: critical angle and TIR (glass to air) ----------------------
tc_an = asin(1/1.5);
SG = em_solve(em_defaults(struct('eps1',2.25,'eps2',1,'pol','TE','theta_i_deg',rad2deg(tc_an))));
add('glass->air: theta_c [deg]', rad2deg(tc_an), SG.theta_c_deg);
S60 = em_solve(em_defaults(struct('eps1',2.25,'eps2',1,'pol','TE','theta_i_deg',60)));
alpha_an = 2*pi/S60.lambda0*sqrt(1.5^2*sind(60)^2 - 1);    % k0 sqrt(n1^2 sin^2 - n2^2)
add('glass->air 60 deg: alpha [1/m]', alpha_an, S60.alpha);
add('glass->air 60 deg: delta [m]', 1/alpha_an, S60.delta);
add('glass->air 60 deg: |Gamma_TE|', 1, S60.absGamma);
add('glass->air 60 deg: T', 0, S60.T);

% ---- case 5: PEC surface current and field ------------------------------
SP = em_solve(em_defaults(struct('mode','pec','pol','TE','theta_i_deg',0)));
Js_an = 2*1/K.eta0;                      % |Js| = 2|Hi| cos(ti), |Hi| = 1/eta0
WP = em_standing_wave(SP, linspace(-SP.lambda1, 0, 1001));
add('PEC normal: Gamma', -1, real(SP.Gamma));
add('PEC normal: |Js| [A/m]', Js_an, WP.Js);
zg = linspace(-SP.lambda1, 0, 1001); zz = zg(691);      % a grid point, no interpolation
add('PEC normal: |Ey| at z = -0.31 lambda1', 2*abs(sin(SP.k1*zz)), WP.Eenv(691));

% ---- case 6: boundary conditions and power (from the field arrays) -------
Sf = em_solve(em_defaults(struct('pol','TM','eps1',1,'eps2',4,'theta_i_deg',50)));
xv = linspace(-Sf.lambda0, Sf.lambda0, 21);
[X,Z] = meshgrid(xv,[0 0]);
F = em_fields(Sf, X, Z);
add('TM 50 deg: max |tangential E jump|', 0, max(abs(F.E1.x(1,:)-F.E2.x(1,:))));
add('TM 50 deg: max |tangential H jump|', 0, max(abs(F.H1.y(1,:)-F.H2.y(1,:))));
add('TM 50 deg: max |eps Ez jump|', 0, max(abs(Sf.P.eps1*F.E1.z(1,:)-Sf.P.eps2*F.E2.z(1,:))));
add('TM 50 deg: R + T - 1', 0, Sf.R + Sf.T - 1);
add('TM 50 deg: Sz(medium 1) - Sz(medium 2)', 0, F.Sz1(1,1) - F.Sz2(1,1));

% ---- case 7: lossy half-space (sigma > 0) -------------------------------
K2 = em_constants();
f2 = 1e9; w2 = 2*pi*f2;
epsr2 = 4.4; s2 = 0.02;
SL = em_solve(em_defaults(struct('eps2',epsr2,'sigma2',s2,'theta_i_deg',0)));
add('lossy FR-4: Re(eps_c)', epsr2, real(SL.eps2c));
add('lossy FR-4: -Im(eps_c)', s2/(w2*K2.eps0), -imag(SL.eps2c));
td = s2/(w2*K2.eps0*epsr2);
add('lossy FR-4: loss tangent', td, SL.tan_delta2);
add('lossy FR-4: alpha [Np/m]', SL.k0*sqrt(epsr2)*sqrt((sqrt(1+td^2)-1)/2), SL.att2);
add('lossy FR-4: skin depth [m]', 1/(SL.k0*sqrt(epsr2)*sqrt((sqrt(1+td^2)-1)/2)), SL.skin2);
add('lossy FR-4: R + T - 1 (interface balance)', 0, SL.R + SL.T - 1);
SLA = em_solve(em_defaults(struct('eps2',epsr2,'sigma2',s2,'pol','TM','theta_i_deg',35)));
add('lossy FR-4 TM 35 deg: R + T - 1', 0, SLA.R + SLA.T - 1);

% ---- case 8: magnetic medium (mu_r ~= 1) --------------------------------
Sm = em_solve(em_defaults(struct('eps2',2.25,'mu2',4,'theta_i_deg',0)));
add('magnetic: n2 = sqrt(eps_r mu_r)', sqrt(2.25*4), real(Sm.n2));
add('magnetic: eta2 = eta0 sqrt(mu_r/eps_r)', K2.eta0*sqrt(4/2.25), real(Sm.eta2));
add('magnetic: Gamma at normal incidence', (sqrt(4/2.25)-1)/(sqrt(4/2.25)+1), real(Sm.Gamma));
aTE = 1*(2.25*4/1 - 1)/(4^2 - 1);
add('magnetic: TE Brewster angle [deg]', acosd(sqrt(aTE)), ...
    em_solve(em_defaults(struct('pol','TE','eps2',2.25,'mu2',4,'theta_i_deg',1))).theta_B_deg);

% ---- case 7b: evanescent decay law --------------------------------------
add('TIR: |E(z+delta)|/|E(z)| - exp(-1)', 0, exp(-S60.alpha*S60.delta) - exp(-1));
end
