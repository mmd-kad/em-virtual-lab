function fuzz_probe()
%FUZZ_PROBE sweep the app through many physical states and verify that every
%   graphics object holds finite data and no panel shows a literal 'NaN'.
%
%   Run:  cd tests; fuzz_probe
%   Prints one line per failing state (and a summary).  Not part of the shipped
%   test suite - a diagnostic used to hunt residual bugs.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'core'));
addpath(fullfile(root,'gui'));

app = EM_VirtualLab('start');
f = app.fig;

% ---- state matrix ------------------------------------------------------
S = {};
add = @(nm, varargin) deal(nm, varargin);

base = struct();
S{end+1} = {'default air->glass', base};
S{end+1} = {'identical media', struct('eps2',1)};
S{end+1} = {'n2 < 1 (eps2=0.5)', struct('eps2',0.5)};
S{end+1} = {'extremes eps 1e4', struct('eps2',1e4)};
S{end+1} = {'extremes eps 1e-3', struct('eps2',1e-3)};
S{end+1} = {'glass->air (TIR able)', struct('eps1',2.25,'eps2',1)};
S{end+1} = {'magnetic mu2=4', struct('mu2',4)};
S{end+1} = {'magnetic mu1=4', struct('mu1',4)};
S{end+1} = {'both magnetic', struct('mu1',2,'mu2',3)};
S{end+1} = {'lossy med2 FR-4', struct('eps2',4.4,'sigma2',0.02)};
S{end+1} = {'sea water', struct('eps2',81,'sigma2',4)};
S{end+1} = {'lossy medium 1', struct('sigma1',0.05)};
S{end+1} = {'both lossy', struct('sigma1',0.02,'sigma2',0.5)};
S{end+1} = {'lossy + magnetic', struct('mu2',3,'sigma2',0.1)};
S{end+1} = {'huge sigma', struct('sigma2',1e6)};
S{end+1} = {'PEC', struct('mode','pec')};
S{end+1} = {'PEC + magnetic med1', struct('mode','pec','mu1',2)};
S{end+1} = {'PEC + lossy med1', struct('mode','pec','sigma1',0.01)};
for th = [0 0.5 30 41.8103 56.3099 60 85 89.9]
    S{end+1} = {sprintf('theta %.4g TE',th), struct('theta_i_deg',th)}; %#ok<AGROW>
    S{end+1} = {sprintf('theta %.4g TM',th), struct('theta_i_deg',th,'pol','TM')}; %#ok<AGROW>
    S{end+1} = {sprintf('theta %.4g TM glass->air',th), ...
        struct('theta_i_deg',th,'pol','TM','eps1',2.25,'eps2',1)}; %#ok<AGROW>
end
for fq = [1e6 1e9 1.5e10 1e11]
    S{end+1} = {sprintf('f %.3g Hz',fq), struct('f_Hz',fq)}; %#ok<AGROW>
end

nFail = 0; nRun = 0;
for k = 1:numel(S)
    nm = S{k}{1}; ov = S{k}{2};
    try
        app.applyParams(em_defaults(ov));
        app.stepFrames(4);
    catch err
        nFail = nFail + 1;
        where = '';
        if ~isempty(err.stack)
            where = sprintf(' [%s:%d]', err.stack(1).name, err.stack(1).line);
        end
        fprintf('FAIL %-30s apply/step: %s%s\n', nm, err.message, where);
        continue;
    end
    nRun = nRun + 1;
    msg = checkAll(f);
    if ~isempty(msg)
        nFail = nFail + 1;
        fprintf('FAIL %-30s %s\n', nm, msg);
    end
end

% ---- also walk the presets, the material list and the swap button ------
for k = 1:numel(app.presetNames)
    try
        app.setPreset(app.presetNames{k});
        for pol = {'TE','TM'}
            app.setPol(pol{1});
            app.stepFrames(4);
            nRun = nRun + 1;
            msg = checkAll(f);
            if ~isempty(msg)
                nFail = nFail + 1;
                fprintf('FAIL preset %-24s/%-2s %s\n', app.presetNames{k}, pol{1}, msg);
            end
        end
    catch err
        nFail = nFail + 1;
        fprintf('FAIL preset %-24s exception: %s\n', app.presetNames{k}, err.message);
    end
end

mats = {'Choose material ...','Air (1, 1, 0)','Glass (2.25, 1, 0)','Teflon (2.1, 1, 0)', ...
        'Water (81, 1, 0)','FR-4 (4.4, 1, 0.02)','Sea water (81, 1, 4)','Ferrite (12, 4, 0)'};
