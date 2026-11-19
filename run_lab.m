%RUN_LAB Launch the EM Virtual Lab graphical application.
%
%   Type   run_lab   in the MATLAB command window (with this folder, or the
%   app folder, on the path) or run this script from the Editor.
%
%   The script adds core/ and gui/ to the path and starts the app.  Nothing
%   else is needed: no toolbox, no compile step, MATLAB R2021a or newer.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;                 % started by name from the current folder
end
addpath(fullfile(here,'core'));
addpath(fullfile(here,'gui'));

fprintf('EM Virtual Lab - starting ...\n');
fprintf('  folder : %s\n', here);
fprintf('  MATLAB : %s\n', version);

EM_VirtualLab('start');
