function app = EM_VirtualLab(action)
%EM_VIRTUAL_LAB Interactive virtual laboratory: EM wave interaction with the
%   boundary between two media.  Programmatic uifigure app (no .mlapp file),
%   base MATLAB only, R2021a or newer.
%
%   app = EM_VIRTUAL_LAB            launches the app (visible)
%   app = EM_VIRTUAL_LAB('start')   same
%   app = EM_VIRTUAL_LAB('selftest')  builds the app INVISIBLE, walks through
%                                   every preset and both polarizations,
%                                   steps the animation, checks the rendered
%                                   data for NaN / Inf, closes the app and
%                                   prints a PASS/FAIL line.  Used by
%                                   tests/smoke_gui.m.
%
%   Physics lives entirely in core/ (em_solve, em_fields, em_standing_wave,
%   em_angle_sweep).  This file only visualises those results.
%
%   Student note: everything shown by the app is produced by the equations of
%   Section 3 of the project specification; the 'Results and Theory' tab prints
%   both the numbers and the formulas they come from.

if nargin < 1 || isempty(action)
    action = 'start';
end

% ---------------------------------------------------------------- state ----
% All state lives in this function's workspace so that the nested functions
% below can share it.  There are NO global variables anywhere in the project.
fig = [];            % main uifigure
H   = struct();      % graphics handle struct
P   = em_defaults(); % validated parameter struct (core)
S   = [];            % em_solve result for the current parameters
CACHE = struct();    % precomputed phasors for the animation
phi = 0;             % animation phase [rad]
playing = false;     % animation state
tmr = [];            % timer
regimeTxt = '';      % last regime string
theoryMode = 'latex';% 'latex' or 'plain' - what the formula panel shows
presetNames = { ...
    'Preset: air to glass, normal incidence', ...
    'Preset: air to glass, 45 deg, horizontal (TE)', ...
    'Preset: air to glass, Brewster angle, vertical (TM)', ...
    'Preset: glass to air, 60 deg, total reflection', ...
    'Preset: PEC, normal incidence', ...
    'Preset: PEC, 45 deg, horizontal (TE)', ...
    'Preset: PEC, 45 deg, vertical (TM)', ...
    'Preset: air to lossy FR-4 (sigma = 0.02 S/m)', ...
    'Preset: air to sea water (eps_r = 81, sigma = 4 S/m)', ...
    'Preset: air to magnetic medium (mu_r = 4, TE Brewster)'};
lastTable = {};      % last numeric table written to the Results tab

switch lower(action)
    case 'start'
        buildApp(true);
        app = api();
    case 'selftest'
        app = selfTest();
    otherwise
        error('EM_VirtualLab:badAction', ...
            'Unknown action ''%s'' (use ''start'' or ''selftest'').', action);
end

% ============================================================ public API ==
    function a = api()
        %API handles used by tests and by the smoke test
        a.fig = fig;
        a.setPreset = @applyPreset;
        a.setPol = @setPol;
        a.stepFrames = @stepFrames;
        a.rendered = @renderedData;
        a.params = @getParams;      % nested-function handles read the LIVE
        a.solve  = @getSolve;       % state; anonymous @() P would snapshot it
        a.applyParams = @(p) applyParams(p);
        a.close = @closeApp;
        a.presetNames = presetNames;
        a.selectTab = @selectTab;
        a.callback = @getCallback;      % fire a real widget callback by name
        a.theoryMode = @getTheoryMode;
        a.renderPng = @renderPng;
    end

% ============================================== live state accessors =====
    function p = getParams()
        p = P;
    end
    function s = getSolve()
        s = S;
    end
    function t = getTheoryMode()
        t = theoryMode;
    end

% ============================================================ build app ===
    function buildApp(visibleFlag)
        if visibleFlag, vis = 'on'; else, vis = 'off'; end
        fig = uifigure('Name','EM Virtual Lab - reflection and transmission at a boundary', ...
            'Position',[60 40 1340 820], 'Visible',vis, ...
            'CloseRequestFcn',@onCloseRequest);

        % every handle field exists from the start (also used by the selftest)
        H.imgE = []; H.imgH = []; H.quivE = []; H.quivH = [];
        H.quivIdx = {1:12:241, 1:12:241};
        H.hSWEinst = []; H.hSWHinst = [];
        H.hSWE = []; H.hSWH = [];

        g = uigridlayout(fig,[1 2]);
        g.ColumnWidth = {330,'1x'};
        g.RowHeight = {'1x'};
        g.Padding = [6 6 6 6];
        g.ColumnSpacing = 8;

        buildControls(g);
        buildTabs(g);

        % ---- animation timer: ONE timer for the whole app -----------------
        % Period ~1/15 s (spec 7.6 requires >= 15 fps with a 241x241 grid).
        tmr = timer('ExecutionMode','fixedSpacing', 'Period',0.067, ...
                    'BusyMode','drop', 'TimerFcn',@onTick);

        applyParams(P, true);        % initial solve + full redraw
    end

% ---------------------------------------------------------- left controls -
    function buildControls(parent)
        pnl = uipanel(parent,'Title','Controls','Scrollable','on');
        pnl.Layout.Row = 1; pnl.Layout.Column = 1;

        gl = uigridlayout(pnl,[1 1]);
        gl.RowHeight = repmat({'fit'},1,40);
        gl.ColumnWidth = {'1x','1x'};
        gl.Padding = [6 6 6 6];
        gl.RowSpacing = 2;      % keeps the whole panel visible without scrolling

        r = 0;
        r = r+1;
        lbl(gl,r,1,'Simulation mode:');
        H.ddMode = uidropdown(gl, 'Items', {'Dielectric half-space','Perfect conductor (PEC)'}, ...
            'Value','Dielectric half-space', 'ValueChangedFcn',@onModeChanged);
        H.ddMode.Layout.Row = r; H.ddMode.Layout.Column = [1 2];

        r = r+1;
        H.lblN = lbl(gl,r,[1 2],'');

        r = r+1;
        lbl(gl,r,[1 2],'POLARIZATION','bold');

        r = r+1;
        lbl(gl,r,1,'Polarization:');
        H.ddPol = uidropdown(gl, 'Items', {'Horizontal (TE, perpendicular)','Vertical (TM, parallel)'}, ...
            'Value','Horizontal (TE, perpendicular)', 'ValueChangedFcn',@onPolChanged);
        H.ddPol.Layout.Row = r; H.ddPol.Layout.Column = [1 2];

        r = r+1;
        H.lblPol = lbl(gl,r,[1 2],'E parallel to the interface, along y.');

        r = r+1;
        lbl(gl,r,[1 2],'WAVE AND GEOMETRY','bold');

        r = r+1;
        lbl(gl,r,1,'Frequency:');
        H.efFreq = uieditfield(gl,'numeric','Value',1,'Limits',[1e-3 1e9], ...
            'ValueChangedFcn',@onFreqChanged);
        H.efFreq.Layout.Row = r; H.efFreq.Layout.Column = 2;

        r = r+1;
        lbl(gl,r,1,'Frequency unit:');
        H.ddUnit = uidropdown(gl, 'Items', {'GHz','MHz'}, 'Value','GHz', ...
            'ValueChangedFcn',@onFreqChanged);
        H.ddUnit.Layout.Row = r; H.ddUnit.Layout.Column = 2;

        r = r+1;
        lbl(gl,r,1,'Incidence angle [deg]:');
        H.efTheta = uieditfield(gl,'numeric','Value',0,'Limits',[0 89.9], ...
            'ValueChangedFcn',@onThetaChanged);
        H.efTheta.Layout.Row = r; H.efTheta.Layout.Column = 2;

        r = r+1;
        H.slTheta = uislider(gl,'Limits',[0 89.9],'Value',0,'MajorTicks',0:15:75, ...
            'ValueChangedFcn',@onThetaSlider, ...
            'ValueChangingFcn',@onThetaSlider);
        H.slTheta.Layout.Row = r; H.slTheta.Layout.Column = [1 2];

        r = r+1;
        H.btnNormal = uibutton(gl,'Text','Normal incidence', ...
            'ButtonPushedFcn',@onNormalIncidence, ...
            'Tooltip','Set the incidence angle to 0 deg. TE and TM then give the same coefficients.');
        H.btnNormal.Layout.Row = r; H.btnNormal.Layout.Column = 1;
        H.btnBrewster = uibutton(gl,'Text','Go to Brewster', ...
            'ButtonPushedFcn',@onGoBrewster);
        H.btnBrewster.Layout.Row = r; H.btnBrewster.Layout.Column = 2;

        r = r+1;
        H.btnCrit = uibutton(gl,'Text','Go to critical angle', ...
            'ButtonPushedFcn',@onGoCritical);
        H.btnCrit.Layout.Row = r; H.btnCrit.Layout.Column = [1 2];

        r = r+1;
        lbl(gl,r,[1 2],'ANIMATION','bold');

        r = r+1;
        H.btnPlay = uibutton(gl,'state','Text','Play','Value',false, ...
            'ValueChangedFcn',@onPlayPause);
        H.btnPlay.Layout.Row = r; H.btnPlay.Layout.Column = [1 2];

        r = r+1;
        lbl(gl,r,1,'Speed [x]:');
        H.slSpeed = uislider(gl,'Limits',[0.1 5],'Value',1, ...
            'MajorTicks',[0.1 1 2 3 4 5],'ValueChangedFcn',@onSpeedChanged);
        H.slSpeed.Layout.Row = r; H.slSpeed.Layout.Column = 2;

        r = r+1;
        lbl(gl,r,1,'Phase [deg]:');
        H.slPhase = uislider(gl,'Limits',[0 360],'Value',0, ...
            'MajorTicks',[0 90 180 270 360],'ValueChangedFcn',@onPhaseSlider);
        H.slPhase.Layout.Row = r; H.slPhase.Layout.Column = 2;

        r = r+1;
        H.lblSlow = lbl(gl,r,[1 2],'time is slowed down (not real time)');

        r = r+1;
        lbl(gl,r,[1 2],'PRESETS','bold');

        r = r+1;
        H.ddPreset = uidropdown(gl,'Items',[{'Choose a preset ...'} presetNames], ...
            'Value','Choose a preset ...', 'ValueChangedFcn',@onPreset);
        H.ddPreset.Layout.Row = r; H.ddPreset.Layout.Column = [1 2];

        r = r+1;
        H.btnReset = uibutton(gl,'Text','Reset to defaults', ...
            'ButtonPushedFcn',@onReset);
        H.btnReset.Layout.Row = r; H.btnReset.Layout.Column = [1 2];

        r = r+1;
        H.lblStatus = lbl(gl,r,[1 2],'Ready.');
    end

    function h = lbl(parent,row,col,txt,weight)
        if nargin < 5, weight = 'normal'; end
        h = uilabel(parent,'Text',txt,'FontWeight',weight,'WordWrap','on');
        h.Layout.Row = row; h.Layout.Column = col;
    end

