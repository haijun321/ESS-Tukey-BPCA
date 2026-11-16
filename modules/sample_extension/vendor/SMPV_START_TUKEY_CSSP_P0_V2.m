function report = SMPV_START_TUKEY_CSSP_P0_V2(action,options)
% Entry point. Examples:
% SMPV_START_TUKEY_CSSP_P0_V2('selftest');
% SMPV_START_TUKEY_CSSP_P0_V2('quick');
% SMPV_START_TUKEY_CSSP_P0_V2('paper_synthetic');
% SMPV_START_TUKEY_CSSP_P0_V2('real_preflight',struct('archiveRoot','H:\...'));
% See README_CN.txt for individual modules, real-data and budget commands.
    if nargin<1 || isempty(action), action='quick'; end
    if nargin<2, options=struct(); end
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'frozen'),'-begin'); addpath(root,'-begin');
    assert(strcmpi(which('SMPV_SU_FROZEN'),fullfile(root,'frozen','SMPV_SU_FROZEN.m')), ...
        'P0:PathShadow','A different SMPV_SU_FROZEN is on the MATLAB path.');
    C=SMPV_P0_CONFIG(); f=fieldnames(options);
    for k=1:numel(f)
        assert(isfield(C,f{k}),'P0:Option','Unknown option: %s',f{k});
        C.(f{k})=options.(f{k});
    end
    assert(strcmp(C.packageRoot,root),'P0:Root','Do not override packageRoot.');
    assert(ischar(C.outputRoot)&&~isempty(C.outputRoot),'P0:Output','Invalid outputRoot.');
    assert(~isempty(C.repeats)&&all(C.repeats>=1)&all(C.repeats==fix(C.repeats)), ...
        'P0:Repeats','Repeats must be positive integers.');
    assert(numel(unique(C.repeats))==numel(C.repeats),'P0:Repeats','Duplicate repeats.');
    C.repeats=C.repeats(:)';
    assert(all(C.budgetMultipliers>=1)&all(C.budgetMultipliers==fix(C.budgetMultipliers)), ...
        'P0:Budget','Budget multipliers must be positive integers.');
    assert(numel(unique(C.budgetMultipliers))==numel(C.budgetMultipliers)&&any(C.budgetMultipliers==1), ...
        'P0:Budget','Unique budget multipliers must include 1.');
    C.budgetMultipliers=C.budgetMultipliers(:)';
    assert(C.bootstrapResamples>=100&&C.bootstrapResamples==fix(C.bootstrapResamples), ...
        'P0:Bootstrap','Use an integer bootstrapResamples >= 100.');
    C.stopFile=fullfile(C.outputRoot,'REQUEST_STOP.flag');
    fprintf('\n%s | action=%s\nOutput: %s\n',C.version,char(action),C.outputRoot);
    report=struct('Action',char(action),'OutputRoot',C.outputRoot,'Completed',false);
    if strcmpi(action,'selftest')
        report=SMPV_P0_SELFTEST(C); return;
    end
    if strcmpi(action,'summary')
        SMPV_P0_SUMMARIZE_ALL(C); report.Completed=true; return;
    end
    if strcmpi(action,'export_review')
        report=SMPV_P0_EXPORT_REVIEW(C);return;
    end
    if strcmpi(action,'real_preflight')
        report.Core=SMPV_P0_PREFLIGHT_REAL(C,'real_core');
        Q=C;Q.realDatasets=C.realMainDatasets;Q.realConditions=C.realMainConditions;
        report.Main=SMPV_P0_PREFLIGHT_REAL(Q,'real_main');report.Pass=true;report.Completed=true;return;
    end
    if C.runSelfTest
        check=SMPV_P0_SELFTEST(C); assert(check.Pass,'P0:SelfTest','Self-test failed.');
    end
    switch lower(char(action))
        case 'quick'
            Q=C; Q.repeats=1; Q.syntheticDimensions=[24 12 10 3 2];
            Q.syntheticBudget=[6 3 8]; Q.syntheticTimeLimit=Inf;
            SMPV_P0_RUN_SYNTHETIC(Q,'smoke_solver'); SMPV_P0_RUN_SYNTHETIC(Q,'smoke_core');
        case 'paper_synthetic'
            SMPV_P0_RUN_SYNTHETIC(C,'solver_synthetic');
            SMPV_P0_RUN_SYNTHETIC(C,'main_synthetic');
            SMPV_P0_RUN_SYNTHETIC(C,'core_synthetic');
        case {'solver_synthetic','main_synthetic','core_synthetic','budget_synthetic'}
            SMPV_P0_RUN_SYNTHETIC(C,lower(char(action)));
        case 'real_pilot'
            Q=C; Q.repeats=C.repeats(1); Q.realConditions={'Clean','I10','B30'};
            SMPV_P0_PREFLIGHT_REAL(Q); SMPV_P0_RUN_REAL(Q,'pilot_real');
        case 'paper_real'
            SMPV_P0_PREFLIGHT_REAL(C);
            Q=C;Q.realDatasets=C.realMainDatasets;Q.realConditions=C.realMainConditions;
            SMPV_P0_PREFLIGHT_REAL(Q,'real_main');
            SMPV_P0_RUN_REAL(C,'solver_real'); SMPV_P0_RUN_REAL(C,'core_real');
            SMPV_P0_RUN_REAL(C,'extension_real'); SMPV_P0_RUN_REAL(C,'main_real');
            SMPV_P0_RUN_TUNE(C);
        case {'solver_real','core_real','extension_real','main_real','budget_real','tune_real'}
            Q=C;
            if strcmpi(action,'solver_real'),Q.realConditions={'Clean'};end
            if strcmpi(action,'budget_real'),Q.realConditions={'Clean','I30','B30'};end
            if strcmpi(action,'main_real'),Q.realDatasets=C.realMainDatasets;Q.realConditions=C.realMainConditions;end
            if strcmpi(action,'tune_real'),Q.realDatasets=C.tuneDatasets;Q.realConditions=C.tuneConditions;end
            SMPV_P0_PREFLIGHT_REAL(Q,lower(char(action)));
            if strcmpi(action,'tune_real'),SMPV_P0_RUN_TUNE(C);else,SMPV_P0_RUN_REAL(C,lower(char(action)));end
        otherwise
            error('P0:Action','Unknown action %s. See README_CN.txt.',char(action));
    end
    report.Completed=true;
end
