function report=CSSP_SUMMARIZE(C)
% Read committed PAPER fits only; no fitting, selection or stopping occurs here.
% Real splits reuse images. All mean/SD and win/loss counts are descriptive;
% no independent-subject significance, equivalence or convergence is claimed.
    root=fullfile(C.outputRoot,'paper');
    assert(exist(root,'dir')==7,'CSSP:SummaryPath','Missing paper directory: %s',root);
    out=fullfile(root,'summary');if ~exist(out,'dir'),mkdir(out);end
    files=dir(fullfile(root,'*','fits','*','fit.mat'));
    records={};paths={};selections={};bad=cell(0,2);
    for k=1:numel(files)
        file=fullfile(files(k).folder,files(k).name);
        try
            s=unwrap(load(file));r=s.record;
            required={'Module','Dataset','Condition','Repeat','Method','Budget','Stage','CaseHash','InitHash'};
            assert(isstruct(r)&&isscalar(r)&&all(isfield(r,required)), ...
                'CSSP:SummarySchema','Required committed record fields missing.');
            assert(strcmp(astext(r.Stage),'paper'),'CSSP:SummaryStage','Non-paper fit under paper directory.');
            assert(isnumeric(r.Repeat)&&isscalar(r.Repeat)&&isfinite(r.Repeat), ...
                'CSSP:SummaryRepeat','Repeat must be finite numeric scalar.');
            if isfield(r,'Scientific'),assert(logical(r.Scientific),'CSSP:SummaryScientific','Pilot fit under paper directory.');end
            records{end+1,1}=r;paths{end+1,1}=file; %#ok<AGROW>
            if isfield(s,'selection')&&isstruct(s.selection)&&~isempty(s.selection)
                for j=1:numel(s.selection)
                    q=s.selection(j);z=base_row(r);z.CandidateIndex=j;
                    z.Value=number(q,'Value');z.ValidationNRE=number(q,'ValidationNRE');
                    z.Seconds=number(q,'Seconds');z.SelectedValue=number(r,'SelectedValue');
                    z.Selected=isfinite(z.Value)&&isfinite(z.SelectedValue)&&z.Value==z.SelectedValue;
                    if isfield(q,'Selected'),z.Selected=logical(q.Selected);end
                    z.SelectionLockedBeforeProbe=false;
                    if isfield(s,'selectionLockedBeforeProbe'),z.SelectionLockedBeforeProbe=logical(s.selectionLockedBeforeProbe);end
                    z.SourceFile=file;selections{end+1,1}=z; %#ok<AGROW>
                end
            end
        catch e
            bad(end+1,:)={file,[e.identifier ': ' e.message]}; %#ok<AGROW>
        end
    end
    reject_duplicates(records,paths,out);
    raw=union_table(records);raw.SourceFile=paths;
    writetable(raw,fullfile(out,'all_fit_records.csv'));
    write_cells(bad,{'File','Reason'},fullfile(out,'unreadable_records.csv'));
    completion=completion_table(root,records,paths);
    writetable(completion,fullfile(out,'completion.csv'));
    cond=condition_summary(records);
    write_structs(cond,fullfile(out,'condition_summary.csv'));
    write_structs(stop_status_counts(records),fullfile(out,'stop_status_counts.csv'));
    paired=paired_rows(records);
    write_structs(paired,fullfile(out,'paired_differences.csv'));
    pairedSummary=paired_summary(paired);
    write_structs(pairedSummary,fullfile(out,'paired_summary.csv'));
    interactions=factorial_interactions(records);
    write_structs(interactions,fullfile(out,'factorial_interactions.csv'));
    write_structs(interaction_summary(interactions),fullfile(out,'factorial_interaction_summary.csv'));
    [repeatMeans,overall]=overall_summary(records,C);
    write_structs(repeatMeans,fullfile(out,'overall_repeat_means.csv'));
    write_structs(overall,fullfile(out,'overall_summary.csv'));
    write_structs(selections,fullfile(out,'selection_candidates.csv'));
    failures=collect_failures(root);
    write_cells(failures,{'File','FailureOrBlockedReason'},fullfile(out,'failures_and_blocked.csv'));
    executionStatus=collect_execution_status(root,out);
    mechanism=collect_mechanism(root,out);
    plotWarnings=cell(0,2);
    if ~isfield(C,'makePlots')||C.makePlots
        plotWarnings=make_plots(pairedSummary,mechanism,out);
    end
    write_cells(plotWarnings,{'Figure','Reason'},fullfile(out,'plot_warnings.csv'));
    notes=[ ...
        "Only committed Stage=paper fit.mat records enter scientific summaries."; ...
        "Pilot fits are never pooled with paper fits. Failed/blocked tasks remain in completion and failure files."; ...
        "Modules can reference equivalent cached fits. Record count is not a count of independent/new trainings."; ...
        "Real-data mean/SD and win/loss counts describe repeated splits that reuse images; no independent-person p-values are produced."; ...
        "Condition summaries retain finite outputs of unusable baselines; paired summaries use only PairValid=true."; ...
        "Native pairs require matching case and initialization hashes. External pairs require matching case hashes and retain native initialization."; ...
        "FeatureMatched and InitMatched are explicit. Matching feature dimension does not match parameter count."; ...
        "NRE differences below zero and ACC differences above zero favor the left method. ACC differences are also given in percentage points."; ...
        "Numerical tie tolerance is 1e-12 times max(1, absolute metric values); a tie is not statistical equivalence."; ...
        "Four-cell interaction is (C3-C2)-(C4-C5). Its sign describes an interaction on that metric, not a general synergy theorem."; ...
        "Overall results first average all required conditions within each repeat; incomplete blocks are reported and excluded from the overall mean."; ...
        "Candidate selection records are descriptive. No probe metric is used by this summary to select parameters or checkpoints."; ...
        "Frozen-residual mechanism rows show one calibration decision, not refitted NRE/ACC or an independently controlled two-parameter weighting scheme."; ...
        "Finite budget-stopped outputs can be summarized; neither a saved result nor a small task-metric change is a convergence certificate."; ...
        "No superiority or publication-readiness conclusion is generated automatically."];
    write_text(fullfile(out,'INTERPRETATION.txt'),strjoin(cellstr(notes),newline));
    report=struct('Stage','paper','OutputDirectory',out,'CommittedRecords',numel(records), ...
        'UnreadableRecords',size(bad,1),'PlannedRows',height(completion), ...
        'MissingPlannedRows',sum(~completion.FitPresent),'FailureOrBlockedFiles',size(failures,1), ...
        'PairedRows',numel(paired),'ValidPairedRows',sum_field(paired,'PairValid'), ...
        'FactorialRows',numel(interactions),'MechanismRows',height(mechanism), ...
        'ExecutionStatusRows',height(executionStatus),'PlotWarnings',size(plotWarnings,1), ...
        'Interpretation','DESCRIPTIVE_NOT_A_SUPERIORITY_CLAIM');
    write_text(fullfile(out,'SUMMARY_STATUS.json'),jsonencode(report));
    fprintf('CSSP summary: %d committed records, %d missing planned rows, %d blocked/failed files.\n', ...
        report.CommittedRecords,report.MissingPlannedRows,report.FailureOrBlockedFiles);