% ------------------------------------------------------------- right tabs -
    function buildTabs(parent)
        tg = uitabgroup(parent);
        tg.Layout.Row = 1; tg.Layout.Column = 2;
        H.tabs = tg;

        % ---------------- Tab 0: media (the electromagnetic constants) -----
        buildMediaTab(tg);

        % ---------------- Tab 1: field animation -------------------------
        t1 = uitab(tg,'Title','Field Animation');
        g1 = uigridlayout(t1,[3 1]);
        g1.RowHeight = {'fit','1x','fit'};
        g1.RowSpacing = 4;

        % display toolbar: which waves are shown, the window size and the two
        % plotted components.  These are display settings, so they live next to
        % the display instead of in the narrow control panel.
        gt = uigridlayout(g1,[3 4]);
        gt.Layout.Row = 1; gt.Layout.Column = 1;
        gt.RowHeight = {'fit','fit','fit'};
        gt.ColumnWidth = {'1x','1x','1x','1x'};
        gt.Padding = [0 0 0 0];

        H.cbInc = uicheckbox(gt,'Text','Incident','Value',true,'ValueChangedFcn',@onWavesChanged);
        H.cbInc.Layout.Row = 1; H.cbInc.Layout.Column = 1;
        H.cbRef = uicheckbox(gt,'Text','Reflected','Value',true,'ValueChangedFcn',@onWavesChanged);
        H.cbRef.Layout.Row = 1; H.cbRef.Layout.Column = 2;
        H.cbTra = uicheckbox(gt,'Text','Transmitted','Value',true,'ValueChangedFcn',@onWavesChanged);
        H.cbTra.Layout.Row = 1; H.cbTra.Layout.Column = 3;
        H.cbQuiver = uicheckbox(gt,'Text','field vectors (quiver)', ...
            'Value',P.view.quiver,'ValueChangedFcn',@onQuiverChanged);
        H.cbQuiver.Layout.Row = 1; H.cbQuiver.Layout.Column = 4;

        q1 = uilabel(gt,'Text','E map:');   q1.Layout.Row = 2; q1.Layout.Column = 1;
        H.ddEc = uidropdown(gt,'Items',{'E_y'},'Value','E_y', ...
            'ValueChangedFcn',@onCompChanged);
        H.ddEc.Layout.Row = 2; H.ddEc.Layout.Column = 2;
        q2 = uilabel(gt,'Text','H map:');   q2.Layout.Row = 2; q2.Layout.Column = 3;
        H.ddHc = uidropdown(gt,'Items',{'H_x'},'Value','H_x', ...
            'ValueChangedFcn',@onCompChanged);
        H.ddHc.Layout.Row = 2; H.ddHc.Layout.Column = 4;

        q3 = uilabel(gt,'Text','Window [lambda0]:'); q3.Layout.Row = 3; q3.Layout.Column = 1;
        H.efWin = uieditfield(gt,'numeric','Value',4,'Limits',[0.5 20], ...
            'ValueChangedFcn',@onWindowChanged);
        H.efWin.Layout.Row = 3; H.efWin.Layout.Column = 2;

        ga = uigridlayout(g1,[1 2]);
        ga.Layout.Row = 2; ga.Layout.Column = 1;
        ga.Padding = [0 0 0 0];
        H.axE = uiaxes(ga); H.axE.Layout.Row = 1; H.axE.Layout.Column = 1;
        H.axH = uiaxes(ga); H.axH.Layout.Row = 1; H.axH.Layout.Column = 2;

        H.lblAnim = uilabel(g1,'Text','','FontName','Courier New','WordWrap','on');
        H.lblAnim.Layout.Row = 3; H.lblAnim.Layout.Column = 1;

        buildRestTabs(tg);
    end

    function buildMediaTab(tg)
        %BUILDMEDIATAB the electromagnetic constants of both media.  They live
        %   in their own tab so that the control panel on the left stays short
        %   enough to show every control (including Play/Pause) without
        %   scrolling.
        tm = uitab(tg,'Title','Media');
        gm = uigridlayout(tm,[8 4]);
        gm.RowHeight = {'fit','fit','fit','fit','fit','fit','fit','1.2x'};
        gm.ColumnWidth = {'0.7x','1x','0.7x','1x'};
        gm.RowSpacing = 6; gm.ColumnSpacing = 6; gm.Padding = [10 10 10 10];

        hm1 = uilabel(gm,'Text','Medium 1   (incident side)','FontWeight','bold');
        hm1.Layout.Row = 1; hm1.Layout.Column = [1 2];
        hm2 = uilabel(gm,'Text','Medium 2   (transmitted side)','FontWeight','bold');
        hm2.Layout.Row = 1; hm2.Layout.Column = [3 4];

        limE = P.limits.eps; limM = P.limits.mu; limS = P.limits.sigma;

        a = uilabel(gm,'Text','eps_r');        a.Layout.Row = 2; a.Layout.Column = 1;
        H.efEps1 = uieditfield(gm,'numeric','Value',P.eps1,'Limits',limE, ...
            'ValueChangedFcn',@onEpsChanged);
        H.efEps1.Layout.Row = 2; H.efEps1.Layout.Column = 2;
        b = uilabel(gm,'Text','eps_r');        b.Layout.Row = 2; b.Layout.Column = 3;
        H.efEps2 = uieditfield(gm,'numeric','Value',P.eps2,'Limits',limE, ...
            'ValueChangedFcn',@onEpsChanged);
        H.efEps2.Layout.Row = 2; H.efEps2.Layout.Column = 4;

        a = uilabel(gm,'Text','mu_r');         a.Layout.Row = 3; a.Layout.Column = 1;
        H.efMu1 = uieditfield(gm,'numeric','Value',P.mu1,'Limits',limM, ...
            'ValueChangedFcn',@onEpsChanged);
        H.efMu1.Layout.Row = 3; H.efMu1.Layout.Column = 2;
        b = uilabel(gm,'Text','mu_r');         b.Layout.Row = 3; b.Layout.Column = 3;
        H.efMu2 = uieditfield(gm,'numeric','Value',P.mu2,'Limits',limM, ...
            'ValueChangedFcn',@onEpsChanged);
        H.efMu2.Layout.Row = 3; H.efMu2.Layout.Column = 4;

        a = uilabel(gm,'Text','sigma  [S/m]'); a.Layout.Row = 4; a.Layout.Column = 1;
        H.efSig1 = uieditfield(gm,'numeric','Value',P.sigma1,'Limits',limS, ...
            'ValueChangedFcn',@onEpsChanged);
        H.efSig1.Layout.Row = 4; H.efSig1.Layout.Column = 2;
        b = uilabel(gm,'Text','sigma  [S/m]'); b.Layout.Row = 4; b.Layout.Column = 3;
        H.efSig2 = uieditfield(gm,'numeric','Value',P.sigma2,'Limits',limS, ...
            'ValueChangedFcn',@onEpsChanged);
        H.efSig2.Layout.Row = 4; H.efSig2.Layout.Column = 4;

        a = uilabel(gm,'Text','Quick material (medium 2):');
        a.Layout.Row = 5; a.Layout.Column = 1;
        matList = materialNames();
        H.ddMat = uidropdown(gm,'Items',matList, 'Value',matList{1}, ...
            'ValueChangedFcn',@onMaterial);
        H.ddMat.Layout.Row = 5; H.ddMat.Layout.Column = [2 4];

        H.btnSwap = uibutton(gm,'Text','Swap media 1 <-> 2', ...
            'ButtonPushedFcn',@onSwapMedia);
        H.btnSwap.Layout.Row = 6; H.btnSwap.Layout.Column = [1 2];

        a = uilabel(gm,'Text',['eps_r, mu_r in (0, 1e4];  sigma in [0, 1e9] S/m.  ' ...
            'sigma > 0 makes a medium lossy;  mu_r ~= 1 makes it magnetic.']);
        a.Layout.Row = 6; a.Layout.Column = [3 4]; a.WordWrap = 'on';

        H.txtMedia = uitextarea(gm,'Editable','off','FontName','Courier New');
        H.txtMedia.Layout.Row = 7; H.txtMedia.Layout.Column = [1 4];

        H.txtMediaHelp = uitextarea(gm,'Editable','off','FontName','Courier New');
        H.txtMediaHelp.Layout.Row = 8; H.txtMediaHelp.Layout.Column = [1 4];
        H.txtMediaHelp.Value = { ...
            'What the constants mean:'; ...
            '  eps_r  relative permittivity   (medium 1 = 1 for air, 2.25 for glass)'; ...
            '  mu_r   relative permeability   (1 for every non-magnetic material)'; ...
            '  sigma  conductivity in S/m     (0 for a lossless dielectric)'; ...
            'With sigma > 0:  eps_c = eps_r - j*sigma/(omega*eps0), n = sqrt(eps_c*mu_r),'; ...
            '  eta = eta0*sqrt(mu_r/eps_c), tan(d) = sigma/(omega*eps0*eps_r), delta_s = 1/alpha.'; ...
            'The transmitted field decays as exp(-alpha*z), the power as exp(-2*alpha*z);'; ...
            'R + T = 1 still holds exactly at the interface (absorption happens inside).'; ...
            'With mu_r ~= 1 the Brewster angle moves: for eps_r = 2.25, mu_r = 4 it exists'; ...
            'for TE (43.09 deg) and not for TM - the opposite of the non-magnetic case.'};
    end

    function buildRestTabs(tg)

        % ---------------- Tab 2: standing wave ---------------------------
        t2 = uitab(tg,'Title','Standing Wave');
        g2 = uigridlayout(t2,[2 2]);
        g2.RowHeight = {'1x','fit'};
        H.axSWE = uiaxes(g2); H.axSWE.Layout.Row = 1; H.axSWE.Layout.Column = 1;
        H.axSWH = uiaxes(g2); H.axSWH.Layout.Row = 1; H.axSWH.Layout.Column = 2;
        H.tblSW = uitable(g2,'ColumnName',{'Type','z [m]','z/lambda1','|field| [SI]'});
        H.tblSW.Layout.Row = 2; H.tblSW.Layout.Column = 1;
        H.txtSW = uitextarea(g2,'Editable','off','FontName','Courier New');
        H.txtSW.Layout.Row = 2; H.txtSW.Layout.Column = 2;

        % ---------------- Tab 3: coefficients vs angle -------------------
        t3 = uitab(tg,'Title','Coefficients vs Angle');
        g3 = uigridlayout(t3,[3 2]);
        g3.RowHeight = {'fit','1x','1x'};
        H.ddPlot = uidropdown(g3,'Items',{'|Gamma| and |tau|','R and T (power)'}, ...
            'Value','|Gamma| and |tau|','ValueChangedFcn',@onPlotModeChanged);
        H.ddPlot.Layout.Row = 1; H.ddPlot.Layout.Column = [1 2];
        H.axC = gobjects(1,4);
        labs = {'|Gamma|','phase(Gamma) [deg]','|tau|','phase(tau) [deg]'};
        for k = 1:4
            H.axC(k) = uiaxes(g3);
            H.axC(k).Layout.Row = 1 + ceil(k/2);
            H.axC(k).Layout.Column = 1 + mod(k-1,2);
            title(H.axC(k), labs{k});
        end

        % ---------------- Tab 4: results and theory ----------------------
        t4 = uitab(tg,'Title','Results and Theory');
        g4 = uigridlayout(t4,[1 2]);
        g4.ColumnWidth = {'1.15x','0.85x'};
        H.txtRes = uitextarea(g4,'Editable','off','FontName','Courier New');
        H.txtRes.Layout.Row = 1; H.txtRes.Layout.Column = 1;
        H.axTheory = uiaxes(g4);
        H.axTheory.Layout.Row = 1; H.axTheory.Layout.Column = 2;
        axis(H.axTheory,'off');
    end

