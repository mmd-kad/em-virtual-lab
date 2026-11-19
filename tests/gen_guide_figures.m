function gen_guide_figures()
%GEN_GUIDE_FIGURES Snapshots for the PDF user guide.
%
%   Produces (into <project>/figures/):
%     guide_media_default.png    Media tab, air -> glass (lossless dielectric)
%     guide_media_tir.png        Media tab after Swap media (glass -> air)
%     guide_media_lossy.png      Media tab, FR-4 with sigma = 0.02 S/m
%     guide_media_sea.png        Media tab, sea water (heavily lossy)
%     guide_media_magnetic.png   Media tab, magnetic medium mu_r = 4
%     guide_media_pec.png        Media tab in PEC mode (medium-2 fields off)
%     guide_field_lossy.png      Field Animation for the lossy FR-4 case
%     guide_standing_lossy.png   Standing Wave for the lossy FR-4 case
%     guide_results_lossy.png    Results and Theory for the lossy case
%
%   These complement figures/fig6_gui_*.png which gen_report_figures.m writes.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'core'));
addpath(fullfile(root,'gui'));

FIGDIR = fullfile(root,'figures');
if ~isfolder(FIGDIR), mkdir(FIGDIR); end

fprintf('building the app for the guide screenshots ...\n');
app = EM_VirtualLab('start');

shots = {
    'guide_media_default.png',  struct(),                                              'Media';
    'guide_media_tir.png',      struct('eps1',2.25,'eps2',1),                           'Media';
    'guide_media_lossy.png',    struct('eps2',4.4,'sigma2',0.02),                       'Media';
    'guide_media_sea.png',      struct('eps2',81,'sigma2',4),                           'Media';
    'guide_media_magnetic.png', struct('eps2',2.25,'mu2',4,'pol','TE'),                 'Media';
    'guide_media_pec.png',      struct('mode','pec'),                                   'Media';
    'guide_field_lossy.png',    struct('eps2',4.4,'sigma2',0.02,'theta_i_deg',45),      'Field Animation';
    'guide_standing_lossy.png', struct('eps2',4.4,'sigma2',0.02,'theta_i_deg',45),      'Standing Wave';
    'guide_results_lossy.png',  struct('eps2',4.4,'sigma2',0.02,'theta_i_deg',45),      'Results and Theory';
};

for k = 1:size(shots,1)
    app.applyParams(em_defaults(shots{k,2}));
    app.stepFrames(6);
    app.selectTab(shots{k,3});
    app.renderPng(fullfile(FIGDIR, shots{k,1}));
    fprintf('  saved %s\n', shots{k,1});
end
app.close();
fprintf('GEN_GUIDE_FIGURES OK\n');
end
