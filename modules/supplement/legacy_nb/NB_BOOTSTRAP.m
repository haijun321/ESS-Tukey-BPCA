function C=NB_BOOTSTRAP(options)
    if nargin<1,options=struct();end
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'vendor','frozen'),'-begin');
    addpath(fullfile(root,'vendor'),'-begin');
    addpath(fullfile(root,'instrumented'),'-begin');
    addpath(fullfile(root,'external'),'-begin');addpath(root,'-begin');
    C=NB_CONFIG();U=NB_USER_CONFIG();
    local=NB_LOCAL_PATHS();
    for pass=1:3
        if pass==1,O=U;elseif pass==2,O=local;else,O=options;end
        f=fieldnames(O);
        for i=1:numel(f)
            assert(isfield(C,f{i}),'NB:Option','Unknown option %s',f{i});C.(f{i})=O.(f{i});
        end
    end
    assert(strcmp(which('P0_SOLVER_V2'),fullfile(root,'vendor','P0_SOLVER_V2.m')), ...
        'NB:Shadow','Another P0_SOLVER_V2 is shadowing the bundled source.');
    assert(strcmp(which('SU_FROZEN'),fullfile(root,'vendor','frozen','SU_FROZEN.m')), ...
        'NB:Shadow','Another SU_FROZEN is shadowing the bundled source.');
    assert(C.traceOuter>=1&&C.traceOuter==fix(C.traceOuter),'NB:Budget','Invalid traceOuter');
    assert(isscalar(C.progressEveryOuter)&&C.progressEveryOuter>=0&&C.progressEveryOuter==fix(C.progressEveryOuter), ...
        'NB:Progress','progressEveryOuter must be a nonnegative integer');
    assert(any(strcmp(C.scope,{'all','synthetic','real'})),'NB:Scope','scope must be all, synthetic or real');
    sourceFile=java.io.File(root);targetFile=java.io.File(C.outputRoot);
    source=char(sourceFile.getCanonicalPath());target=char(targetFile.getCanonicalPath());
    assert(~strcmpi(source,target)&&~startsWith(lower(source),[lower(target) filesep]), ...
        'NB:OutputPath','outputRoot cannot be the source directory or its ancestor. Choose a results subfolder.');
    C.stopFile=fullfile(C.outputRoot,'REQUEST_STOP.flag');
end