% ======================================================= parameter read ===
    function p = readControls()
        %READCONTROLS build a parameter struct from the widget values.
        p = em_defaults();
        if strcmp(H.ddMode.Value,'Perfect conductor (PEC)')
            p.mode = 'pec';
        else
            p.mode = 'dielectric';
        end
        if strcmp(H.ddPol.Value,'Vertical (TM, parallel)')
            p.pol = 'TM';
        else
            p.pol = 'TE';
        end
        p.eps1   = H.efEps1.Value;
        p.mu1    = H.efMu1.Value;
        p.sigma1 = H.efSig1.Value;
        p.eps2   = H.efEps2.Value;
        p.mu2    = H.efMu2.Value;
        p.sigma2 = H.efSig2.Value;   % ignored in PEC mode (no transmitted field)
        p.f_Hz = H.efFreq.Value * unitFactor();
        p.theta_i_deg = H.efTheta.Value;
        p.view.win_z = H.efWin.Value;
        % keep the derived x-extent inside its own legal range: with win_z at the
        % minimum (0.5 lambda0) 0.75*win_z would be 0.375 and the whole update
        % was rejected as "invalid input" for a perfectly legal window
        p.view.win_x = max(H.efWin.Value*0.75, P.limits.win_lambda0(1));
        p.view.speed = H.slSpeed.Value;
        p.view.show_incident    = H.cbInc.Value;
        p.view.show_reflected   = H.cbRef.Value;
        p.view.show_transmitted = H.cbTra.Value;
        p.view.quiver = H.cbQuiver.Value;
    end

    function f = unitFactor()
        if strcmp(H.ddUnit.Value,'MHz'), f = 1e6; else, f = 1e9; end
    end

    function applyParams(newP, doFull)
        %APPLYPARAMS validate, solve, refresh every tab.
        try
            P = em_defaults(newP);
        catch err
            uialert(fig, err.message, 'Invalid input');
            syncControls();
            return;
        end
        S = em_solve(P);

        % update the mode-dependent widgets
        isPEC = strcmp(P.mode,'pec');
        en2 = matlab.lang.OnOffSwitchState(~isPEC);   % medium 2 is the PEC itself
        H.efEps2.Enable = en2; H.efMu2.Enable = en2; H.efSig2.Enable = en2;
        H.ddMat.Enable  = en2;
        % The special-angle buttons carry their reason in the label: the angle
        % when it exists, otherwise why not and what to change.  This is how a
        % user discovers that the critical angle needs n1 > n2 (Swap media).
        hasB  = ~isPEC && isfinite(S.theta_B_deg);
        hasC  = ~isPEC && isfinite(S.theta_c_deg);
        H.btnBrewster.Enable = matlab.lang.OnOffSwitchState(hasB);
        H.btnCrit.Enable     = matlab.lang.OnOffSwitchState(hasC);
        if hasB
            H.btnBrewster.Text = sprintf('Brewster %.2f deg', S.theta_B_deg);
        elseif isPEC
            H.btnBrewster.Text = 'Brewster: n/a (PEC)';
        else
            % the same setup can still have a Brewster angle for the OTHER
            % polarization (that is exactly what happens for magnetic media):
            % say so instead of a bare "none"
            Pother = P;
            if strcmp(P.pol,'TE'), Pother.pol = 'TM'; else, Pother.pol = 'TE'; end
            Sother = em_solve(Pother);
            if isfinite(Sother.theta_B_deg)
                H.btnBrewster.Text = sprintf('Brewster %.2f deg for %s', ...
                    Sother.theta_B_deg, Pother.pol);
            else
                H.btnBrewster.Text = 'Brewster: none here';
            end
        end
        if hasC
            H.btnCrit.Text = sprintf('critical %.2f deg', S.theta_c_deg);
        elseif isPEC
            H.btnCrit.Text = 'critical: n/a (PEC)';
        else
            H.btnCrit.Text = 'critical: needs n1 > n2';
        end
        H.btnBrewster.Tooltip = ['Brewster angle (Gamma = 0). For lossless ' ...
            'non-magnetic media it exists for TM only; with mu_r ~= 1 it can ' ...
            'exist for TE instead, and a lossy (sigma > 0) medium has none. ' ...
            'Change the media on the Media tab.'];
        H.btnCrit.Tooltip = ['Critical angle (total reflection). It exists only ' ...
            'for two LOSSLESS media with n1 > n2, i.e. when medium 1 is ' ...
            'optically denser than medium 2. Press "Swap media 1 <-> 2" on the ' ...
            'Media tab (glass -> air), or choose the preset "glass to air, 60 ' ...
            'deg, total reflection".'];

        syncControls();
        updateComponentLists();
        buildCache();
        updateAnimAxes();
        updateStanding();
        updateCoeffs();
        updateResults();
        updateTheory();
        updateStatus();
        if nargin > 1 && doFull
            % nothing else for now
        end
    end

    function syncControls()
        % reflect P back into the widgets (no callbacks fired)
        if strcmp(P.mode,'pec')
            H.ddMode.Value = 'Perfect conductor (PEC)';
        else
            H.ddMode.Value = 'Dielectric half-space';
        end
        if strcmp(P.pol,'TM')
            H.ddPol.Value = 'Vertical (TM, parallel)';
        else
            H.ddPol.Value = 'Horizontal (TE, perpendicular)';
        end
        % the six electromagnetic constants, clamped to the field limits
        H.efEps1.Value = clampfld(H.efEps1, P.eps1);
        H.efMu1.Value  = clampfld(H.efMu1,  P.mu1);
        H.efSig1.Value = clampfld(H.efSig1, P.sigma1);
        H.efEps2.Value = clampfld(H.efEps2, P.eps2);
        H.efMu2.Value  = clampfld(H.efMu2,  P.mu2);
        H.efSig2.Value = clampfld(H.efSig2, P.sigma2);
        H.efTheta.Value = P.theta_i_deg;
        H.slTheta.Value = P.theta_i_deg;
        if P.f_Hz >= 1e9
            H.ddUnit.Value = 'GHz'; H.efFreq.Value = P.f_Hz/1e9;
        else
            H.ddUnit.Value = 'MHz'; H.efFreq.Value = P.f_Hz/1e6;
        end
        H.efWin.Value = P.view.win_z;
        H.cbInc.Value = P.view.show_incident;
        H.cbRef.Value = P.view.show_reflected;
        H.cbTra.Value = P.view.show_transmitted;
        H.cbQuiver.Value = P.view.quiver;
        H.slSpeed.Value = P.view.speed;
        if strcmp(P.pol,'TE')
            H.lblPol.Text = 'TE (horizontal): E along y, parallel to the interface.';
        else
            H.lblPol.Text = 'TM (vertical): E in the plane of incidence (x-z).';
        end
        if strcmp(P.mode,'pec')
            H.lblN.Text = {sprintf(['Medium 1: eps_r = %.4g, mu_r = %.4g, sigma = %.4g S/m, ' ...
                'n1 = %s'], P.eps1, P.mu1, P.sigma1, fmtnum(S.n1)), ...
                'Medium 2 = PEC: eta2 = 0, tau = 0, no transmitted field.'};
        else
            H.lblN.Text = { ...
                sprintf('n1 = %s    n2 = %s', fmtnum(S.n1), fmtnum(S.n2)), ...
                sprintf('eta1 = %.4g ohm   eta2 = %.4g ohm', real(S.eta1), real(S.eta2)), ...
                lossynote(S)};
        end

        % detailed medium report shown on the Media tab
        L = {};
        L{end+1} = sprintf('MEDIUM 1   eps_r = %.6g    mu_r = %.6g    sigma = %.6g S/m', ...
            P.eps1, P.mu1, P.sigma1);
        L{end+1} = sprintf('   eps_c1 = %s    n1 = %s    eta1 = %s ohm', ...
            fmtnum(S.eps1c), fmtnum(S.n1), fmtnum(S.eta1));
        L{end+1} = sprintf('   lambda1 = %.6g m    alpha1 = %s Np/m', S.lambda1, fmtnum(S.att1));
        if ~S.lossless1
            L{end+1} = sprintf('   lossy: tan d1 = %.6g, skin depth = %s m', ...
                S.tan_delta1, fmtnum(S.skin1));
        end
        L{end+1} = '';
        if strcmp(P.mode,'pec')
            L{end+1} = 'MEDIUM 2   PERFECT CONDUCTOR:  eta2 = 0, tau = 0, T = 0, no field for z > 0';
        else
            L{end+1} = sprintf('MEDIUM 2   eps_r = %.6g    mu_r = %.6g    sigma = %.6g S/m', ...
                P.eps2, P.mu2, P.sigma2);
            L{end+1} = sprintf('   eps_c2 = %s    n2 = %s    eta2 = %s ohm', ...
                fmtnum(S.eps2c), fmtnum(S.n2), fmtnum(S.eta2));
            L{end+1} = sprintf('   lambda2 = %.6g m    alpha2 = %s Np/m', S.lambda2, fmtnum(S.att2));
            if ~S.lossless2
                L{end+1} = sprintf('   lossy: tan d2 = %.6g, skin depth = %s m', ...
                    S.tan_delta2, fmtnum(S.skin2));
            end
        end
        L{end+1} = '';
        L{end+1} = sprintf('n2/n1 = %s        eta2/eta1 = %s', ...
            fmtnum(S.n2/S.n1), fmtnum(S.eta2/S.eta1));
        L{end+1} = lossynote(S);
        if isfinite(S.theta_c_deg)
            L{end+1} = sprintf('critical angle = %.4f deg (n1 > n2)', S.theta_c_deg);
        end
        if isfinite(S.theta_B_deg)
            L{end+1} = sprintf('Brewster angle = %.4f deg (%s, %s)', ...
                S.theta_B_deg, P.pol, S.theta_B_src);
        end
        if isfield(H,'txtMedia') && ~isempty(H.txtMedia) && isvalid(H.txtMedia)
            H.txtMedia.Value = L;
        end
    end

