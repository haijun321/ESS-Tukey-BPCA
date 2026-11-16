function candidates=NB_FIND_ARCHIVE(searchRoot)
% Read-only discovery; never creates a fake archive or chooses an ambiguous one.
    if nargin<1
        searchRoot=uigetdir(pwd,'Select an old experiment parent directory to search');
        if isequal(searchRoot,0),candidates=struct([]);return;end
    end
    assert(exist(searchRoot,'dir')==7,'NB:FindArchive','Search root does not exist');
    fprintf('Searching for archived ORL_normalized.mat under %s ...\n',searchRoot);
    fs=dir(fullfile(searchRoot,'**','ORL_normalized.mat'));candidates=struct([]);seen={};
    for i=1:numel(fs)
        [parent,name]=fileparts(fs(i).folder);
        if ~strcmpi(name,'cache')||any(strcmpi(seen,parent)),continue;end
        seen{end+1}=parent; %#ok<AGROW>
        z=struct('Root',parent,'HasYALE',exist(fullfile(parent,'cache','YALE_normalized.mat'),'file')==2, ...
            'HasORL',true,'HasSplits',exist(fullfile(parent,'splits'),'dir')==7, ...
            'HasCalibration',exist(fullfile(parent,'calibration'),'dir')==7, ...
            'HasJobs',exist(fullfile(parent,'jobs'),'dir')==7,'StructureReady',false);
        z.StructureReady=z.HasYALE&&z.HasORL&&z.HasSplits&&z.HasCalibration&&z.HasJobs;
        if isempty(candidates),candidates=z;else,candidates(end+1)=z;end %#ok<AGROW>
    end
    if isempty(candidates)
        fprintf('No frozen TC archive found. CSV summaries and raw images cannot replace frozen split/calibration objects.\n');
    else
        disp(struct2table(candidates));
        fprintf('Choose the intended archive explicitly with NB_SETUP_PATHS; deep preflight will verify its contents.\n');
    end
end