end

function s=unwrap(z)
    if isfield(z,'payload'),s=z.payload;elseif isfield(z,'saved'),s=z.saved;
    elseif isfield(z,'result'),s=z.result;elseif isfield(z,'record'),s=z;
    else,f=fieldnames(z);assert(numel(f)==1,'CSSP:SummarySchema','Ambiguous MAT wrapper.');s=z.(f{1});end
    assert(isfield(s,'record'),'CSSP:SummarySchema','No record in committed MAT.');
end

function reject_duplicates(records,paths,out)
    keys=cellfun(@record_key,records,'UniformOutput',false);u=unique(keys,'stable');bad=cell(0,3);
    for k=1:numel(u)
        ix=find(strcmp(keys,u{k}));
        if numel(ix)>1,bad(end+1,:)={u{k},numel(ix),strjoin(paths(ix),' | ')};end %#ok<AGROW>
    end
    write_cells(bad,{'RecordKey','Count','Files'},fullfile(out,'duplicate_committed_keys.csv'));
    assert(isempty(bad),'CSSP:SummaryDuplicates','Duplicate committed record keys; inspect duplicate_committed_keys.csv.');
end

function key=record_key(r)
    key=strjoin({astext(r.Module),astext(r.Dataset),astext(r.Condition), ...
        sprintf('%.17g',r.Repeat),astext(r.Method),astext(r.Budget)},'|');
end