% --------------------------------------------------------- callbacks ------
    function v2 = clampfld(h, v)
        %CLAMPFLD keep a value inside the edit field's own limits.
        %   Do NOT shift the lower limit: a sigma of exactly 0 must stay 0,
        %   otherwise a lossless medium silently becomes lossy (1e-9 S/m is
        %   still a complex permittivity and makes theta_t complex).
        v2 = min(max(v, h.Limits(1)), h.Limits(2));
    end

    function s = fmtnum(v)
        %FMTNUM format a possibly complex / non-finite number for the panels
        if isnan(v)
            s = 'undefined';
        elseif ~isfinite(v)
            s = sprintf('%g', v);            % Inf stays 'Inf', never 'NaN'
        elseif imag(v) == 0
            s = sprintf('%.6g', real(v));
        else
            s = sprintf('%.6g %+.6gi', real(v), imag(v));
        end
    end

    function s = lossynote(S_)
        %LOSSYNOTE one-line summary of the loss / magnetic state of the media
        t = {};
        if S_.lossless1 && S_.lossless2
            t{end+1} = 'both media lossless (sigma = 0)';
        else
            if ~S_.lossless1
                t{end+1} = sprintf('medium 1 lossy: tan d = %.4g, skin depth = %.4g m', ...
                    S_.tan_delta1, S_.skin1);
            end
            if ~S_.lossless2
                t{end+1} = sprintf('medium 2 lossy: tan d = %.4g, skin depth = %.4g m (%.4g lambda0)', ...
                    S_.tan_delta2, S_.skin2, S_.skin2/S_.lambda0);
            end
        end
        if S_.is_magnetic
            t{end+1} = sprintf('magnetic: mu_r = %.4g / %.4g (TE may have a Brewster angle)', ...
                S_.mu1, S_.mu2);
        end
        s = strjoin(t, '  |  ');
    end

    function onMaterial(~,~)
        %ONMATERIAL fill medium 2 with a standard material
        d = materialData(H.ddMat.Value);
        if isempty(d)
            return;
        end
        H.efEps2.Value = clampfld(H.efEps2, d.eps);
        H.efMu2.Value  = clampfld(H.efMu2,  d.mu);
        H.efSig2.Value = clampfld(H.efSig2, d.sigma);
        nm = materialNames();
        H.ddMat.Value = nm{1};
        applyFromControls();
    end

    function onSwapMedia(~,~)
        %ONSWAPMEDIA exchange the constants of medium 1 and medium 2 - the
        %   easiest way to reach total reflection (n1 > n2) with any pair.
        e1 = H.efEps1.Value; m1 = H.efMu1.Value; s1 = H.efSig1.Value;
        H.efEps1.Value = clampfld(H.efEps1, H.efEps2.Value);
        H.efMu1.Value  = clampfld(H.efMu1,  H.efMu2.Value);
        H.efSig1.Value = clampfld(H.efSig1, H.efSig2.Value);
        H.efEps2.Value = clampfld(H.efEps2, e1);
        H.efMu2.Value  = clampfld(H.efMu2,  m1);
        H.efSig2.Value = clampfld(H.efSig2, s1);
        applyFromControls();
    end

    function onModeChanged(~,~)
        applyFromControls();
    end
    function onFromChanged(~,~)
        applyFromControls();
    end
    function onEpsChanged(~,~)
        applyFromControls();
    end
    function onFreqChanged(~,~)
        applyFromControls();
    end
    function onThetaChanged(~,~)
        applyFromControls();
    end
    function onThetaSlider(~,~)
        H.efTheta.Value = min(89.9, max(0, H.slTheta.Value));
        applyFromControls();
    end
    function onPolChanged(~,~)
        applyFromControls();
    end
    function onWavesChanged(~,~)
        applyFromControls();
    end
    function onWindowChanged(~,~)
        applyFromControls();
    end
    function onSpeedChanged(~,~)
        P.view.speed = H.slSpeed.Value;
        H.lblSlow.Text = sprintf('time is slowed down: speed %.2fx, phase step %.4f rad/frame', ...
            P.view.speed, P.view.dphi*P.view.speed);
    end
    function onCompChanged(~,~)
        buildCache();
        updateAnimAxes();
    end
    function onQuiverChanged(~,~)
        P.view.quiver = H.cbQuiver.Value;
        buildCache();
        updateAnimAxes();
    end
    function applyFromControls()
        try
            p = readControls();
            applyParams(p);
        catch err
            uialert(fig, err.message, 'Invalid input');
        end
    end

    function goToAngle(val)
        if ~isfinite(val), return; end
        H.efTheta.Value = min(89.9, max(0, val));
        H.slTheta.Value = H.efTheta.Value;
        applyFromControls();
    end

    function v = BrewsterValue()
        v = NaN;
        if strcmp(P.mode,'pec'), return; end
        n1 = sqrt(P.eps1); n2 = sqrt(P.eps2);
        v = atand(n2/n1);
    end

    function v = CriticalValue()
        v = NaN;
        if strcmp(P.mode,'pec'), return; end
        n1 = sqrt(P.eps1); n2 = sqrt(P.eps2);
        if n1 > n2
            v = asind(n2/n1);
        end
    end

    function onReset(~,~)
        P = em_defaults();
        phi = 0;
        setPlaying(false);
        H.ddPreset.Value = 'Choose a preset ...';
        applyParams(P, true);
    end

    function onPreset(~,~)
        if strcmp(H.ddPreset.Value,'Choose a preset ...'), return; end
        applyPreset(H.ddPreset.Value);
    end

    function applyPreset(name)
        %APPLYPRESET set mode/polarization/medium/angle of a named scenario
        p = em_defaults();
        switch name
            case presetNames{1}                 % air -> glass, normal
                p.mode='dielectric'; p.pol='TE'; p.eps1=1; p.eps2=2.25; p.theta_i_deg=0;
            case presetNames{2}                 % air -> glass, 45 deg, TE
                p.mode='dielectric'; p.pol='TE'; p.eps1=1; p.eps2=2.25; p.theta_i_deg=45;
            case presetNames{3}                 % air -> glass, Brewster, TM
                p.mode='dielectric'; p.pol='TM'; p.eps1=1; p.eps2=2.25; p.theta_i_deg=atand(1.5);
            case presetNames{4}                 % glass -> air, 60 deg, TIR
                p.mode='dielectric'; p.pol='TE'; p.eps1=2.25; p.eps2=1; p.theta_i_deg=60;
            case presetNames{5}                 % PEC, normal
                p.mode='pec'; p.pol='TE'; p.theta_i_deg=0;
            case presetNames{6}                 % PEC, 45 deg, TE
                p.mode='pec'; p.pol='TE'; p.theta_i_deg=45;
            case presetNames{7}                 % PEC, 45 deg, TM
                p.mode='pec'; p.pol='TM'; p.theta_i_deg=45;
            case presetNames{8}                 % lossy dielectric (FR-4 at 1 GHz)
                p.mode='dielectric'; p.pol='TE'; p.eps1=1; p.eps2=4.4;
                p.sigma2=0.02; p.theta_i_deg=45;
            case presetNames{9}                 % sea water: strongly lossy
                p.mode='dielectric'; p.pol='TM'; p.eps1=1; p.eps2=81;
                p.sigma2=4; p.theta_i_deg=30;
            case presetNames{10}                % magnetic medium: TE Brewster
                p.mode='dielectric'; p.pol='TE'; p.eps1=1; p.eps2=2.25;
                p.mu2=4; p.theta_i_deg=43.0887;
            otherwise
                error('EM_VirtualLab:badPreset','Unknown preset ''%s''.', name);
        end
        phi = 0; H.slPhase.Value = 0;
        P = em_defaults(p);
        S = em_solve(P);
        syncControls();
        updateComponentLists();
        buildCache();
        updateAnimAxes(); updateStanding(); updateCoeffs();
        updateResults(); updateTheory(); updateStatus();
        if ~strcmp(H.ddPreset.Value, name)
            H.ddPreset.Value = name;
        end
    end

    function setPol(pol)
        if strcmp(pol,'TM')
            H.ddPol.Value = 'Vertical (TM, parallel)';
        else
            H.ddPol.Value = 'Horizontal (TE, perpendicular)';
        end
        applyFromControls();
    end

% ====================================================== animation ========
    function onPlayPause(~,~)
        setPlaying(logical(H.btnPlay.Value));
    end

    function setPlaying(tf)
        playing = tf;
        if playing
            H.btnPlay.Text = 'Pause';
            H.btnPlay.Value = true;
            if ~isempty(tmr) && strcmp(tmr.Running,'off')
                start(tmr);
            end
        else
            H.btnPlay.Text = 'Play';
            H.btnPlay.Value = false;
            if ~isempty(tmr) && strcmp(tmr.Running,'on')
                stop(tmr);
            end
        end
    end

    function onPhaseSlider(~,~)
        phi = deg2rad(H.slPhase.Value);
        renderFrame();
    end

    function onTick(~,~)
        if ~playing, return; end
        phi = phi + P.view.dphi*P.view.speed;
        if phi > 2*pi, phi = phi - 2*pi; end
        renderFrame();
        % keep the phase slider in sync without firing its callback
        H.slPhase.Value = mod(rad2deg(phi),360);
    end

    function stepFrames(n)
        %STEPFRAMES advance the animation by n frames (used by the smoke test)
        for k = 1:n
            phi = phi + P.view.dphi*P.view.speed;
            if phi > 2*pi, phi = phi - 2*pi; end
            renderFrame();
        end
    end

% ====================================================== field cache =======
    function updateComponentLists()
        if strcmp(P.pol,'TE')
            eitems = {'E_y';'E magnitude'};
            hitems = {'H_x';'H_z';'H magnitude'};
        else
            eitems = {'E_x';'E_z';'E magnitude'};
            hitems = {'H_y';'H magnitude'};
        end
        cur = H.ddEc.Value;   H.ddEc.Items = eitems;
        if any(strcmp(cur,eitems)), H.ddEc.Value = cur; else, H.ddEc.Value = eitems{1}; end
        cur = H.ddHc.Value;   H.ddHc.Items = hitems;
        if any(strcmp(cur,hitems)), H.ddHc.Value = cur; else, H.ddHc.Value = hitems{1}; end
    end

    function buildCache()
        %BUILDCACHE precompute the complex phasors ONCE per parameter change.
        %   Each animation frame then only evaluates
        %       field(t) = Re(phasor) * cos(phi) - Im(phasor) * sin(phi),
        %   so nothing but the image CData is touched per frame (spec 7.6).
        lam = S.lambda0;
        wx = P.view.win_x*lam;         % total x width
        wz = P.view.win_z*lam;         % total z height
        CACHE.xv = linspace(-wx/2, wx/2, P.view.Nx);
        CACHE.zv = linspace(-0.75*wz, 0.25*wz, P.view.Nz);
        [X,Z] = meshgrid(CACHE.xv, CACHE.zv);
        F = em_fields(S, X, Z);
        CACHE.in2 = F.in2;
        CACHE.F = F;
        for which = {'E','H'}
            w = which{1};
            switch w
                case 'E', Ei = F.Ei; Er = F.Er; Et = F.Et; Ft = F.E;
                case 'H', Ei = F.Hi; Er = F.Hr; Et = F.Ht; Ft = F.H;
            end
            if P.view.show_incident && P.view.show_reflected && P.view.show_transmitted
                v = Ft;                       % total field (spec: all checked)
            else
                % index instead of multiplying by the mask: a strongly lossy
                % medium 2 makes the analytic continuation of the transmitted
                % wave Inf for z < 0, and Inf*0 would be NaN
                v = struct();
                for cf = {'x','y','z'}
                    vals = zeros(size(F.in1));
                    m1v = P.view.show_incident*Ei.(cf{1}) + P.view.show_reflected*Er.(cf{1});
                    vals(F.in1)  = m1v(F.in1);
                    vals(F.in2)  = P.view.show_transmitted*Et.(cf{1})(F.in2);
                    v.(cf{1}) = vals;
                end
            end
            c = struct('x',real(v.x),'y',real(v.y),'z',real(v.z));
            d = struct('x',imag(v.x),'y',imag(v.y),'z',imag(v.z));
            CACHE.(w) = struct('re',c,'im',d);
        end
        % Fixed symmetric colour limits.  The instantaneous value of a
        % component is re{phasor}cos(phi) - im{phasor}sin(phi), so its maximum
        % over a full cycle is exactly |phasor|: computing the limits from the
        % phasors keeps the colours from flickering while the animation runs.
        for which = {'E','H'}
            w = which{1};
            lim = struct();
            mx = @(A) max(abs(A(:)));       % scalar maximum over the whole map
            lim.x = max(mx(compVec(CACHE.(w),'x')), 0);
            lim.y = max(mx(compVec(CACHE.(w),'y')), 0);
            lim.z = max(mx(compVec(CACHE.(w),'z')), 0);
            lim.mag = max(sqrt(lim.x.^2 + lim.y.^2 + lim.z.^2), 1e-30);
            for f = {'x','y','z','mag'}
                if ~isfinite(lim.(f{1})) || lim.(f{1}) <= 0, lim.(f{1}) = 1; end
            end
            CACHE.lim.(w) = lim;
        end
    end

    function [cname, lim] = selInfo(which)
        %SELINFO selected component name and its colour limit
        if strcmp(which,'E'), sel = H.ddEc.Value; else, sel = H.ddHc.Value; end
        switch sel
            case 'E_x', cname = 'x';
            case 'E_y', cname = 'y';
            case 'E_z', cname = 'z';
            case 'H_x', cname = 'x';
            case 'H_y', cname = 'y';
            case 'H_z', cname = 'z';
            otherwise,  cname = 'mag';
        end
        lim = CACHE.lim.(which).(cname);
    end

    function s = compLabel(which, cname)
        %COMPLABEL printable name of the plotted component
        if strcmp(cname,'mag')
            s = sprintf('|%s| (instantaneous magnitude)', which);
        else
            s = sprintf('|%s_%s|', which, cname);
        end
    end

    function v = compVec(cc, name)
        %COMPVEC the phasor magnitude of one component (used for colour limits)
        switch name
            case 'x', re = cc.re.x; im = cc.im.x;
            case 'y', re = cc.re.y; im = cc.im.y;
            case 'z', re = cc.re.z; im = cc.im.z;
        end
        v = sqrt(re.^2 + im.^2);
    end

