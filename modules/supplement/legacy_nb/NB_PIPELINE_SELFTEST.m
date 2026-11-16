function report=NB_PIPELINE_SELFTEST()
% Small engineering integration check: selected procedures, native dimensions,
% mean-aware metrics, actual CSV round trips, and real evaluation with synthetic fitting.
    exportRoot=tempname;mkdir(exportRoot);
    exportCleanup=onCleanup(@()remove_exports(exportRoot));
    emptyText=struct('Method','C1','NRE',.125,'BaselineIssue','');
    check_rows(emptyText,fullfile(exportRoot,'empty_text.csv'));
    C=NB_CONFIG();C.syntheticDimensions=[18 9 7 2 2];
    C.syntheticBudget=[3 2 8];C.syntheticTimeLimit=Inf;
    C.etaGrid=[.85 .97];C.cGrid=[2.5 4.685];C.raLambdaGrid=[.1 1];
    C.raMaxOuter=3;C.syntheticReps=1;C.runReal=false;C.runDimensionCurves=false;
    j=NB_JOBS(C,'B','pilot');j=j(1);j.Case.Type='impulse';j.Case.TypeIndex=2;
    j.Case.NominalRate=.1;j.Case.RateIndex=4;j.Condition='pipeline_fixture';
    [K,D,A,regime]=NB_CASE(C,j);
    methods={'C1','C3','TunedC','TunedEta','RA2DPCA_dev','C3_dim1','RA_dim1'};
    dimension=zeros(1,numel(methods));
    for i=1:numel(methods)
        j.Method=methods{i};s=NB_FIT(C,j,K,D,A,regime,'engineering_fixture_only');
        assert(isfinite(s.record.NRE)&&s.selectionLockedBeforeProbe, ...
            'NB:PipelineTest','Invalid final metric/selection state');
        dimension(i)=s.record.FeatureDimension;
        check_exports(s,exportRoot,sprintf('method_%02d',i));
        if startsWith(j.Method,'RA')
            assert(strcmp(s.record.InitializationProtocol,'native_RA_identity_plus_training_mean') ...
                &&s.record.InitializationSeconds==0,'NB:PipelineInit','Incorrect RA initialization accounting');
            if s.record.RAZeroWeightDegenerate||s.record.RARankDeficient||s.record.RASelectionDegenerate
                assert(~s.record.BaselineUsable,'NB:PipelineDegenerate','Degenerate RA was marked usable');
            end
        end
        if strcmp(j.Method,'TunedC')||strcmp(j.Method,'TunedEta')||strcmp(j.Method,'RA2DPCA_dev')
            [~,best]=min([s.selection.ValidationNRE]);
            assert(s.record.SelectedValue==s.selection(best).Value,'NB:PipelineSelection','Selection is not a development minimum');
        end
    end
    assert(dimension(end)==dimension(end-1),'NB:PipelineDimension','Matched feature budgets differ');
    j.Method='C3';j.Module='A_trajectory';
    traced=NB_FIT(C,j,K,D,A,regime,'engineering_trace_export');
    assert(isfield(traced,'checkpointMetrics')&&isfield(traced,'mechanism'), ...
        'NB:PipelineExport','Trace diagnostics were not produced');
    check_exports(traced,exportRoot,'trace');
    Dr=struct('evaluation','real','gallery',K.X(:,:,1:4),'galleryLabels',[1;1;2;2], ...
        'probe',K.X(:,:,5:8),'probeLabels',[1;1;2;2], ...
        'cfg',struct('classifier',struct('zscoreFeatures',true)));
    j.Method='C3';j.Module='E_coil';s=NB_FIT(C,j,K,Dr,A,'synthetic','engineering_real_eval');
    assert(isfinite(s.record.NRE)&&s.record.ACC>=0&&s.record.ACC<=1, ...
        'NB:PipelineReal','Real evaluation branch failed');
    assert(strcmp(s.record.Regime,'synthetic'),'NB:PipelineRegime','Calibration regime changed');
    check_exports(s,exportRoot,'real_evaluation');
    report=struct('Pass',true,'EngineeringOnly',true,'SelectedAndNativeMethods',numel(methods), ...
        'FeatureDimensionMatched',true,'RealEvaluationWithSyntheticCalibration',true, ...
        'CSVExportRoundtrip',true,'EmptyTextRecord',true,'TraceDiagnosticsExport',true);
    fprintf('NB_PIPELINE_SELFTEST PASS: fitted records and diagnostics exported with one row per struct.\n');
    clear exportCleanup;
end

function check_exports(saved,root,label)
    file=fullfile(root,[label '_record.csv']);
    check_rows(saved.record,file);
    T=readtable(file,'TextType','string');
    assert(height(T)==1&&strcmp(char(T.Method(1)),saved.record.Method), ...
        'NB:PipelineExport','Exported record identity changed');
    assert(abs(T.NRE(1)-saved.record.NRE)<1e-12*max(1,abs(saved.record.NRE)), ...
        'NB:PipelineExport','Exported NRE changed');
    names={'selection','checkpointMetrics','mechanism'};
    for k=1:numel(names)
        name=names{k};
        if isfield(saved,name)&&~isempty(saved.(name))
            rows=saved.(name);check_rows(rows,fullfile(root,[label '_' name '.csv']));
            check_rows(rows(1),fullfile(root,[label '_' name '_single.csv']));
        end
    end
    if isfield(saved.model,'weightTrace')&&~isempty(saved.model.weightTrace)
        rows=saved.model.weightTrace;
        check_rows(rows,fullfile(root,[label '_weights.csv']));
        check_rows(rows(1),fullfile(root,[label '_weights_single.csv']));
    end
end

function check_rows(rows,file)
    T=struct2table(rows,'AsArray',true);
    assert(height(T)==numel(rows)&&width(T)==numel(fieldnames(rows)), ...
        'NB:PipelineExport','Each struct must become exactly one CSV row');
    assert(isequaln(table2struct(T),rows(:)), ...
        'NB:PipelineExport','Table conversion changed a field value or type');
    writetable(T,file);
    actual=readtable(file,'TextType','string');
    assert(height(actual)==numel(rows)&&width(actual)==width(T), ...
        'NB:PipelineExport','CSV round trip lost rows or columns');
end

function remove_exports(root)
    if exist(root,'dir')==7,rmdir(root,'s');end
end