function T=completion_table(root,records,paths)
    % The driver writes one authoritative full manifest at paper root.
    % Per-module manifests are a backward-compatible fallback, never added
    % to the root manifest (which would count the same planned tasks twice).
    fs=dir(fullfile(root,'expected_manifest.csv'));
    if isempty(fs),fs=dir(fullfile(root,'*','expected_manifest.csv'));end
    rows=cell(0,9);
    keys=cellfun(@record_key,records,'UniformOutput',false);
    for k=1:numel(fs)
        E=readtable(fullfile(fs(k).folder,fs(k).name),'TextType','string');
        req={'Module','Dataset','Condition','Repeat','Method','Budget'};
        assert(all(ismember(req,E.Properties.VariableNames)),'CSSP:SummaryManifest','Manifest schema mismatch.');
        for j=1:height(E)
            r=struct('Module',astext(E.Module(j)),'Dataset',astext(E.Dataset(j)), ...
                'Condition',astext(E.Condition(j)),'Repeat',double(E.Repeat(j)), ...
                'Method',astext(E.Method(j)),'Budget',astext(E.Budget(j)));
            ix=find(strcmp(keys,record_key(r)));file='';status='MISSING';
            if ~isempty(ix),file=paths{ix(1)};status=status_text(records{ix(1)});end
            rows(end+1,:)={r.Module,r.Dataset,r.Condition,r.Repeat,r.Method,r.Budget,~isempty(ix),status,file}; %#ok<AGROW>
        end
    end
    if isempty(fs)
        for j=1:numel(records)
            r=records{j};rows(end+1,:)={r.Module,r.Dataset,r.Condition,r.Repeat,r.Method, ...
                astext(r.Budget),true,status_text(r),paths{j}}; %#ok<AGROW>
        end
    end
    T=cell2table(rows,'VariableNames',{'Module','Dataset','Condition','Repeat','Method','Budget','FitPresent','Status','File'});
    if isempty(rows),T.FitPresent=false(0,1);end
end

function rows=condition_summary(records)
    metrics=metric_names();keys=cellfun(@condition_key,records,'UniformOutput',false);groups=unique(keys,'stable');rows={};
    for g=1:numel(groups)
        ix=find(strcmp(keys,groups{g}));r=records{ix(1)};usable=cellfun(@baseline_usable,records(ix));
        for j=1:numel(metrics)
            v=cellfun(@(x)number(x,metrics{j}),records(ix));z=base_row(r);z=rmfield(z,'Repeat');
            z.Metric=metrics{j};z.NRecords=numel(ix);z.NFinite=sum(isfinite(v));z.NNonfinite=sum(~isfinite(v));
            z.NBaselineUsable=sum(usable);z.NBaselineUnusable=sum(~usable);
            [z.Mean,z.SampleSD,z.Median,z.Minimum,z.Maximum]=describe(v(isfinite(v)));
            vu=v(isfinite(v)&usable);[z.UsableMean,z.UsableSampleSD]=describe(vu);
            rows{end+1,1}=z; %#ok<AGROW>
        end
    end
end

function rows=stop_status_counts(records)
    rows={};if isempty(records),return;end
    keys=cellfun(@(r)[condition_key(r) '|' status_text(r) '|' stop_reason(r)],records,'UniformOutput',false);
    groups=unique(keys,'stable');
    for k=1:numel(groups)
        ix=find(strcmp(keys,groups{k}));r=records{ix(1)};z=rmfield(base_row(r),'Repeat');
        z.Status=status_text(r);z.StopReason=stop_reason(r);z.Count=numel(ix);
        z.NBaselineUsable=sum(cellfun(@baseline_usable,records(ix)));rows{end+1,1}=z; %#ok<AGROW>
    end
end

