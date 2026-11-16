% Run this file, or type: START_SAMPLE_EXTENSION
% No image data, old archive, or interactive directory selection is needed.
sample_extension_start(fileparts(mfilename('fullpath')));

function sample_extension_start(root)
    previousPath=path;
    restorePath=onCleanup(@() path(previousPath)); %#ok<NASGU>
    addpath(root,'-begin');
    SMP_RUN('all');
end
