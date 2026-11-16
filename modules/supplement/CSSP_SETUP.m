function C=CSSP_SETUP(stage,options)
% Build an isolated, non-interactive configuration. Never invent data splits.
if nargin<1,stage='paper';end
if nargin<2,options=struct();end
root=fileparts(mfilename('fullpath'));old=fullfile(root,'legacy_nb');
addpath(fullfile(old,'vendor','frozen'),'-begin');addpath(fullfile(old,'vendor'),'-begin');
addpath(fullfile(old,'instrumented'),'-begin');addpath(fullfile(old,'external'),'-begin');
addpath(old,'-begin');addpath(root,'-begin');
assert(strcmp(which('P0_SOLVER_V2'),fullfile(old,'vendor','P0_SOLVER_V2.m')), ...
    'CSSP:Shadow','The bundled P0 solver is shadowed.');
assert(strcmp(which('SU_FROZEN'),fullfile(old,'vendor','frozen','SU_FROZEN.m')), ...
    'CSSP:Shadow','The bundled frozen implementation is shadowed.');
C=NB_CONFIG();C.nbRoot=old;C.packageRoot=fullfile(old,'vendor');C.csspRoot=root;
C.version='CSSP_SUPPLEMENT_20261115_V1';C.stage=lower(char(stage));
assert(any(strcmp(C.stage,{'paper','pilot','plan'})),'CSSP:Stage','Use paper, pilot or plan.');
C.outputRoot=fullfile(root,'results_CSSP_20261115');C.archiveRoot='';
C.repeats=1:10;C.realReps=1:10;C.realDatasets={'YALE','ORL'};
C.realConditions={'Clean','I10','I30','B10','B30'};
C.realBudget=[50 5 12];C.realTimeLimit=Inf;C.includeFixedEtaNoZero=true;
C.syntheticSeedOffset=0;C.checkpointEvery=5;C.progressEveryOuter=10;
C.etaGrid=[.82 .85 .88 .91 .94 .97];C.cGrid=[2.5 3.5 4.685 6 8];
C.modules={'01_initialization','02_factorial','03_external','04_yale_selection','05_b10_budget'};
C.externalMethods={'L2','BA2DPCA','ROMPCA'}; % RA2DPCA_dev is an optional, capacity-different port
C.rscriptPath='';C.rompcaSource='';
C.rLibraryPath=fullfile(root,'external_original','R_library');
C.rompcaMaxOuter=50;C.rompcaTolerance=1e-5;
C.externalAdapters=struct('BA2DPCA','','L2pSB2DPCA','');
C.priorResultRoots={};
C.allowPartial=true;C.makePlots=true;C.sourceHash='';C.coreHash='';
C.requireNativeSelfTest=true;C.trustExistingReadyReceipt=false;
C.requirePilotBeforePaper=false;C.requireRACheckBeforePaper=false; % old NB gates are not used by this runner
u=CSSP_USER_CONFIG();
for pass=1:2
    if pass==1,o=u;else,o=options;end
    names=fieldnames(o);
    for k=1:numel(names)
        assert(isfield(C,names{k}),'CSSP:Option','Unknown configuration field: %s',names{k});
        C.(names{k})=o.(names{k});
    end
end
assert(~isempty(C.outputRoot),'CSSP:Output','outputRoot cannot be empty.');
if isempty(C.archiveRoot)
    candidates={getenv('TUKEY_ARCHIVE_ROOT'), ...
        'H:\Students\Jiang_haijun\Tukey BPCA\results_Tukey_CONFIRM_v1', ...
        fullfile(root,'results_Tukey_CONFIRM_v1'), ...
        fullfile(fileparts(root),'results_Tukey_CONFIRM_v1')};
    local=NB_LOCAL_PATHS();if isfield(local,'archiveRoot'),candidates{end+1}=local.archiveRoot;end
    found={};
    for k=1:numel(candidates)
        p=candidates{k};
        if isempty(p)||exist(p,'dir')~=7,continue;end
        if all(cellfun(@(n)exist(fullfile(p,n),'dir')==7,{'cache','splits','calibration','jobs'}))
            f=java.io.File(p);p=char(f.getCanonicalPath());
            if ~any(strcmpi(found,p)),found{end+1}=p;end %#ok<AGROW>
        end
    end
    if numel(found)==1,C.archiveRoot=found{1};
    elseif numel(found)>1
        error('CSSP:AmbiguousArchive','Multiple archives found. Set archiveRoot explicitly in CSSP_USER_CONFIG.m.');
    end
end
C.priorResultRoots=cellstr(string(C.priorResultRoots));
if isempty(C.priorResultRoots)
    parents={fileparts(root),fileparts(C.archiveRoot)};names={'results_P0_V2','results_P0_V2_FIX1','results_P0_V2_FINAL'};
    for pp=1:numel(parents)
        for nn=1:numel(names)
            candidate=fullfile(parents{pp},names{nn});
            if exist(fullfile(candidate,'source_manifest.mat'),'file')==2
                C.priorResultRoots{end+1}=candidate; %#ok<AGROW>
            end
        end
    end
end
if strcmp(C.stage,'pilot')
    C.realReps=1;C.repeats=1;C.realConditions={'Clean','I30','B10'};
    C.realBudget=[3 2 8];C.etaGrid=[.85 .97];C.cGrid=[2.5 4.685];C.raMaxOuter=3;
end
C.cacheRoot=fullfile(C.outputRoot,C.stage,'native_cache');
C.stopFile=fullfile(C.outputRoot,'REQUEST_STOP.flag');
source=java.io.File(root);target=java.io.File(C.outputRoot);
sp=char(source.getCanonicalPath());tp=char(target.getCanonicalPath());
assert(~strcmpi(sp,tp)&&~startsWith(lower(sp),[lower(tp) filesep]), ...
    'CSSP:Output','outputRoot cannot be the source directory or its parent.');
assert(~isempty(C.realReps)&&all(C.realReps==fix(C.realReps))&&all(ismember(C.realReps,1:10)), ...
    'CSSP:Repeats','The frozen archive supports repeats 1:10.');
end