function rows=paired_rows(records)
    rows={};metrics={'NRE','ACC','ErrSubNorm','RuntimeSeconds'};
    for k=1:numel(records)
        r=records{k};module=astext(r.Module);method=astext(r.Method);contrasts={};
        if contains(module,'initialization')&&~strcmp(method,'INIT')
            contrasts(end+1,:)={method,'INIT','InitializationIncrement',false}; %#ok<AGROW>
        end
        if contains(module,'factorial')
            if strcmp(method,'C3'),contrasts=[contrasts;{'C3','C2','FactorialContrast',false};{'C3','C4','FactorialContrast',false}];end %#ok<AGROW>
            if strcmp(method,'C2')||strcmp(method,'C4'),contrasts(end+1,:)={method,'C5','FactorialContrast',false};end %#ok<AGROW>
        end
        if contains(module,'selection')&&strcmp(method,'C3')
            contrasts=[contrasts;{'C3','TunedC','ValidationSelection',false};{'C3','TunedEta','ValidationSelection',false}; ...
                {'C3','C1','DefaultParameter',false};{'C3','C2','DefaultParameter',false}]; %#ok<AGROW>
        end
        if contains(module,'external')&&~any(strcmp(method,{'C1','C2','C3','C4','C5','INIT'}))
            % Left=external, right=C3. The contrast label preserves this direction.
            contrasts(end+1,:)={method,'C3','ExternalComparison',true}; %#ok<AGROW>
        end
        if contains(module,'budget')&&strcmp(astext(r.Budget),'B2')
            contrasts(end+1,:)={method,method,'BudgetExpansion',false}; %#ok<AGROW>
        end
        if contains(module,'initialization')&&strcmp(method,'C3')
            contrasts(end+1,:)={'C3','C1','DefaultParameter',false}; %#ok<AGROW>
        end
        for c=1:size(contrasts,1)
            budget=astext(r.Budget);if strcmp(contrasts{c,3},'BudgetExpansion'),budget='B1';end
            [b,reason]=lookup(records,r,contrasts{c,2},budget,logical(contrasts{c,4}));
            for j=1:numel(metrics)
                z=pair_row(r,b,reason,contrasts{c,3},metrics{j},logical(contrasts{c,4}));
                if isempty(b)
                    z.RightMethod=contrasts{c,2};z.RightBudget=budget;
                    z.Contrast=[z.LeftMethod ' minus ' z.RightMethod];
                    if strcmp(z.PairType,'BudgetExpansion'),z.Contrast=[z.LeftMethod ': B2 minus B1'];end
                end
                rows{end+1,1}=z; %#ok<AGROW>
            end
        end
    end
end

function [b,reason]=lookup(records,r,method,budget,allowCrossModule)
    candidates=[];
    for k=1:numel(records)
        q=records{k};
        if strcmp(astext(q.Dataset),astext(r.Dataset))&&strcmp(astext(q.Condition),astext(r.Condition)) ...
                &&q.Repeat==r.Repeat&&strcmp(astext(q.Method),method)&&strcmp(astext(q.Budget),budget)
            candidates(end+1)=k; %#ok<AGROW>
        end
    end
    same=candidates(cellfun(@(q)strcmp(astext(q.Module),astext(r.Module)),records(candidates)));
    if ~isempty(same),candidates=same;
    elseif ~allowCrossModule,b=[];reason='MISSING_WITHIN_MODULE';return;end
    if isempty(candidates),b=[];reason='MISSING_REFERENCE';return;end
    if numel(candidates)>1
        preferred=candidates(cellfun(@(q)contains(astext(q.Module),'initialization'),records(candidates)));
        if numel(preferred)==1,candidates=preferred;end
    end
    if numel(candidates)>1,b=[];reason='AMBIGUOUS_REFERENCE';return;end
    b=records{candidates};reason='MATCH_FOUND';
end

function z=pair_row(a,b,reason,pairType,metric,allowDifferentInit)
    z=base_row(a);z.PairType=pairType;z.LeftMethod=astext(a.Method);z.RightMethod='';
    z.LeftModule=astext(a.Module);z.RightModule='';z.LeftBudget=astext(a.Budget);z.RightBudget='';
    z.Contrast='';z.Metric=metric;z.Left=number(a,metric);z.Right=NaN;z.Difference=NaN;
    z.DifferencePercentagePoints=NaN;z.CaseMatched=false;z.InitMatched=false;z.FeatureMatched=false;
    z.PairValid=false;z.PairIssue=reason;z.NumericalTieTolerance=NaN;z.BeneficialDirection='';
    if isempty(b),return;end
    z.RightMethod=astext(b.Method);z.RightModule=astext(b.Module);z.RightBudget=astext(b.Budget);
    z.Contrast=[z.LeftMethod ' minus ' z.RightMethod];
    if strcmp(pairType,'BudgetExpansion'),z.Contrast=[z.LeftMethod ': B2 minus B1'];end
    z.Right=number(b,metric);z.Difference=z.Left-z.Right;
    z.CaseMatched=strcmp(astext(a.CaseHash),astext(b.CaseHash));
    z.InitMatched=strcmp(astext(a.InitHash),astext(b.InitHash));
    da=number(a,'FeatureDimension');db=number(b,'FeatureDimension');
    z.FeatureMatched=isfinite(da)&&isfinite(db)&&da==db;
    issues={};
    if ~z.CaseMatched,issues{end+1}='CASE_HASH_MISMATCH';end %#ok<AGROW>
    if ~allowDifferentInit&&~z.InitMatched,issues{end+1}='INIT_HASH_MISMATCH';end %#ok<AGROW>
    if ~baseline_usable(a)||~baseline_usable(b),issues{end+1}='UNUSABLE_BASELINE';end %#ok<AGROW>
    if ~isfinite(z.Left)||~isfinite(z.Right),issues{end+1}='NONFINITE_METRIC';end %#ok<AGROW>
    z.PairValid=isempty(issues);z.PairIssue=strjoin(issues,';');
    if z.PairValid,z.PairIssue='VALID_DESCRIPTIVE_PAIR';end
    z.NumericalTieTolerance=1e-12*max([1 abs(z.Left) abs(z.Right)]);
    if strcmp(metric,'ACC'),z.DifferencePercentagePoints=100*z.Difference;z.BeneficialDirection='positive';
    else,z.BeneficialDirection='negative';end