% ====================================================== axes drawing =====

    function drawStaticOverlay(ax, which)
        lam = S.lambda0;
        xr = [CACHE.xv(1) CACHE.xv(end)];
        zr = [CACHE.zv(1) CACHE.zv(end)];
        % PEC: shade the conductor
        if strcmp(P.mode,'pec')
            patch(ax, [xr(1) xr(2) xr(2) xr(1)], [0 0 zr(2) zr(2)], ...
                [0.6 0.6 0.6], 'FaceAlpha',0.30,'EdgeColor','none');
            text(ax, mean(xr), zr(2)*0.55, 'PEC (E = 0, H = 0)', ...
                'HorizontalAlignment','center','FontSize',9);
        else
            text(ax, xr(1)+0.02*diff(xr), 0.04*diff(zr), ...
                sprintf('Medium 2: eps_r = %.4g, mu_r = %.4g, sigma = %.4g S/m, n = %s', ...
                P.eps2, P.mu2, P.sigma2, fmtnum(S.n2)), ...
                'HorizontalAlignment','left','FontSize',9);
        end
        plot(ax, xr, [0 0], 'k-', 'LineWidth',1.2);         % interface
        plot(ax, [0 0], zr, 'k:', 'LineWidth',0.6);         % normal
        if ~strcmp(P.mode,'pec')
            text(ax, xr(1)+0.02*diff(xr), zr(1)+0.06*diff(zr), ...
                'Medium 1 (incident + reflected)', 'HorizontalAlignment','left','FontSize',9);
        else
            text(ax, xr(1)+0.02*diff(xr), zr(1)+0.06*diff(zr), ...
                'Medium 1: air (incident + reflected)', 'HorizontalAlignment','left','FontSize',9);
        end
        colormap(ax, divergingMap(64));

        % --- propagation directions: TEXT ONLY, no arrows ----------------
        % The arrows that used to be drawn here (k_i, k_r, k_t) were removed
        % on the user's request; the same information is now reported as a
        % compact text block, and the angles also appear in the status strip
        % below the maps.
        if strcmp(P.mode,'pec')
            dirTxt = sprintf(['k_i at \\theta_i = %.1f deg ;  k_r at \\theta_r = %.1f deg ;  ' ...
                'no transmitted wave (PEC)'], P.theta_i_deg, S.theta_r_deg);
        elseif S.is_TIR
            dirTxt = sprintf(['k_i and k_r at \\theta_i = %.1f deg ;  k_t is evanescent: ' ...
                'propagates along +x, decays along z (alpha = %.4g Np/m, delta = %.4g m)'], ...
                P.theta_i_deg, S.alpha, S.delta);
        elseif ~isfinite(S.theta_t_deg)
            dirTxt = sprintf(['k_i, k_r at \\theta_i = \\theta_r = %.1f deg ;  ' ...
                'k_t has no real angle (sin(theta_t) = %s, attenuated medium)'], ...
                P.theta_i_deg, fmtnum(S.sin_t));
        else
            dirTxt = sprintf(['k_i, k_r at \\theta_i = \\theta_r = %.1f deg ;  ' ...
                'k_t at \\theta_t = %.1f deg'], P.theta_i_deg, S.theta_t_deg);
        end
        text(ax, xr(1)+0.02*diff(xr), zr(2)-0.04*diff(zr), dirTxt, ...
            'HorizontalAlignment','left','VerticalAlignment','top','FontSize',9);
    end

    function updateAnimAxes()
        % (re)create the images for both maps and draw the static overlay
        setupMapAxes(H.axE, 'E', P.view.e_comp);
        setupMapAxes(H.axH, 'H', P.view.h_comp);
        renderFrame();
    end

    function setupMapAxes(ax, which, ignore)
        cla(ax); hold(ax,'on');
        colormap(ax, divergingMap(64));
        set(ax,'YDir','reverse','FontSize',8);
        if strcmp(which,'E')
            xlabel(ax,'x [m]'); ylabel(ax,'z [m]');
            title(ax, sprintf('E field: %s   (TE = Ey, TM = Ex)', H.ddEc.Value));
        else
            xlabel(ax,'x [m]'); ylabel(ax,'z [m]');
            title(ax, sprintf('H field: %s', H.ddHc.Value));
        end
        Z = zeros(P.view.Nz,P.view.Nx);
        h = imagesc(ax, CACHE.xv, CACHE.zv, Z);
        [~, lim] = selInfo(which);
        clim(ax, [-lim lim]);
        drawStaticOverlay(ax, which);
        % quiver overlay (in-plane components).  The subsample indices must
        % exist whether or not the overlay is currently switched on, because
        % renderFrame indexes them on every frame.
        xs = 1:12:P.view.Nx; zs = 1:12:P.view.Nz;
        if P.view.quiver
            [XX,ZZ] = meshgrid(CACHE.xv(xs), CACHE.zv(zs));
            q = quiver(ax, XX, ZZ, zeros(size(XX)), zeros(size(ZZ)), 0, ...
                'Color',[0.15 0.15 0.15],'LineWidth',0.7);
        else
            q = [];
        end
        if strcmp(which,'E')
            H.imgE = h; H.quivE = q; H.quivIdx = {xs,zs};
        else
            H.imgH = h; H.quivH = q; H.quivIdx = {xs,zs};
        end
    end

    function renderFrame()
        %RENDERFRAME one animation frame: only CData / UData / VData change.
        c = cos(phi); s = sin(phi);
        inst = struct();
        for which = {'E','H'}
            w = which{1};
            cc = CACHE.(w);
            ix = cc.re.x*c - cc.im.x*s;
            iy = cc.re.y*c - cc.im.y*s;
            iz = cc.re.z*c - cc.im.z*s;
            inst.(w) = struct('x',ix,'y',iy,'z',iz);
            if strcmp(w,'E'), sel = H.ddEc.Value; else, sel = H.ddHc.Value; end
            switch sel
                case 'E_x', C = ix;
                case 'E_y', C = iy;
                case 'E_z', C = iz;
                case 'H_x', C = ix;
                case 'H_y', C = iy;
                case 'H_z', C = iz;
                otherwise,  C = sqrt(ix.^2 + iy.^2 + iz.^2);      % magnitude
            end
            if strcmp(w,'E'), hIm = H.imgE; hQ = H.quivE; else, hIm = H.imgH; hQ = H.quivH; end
            if ~isempty(hIm) && isvalid(hIm)
                hIm.CData = C;
            end
            if ~isempty(hQ) && isvalid(hQ)
                [xs,zs] = deal(H.quivIdx{1}, H.quivIdx{2});
                hQ.UData = ix(zs,xs);
                hQ.VData = -iz(zs,xs);      % axes are drawn with z increasing downward
            end
        end
        if ~isempty(H.lblAnim) && isvalid(H.lblAnim)
            % report the maxima of the components that are ACTUALLY plotted:
            % in TM mode the dominant components are E_x and H_y, so a
            % hard-wired E_y/H_x readout would print zeros.
            [cE, lE] = selInfo('E');
            [cH, lH] = selInfo('H');
            if strcmp(P.mode,'pec')
                tt = 'theta_t = none (PEC)';
            elseif S.is_TIR
                tt = 'theta_t = evanescent';
            elseif ~isfinite(S.theta_t_deg)
                tt = 'theta_t = complex (lossy)';
            else
                tt = sprintf('theta_t = %.2f deg', S.theta_t_deg);
            end
            H.lblAnim.Text = { ...
                sprintf('phi = %.2f deg    f = %.4g Hz    lambda0 = %.4g m    regime: %s', ...
                    mod(rad2deg(phi),360), P.f_Hz, S.lambda0, S.regime{1}), ...
                sprintf('theta_i = %.2f deg    theta_r = %.2f deg    %s', ...
                    P.theta_i_deg, S.theta_r_deg, tt), ...
                sprintf('max %s = %.4g V/m    |    max %s = %.4g A/m', ...
                    compLabel('E',cE), lE, compLabel('H',cH), lH)};
        end
        updateSWInstant(inst);
        drawnow limitrate;
    end

% ================================================= standing wave tab =====
    function updateStanding()
        wz = P.view.win_z*S.lambda0;
        z = linspace(-0.75*wz, 0.25*wz, 1601);
        W = em_standing_wave(S, z);
        CACHE.W = W;
        CACHE.Wz = z;
        in2 = z > 0;

        % Exact complex phasors of the dominant components along x = 0, taken
        % from the same field code as the animation tab.  The instantaneous
        % curves are then literally real(phasor * exp(1j*phi)), which keeps the
        % propagating factor exp(-j kz z) - without it the "instantaneous" curve
        % is NOT the physical field (it was up to 3x off).
        Fz = em_fields(S, zeros(size(z)), z);
        if strcmp(P.pol,'TE')
            CACHE.SW_E = Fz.E.y;    % Ey
            CACHE.SW_H = Fz.H.x;    % Hx
        else
            CACHE.SW_E = Fz.E.x;    % Ex
            CACHE.SW_H = Fz.H.y;    % Hy
        end

        for which = {'E','H'}
            w = which{1};
            % The envelope is the magnitude of the exact phasor, so it holds in
            % BOTH media (partial standing wave in medium 1, transmitted wave in
            % medium 2) and for lossy/magnetic/PEC media.  For a lossless medium 1
            % it is identical to the textbook |1 +- Gamma exp(2j kz1 z)|.
            if strcmp(w,'E')
                ax = H.axSWE; env = abs(CACHE.SW_E);
            else
                ax = H.axSWH; env = abs(CACHE.SW_H);
            end
            CACHE.(['SW_env' w]) = env;
            emax = max(env);
            if ~isfinite(emax) || emax <= 0, emax = 1; end
            yl = 1.15*emax;

            cla(ax); hold(ax,'on');
            set(ax,'FontSize',8);
            hZero = plot(ax, [z(1) z(end)], [0 0], 'Color',[0.6 0.6 0.6], 'LineWidth',0.6);
            hEnv = plot(ax, z, env, 'k-', 'LineWidth',1.4);
            hInst = plot(ax, z, zeros(size(z)), 'b-', 'LineWidth',0.8);
            hIF = plot(ax, [0 0], [-yl yl], 'k:','LineWidth',0.6);
            xlim(ax, [z(1) z(end)]);
            % symmetric limits: the instantaneous curve is signed, so a [0, max]
            % window would clip its negative half (it looked like the wave left
            % the box and came back)
            ylim(ax, [-yl yl]);
            grid(ax,'on');
            xlabel(ax,'z [m]');
            if strcmp(w,'E')
                ylabel(ax,'dominant E [V/m]');
            else
                ylabel(ax,'dominant H [A/m]');
            end
            % analytic markers (medium 1 only)
            hNod = []; hAnt = [];
            zNodes = W.nodes.E(W.nodes.E >= z(1) & W.nodes.E <= z(end));
            zAntis = W.antinodes.E(W.antinodes.E >= z(1) & W.antinodes.E <= z(end));
            if ~isempty(zNodes)
                hNod = plot(ax, zNodes, envAt(z, env, zNodes), 'ro', ...
                    'MarkerFaceColor','r','MarkerSize',5);
            end
            if ~isempty(zAntis)
                hAnt = plot(ax, zAntis, envAt(z, env, zAntis), 'gs', ...
                    'MarkerFaceColor','g','MarkerSize',5);
            end
            if strcmp(w,'E')
                title(ax, sprintf('Standing wave: dominant E (%s), SWR = %s', ...
                    compName('E'), swrTxt(W)));
                H.hSWEinst = hInst; H.hSWE = ax;
            else
                title(ax, sprintf('Standing wave: dominant H (%s)', compName('H')));
                H.hSWHinst = hInst; H.hSWH = ax;
            end
            lh = [hEnv hInst hIF]; ln = {'|field| envelope','instantaneous','interface (z = 0)'};
            if ~isempty(hNod), lh(end+1) = hNod; ln{end+1} = 'nodes (analytic)'; end
            if ~isempty(hAnt), lh(end+1) = hAnt; ln{end+1} = 'antinodes'; end
            legend(ax, lh, ln, 'Location','best','FontSize',7);
        end
        updateSWTable(W);
    end

    function updateSWInstant(inst) %#ok<INUSD>
        %UPDATESWINSTANT signed instantaneous field on the standing-wave axes.
        %   Medium 1 (z < 0): incident + reflected, i.e. the partial standing
        %   wave factor (1 +- Gamma e^{2j kz1 z}) times e^{j phi}.
        %   Medium 2 (z >= 0): the transmitted travelling (and possibly
        %   decaying) wave - NOT the analytic continuation of the medium-1
        %   expression, which is what the envelope would otherwise show.
        if ~isfield(CACHE,'SW_E') || isempty(CACHE.SW_E), return; end
        ph = exp(1i*phi);
        if ~isempty(H.hSWEinst) && isvalid(H.hSWEinst)
            H.hSWEinst.YData = real(CACHE.SW_E.*ph);
        end
        if ~isempty(H.hSWHinst) && isvalid(H.hSWHinst)
            H.hSWHinst.YData = real(CACHE.SW_H.*ph);
        end
    end

    function v = envAt(z, env, p)
        %ENVAT envelope value at p, with p clamped into the plotted range.
        %   em_standing_wave filters the analytic positions with a tiny
        %   tolerance, so a position can sit a hair outside the grid; interp1
        %   would then return NaN, which showed up in the table as 'NaN'.
        p = min(max(p, z(1)), z(end));
        v = interp1(z, env, p, 'nearest');
        if ~isfinite(v)
            v = 0;
        end
    end

    function s = compName(which)
        %COMPNAME name of the dominant component plotted on a standing-wave axes
        if strcmp(which,'E')
            if strcmp(P.pol,'TE'), s = 'Ey'; else, s = 'Ex'; end
        else
            if strcmp(P.pol,'TE'), s = 'Hx'; else, s = 'Hy'; end
        end
    end

    function s = swrTxt(W)
        %SWRTXT never print 'NaN' in a panel (see the smoke test)
        if isnan(W.swr)
            s = 'not defined (medium 1 is lossy: no periodic standing wave)';
        elseif isinf(W.swr)
            s = 'Inf (|Gamma| = 1)';
        else
            s = sprintf('%.4f', W.swr);
        end
    end

    function updateSWTable(W)
        lam1 = S.lambda1;
        z = CACHE.Wz;
        envE = CACHE.W.Eenv;
        D = {};
        nE = min(3, numel(W.nodes.E));
        for k = 1:nE
            D(end+1,:) = {'E node', sprintf('%.6g', W.nodes.E(k)), ...
                sprintf('%.4f', W.nodes.E(k)/lam1), ...
                sprintf('%.4g', envAt(z, envE, W.nodes.E(k)))}; %#ok<AGROW>
        end
        nA = min(2, numel(W.antinodes.E));
        for k = 1:nA
            D(end+1,:) = {'E antinode', sprintf('%.6g', W.antinodes.E(k)), ...
                sprintf('%.4f', W.antinodes.E(k)/lam1), ...
                sprintf('%.4g', envAt(z, envE, W.antinodes.E(k)))}; %#ok<AGROW>
        end
        nH = min(2, numel(W.nodes.H));
        for k = 1:nH
            D(end+1,:) = {'H node', sprintf('%.6g', W.nodes.H(k)), ...
                sprintf('%.4f', W.nodes.H(k)/lam1), '0 (ideal)'}; %#ok<AGROW>
        end
        if isempty(D), D = {'-','-','-','-'}; end
        H.tblSW.Data = D;

        t = {};
        t{end+1} = sprintf('SWR = %s', swrTxt(W));
        t{end+1} = sprintf('|Gamma| = %.6f, angle(Gamma) = %s deg', S.absGamma, ...
            numTxt(S.phaseGamma_deg));
        t{end+1} = sprintf('|Gamma| = absGamma, G_E = Gamma, G_H = -Gamma');
        t{end+1} = sprintf('nodes of E:  angle(G_E) + 2 kz1 z = (2m+1) pi');
        % kz1 and Js can be COMPLEX when medium 1 is lossy: format them properly
        t{end+1} = sprintf('kz1 = %s rad/m, lambda1 = %.6g m', fmtnum(S.kz1), S.lambda1);
        if S.is_TIR
            t{end+1} = sprintf('TIR: alpha = %.6g Np/m, delta = %.6g m = %.4f lambda0', ...
                S.alpha, S.delta, S.delta/S.lambda0);
            t{end+1} = 'medium 2 envelope: exp(-alpha z) (evanescent)';
        elseif strcmp(P.mode,'pec')
            t{end+1} = sprintf('PEC surface current |Js| = %s A/m', fmtnum(abs(W.Js)));
            if isfinite(W.rho_s)
                t{end+1} = sprintf('PEC surface charge  rho_s = %.6g C/m^2', W.rho_s);
            else
                t{end+1} = 'rho_s = 0 for TE (no normal E at the surface)';
            end
        else
            t{end+1} = sprintf('transmitted envelope in medium 2: |tau| = %.6f', abs(S.tau));
        end
        t{end+1} = sprintf('node spacing = lambda1/(2 cos_i) = %.6g m', S.lambda1/(2*S.cos_i));
        H.txtSW.Value = t;
    end