cb = app.callback('onMaterial');
for k = 1:numel(mats)
    try
        m = findall(f,'-isa','matlab.ui.control.DropDown');
        for q = 1:numel(m)
            if any(strcmp(m(q).Items, mats{k}))
                m(q).Value = mats{k};
                feval(cb, m(q), []);
                break
            end
        end
        app.stepFrames(2);
        nRun = nRun + 1;
        msg = checkAll(f);
        if ~isempty(msg)
            nFail = nFail + 1;
            fprintf('FAIL material %-22s %s\n', mats{k}, msg);
        end
    catch err
        nFail = nFail + 1;
        fprintf('FAIL material %-22s %s\n', mats{k}, err.message);
    end
end
% swap twice, and 89.9 deg with everything through the swap path
try
    sw = app.callback('onSwapMedia');
    for k = 1:3
        feval(sw,[],[]);
        app.stepFrames(2);
        nRun = nRun + 1;
        msg = checkAll(f);
        if ~isempty(msg)
            nFail = nFail + 1;
            fprintf('FAIL swap %d %s\n', k, msg);
        end
    end
catch err
    nFail = nFail + 1;
    fprintf('FAIL swap: %s\n', err.message);
end

% ---- sweep every UI control that can change the picture ---------------
drops = findall(f,'-isa','matlab.ui.control.DropDown');
for q = 1:numel(drops)
    it = drops(q).Items;
    if iscell(it) && (any(strcmp(it,'E magnitude')) || any(strcmp(it,'H magnitude'))) ...
            || (iscell(it) && any(strcmp(it,'Air (1, 1, 0)')))
        for k = 1:numel(it)
            try
                drops(q).Value = it{k};
                feval(app.callback('onCompChanged'), [], []);
                app.stepFrames(3);
                nRun = nRun + 1;
                msg = checkAll(f);
                if ~isempty(msg)
                    nFail = nFail + 1;
                    fprintf('FAIL dropdown %-18s item %-14s %s\n', drops(q).Tooltip, it{k}, msg);
                end
            catch err
                nFail = nFail + 1;
                fprintf('FAIL dropdown item %-14s %s\n', it{k}, err.message);
            end
        end
    end
end
% window size, speed and phase extremes, quiver on/off, wave checkboxes
% the window size must be driven through the WIDGET (readControls derives
% win_x = 0.75*win_z from it; passing win_x directly bypasses that logic)
efs = findall(f,'-isa','matlab.ui.control.NumericEditField');
for q = 1:numel(efs)
    if isequal(efs(q).Limits, [0.5 20])          % the window field
        for wv = [0.5 0.7 4 20]
            try
                efs(q).Value = wv;
                feval(app.callback('onWindowChanged'), [], []);
                app.stepFrames(3);
                nRun = nRun + 1;
                msg = checkAll(f);
                if ~isempty(msg)
                    nFail = nFail + 1;
                    fprintf('FAIL window widget %-5g %s\n', wv, msg);
                end
            catch err
                nFail = nFail + 1;
                fprintf('FAIL window widget %-5g %s\n', wv, err.message);
            end
        end
        efs(q).Value = 4;
        feval(app.callback('onWindowChanged'), [], []);
    end
end
ctrl = {struct('view',struct('speed',0.1)),                 'speed 0.1x';
        struct('view',struct('speed',5)),                   'speed 5x';
        struct('view',struct('quiver',true)),               'quiver on';
        struct('view',struct('quiver',false)),              'quiver off';
        struct('view',struct('show_incident',false,'show_reflected',false, ...
               'show_transmitted',true)),                   'only transmitted';
        struct('view',struct('show_incident',false,'show_reflected',true, ...
               'show_transmitted',false)),                  'only reflected';
        struct('view',struct('show_incident',true,'show_reflected',false, ...
               'show_transmitted',false)),                  'only incident'};
for k = 1:size(ctrl,1)
    try
        app.applyParams(em_defaults(ctrl{k,1}));
        app.stepFrames(4);
        nRun = nRun + 1;
        msg = checkAll(f);
        if ~isempty(msg)
            nFail = nFail + 1;
            fprintf('FAIL ctrl %-16s %s\n', ctrl{k,2}, msg);
        end
    catch err
        nFail = nFail + 1;
        fprintf('FAIL ctrl %-16s %s\n', ctrl{k,2}, err.message);
    end