end

function rows=paired_summary(pairs)
    rows={};if isempty(pairs),return;end
    keys=cellfun(@(r)strjoin({astext(r.Module),r.Dataset,r.Condition,r.PairType,r.Contrast,r.Metric,r.LeftBudget,r.RightBudget},'|'),pairs,'UniformOutput',false);
    groups=unique(keys,'stable');
    for g=1:numel(groups)
        ix=find(strcmp(keys,groups{g}));r=pairs{ix(1)};valid=cellfun(@(x)logical(x.PairValid),pairs(ix));
        values=cellfun(@(x)x.Difference,pairs(ix));tol=cellfun(@(x)x.NumericalTieTolerance,pairs(ix));
        use=valid&isfinite(values);d=values(use);t=tol(use);
        z=struct('Module',r.Module,'Dataset',r.Dataset,'Condition',r.Condition,'PairType',r.PairType, ...
            'Contrast',r.Contrast,'Metric',r.Metric,'LeftBudget',r.LeftBudget,'RightBudget',r.RightBudget, ...
            'NRecordedPairs',numel(ix),'NValidPairs',sum(use),'NInvalidPairs',sum(~use), ...
            'MeanDifference',NaN,'SampleSD',NaN,'MedianDifference',NaN,'MinimumDifference',NaN,'MaximumDifference',NaN, ...
            'NImproved',0,'NTiedNumerically',0,'NWorse',0,'MeanPercentagePoints',NaN,'SDPercentagePoints',NaN);
        [z.MeanDifference,z.SampleSD,z.MedianDifference,z.MinimumDifference,z.MaximumDifference]=describe(d);
        if strcmp(r.Metric,'ACC')
            z.NImproved=sum(d>t);z.NWorse=sum(d<-t);z.MeanPercentagePoints=100*z.MeanDifference;z.SDPercentagePoints=100*z.SampleSD;
        else,z.NImproved=sum(d<-t);z.NWorse=sum(d>t);end
        z.NTiedNumerically=sum(abs(d)<=t);rows{end+1,1}=z; %#ok<AGROW>
    end
end

function rows=factorial_interactions(records)
    rows={};metrics={'NRE','ACC'};
    for k=1:numel(records)
        a=records{k};if ~contains(astext(a.Module),'factorial')||~strcmp(astext(a.Method),'C3'),continue;end
        [b,rb]=lookup(records,a,'C2',astext(a.Budget),false);
        [c,rc]=lookup(records,a,'C4',astext(a.Budget),false);
        [d,rd]=lookup(records,a,'C5',astext(a.Budget),false);
        for j=1:numel(metrics)
            z=base_row(a);z.Metric=metrics{j};z.Interaction=NaN;z.InteractionPercentagePoints=NaN;
            z.PairValid=false;z.PairIssue=strjoin({rb,rc,rd},';');
            if ~isempty(b)&&~isempty(c)&&~isempty(d)
                q={a,b,c,d};caseOK=all(cellfun(@(x)strcmp(astext(x.CaseHash),astext(a.CaseHash)),q));
                initOK=all(cellfun(@(x)strcmp(astext(x.InitHash),astext(a.InitHash)),q));
                v=cellfun(@(x)number(x,metrics{j}),q);
                z.Interaction=(v(1)-v(2))-(v(3)-v(4));
                z.PairValid=caseOK&&initOK&&all(isfinite(v))&&all(cellfun(@baseline_usable,q));
                if z.PairValid,z.PairIssue='VALID_DESCRIPTIVE_FOUR_CELL_INTERACTION';else,z.PairIssue='HASH_USABILITY_OR_FINITE_CHECK_FAILED';end
                if strcmp(metrics{j},'ACC'),z.InteractionPercentagePoints=100*z.Interaction;end
            end
            rows{end+1,1}=z; %#ok<AGROW>
        end
    end