% ================================================== coefficients tab =====
    function updateCoeffs()
        th = 0:0.5:89.9;
        C = em_angle_sweep(P, th);
        CACHE.C = C;
        showPower = strncmp(H.ddPlot.Value,'R and T',8);
        for k = 1:4
            ax = H.axC(k); cla(ax); hold(ax,'on');
            set(ax,'FontSize',8); grid(ax,'on');
            xlabel(ax,'theta_i [deg]');
            switch k
                case 1
                    if showPower
                        yTE = C.TE.R; yTM = C.TM.R; yl = 'R';
                    else
                        yTE = C.absGamma_TE; yTM = C.absGamma_TM; yl = '|Gamma|';
                    end
                case 2
                    if showPower
                        yTE = C.TE.T; yTM = C.TM.T; yl = 'T';
                    else
                        yTE = C.phaseGamma_TE_deg; yTM = C.phaseGamma_TM_deg; yl = 'phase(Gamma) [deg]';
                    end
                case 3
                    yTE = abs(C.TE.tau); yTM = abs(C.TM.tau); yl = '|tau|';
                case 4
                    yTE = angle(C.TE.tau)*180/pi; yTM = angle(C.TM.tau)*180/pi; yl = 'phase(tau) [deg]';
            end
            if strcmp(P.pol,'TE'), lwTE = 2.0; lwTM = 0.9; else, lwTE = 0.9; lwTM = 2.0; end
            hTE = plot(ax, th, yTE, 'b-', 'LineWidth',lwTE);
            hTM = plot(ax, th, yTM, 'r--','LineWidth',lwTM);
            ylabel(ax, yl);
            % special angles as vertical dotted lines, labelled with text so
            % that the legend keeps only the two coefficient curves
            ylims = ylim(ax);
            if isnan(ylims(1)) || ylims(1) == ylims(2), ylims = [0 1]; end
            if isfinite(C.theta_B_deg) && k <= 2
                plot(ax, [C.theta_B_deg C.theta_B_deg], ylims, 'g:', 'LineWidth',1.2);
                text(ax, C.theta_B_deg, ylims(2), ...
                    sprintf(' \theta_B = %.2f', C.theta_B_deg), 'Color',[0 0.5 0],'FontSize',7);
            end
            if isfinite(C.theta_c_deg) && k <= 2
                plot(ax, [C.theta_c_deg C.theta_c_deg], ylims, 'm:', 'LineWidth',1.2);
                text(ax, C.theta_c_deg, ylims(2), ...
                    sprintf(' \theta_c = %.2f', C.theta_c_deg), 'Color',[0.5 0 0.5],'FontSize',7);
            end
            % current incidence angle
            plot(ax, [P.theta_i_deg P.theta_i_deg], ylims, 'k-', 'LineWidth',0.7);
            ylim(ax, ylims);
            if any(k == [1 2])
                legend(ax, [hTE hTM], {'TE (horizontal)','TM (vertical)'}, ...
                    'Location','best','FontSize',7);
            end
        end
        title(H.axC(1), sprintf('Coefficients vs incidence angle (current: %.1f deg)', P.theta_i_deg));
        title(H.axC(2), 'phase (line breaks where the amplitude is zero)');
        title(H.axC(3), 'transmission coefficient');
        title(H.axC(4), 'phase(tau)');
    end

