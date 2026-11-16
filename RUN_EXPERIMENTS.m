function report = RUN_EXPERIMENTS(action, options)
%RUN_EXPERIMENTS Repository entry point; no-argument call only checks inputs.
% RUN_EXPERIMENTS('check')
% RUN_EXPERIMENTS('selftest')
% RUN_EXPERIMENTS('sample_all')  % 8 computational prechecks + 80 formal fits
% RUN_EXPERIMENTS('core_synthetic')
% RUN_EXPERIMENTS('core_real',struct('archiveRoot','D:\TukeyData\archive'))
% See README.md and docs/EXPERIMENT_MAP.md before starting formal fits.
    if nargin < 1 || isempty(action), action = 'check'; end
    if nargin < 2, options = struct(); end
    assert(isstruct(options) && isscalar(options), ...
        'TUKEY:Options','options must be one scalar struct.');
    allowed = {'archiveRoot','outputRoot','modules','moduleOptions'};
    names = fieldnames(options);
    assert(all(ismember(names,allowed)), ...
        'TUKEY:Options','Use archiveRoot, outputRoot, modules or moduleOptions.');
    action = lower(char(action));
    root = fileparts(mfilename('fullpath'));
    core = fullfile(root,'modules','core');
    sample = fullfile(root,'modules','sample_extension');
    supplement = fullfile(root,'modules','supplement');
    archiveRoot = getenv('TUKEY_ARCHIVE_ROOT');
    if isfield(options,'archiveRoot'), archiveRoot = char(options.archiveRoot); end
    if strcmp(action,'check')
        report = inspect_repository(root,core,sample,supplement,archiveRoot);
        disp(report); return;
    end
    assert(usejava('jvm'),'TUKEY:JVM','Start MATLAB with the JVM enabled.');
    previousPath = path;
    restorePath = onCleanup(@() path(previousPath)); %#ok<NASGU>
    opts = struct();
    if isfield(options,'moduleOptions')
        assert(isstruct(options.moduleOptions) && isscalar(options.moduleOptions), ...
            'TUKEY:ModuleOptions','moduleOptions must be one scalar struct.');
        opts = options.moduleOptions;
    end
    assert(~isfield(opts,'packageRoot'),'TUKEY:SourceRoot','Do not override packageRoot.');
    if startsWith(action,'sample_')
        addpath(sample,'-begin');
        assert(strcmpi(which('SMP_RUN'),fullfile(sample,'SMP_RUN.m')), ...
            'TUKEY:Path','An unexpected SMP_RUN is on the MATLAB path.');
        opts.outputRoot = output_path(options,root,'sample_extension');
        mode = extractAfter(action,'sample_');
        mode = char(mode);
        if strcmp(mode,'selftest')
            addpath(fullfile(sample,'vendor'),'-begin');
            C = SMP_CONFIG();
            fields = fieldnames(opts);
            for k = 1:numel(fields)
                assert(isfield(C,fields{k}),'TUKEY:SampleOption','Unknown sample option.');
                C.(fields{k}) = opts.(fields{k});
            end
            C.packageRoot = sample;
            if ~isfolder(C.outputRoot), mkdir(C.outputRoot); end
            SMP_SELFTEST(C);
        else
            assert(any(strcmp(mode,{'all','precheck','formal','summary'})), ...
                'TUKEY:Action','Unknown sample action. See README.md.');
            SMP_RUN(mode,opts);
        end
        report = struct('Action',action,'OutputRoot',opts.outputRoot, ...
            'RunnerReturned',true);
        return;
    end
    if startsWith(action,'supp_')
        require_archive(archiveRoot);
        addpath(supplement,'-begin');
        assert(strcmpi(which('CSSP_RUN'),fullfile(supplement,'CSSP_RUN.m')), ...
            'TUKEY:Path','An unexpected CSSP_RUN is on the MATLAB path.');
        opts.archiveRoot = archiveRoot;
        opts.outputRoot = output_path(options,root,'supplement');
        if isfield(options,'modules')
            opts.modules = options.modules;
        elseif ~isfield(opts,'modules')
            opts.modules = {'01_initialization'};
        end
        stage = char(extractAfter(action,'supp_'));
        if strcmp(stage,'summary')
            C = CSSP_SETUP('paper',opts);
            report = CSSP_SUMMARIZE(C);
        else
            assert(any(strcmp(stage,{'plan','pilot','paper'})), ...
                'TUKEY:Action','Unknown supplemental action.');
            report = CSSP_RUN(stage,opts);
        end
        return;
    end
    actions = {'selftest','quick','solver_synthetic','core_synthetic', ...
        'budget_synthetic','real_preflight','solver_real','core_real', ...
        'extension_real','tune_real','budget_real','summary','export_review'};
    assert(any(strcmp(action,actions)),'TUKEY:Action','Unknown action. See README.md.');
    realActions = {'real_preflight','solver_real','core_real','extension_real', ...
        'tune_real','budget_real'};
    if any(strcmp(action,realActions))
        require_archive(archiveRoot);
        opts.archiveRoot = archiveRoot;
    elseif ~isempty(archiveRoot)
        opts.archiveRoot = archiveRoot;
    end
    tag = 'p0_core';
    if strcmp(action,'quick'), tag = 'p0_quick'; end
    if strcmp(action,'selftest'), tag = 'p0_selftest'; end
    opts.outputRoot = output_path(options,root,tag);
    addpath(core,'-begin');
    report = START_TUKEY_CSSP_P0_V2(action,opts);
end

function folder = output_path(options,root,tag)
    folder = fullfile(root,'results',tag);
    if isfield(options,'outputRoot'), folder = char(options.outputRoot); end
    assert(ischar(folder) && ~isempty(folder),'TUKEY:Output','outputRoot is empty.');
end

function require_archive(folder)
    assert(~isempty(folder) && isfolder(folder),'TUKEY:Archive', ...
        'Set options.archiveRoot or TUKEY_ARCHIVE_ROOT to the frozen real-data archive.');
    names = {'cache','splits','calibration','jobs'};
    for k = 1:numel(names)
        assert(isfolder(fullfile(folder,names{k})),'TUKEY:Archive', ...
            'archiveRoot lacks %s. A raw image directory is not this archive.',names{k});
    end
end

function report = inspect_repository(root,core,sample,supplement,archiveRoot)
    required = {fullfile(core,'START_TUKEY_CSSP_P0_V2.m'), ...
        fullfile(core,'frozen','SU_FROZEN.m'),fullfile(sample,'SMP_RUN.m'), ...
        fullfile(sample,'vendor','SMPV_P0_SOLVER_V2.m'), ...
        fullfile(supplement,'CSSP_RUN.m'), ...
        fullfile(supplement,'legacy_nb','vendor','P0_SOLVER_V2.m')};
    present = cellfun(@isfile,required);
    folders = {'cache','splits','calibration','jobs'};
    archivePresent = ~isempty(archiveRoot) && isfolder(archiveRoot);
    if archivePresent
        archivePresent = all(cellfun(@(x) isfolder(fullfile(archiveRoot,x)),folders));
    end
    report = struct('RepositoryRoot',root,'MATLABVersion',version, ...
        'JVMEnabled',usejava('jvm'),'RequiredSourcesPresent',all(present), ...
        'ReadyForSyntheticSelftest',all(present) && usejava('jvm'), ...
        'RealArchiveDirectoryStructurePresent',archivePresent, ...
        'ArchiveRoot',archiveRoot,'ScientificFitsExecuted',0, ...
        'Notice','Directory presence is not a deep real-data or convergence check.');
end