end

function rows=interaction_summary(interactions)
    rows={};if isempty(interactions),return;end
    keys=cellfun(@(r)[condition_key(r) '|' r.Metric],interactions,'UniformOutput',false);groups=unique(keys,'stable');
    for g=1:numel(groups)
        ix=find(strcmp(keys,groups{g}));r=interactions{ix(1)};v=cellfun(@(x)x.Interaction,interactions(ix));
        ok=cellfun(@(x)x.PairValid,interactions(ix))&isfinite(v);z=rmfield(base_row(r),{'Repeat','Method'});
        z.Metric=r.Metric;z.Formula='(C3-C2)-(C4-C5)';z.NValid=sum(ok);z.NInvalid=sum(~ok);
        [z.MeanInteraction,z.SampleSD,z.MedianInteraction,z.Minimum,z.Maximum]=describe(v(ok));
        z.MeanPercentagePoints=NaN;if strcmp(r.Metric,'ACC'),z.MeanPercentagePoints=100*z.MeanInteraction;end
        rows{end+1,1}=z; %#ok<AGROW>
    end
end

function [repeatRows,summary]=overall_summary(records,C)
    repeatRows={};summary={};if isempty(records),return;end
    reps=1:10;if isfield(C,'realReps'),reps=C.realReps;end
    metrics={'NRE','ACC'};keys=cellfun(@(r)strjoin({astext(r.Module),astext(r.Dataset),astext(r.Method),astext(r.Budget)},'|'),records,'UniformOutput',false);
    groups=unique(keys,'stable');
    for g=1:numel(groups)
        ix=find(strcmp(keys,groups{g}));r=records{ix(1)};
        conditions={'Clean','I10','I30','B10','B30'};
        if contains(astext(r.Module),'b10_budget'),conditions={'B10'};end
        for j=1:numel(metrics)
            means=NaN(numel(reps),1);complete=false(numel(reps),1);
            for t=1:numel(reps)
                values=NaN(numel(conditions),1);usable=true;
                for c=1:numel(conditions)
                    local=ix(cellfun(@(x)x.Repeat==reps(t)&&strcmp(astext(x.Condition),conditions{c}),records(ix)));
                    if numel(local)==1,values(c)=number(records{local},metrics{j});usable=usable&&baseline_usable(records{local});else,usable=false;end
                end
                complete(t)=all(isfinite(values))&&usable;
                if complete(t),means(t)=mean(values);end
                z=rmfield(base_row(r),'Condition');z.Repeat=reps(t);z.Metric=metrics{j};z.RequiredConditions=strjoin(conditions,';');
                z.NRequiredConditions=numel(conditions);z.NFiniteConditions=sum(isfinite(values));
                z.CompleteBlock=complete(t);z.ConditionMean=means(t);repeatRows{end+1,1}=z; %#ok<AGROW>
            end
            z=rmfield(base_row(r),{'Condition','Repeat'});z.Metric=metrics{j};z.RequiredConditions=strjoin(conditions,';');
            z.NPlannedRepeats=numel(reps);z.NCompleteRepeats=sum(complete);z.NIncompleteRepeats=sum(~complete);
            [z.Mean,z.SampleSD,z.Median,z.Minimum,z.Maximum]=describe(means(complete));
            z.ACCPercent=NaN;if strcmp(metrics{j},'ACC'),z.ACCPercent=100*z.Mean;end
            summary{end+1,1}=z; %#ok<AGROW>
        end
    end
end

function rows=collect_failures(root)
    fs=dir(fullfile(root,'**','FAILED_OR_BLOCKED.txt'));rows=cell(0,2);
    for k=1:numel(fs),file=fullfile(fs(k).folder,fs(k).name);rows(end+1,:)={file,fileread(file)};end %#ok<AGROW>
end