% ==================================================== results and theory =
    function updateResults()
        K = P.const;
        L = {};
        L{end+1} = '=== PARAMETERS ===';
        L{end+1} = sprintf('mode               = %s', P.mode);
        L{end+1} = sprintf('polarization       = %s (%s)', P.pol, ...
            ternary(strcmp(P.pol,'TE'),'horizontal','vertical'));
        L{end+1} = sprintf('f                  = %.6g Hz', P.f_Hz);
        L{end+1} = sprintf('omega              = %.6g rad/s', S.omega);
        L{end+1} = sprintf('lambda0            = %.6g m', S.lambda0);
        L{end+1} = sprintf('eta0               = %.6g ohm', K.eta0);
        L{end+1} = '';
        L{end+1} = '=== MEDIA (eps_r, mu_r, sigma) ===';
        L{end+1} = sprintf('M1: eps_r = %.6g   mu_r = %.6g   sigma = %.6g S/m', ...
            P.eps1, P.mu1, P.sigma1);
        L{end+1} = sprintf('    eps1c = %s   n1 = %s', fmtnum(S.eps1c), fmtnum(S.n1));
        L{end+1} = sprintf('    eta1 = %s ohm   lambda1 = %.6g m   alpha1 = %s Np/m', ...
            fmtnum(S.eta1), S.lambda1, fmtnum(S.att1));
        if strcmp(P.mode,'pec')
            L{end+1} = 'M2: PERFECT CONDUCTOR (eta2 = 0, tau = 0, T = 0, no field for z > 0)';
        else
            L{end+1} = sprintf('M2: eps_r = %.6g   mu_r = %.6g   sigma = %.6g S/m', ...
                P.eps2, P.mu2, P.sigma2);
            L{end+1} = sprintf('    eps2c = %s   n2 = %s', fmtnum(S.eps2c), fmtnum(S.n2));
            L{end+1} = sprintf('    eta2 = %s ohm   lambda2 = %.6g m   alpha2 = %s Np/m', ...
                fmtnum(S.eta2), S.lambda2, fmtnum(S.att2));
        end
        if ~S.lossless1 || ~S.lossless2
            L{end+1} = sprintf('    loss tangents: tan d1 = %.6g, tan d2 = %.6g', ...
                S.tan_delta1, S.tan_delta2);
            L{end+1} = sprintf('    skin depths:   d1 = %s m, d2 = %s m', ...
                fmtnum(S.skin1), fmtnum(S.skin2));
            L{end+1} = '    (a lossy medium has no exact Brewster angle and no total reflection)';
        end
        L{end+1} = sprintf('k0 = %.6g    k1 = %s    k2 = %s rad/m', ...
            S.k0, fmtnum(S.k1), ternary(isfinite(S.k2), fmtnum(S.k2), 'Inf (PEC)'));
        L{end+1} = '';
        L{end+1} = '=== GEOMETRY ===';
        L{end+1} = sprintf('theta_i            = %.6g deg', P.theta_i_deg);
        L{end+1} = sprintf('theta_r            = %.6g deg (= theta_i)', S.theta_r_deg);
        if strcmp(P.mode,'pec')
            L{end+1} = sprintf('theta_t            = no transmitted wave (PEC)');
        elseif S.is_TIR
            L{end+1} = sprintf('theta_t            = evanescent (no real refraction angle)');
        elseif ~isfinite(S.theta_t_deg)
            L{end+1} = sprintf(['theta_t            = complex (attenuated medium: ' ...
                'sin(theta_t) = %s, no real refraction angle)'], fmtnum(S.sin_t));
        else
            L{end+1} = sprintf('theta_t            = %.6g deg (Snell)', S.theta_t_deg);
        end
        L{end+1} = sprintf('kx = %s rad/m  (k1 sin(theta_i) = k2 sin(theta_t))', fmtnum(S.kx));
        L{end+1} = sprintf('kz1 = %s rad/m', fmtnum(S.kz1));
        L{end+1} = sprintf('kz2 = %s', ternary(isfinite(real(S.kz2)), ...
            sprintf('%.6g %+.6gi rad/m', real(S.kz2), imag(S.kz2)), 'not defined (PEC)'));
        L{end+1} = '';
        L{end+1} = '=== COEFFICIENTS (E-field amplitude ratios) ===';
        L{end+1} = sprintf('Gamma              = %+.6f %+.6fi', real(S.Gamma), imag(S.Gamma));
        L{end+1} = sprintf('|Gamma|            = %.6f', S.absGamma);
        L{end+1} = sprintf('phase(Gamma)       = %s deg', numTxt(S.phaseGamma_deg));
        L{end+1} = sprintf('tau                = %+.6f %+.6fi', real(S.tau), imag(S.tau));
        L{end+1} = sprintf('|tau|              = %.6f', S.abstau);
        L{end+1} = sprintf('phase(tau)         = %s deg', numTxt(S.phasetau_deg));
        L{end+1} = sprintf('R = |Gamma|^2      = %.6f', S.R);
        if S.lossless1 && S.lossless2
            L{end+1} = sprintf('T = |tau|^2 (eta1/eta2) Re(cos_t)/cos_i = %.6f', S.T);
        else
            L{end+1} = sprintf('T = |tau|^2 Re(cos_t/eta2)/Re(cos_i/eta1) = %.6f', S.T);
        end
        L{end+1} = sprintf('R + T              = %.12f  (interface power balance)', S.R + S.T);
        L{end+1} = sprintf('theta_B (Brewster) = %s', angTxt(P, S.theta_B_deg, 'TM only'));
        L{end+1} = sprintf('theta_c (critical) = %s', angTxt(P, S.theta_c_deg, 'does not exist'));
        L{end+1} = sprintf('regime             = %s', S.regime{1});
        if S.is_TIR
            L{end+1} = sprintf('alpha              = %.6g Np/m', S.alpha);
            L{end+1} = sprintf('delta = 1/alpha    = %.6g m = %.4f lambda0', S.delta, S.delta/S.lambda0);
            L{end+1} = sprintf('phase velocity along x = %.6g m/s', S.vx);
        end
        if strcmp(P.mode,'pec')
            W = CACHE.W;
            L{end+1} = sprintf('|Js|               = %s A/m', fmtnum(abs(W.Js)));
            if isfinite(W.rho_s)
                L{end+1} = sprintf('rho_s              = %.6g C/m^2', W.rho_s);
            else
                L{end+1} = 'rho_s              = 0 (TE has no normal E at the surface)';
            end
        end
        L{end+1} = '';
        L{end+1} = '=== NUMBERS FROM THE STANDING WAVE ===';
        W = CACHE.W;
        L{end+1} = sprintf('SWR                = %s', swrTxt(W));
        if ~isempty(W.nodes.E)
            L{end+1} = sprintf('first E nodes [m]  = %s', mat2str(W.nodes.E(1:min(4,end)),5));
        else
            L{end+1} = 'first E nodes      = none (no reflected wave)';
        end
        if ~isempty(W.antinodes.E)
            L{end+1} = sprintf('first E antinodes  = %s', mat2str(W.antinodes.E(1:min(4,end)),5));
        end
        L{end+1} = '';
        L{end+1} = '=== COMPUTATIONAL PARAMETERS ===';
        L{end+1} = sprintf('grid               = %d x %d points (x, z)', P.view.Nx, P.view.Nz);
        L{end+1} = sprintf('window             = %.3g x %.3g lambda0', P.view.win_x, P.view.win_z);
        L{end+1} = sprintf('phase step         = %.5g rad/frame at speed 1x', P.view.dphi);
        L{end+1} = sprintf('points per lambda1 = %.1f (x), %.1f (z)', ...
            P.view.Nx/(P.view.win_x*S.n1), P.view.Nz/(0.75*P.view.win_z*S.n1));
        H.txtRes.Value = L;
        lastTable = L;
    end

    function s = numTxt(v)
        if isnan(v), s = 'undefined (amplitude = 0)'; else, s = sprintf('%.6f', v); end
    end

    function s = angTxt(P_, v, otherwise_)
        if strcmp(P_.mode,'pec')
            s = 'not applicable (PEC)';
        elseif isnan(v)
            s = otherwise_;
        else
            s = sprintf('%.6f deg', v);
        end
    end

    function out = ternary(c, a, b)
        if c, out = a; else, out = b; end
    end

    function updateTheory()
        ax = H.axTheory;
        cla(ax); set(ax,'XTick',[],'YTick',[]); hold(ax,'on');
        % The formula panel is drawn with the LaTeX interpreter.  Only
        % math-mode constructs are used because the uiaxes renderer supports a
        % restricted LaTeX subset; if a construct is rejected (or the
        % interpreter is unavailable) the panel falls back to plain text.
        eq = { ...
            '$$\mathrm{Snell:}\quad n_1\sin\theta_i = n_2\sin\theta_t,\qquad \kappa_x = k_1\sin\theta_i = k_2\sin\theta_t$$';
            '$$\mathrm{TE:}\quad \Gamma_{TE}=\frac{\eta_2\cos\theta_i-\eta_1\cos\theta_t}{\eta_2\cos\theta_i+\eta_1\cos\theta_t},\qquad \tau_{TE}=1+\Gamma_{TE}$$';
            '$$\mathrm{TM:}\quad \Gamma_{TM}=\frac{\eta_2\cos\theta_t-\eta_1\cos\theta_i}{\eta_2\cos\theta_t+\eta_1\cos\theta_i},\qquad 1+\Gamma_{TM}=\tau_{TM}\frac{\cos\theta_t}{\cos\theta_i}$$';
            '$$R=|\Gamma|^2,\qquad T=|\tau|^2\frac{\eta_1}{\eta_2}\frac{\mathrm{Re}(\cos\theta_t)}{\cos\theta_i},\qquad R+T=1$$';
            '$$\mathrm{Brewster\ (TM\ only):}\quad \theta_B=\arctan\frac{n_2}{n_1},\qquad \Gamma_{TM}(\theta_B)=0$$';
            '$$\mathrm{Critical:}\quad \theta_c=\arcsin\frac{n_2}{n_1}\ \ (n_1>n_2),\qquad |\Gamma|=1,\ T=0\ \ \mathrm{for}\ \theta_i\ge\theta_c$$';
            '$$\mathrm{TIR:}\quad \cos\theta_t=-j\sqrt{\left(\frac{n_1}{n_2}\sin\theta_i\right)^2-1},\quad \alpha=k_0\sqrt{n_1^2\sin^2\theta_i-n_2^2},\quad \delta=\frac{1}{\alpha}$$';
            '$$\mathrm{Standing\ wave}\ (z<0):\quad |E_y|=\left|1+\Gamma e^{+2jk_{z1}z}\right|,\qquad \eta_1|H_y|=\left|1-\Gamma e^{+2jk_{z1}z}\right|$$';
            '$$\mathrm{SWR}=\frac{1+|\Gamma|}{1-|\Gamma|},\qquad \mathrm{max:}\ \angle G+2k_{z1}z=2\pi m,\qquad \mathrm{min:}\ \angle G+2k_{z1}z=(2m+1)\pi$$';
            '$$\mathrm{PEC:}\quad \Gamma=-1,\quad \tau=0,\quad |J_s|=2|H_i|\cos\theta_i\ \mathrm{(TE)},\quad |J_s|=2|H_i|\ \mathrm{(TM)}$$';
            '$$\mathrm{Lossy:}\quad \epsilon_c=\epsilon_r-j\frac{\sigma}{\omega\epsilon_0},\quad n=\sqrt{\epsilon_c\mu_r},\quad \eta=\eta_0\sqrt{\frac{\mu_r}{\epsilon_c}},\quad \tan\delta=\frac{\sigma}{\omega\epsilon_0\epsilon_r}$$';
            '$$\mathrm{Attenuation:}\quad \alpha=-\mathrm{Im}(k_z),\qquad \delta_s=\frac{1}{\alpha},\qquad |E(z)|\propto e^{-\alpha z}\ \ (\mathrm{power}:\ e^{-2\alpha z})$$';
            };
        okLatex = true;
        try
            lastwarn('');
            for k = 1:numel(eq)
                text(ax, 0.02, 1-0.085*k, eq{k}, 'Interpreter','latex','FontSize',10, ...
                    'VerticalAlignment','top');
            end
            [wmsg,~] = lastwarn;
            if ~isempty(wmsg)
                okLatex = false;      % renderer refused part of the markup
            end
        catch
            okLatex = false;
        end
        if okLatex, theoryMode = 'latex'; else, theoryMode = 'plain'; end
        if ~okLatex
            % plain-text fallback (spec 7.5)
            cla(ax);
            plain = {'Snell: n1 sin(ti) = n2 sin(tt);  kx = k1 sin(ti) = k2 sin(tt)'; ...
                     'TE: Gamma = (eta2 ci - eta1 ct)/(eta2 ci + eta1 ct), tau = 1 + Gamma'; ...
                     'TM: Gamma = (eta2 ct - eta1 ci)/(eta2 ct + eta1 ci), 1 + G = tau ct/ci'; ...
                     'R = |G|^2,  T = |tau|^2 (eta1/eta2) Re(ct)/ci,  R + T = 1'; ...
                     'Brewster: theta_B = atan(n2/n1)   (TM only), Gamma_TM(theta_B) = 0'; ...
                     'Critical: theta_c = asin(n2/n1) if n1 > n2,  |Gamma| = 1, T = 0'; ...
                     'TIR: cos(tt) = -j sqrt((n1 sin(ti)/n2)^2 - 1), alpha = k0 sqrt(...), delta = 1/alpha'; ...
                     'Standing wave: |Ey| = |1 + G exp(2j kz1 z)|, eta1|Hy| = |1 - G exp(2j kz1 z)|'; ...
                     'SWR = (1+|G|)/(1-|G|);  nodes: angle(G) + 2 kz1 z = (2m+1) pi'; ...
                     'PEC: Gamma = -1, tau = 0, |Js| = 2|Hi| cos(ti) (TE) / 2|Hi| (TM)'};
            for k = 1:numel(plain)
                text(ax, 0.02, 1-0.09*k, plain{k}, 'FontName','Courier New','FontSize',9, ...
                    'VerticalAlignment','top');
            end
        end
        title(ax,'Formulas used by the app (Section 3 of the specification)');
        hold(ax,'off');
    end

% ============================================================ status =====
    function updateStatus()
        H.lblStatus.Text = sprintf('regime: %s | Gamma = %+.4f %+.4fi | tau = %+.4f %+.4fi | R = %.4f | T = %.4f', ...
            S.regime{1}, real(S.Gamma), imag(S.Gamma), real(S.tau), imag(S.tau), S.R, S.T);
        regimeTxt = S.regime{1};
    end

    function onCloseRequest(src, evt)          %#ok<INUSD>
        closeApp();
    end
    function onNormalIncidence(src, evt)       %#ok<INUSD>
        goToAngle(0);
    end
    function onGoBrewster(src, evt)            %#ok<INUSD>
        goToAngle(BrewsterValue());
    end
    function onGoCritical(src, evt)            %#ok<INUSD>
        goToAngle(CriticalValue());
    end
    function onPlotModeChanged(src, evt)       %#ok<INUSD>
        updateCoeffs();
    end

