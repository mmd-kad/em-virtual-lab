function smoke_gui()
%SMOKE_GUI Headless smoke test of the EM Virtual Lab GUI (task B8).
%
%   Run with:   cd EM_VirtualLab/tests; smoke_gui
%   or headless: matlab -batch "run('.../tests/smoke_gui.m')"
%
%   It builds the app with Visible = 'off', walks through every preset and
%   BOTH polarizations, steps 30 animation frames each, checks every rendered
%   array and the numeric panel for NaN / Inf, verifies R + T = 1, then closes
%   the app.  Prints SMOKE TEST PASSED on success and raises an error
%   otherwise, so a non-zero MATLAB exit status means the GUI is broken.
%
%   The app exposes the test entry EM_VirtualLab('selftest') used here; the
%   GUI itself is never claimed to work unless this test has been executed.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'core'));
addpath(fullfile(root,'gui'));

fprintf('\n================================================================\n');
fprintf(' EM Virtual Lab - GUI smoke test (headless, Visible = off)\n');
fprintf(' MATLAB %s\n', version);
fprintf('================================================================\n');

t0 = tic;
app = EM_VirtualLab('selftest');
elapsed = toc(t0);

if ~isfield(app,'passed') || ~app.passed
    error('smoke_gui:notPassed','The app did not report a passing selftest.');
end

% --- one explicit external check: the app really is closed afterwards -----
if ~isempty(app.fig) && isvalid(app.fig)
    error('smoke_gui:stillOpen','The app window was not closed by the selftest.');
end

fprintf(' checks executed : %d\n', app.checks);
fprintf(' failures        : %d\n', app.failures);
fprintf(' elapsed         : %.1f s\n', elapsed);
fprintf('---------------------------------------------------------------\n');
fprintf(' SMOKE TEST PASSED\n');
fprintf('================================================================\n\n');
end