function T=collect_execution_status(root,out)
    fs=dir(fullfile(root,'task_status.csv'));
    if isempty(fs)
        fs=[dir(fullfile(root,'**','status.csv'));dir(fullfile(root,'**','task_status.csv'))];
    end
    rows={};
    for k=1:numel(fs)
        file=fullfile(fs(k).folder,fs(k).name);
        if startsWith(file,[out filesep]),continue;end
        q=table2struct(readtable(file,'TextType','string'));
        for j=1:numel(q),z=q(j);z.SourceFile=file;rows{end+1,1}=z;end %#ok<AGROW>
    end
    T=union_table(rows);
    if width(T)==0,T=table(strings(0,1),'VariableNames',{'RecordStatus'});end
    writetable(T,fullfile(out,'execution_status_records.csv'));
end

function T=collect_mechanism(root,out)
    fs=dir(fullfile(root,'**','mechanism_candidates.csv'));T=table();
    for k=1:numel(fs)
        file=fullfile(fs(k).folder,fs(k).name);
        if startsWith(file,[out filesep]),continue;end
        q=readtable(file,'TextType','string');
        q.SourceFile=repmat(string(file),height(q),1);
        if isempty(T),T=q;else,T=[T;q];end %#ok<AGROW>
    end
    if width(T)==0,T=table(strings(0,1),'VariableNames',{'EvidenceType'});end
    writetable(T,fullfile(out,'mechanism_candidates.csv'));
    if ~isempty(T)&&ismember('Selected',T.Properties.VariableNames)
        selected=T(T.Selected==1,:);writetable(selected,fullfile(out,'mechanism_selected.csv'));
    end
end

function warnings=make_plots(summary,mechanism,out)
    warnings=cell(0,2);
    if ~isempty(summary)
        T=union_table(summary);
        for dataset={'YALE','ORL'}
            name=['paired_NRE_' dataset{1} '.pdf'];
            try
                ix=strcmp(string(T.Dataset),dataset{1})&strcmp(string(T.Metric),'NRE')&T.NValidPairs>0;
                if ~any(ix),continue;end
                Q=T(ix,:);f=figure('Visible','off','Color','w','Position',[100 100 1100 max(400,30*height(Q))]);
                g=onCleanup(@()close(f));y=(1:height(Q))';
                errorbar(Q.MeanDifference,y,Q.SampleSD,'horizontal','o','LineWidth',1);xline(0,'k:');
                labels=strcat(string(Q.Module)," / ",string(Q.Condition)," / ",string(Q.Contrast)," / ",string(Q.LeftBudget));
                yticks(y);yticklabels(labels);set(gca,'TickLabelInterpreter','none','FontSize',9);grid on;
                xlabel('Paired NRE difference (left minus right)');title([dataset{1} ': descriptive mean and sample SD']);
                exportgraphics(f,fullfile(out,name),'ContentType','vector');clear g;
            catch e,warnings(end+1,:)={name,e.message};end %#ok<AGROW>
        end
    end
    if isempty(mechanism),return;end
    req={'Dataset','Condition','Repeat','Method','ESSOperational','R0Operational','TargetEta','Selected'};
    if ~all(ismember(req,mechanism.Properties.VariableNames)),return;end
    for dataset={'YALE','ORL'}
        for condition={'Clean','I30','B10'}
            name=['mechanism_' dataset{1} '_' condition{1} '.pdf'];
            try
                ix=strcmp(string(mechanism.Dataset),dataset{1})&strcmp(string(mechanism.Condition),condition{1});
                if ~any(ix),continue;end
                minRep=min(mechanism.Repeat(ix));Q=mechanism(ix&mechanism.Repeat==minRep,:);
                curve=Q(strcmp(string(Q.Method),'C3'),:);if isempty(curve),continue;end
                f=figure('Visible','off','Color','w','Position',[100 100 850 480]);g=onCleanup(@()close(f));
                plot(curve.ESSOperational,curve.R0Operational,'k-','DisplayName','Candidate curve');hold on;
                ids={'C2','C3','C4','C5'};colors=lines(4);
                for j=1:4
                    q=Q(strcmp(string(Q.Method),ids{j})&Q.Selected==1,:);
                    if isempty(q),continue;end
                    scatter(q.ESSOperational,q.R0Operational,65,colors(j,:),'filled','DisplayName',ids{j});
                    xline(q.TargetEta(1),':','Color',colors(j,:),'HandleVisibility','off');
                end
                if ismember('R0LowerPreference',Q.Properties.VariableNames)
                    yline(Q.R0LowerPreference(1),'--','HandleVisibility','off');yline(Q.R0UpperPreference(1),'--','HandleVisibility','off');
                end
                xlabel('Operational normalized Kish ESS');ylabel('Operational rejection ratio, |e| > cutoff');
                title(sprintf('%s %s repeat %d: common initial residual',dataset{1},condition{1},minRep));
                legend('Location','best');grid on;exportgraphics(f,fullfile(out,name),'ContentType','vector');clear g;
            catch e,warnings(end+1,:)={name,e.message};end %#ok<AGROW>
        end
    end