% ============================================================ closing ====
    function h = getCallback(name)
        %GETCALLBACK handle to a registered callback, for tests.  Firing these
        %   exercises exactly the path a user's mouse takes, which the internal
        %   functions (applyPreset/applyParams) do not.
        % NOTE: str2func('@name') cannot resolve a NESTED function (nested
        % functions are not on the path by name), so the handles must be
        % collected explicitly inside the parent function scope.
        map = struct( ...
            'onCloseRequest',    @onCloseRequest, ...
            'onNormalIncidence', @onNormalIncidence, ...
            'onGoBrewster',      @onGoBrewster, ...
            'onGoCritical',      @onGoCritical, ...
            'onPlotModeChanged', @onPlotModeChanged, ...
            'onModeChanged',     @onModeChanged, ...
            'onFromChanged',     @onFromChanged, ...
            'onEpsChanged',      @onEpsChanged, ...
            'onFreqChanged',     @onFreqChanged, ...
            'onThetaChanged',    @onThetaChanged, ...
            'onThetaSlider',     @onThetaSlider, ...
            'onPolChanged',      @onPolChanged, ...
            'onWavesChanged',    @onWavesChanged, ...
            'onWindowChanged',   @onWindowChanged, ...
            'onCompChanged',     @onCompChanged, ...
            'onQuiverChanged',   @onQuiverChanged, ...
            'onPlayPause',       @onPlayPause, ...
            'onSpeedChanged',    @onSpeedChanged, ...
            'onPhaseSlider',     @onPhaseSlider, ...
            'onPreset',          @onPreset, ...
            'onReset',           @onReset, ...
            'onMaterial',        @onMaterial, ...
            'onSwapMedia',       @onSwapMedia, ...
            'onTick',            @onTick);
        if ~isfield(map, name)
            error('EM_VirtualLab:badCallback', 'Unknown callback ''%s''.', name);
        end
        h = map.(name);
    end

    function selectTab(name)
        %SELECTTAB bring one of the four tabs to the front (used for the
        % report screenshots).  Accepted names are substrings of the titles.
        tabs = H.tabs.Children;
        for k = 1:numel(tabs)
            if contains(tabs(k).Title, name, 'IgnoreCase', true)
                H.tabs.SelectedTab = tabs(k);
                drawnow;
                return;
            end
        end
        error('EM_VirtualLab:badTab','No tab whose title contains ''%s''.', name);
    end

    function renderPng(file, tabname)
        %RENDERPNG save a PNG snapshot of the whole app (report figures).
        if nargin >= 2 && ~isempty(tabname)
            selectTab(tabname);
        end
        drawnow; pause(0.2); drawnow;
        exportapp(fig, file);
    end

    function closeApp()
        if ~isempty(tmr) && isvalid(tmr)
            stop(tmr); delete(tmr);
        end
        tmr = [];
        if ~isempty(fig) && isvalid(fig)
            delete(fig);
        end
        fig = [];
    end

% ============================================================ selftest ===
    function a = selfTest()
        %SELFTEST headless walk-through used by tests/smoke_gui.m
        fprintf('\n--- EM_VirtualLab selftest: building the app (invisible) ---\n');
        buildApp(false);
        a = api();
        nFail = 0; nCheck = 0;
        combos = {};
        for p = 1:numel(presetNames)
            combos{end+1} = presetNames{p}; %#ok<AGROW>
        end
        for k = 1:numel(combos)
            try
                applyPreset(combos{k});
            catch err
                nFail = nFail + 1;
                fprintf(' FAIL preset %s: %s\n', combos{k}, err.message);
                continue;
            end
            for pol = {'TE','TM'}
                try
                    setPol(pol{1});
                catch err
                    nFail = nFail + 1;
                    fprintf(' FAIL preset %s / %s: %s\n', combos{k}, pol{1}, err.message);
                    continue;
                end
                stepFrames(30);
                [bad, info] = checkRendered();
                nCheck = nCheck + 1;
                if bad
                    nFail = nFail + 1;
                    fprintf(' FAIL preset %s / %s: %s\n', combos{k}, pol{1}, info);
                else
                    fprintf(' ok   %-52s %s\n', combos{k}, pol{1});
                end
            end
        end
        % a few extra robustness cases required by spec 7.6
        extra = {struct('mode','dielectric','pol','TE','eps1',1,'eps2',1,'theta_i_deg',30), ...   % eps_r = 1
                 struct('mode','dielectric','pol','TM','eps1',1,'eps2',0.5,'theta_i_deg',10), ... % eps_r < 1 (accepted, documented)
                 struct('mode','dielectric','pol','TM','eps1',1,'eps2',2.25,'theta_i_deg',56.309932474020215), ... % exactly Brewster
                 struct('mode','dielectric','pol','TE','eps1',2.25,'eps2',1,'theta_i_deg',41.8103149), ...      % exactly critical
                 struct('mode','pec','pol','TE','theta_i_deg',0)};
        for k = 1:numel(extra)
            try
                applyParams(em_defaults(extra{k}));
                stepFrames(5);
                [bad, info] = checkRendered();
                nCheck = nCheck + 1;
                if bad
                    nFail = nFail + 1;
                    fprintf(' FAIL extra case %d: %s\n', k, info);
                else
                    fprintf(' ok   extra case %d (mode = %s, theta = %g deg)\n', ...
                        k, extra{k}.mode, extra{k}.theta_i_deg);
                end
            catch err
                nFail = nFail + 1;
                fprintf(' FAIL extra case %d: %s\n', k, err.message);
            end
        end
        % --- fire every registered widget callback once -------------------
        cbs = {'onModeChanged','onFromChanged','onEpsChanged','onFreqChanged', ...
               'onThetaChanged','onThetaSlider','onPolChanged','onWavesChanged', ...
               'onWindowChanged','onCompChanged','onQuiverChanged','onPlayPause', ...
               'onSpeedChanged','onPhaseSlider','onNormalIncidence','onGoBrewster', ...
               'onGoCritical','onPlotModeChanged','onPreset','onReset', ...
               'onMaterial','onSwapMedia','onTick'};
        for k = 1:numel(cbs)
            try
                h = getCallback(cbs{k});
                h([], []);                      % same signature MATLAB passes
                nCheck = nCheck + 1;
                if k == numel(cbs)
                    fprintf(' ok   all %d widget callbacks fired\n', numel(cbs));
                end
            catch err
                nFail = nFail + 1;
                fprintf(' FAIL callback %s: %s (%s)\n', cbs{k}, err.message, err.identifier);
            end
        end

        % --- close through the callback the window's X button uses --------
        try
            fcn = fig.CloseRequestFcn;
            if isempty(fcn)
                nFail = nFail + 1;
                fprintf(' FAIL CloseRequestFcn is empty\n');
            else
                feval(fcn, fig, []);
                nCheck = nCheck + 1;
                if ~isempty(fig) && isvalid(fig)
                    nFail = nFail + 1;
                    fprintf(' FAIL CloseRequestFcn did not close the app\n');
                else
                    fprintf(' ok   CloseRequestFcn closed the app\n');
                end
            end
        catch err
            nFail = nFail + 1;
            fprintf(' FAIL CloseRequestFcn: %s (%s)\n', err.message, err.identifier);
        end
        if ~isempty(tmr) && isvalid(tmr)
            stop(tmr); delete(tmr); tmr = [];
        end
        fprintf(' selftest: %d checks, %d failures.\n', nCheck, nFail);
        a.failures = nFail;
        a.checks = nCheck;
        if nFail > 0
            error('EM_VirtualLab:selftestFailed', '%d selftest checks FAILED.', nFail);
        end
        a.passed = true;
    end

    function [bad, info] = checkRendered()
        %CHECKRENDERED inspect everything the app has drawn for NaN / Inf
        bad = false; info = '';
        % animation maps
        for which = {'E','H'}
            w = which{1};
            c = CACHE.(w);
            for f = {'x','y','z'}
                A = c.re.(f{1});
                if any(~isfinite(A(:)))
                    bad = true; info = sprintf('non-finite cached %s.%s', w, f{1}); return;
                end
            end
        end
        ims = {H.imgE, H.imgH};
        for k = 1:2
            if isempty(ims{k}) || ~isvalid(ims{k})
                bad = true; info = 'image handle missing'; return;
            end
            D = ims{k}.CData;
            if any(~isfinite(D(:)))
                bad = true; info = sprintf('non-finite CData in map %d', k); return;
            end
        end
        % standing wave envelopes
        W = CACHE.W;
        if any(~isfinite(W.Eenv)) || any(~isfinite(W.Henv))
            bad = true; info = 'non-finite standing-wave envelope'; return;
        end
        % the signed instantaneous curves must stay INSIDE their axes: a [0,max]
        % y-window used to clip the negative half of the wave
        for hh = {H.hSWEinst, H.hSWHinst}
            h = hh{1};
            if isempty(h) || ~isvalid(h), continue; end
            y = h.YData;
            if any(~isfinite(y))
                bad = true; info = 'non-finite instantaneous standing-wave curve'; return;
            end
            % the signed instantaneous field must stay inside the envelope of
            % its OWN phasor: |real(P e^{j phi})| <= |P|
            if isequal(h, H.hSWEinst), ee = 'E'; else, ee = 'H'; end
            envn = ['SW_env' ee];
            if isfield(CACHE, envn)
                e = CACHE.(envn); c = h.YData;
                if numel(e) == numel(c) && any(abs(c(:)) > e(:)*1.02 + 1e-15)
                    bad = true;
                    info = sprintf(['instantaneous %s field exceeds its envelope ', ...
                        '(max ratio %.4f)'], ee, max(abs(c(:))./max(e(:),1e-30)));
                    return;
                end
            end
            yl = h.Parent.YLim;
            if max(abs(y)) > max(abs(yl))*1.002
                bad = true;
                info = sprintf('instantaneous wave leaves the axes (%.4g > %.4g)', ...
                    max(abs(y)), max(abs(yl)));
                return;
            end
            if yl(1) > -eps(1) && min(y) < -1e-12*max(1,max(abs(y)))
                bad = true; info = 'axes do not allow negative values'; return;
            end
        end
        % coefficients
        C = CACHE.C;
        if any(~isfinite(C.TE.R)) || any(~isfinite(C.TM.R)) || ...
           any(~isfinite(abs(C.TE.tau))) || any(~isfinite(abs(C.TM.tau)))
            bad = true; info = 'non-finite coefficient sweep'; return;
        end
        % the numeric table shown to the user
        D = H.txtRes.Value;
        joined = strjoin(D,' ');
        if ~isempty(strfind(joined,'NaN')) %#ok<STREMP>
            bad = true; info = 'NaN appears in the numeric results panel'; return;
        end
        if S.R + S.T < 1 - 1e-9
            bad = true; info = sprintf('R + T = %.12f < 1', S.R + S.T); return;
        end
    end

    function D = renderedData()
        % plain field-by-field assignment (struct() with cell values would build
        % a struct ARRAY, which silently truncates 'res' to its first line)
        D = struct();
        D.CDataE = H.imgE.CData;
        D.CDataH = H.imgH.CData;
        D.res = H.txtRes.Value;
        D.S = S; D.P = P; D.phi = phi;
        D.W = CACHE.W; D.C = CACHE.C; D.Wz = CACHE.Wz;
        if isfield(CACHE,'SW_E'),    D.SW_E = CACHE.SW_E; end
        if isfield(CACHE,'SW_H'),    D.SW_H = CACHE.SW_H; end
        if isfield(CACHE,'SW_envE'), D.SW_envE = CACHE.SW_envE; end
        if isfield(CACHE,'SW_envH'), D.SW_envH = CACHE.SW_envH; end
    end
end

% ============================================================== helpers ===
function names = materialNames()
%MATERIALNAMES items of the "quick material" dropdown (medium 2)
names = {'Choose material ...', 'Air (1, 1, 0)', 'Glass (2.25, 1, 0)', ...
         'Teflon (2.1, 1, 0)', 'Water (81, 1, 0)', 'FR-4 (4.4, 1, 0.02)', ...
         'Sea water (81, 1, 4)', 'Ferrite (12, 4, 0)'};
end

function d = materialData(name)
%MATERIALDATA eps_r, mu_r, sigma for a standard material (empty if unknown)
switch name
    case 'Air (1, 1, 0)',           d = struct('eps',1,   'mu',1,'sigma',0);
    case 'Glass (2.25, 1, 0)',      d = struct('eps',2.25,'mu',1,'sigma',0);
    case 'Teflon (2.1, 1, 0)',      d = struct('eps',2.1, 'mu',1,'sigma',0);
    case 'Water (81, 1, 0)',        d = struct('eps',81,  'mu',1,'sigma',0);
    case 'FR-4 (4.4, 1, 0.02)',     d = struct('eps',4.4, 'mu',1,'sigma',0.02);
    case 'Sea water (81, 1, 4)',    d = struct('eps',81,  'mu',1,'sigma',4);
    case 'Ferrite (12, 4, 0)',      d = struct('eps',12,  'mu',4,'sigma',0);
    otherwise,                      d = [];
end
end

function cm = divergingMap(n)
%DIVERGINGMAP blue - white - red colormap (signed fields, no flicker).
x = linspace(0,1,n).';
cm = [interp1([0 .5 1],[0.20 1.00 0.85],x), ...
      interp1([0 .5 1],[0.35 1.00 0.10],x), ...
      interp1([0 .5 1],[0.85 1.00 0.10],x)];
end