end
% PEC + lossy + magnetic combined with the display toggles
for ov = {struct('mode','pec','view',struct('quiver',true)), ...
          struct('eps2',4.4,'sigma2',0.02,'view',struct('quiver',true)), ...
          struct('eps1',2.25,'eps2',1,'theta_i_deg',75), ...
          struct('mu2',4,'pol','TM'), struct('sigma1',0.05,'pol','TM')}
    try
        app.applyParams(em_defaults(ov{1}));
        app.stepFrames(4);
        nRun = nRun + 1;
        msg = checkAll(f);
        if ~isempty(msg)
            nFail = nFail + 1; fprintf('FAIL combo %s\n', msg);
        end
    catch err
        nFail = nFail + 1; fprintf('FAIL combo %s\n', err.message);
    end
end

fprintf('\nFUZZ: %d states checked, %d failures\n', nRun, nFail);
app.close();
end

% -------------------------------------------------------------------------
function n = strlen_field(k) %#ok<DEFNU>
%STRLEN_FIELD helper kept trivial: NaN is only allowed in line data
n = 0;
end

function msg = checkAll(f)
%CHECKALL every graphics object must hold finite data; no panel may show NaN
msg = '';
objs = findall(f);
for k = 1:numel(objs)
    o = objs(k);
    if ~isvalid(o), continue; end
    props = {'XData','YData','ZData','CData','UData','VData','AlphaData'};
    isLine = isa(o,'matlab.graphics.chart.primitive.Line') || ...
             isa(o,'matlab.graphics.primitive.Line');
    for p = 1:numel(props)
        if isprop(o, props{p})
            v = o.(props{p});
            if ~isnumeric(v) || isempty(v), continue; end
            if any(isinf(v(:)))
                msg = sprintf('%s has Inf in %s', class(o), props{p});
                return;
            end
            if ~isreal(v) && any(imag(v(:)) ~= 0)
                % MATLAB silently plots only the real part of complex data, so a
                % complex envelope/curve is a WRONG PLOT that looks plausible
                msg = sprintf('%s has COMPLEX data in %s (imag part dropped!)', ...
                    class(o), props{p});
                return;
            end
            if any(isnan(v(:)))
                % a NaN in a line simply breaks the curve (used deliberately for
                % the phase plots); anywhere else it is a defect
                if ~(isLine && any(strcmp(props{p},{'XData','YData','ZData'})))
                    msg = sprintf('%s has NaN in %s', class(o), props{p});
                    return;
                end
            end
        end
    end
    if isprop(o,'Limits') && isnumeric(o.Limits) && any(~isfinite(o.Limits))
        msg = sprintf('%s has non-finite Limits', class(o));
        return;
    end
    if isprop(o,'XLim') && any(~isfinite(o.XLim))
        msg = 'axes has non-finite XLim'; return;
    end
    if isprop(o,'YLim') && any(~isfinite(o.YLim))
        msg = 'axes has non-finite YLim'; return;
    end
    if isprop(o,'CLim') && any(~isfinite(o.CLim))
        msg = 'axes has non-finite CLim'; return;
    end
    % text content: a literal NaN in any user-visible string is a defect
    if isprop(o,'Value') && (iscell(o.Value) || ischar(o.Value) || isstring(o.Value))
        s = strjoin(cellstr(string(o.Value)), ' ');
        if contains(s,'NaN')
            msg = sprintf('%s shows ''NaN''', class(o)); return;
        end
    end
    if isprop(o,'Text') && (ischar(o.Text) || isstring(o.Text))
        if contains(string(o.Text),'NaN')
            msg = sprintf('%s (text) shows ''NaN''', class(o)); return;
        end
    end
    if isprop(o,'Title')
        tv = o.Title;
        if ischar(tv) && contains(tv,'NaN')
            msg = sprintf('%s title shows ''NaN''', class(o)); return;
        elseif isobject(tv) && isprop(tv,'String') && contains(string(tv.String),'NaN')
            msg = 'axes title shows ''NaN'''; return;
        end
    end
    if isprop(o,'String') && (ischar(o.String) || iscell(o.String) || isstring(o.String))
        s = strjoin(cellstr(string(o.String)), ' ');
        if contains(s,'NaN')
            msg = sprintf('%s shows ''NaN''', class(o)); return;
        end
    end
    if isa(o,'matlab.ui.control.Table')
        d = o.Data;
        if iscell(d)
            s = strjoin(cellstr(string(d(:))), ' ');
            if contains(s,'NaN'), msg = 'table shows ''NaN'''; return; end
        elseif isnumeric(d) && any(~isfinite(d(:)))
            msg = 'table has non-finite numbers'; return;
        end
    end
end
end