end

function r=base_row(s)
    r=struct('Module',astext(s.Module),'Dataset',astext(s.Dataset),'Condition',astext(s.Condition), ...
        'Repeat',s.Repeat,'Method',astext(s.Method),'Budget',astext(s.Budget));
end

function k=condition_key(s)
    k=strjoin({astext(s.Module),astext(s.Dataset),astext(s.Condition),astext(s.Method),astext(s.Budget)},'|');
end

function names=metric_names()
    names={'NRE','ACC','ErrSubNorm','RuntimeSeconds','OptimizationSeconds','SelectionSeconds', ...
        'InitializationSeconds','EvaluationSeconds','AcceptedSteps','FinalGradient', ...
        'ESS','ZeroFraction','TPR0','FPR0','Tau','TargetEta','CurrentSeverity'};
end

function tf=baseline_usable(r)
    if isfield(r,'BaselineUsable'),v=number(r,'BaselineUsable');tf=isfinite(v)&&v==1;
    else,tf=any(strcmp(astext(r.Method),{'INIT','L2','C1','C2','C3','C4','C5','TunedC','TunedEta'}));end
    % A finite native failed_search endpoint is an algorithm outcome just
    % like timecap/budget_exhausted. Do not exclude by stopping label.
    % Missing models/contract violations are rejected by the driver/schema;
    % an explicitly unusable external baseline remains excluded above.
end

function x=number(s,f)
    x=NaN;if isfield(s,f)&&(isnumeric(s.(f))||islogical(s.(f)))&&isscalar(s.(f)),x=double(s.(f));end
end

function s=status_text(r)
    s='';if isfield(r,'Status'),s=astext(r.Status);elseif isfield(r,'StopReason'),s=astext(r.StopReason);end
end

function s=stop_reason(r)
    s='';if isfield(r,'StopReason'),s=astext(r.StopReason);else,s=status_text(r);end
end

function s=astext(v)
    if ischar(v),s=v;elseif isstring(v),s=char(v);
    elseif isnumeric(v)||islogical(v),s=mat2str(v);else,s=jsonencode(v);end
end

function [mu,sd,med,lo,hi]=describe(v)
    mu=NaN;sd=NaN;med=NaN;lo=NaN;hi=NaN;
    if isempty(v),return;end
    mu=mean(v);med=median(v);lo=min(v);hi=max(v);if numel(v)>1,sd=std(v,0);end
end

function T=union_table(rows)
    if isempty(rows),T=table();return;end
    if isstruct(rows),rows=num2cell(rows);end
    fields={};for k=1:numel(rows),fields=union(fields,fieldnames(rows{k}),'stable');end
    T=table();
    for j=1:numel(fields)
        field=fields{j};numeric=true;
        for k=1:numel(rows)
            if isfield(rows{k},field),v=rows{k}.(field);numeric=numeric&&((isnumeric(v)||islogical(v))&&isscalar(v));end
        end
        if numeric
            values=NaN(numel(rows),1);for k=1:numel(rows),if isfield(rows{k},field),values(k)=double(rows{k}.(field));end,end
        else
            values=cell(numel(rows),1);for k=1:numel(rows),values{k}='';if isfield(rows{k},field),values{k}=astext(rows{k}.(field));end,end
        end
        T.(field)=values;
    end
end

function write_structs(rows,file)
    T=union_table(rows);
    if width(T)==0,T=table(strings(0,1),'VariableNames',{'RecordStatus'});end
    writetable(T,file);
end

function write_cells(rows,names,file)
    T=cell2table(rows,'VariableNames',names);writetable(T,file);
end

function write_text(file,value)
    f=fopen(file,'w');assert(f>=0,'CSSP:SummaryWrite','Cannot write %s.',file);g=onCleanup(@()fclose(f));fprintf(f,'%s\n',value);clear g;
end

function n=sum_field(rows,field)
    n=0;for k=1:numel(rows),n=n+double(rows{k}.(field));end
end
