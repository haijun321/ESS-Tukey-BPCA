function report = NB_SUMMARIZE(outputRoot,stage)
% Aggregate committed fits only. Budget exits remain valid, labelled outputs.
% No Statistics Toolbox is used. Real-data intervals describe split variability.
    if nargin<2,stage='pilot';end
    stage=char(stage);root=fullfile(outputRoot,stage);
    assert(exist(root,'dir')==7,'NB:SummaryPath','Missing stage directory: %s',root);
    out=fullfile(root,'summary');if ~exist(out,'dir'),mkdir(out);end
    fs=dir(fullfile(root,'window*','fits','*','fit.mat'));
    records=cell(0,1);paths=cell(0,1);bad=cell(0,2);
    for k=1:numel(fs)
        file=fullfile(fs(k).folder,fs(k).name);
        try
            z=load(file);s=unwrap(z);
            assert(isfield(s,'record')&&isstruct(s.record)&&isscalar(s.record), ...
                'NB:SummarySchema','Committed fit must contain one record struct.');
            r=s.record;
            required={'Module','Dataset','Condition','Repeat','Method','CaseHash','InitHash'};
            assert(all(isfield(r,required)),'NB:SummarySchema','Missing record key fields.');
            assert(isnumeric(r.Repeat)&&isscalar(r.Repeat)&&isfinite(r.Repeat), ...
                'NB:SummarySchema','Repeat must be a finite scalar.');
            if isfield(r,'Stage'),assert(strcmp(char(r.Stage),stage),'NB:Stage','Stage mismatch.');end
            records{end+1,1}=r;paths{end+1,1}=file; %#ok<AGROW>
        catch e
            bad(end+1,:)={file,[e.identifier ': ' e.message]}; %#ok<AGROW>
        end
    end
    reject_duplicate_records(records,paths,out);
    raw=union_table(records);raw.SourceFile=paths;
    writetable(raw,fullfile(out,'raw_fit_records.csv'));
    write_cells(bad,{'File','Reason'},fullfile(out,'unreadable_records.csv'));
    completion=completion_table(root,records,paths);
    writetable(completion,fullfile(out,'completion.csv'));
    [cond,statuses]=condition_tables(records);
    write_structs(cond,condition_headers(),fullfile(out,'condition_summary.csv'));
    write_structs(statuses,{'Module','Dataset','Condition','Method','Status','StopReason','OutcomeClass','Count'}, ...
        fullfile(out,'status_counts.csv'));
    pairs=pair_records(records,completion);
    write_structs(pairs,pair_headers(),fullfile(out,'paired_differences.csv'));
    ps=pair_summary(pairs);
    write_structs(ps,paired_summary_headers(),fullfile(out,'paired_statistics.csv'));
    whole=whole_grid(pairs);
    write_structs(whole,grid_headers(),fullfile(out,'whole_grid_paired_statistics.csv'));
    notes=sprintf(['Means and SDs include only finite values; NNonfinite is reported explicitly.\n' ...
        'Condition Mean/SD describe all committed finite outputs, including unusable RA fits; baseline usability counts and usable-only means are separate.\n' ...
        'Zero-weight, rank-deficient or development-selection-degenerate RA outputs are retained as diagnostics but cannot enter paired superiority summaries.\n' ...
        'External RA pairs require BaselineUsable=true; missing usability flags are unknown and excluded from inference.\n' ...
        'SD uses the sample denominator n-1, and is NaN for n<2.\n' ...
        'NRE is the primary metric; ACC, subspace and weight diagnostics have separate purposes.\n' ...
        'Native control pairs share module, dataset, condition, repeat, data and initialization hashes.\n' ...
        'External RA pairs share data/seed but retain their native initialization; InitMatched and feature dimensions are explicit.\n' ...
        'Dimension-matched C3_dimK versus RA_dimK contrasts report FeatureMatched; matching feature size does not match model parameter counts.\n' ...
        'RA relative_residual_stable is its native stopping condition, not the native solver verified-gradient stability criterion.\n' ...
        'A completed fit can end at a time/iteration budget; this is not a convergence certificate.\n' ...
        'Real-data bootstrap intervals are descriptive across reused-image splits, not independent-subject inference.\n' ...
        'Synthetic whole-grid statistics first average conditions within each repeat; only complete blocks are used.\n' ...
        'NoiseSigma groups are kept separate; no pooling across modules, datasets or noise levels.\n' ...
        'All intervals are pointwise percentile-bootstrap intervals (2000 draws, fixed seed); no equivalence claim.\n' ...
        'Missing/mismatched/degenerate pairs are retained in paired_differences.csv and counted in paired_statistics.csv.\n' ...
        'A finite Difference in an invalid baseline pair is a raw diagnostic only; inference uses PairValid=true rows.\n' ...
        'Duplicate committed record keys are fatal and reported in duplicate_committed_keys.csv before aggregation.\n' ...
        'Only committed fit.mat records are summarized. Missing/unreadable fits are not silently marked complete.\n']);
    f=fopen(fullfile(out,'INTERPRETATION.txt'),'w');assert(f>=0);g=onCleanup(@()fclose(f));fprintf(f,'%s',notes);clear g;
    report=struct('Stage',stage,'OutputDirectory',out,'CommittedRecords',numel(records), ...
        'UnreadableRecords',size(bad,1),'PlannedRecords',height(completion), ...
        'MissingRecords',sum(~completion.FitPresent),'PairedRows',numel(pairs));
    fprintf('SUMMARY %s: %d committed; %d unreadable; %d missing planned fits.\n', ...
        stage,report.CommittedRecords,report.UnreadableRecords,report.MissingRecords);
end

function reject_duplicate_records(records,paths,out)
    keys=cellfun(@record_key,records,'UniformOutput',false);uk=unique(keys,'stable');rows=cell(0,3);
    for k=1:numel(uk)
        ix=find(strcmp(keys,uk{k}));
        if numel(ix)>1,rows(end+1,:)={uk{k},numel(ix),strjoin(paths(ix),' | ')};end %#ok<AGROW>
    end
    if isempty(rows),return;end
    file=fullfile(out,'duplicate_committed_keys.csv');
    write_cells(rows,{'RecordKey','CommittedKeyCount','Files'},file);
    error('NB:DuplicateCommittedKey','%d duplicate committed record key(s); no summaries written. Inspect %s.',size(rows,1),file);
end

function s=unwrap(z)
    if isfield(z,'payload'),s=z.payload;
    elseif isfield(z,'result'),s=z.result;
    elseif isfield(z,'record'),s=z;
    else,f=fieldnames(z);assert(numel(f)==1,'NB:SummarySchema','Ambiguous MAT schema.');s=z.(f{1});end
end

function T=union_table(records)
    fields=cell(0,1);
    for k=1:numel(records),fields=union(fields,fieldnames(records{k}),'stable');end
    T=table();
    for j=1:numel(fields)
        field=fields{j};isnum=true;
        for k=1:numel(records)
            if isfield(records{k},field)
                v=records{k}.(field);isnum=isnum&&((isnumeric(v)||islogical(v))&&isscalar(v));
            end
        end
        if isnum
            col=NaN(numel(records),1);
            for k=1:numel(records),if isfield(records{k},field),col(k)=double(records{k}.(field));end,end
        else
            col=cell(numel(records),1);
            for k=1:numel(records)
                col{k}='';if isfield(records{k},field),col{k}=astext(records{k}.(field));end
            end
        end
        T.(field)=col;
    end
end

function T=completion_table(root,records,paths)
    mf=dir(fullfile(root,'window*','expected_manifest.csv'));rows=cell(0,9);
    actualKeys=cellfun(@record_key,records,'UniformOutput',false);
    for k=1:numel(mf)
        E=readtable(fullfile(mf(k).folder,mf(k).name),'TextType','string');
        names={'Module','Dataset','Condition','Repeat','Method'};
        assert(all(ismember(names,E.Properties.VariableNames)),'NB:Manifest','Invalid expected manifest.');
        for j=1:height(E)
            r=struct('Module',char(E.Module(j)),'Dataset',char(E.Dataset(j)), ...
                'Condition',char(E.Condition(j)),'Repeat',double(E.Repeat(j)),'Method',char(E.Method(j)));
            ix=find(strcmp(actualKeys,record_key(r)));
            if isempty(ix),present=false;st='MISSING';file='';dup=0;
            elseif numel(ix)>1,present=true;st='DUPLICATE_COMMITTED_KEY';file=strjoin(paths(ix),' | ');dup=numel(ix);
            else,present=true;st=terminal_status(records{ix});file=paths{ix};dup=1;end
            rows(end+1,:)={r.Module,r.Dataset,r.Condition,r.Repeat,r.Method,present,st,dup,file}; %#ok<AGROW>
        end
    end
    if isempty(mf)
        for k=1:numel(records)
            r=records{k};rows(end+1,:)={astext(r.Module),astext(r.Dataset),astext(r.Condition), ...
                r.Repeat,astext(r.Method),true,terminal_status(r),1,paths{k}}; %#ok<AGROW>
        end
    end
    T=cell2table(rows,'VariableNames',{'Module','Dataset','Condition','Repeat','Method', ...
        'FitPresent','TerminalStatus','CommittedKeyCount','File'});
    if isempty(rows),T.FitPresent=false(0,1);end
end

function [summary,statuses]=condition_tables(records)
    metrics={'NRE','ErrSubNorm','ACC','RuntimeSeconds','OptimizationSeconds', ...
        'EvaluationSeconds','SelectionSeconds','ESS','ZeroFraction','TPR0','FPR0','FinalGradient', ...
        'RAInitialNonzeroFraction','RAFinalNonzeroFraction','RAInitialCovarianceRank','RAFinalCovarianceRank'};
    summary=struct([]);statuses=struct([]);keys=cellfun(@condition_key,records,'UniformOutput',false);
    group=unique(keys,'stable');
    for g=1:numel(group)
        ix=find(strcmp(keys,group{g}));r=records{ix(1)};
        usable=cellfun(@baseline_usable,records(ix));
        degenerate=cellfun(@zero_weight_degenerate,records(ix));
        ss=cellfun(@(x)[terminal_status(x) '|' stop_reason(x) '|' outcome_class(x)],records(ix),'UniformOutput',false);us=unique(ss,'stable');
        for u=1:numel(us)
            match=find(strcmp(ss,us{u}));sr=records{ix(match(1))};
            z=base_condition(r);z.Status=terminal_status(sr);z.StopReason=stop_reason(sr);
            z.OutcomeClass=outcome_class(sr);z.Count=numel(match);statuses=append(statuses,z);
        end
        for j=1:numel(metrics)
            metric=metrics{j};v=cellfun(@(x)number(x,metric),records(ix));vf=v(isfinite(v));
            z=base_condition(r);z.NoiseSigma=number(r,'NoiseSigma');z.Metric=metric;
            z.NRecords=numel(ix);z.NFinite=numel(vf);z.NNonfinite=sum(~isfinite(v));
            z.NBaselineUsable=sum(usable==1);z.NBaselineUnusable=sum(usable==0);
            z.NBaselineUnknown=sum(isnan(usable));z.NZeroWeightDegenerate=sum(degenerate);
            z.NRankDeficient=sum(cellfun(@(x)number(x,'RARankDeficient')==1,records(ix)));
            z.NSelectionDegenerate=sum(cellfun(@(x)number(x,'RASelectionDegenerate')==1,records(ix)));
            vu=v(isfinite(v)&usable==1);z.NFiniteBaselineUsable=numel(vu);
            [z.BaselineUsableMean,z.BaselineUsableSampleSD]=describe(vu);
            [z.Mean,z.SampleSD,z.Median,z.Minimum,z.Maximum]=describe(vf);
            summary=append(summary,z);
        end
    end
end

function pairs=pair_records(records,completion)
    contrasts={'C3','C2';'C3','C4';'C2','C5';'C3','C1'; ...
        'C3','RA2DPCA_dev';'C3','TunedC';'C3','TunedEta';'C3','L2'; ...
        'C3_dim1','RA_dim1';'C3_dim2','RA_dim2'};
    metrics={'NRE','ErrSubNorm','ACC','RuntimeSeconds','ESS','ZeroFraction','TPR0','FPR0'};
    pairs=struct([]);
    % Include planned-but-absent fits in pair accounting, without polluting raw means.
    actualKeys=cellfun(@record_key,records,'UniformOutput',false);
    for j=1:height(completion)
        planned=struct('Module',astext(completion.Module(j)), ...
            'Dataset',astext(completion.Dataset(j)),'Condition',astext(completion.Condition(j)), ...
            'Repeat',completion.Repeat(j),'Method',astext(completion.Method(j)), ...
            'CaseHash','','InitHash','','SummaryMissingFit',true,'NoiseSigma',NaN);
        if any(strcmp(actualKeys,record_key(planned))),continue;end
        % Carry the known noise group from another repeat of the same condition.
        for q=1:numel(records)
            x=records{q};
            if strcmp(astext(x.Module),planned.Module)&&strcmp(astext(x.Dataset),planned.Dataset)&&strcmp(astext(x.Condition),planned.Condition)
                planned.NoiseSigma=number(x,'NoiseSigma');break;
            end
        end
        records{end+1,1}=planned; %#ok<AGROW>
    end
    keys=cellfun(@case_key,records,'UniformOutput',false);uk=unique(keys,'stable');
    for g=1:numel(uk)
        ix=find(strcmp(keys,uk{g}));rs=records(ix);r=rs{1};
        for c=1:size(contrasts,1)
            methods=cellfun(@(x)astext(x.Method),rs,'UniformOutput',false);
            li=find(strcmp(methods,contrasts{c,1}));ri=find(strcmp(methods,contrasts{c,2}));
            % An intentionally absent method is not a missing experiment.
            if isempty(li)||isempty(ri),continue;end
            reason='';external=strcmp(contrasts{c,2},'RA2DPCA_dev')||startsWith(contrasts{c,2},'RA_dim');initMatched=false;
            if numel(li)~=1||numel(ri)~=1,reason='DUPLICATE_KEY';
            else
                left=rs{li};right=rs{ri};
                initMatched=strcmp(astext(left.InitHash),astext(right.InitHash))&&~isempty(astext(left.InitHash));
                if isfield(left,'SummaryMissingFit')&&left.SummaryMissingFit,reason='LEFT_MISSING';
                elseif isfield(right,'SummaryMissingFit')&&right.SummaryMissingFit,reason='RIGHT_MISSING';
                elseif external&&baseline_usable(right)==0,reason='BASELINE_DEGENERATE';
                elseif external&&isnan(baseline_usable(right)),reason='BASELINE_USABILITY_UNKNOWN';
                elseif ~strcmp(astext(left.CaseHash),astext(right.CaseHash)),reason='CASE_HASH_MISMATCH';
                elseif ~external&&~initMatched,reason='INIT_HASH_MISMATCH';
                elseif isempty(astext(left.CaseHash)),reason='EMPTY_HASH';
                elseif isfinite(number(left,'Seed'))&&isfinite(number(right,'Seed'))&&number(left,'Seed')~=number(right,'Seed'),reason='SEED_MISMATCH';
                elseif ~same_number(number(left,'NoiseSigma'),number(right,'NoiseSigma')),reason='NOISE_SIGMA_MISMATCH';end
            end
            for m=1:numel(metrics)
                z=struct('Module',astext(r.Module),'Dataset',astext(r.Dataset), ...
                    'Condition',astext(r.Condition),'NoiseSigma',number(r,'NoiseSigma'), ...
                    'Repeat',r.Repeat,'Seed',number(r,'Seed'),'Contrast',[contrasts{c,1} '-' contrasts{c,2}], ...
                    'Metric',metrics{m},'Left',NaN,'Right',NaN,'Difference',NaN, ...
                    'PairValid',false,'Reason',reason,'InitComparable',~external,'InitMatched',initMatched, ...
                    'LeftBaselineUsable',NaN,'RightBaselineUsable',NaN, ...
                    'LeftFeatureDimension',NaN,'RightFeatureDimension',NaN,'FeatureMatched',false);
                if numel(li)==1,z.Left=number(rs{li},metrics{m});end
                if numel(ri)==1,z.Right=number(rs{ri},metrics{m});end
                if numel(li)==1,z.LeftBaselineUsable=baseline_usable(rs{li});end
                if numel(ri)==1,z.RightBaselineUsable=baseline_usable(rs{ri});end
                if numel(li)==1,z.LeftFeatureDimension=number(rs{li},'FeatureDimension');end
                if numel(ri)==1,z.RightFeatureDimension=number(rs{ri},'FeatureDimension');end
                z.FeatureMatched=isfinite(z.LeftFeatureDimension)&&isfinite(z.RightFeatureDimension)&& ...
                    z.LeftFeatureDimension==z.RightFeatureDimension;
                if isempty(reason)
                    if isfinite(z.Left)&&isfinite(z.Right),z.Difference=z.Left-z.Right;z.PairValid=true;z.Reason='OK';
                    else,z.Reason='NONFINITE_METRIC';end
                elseif strcmp(reason,'BASELINE_DEGENERATE')&&isfinite(z.Left)&&isfinite(z.Right)
                    z.Difference=z.Left-z.Right;
                end
                pairs=append(pairs,z);
            end
        end
    end
end

function summary=pair_summary(pairs)
    summary=struct([]);if isempty(pairs),return;end
    keys=arrayfun(@(x)[x.Module '|' x.Dataset '|' x.Condition '|' x.Contrast '|' x.Metric],pairs,'UniformOutput',false);
    uk=unique(keys,'stable');
    for k=1:numel(uk)
        ix=find(strcmp(keys,uk{k}));p=pairs(ix);r=p(1);v=[p([p.PairValid]).Difference];
        z=struct('Module',r.Module,'Dataset',r.Dataset,'Condition',r.Condition,'NoiseSigma',r.NoiseSigma, ...
            'Contrast',r.Contrast,'Metric',r.Metric,'NExpectedPairs',numel(p),'NValidPairs',numel(v), ...
            'NMissingOrInvalid',sum(~[p.PairValid]),'MeanDifference',NaN,'SampleSD',NaN, ...
            'NBaselineDegenerate',sum(strcmp({p.Reason},'BASELINE_DEGENERATE')), ...
            'NBaselineUnknown',sum(strcmp({p.Reason},'BASELINE_USABILITY_UNKNOWN')), ...
            'Lower95',NaN,'Upper95',NaN,'WinsLeft',sum(v<0),'Ties',sum(v==0), ...
            'LossesLeft',sum(v>0),'InitMatchedPairs',sum([p.PairValid]&[p.InitMatched]), ...
            'FeatureMatchedPairs',sum([p.PairValid]&[p.FeatureMatched]), ...
            'FeatureMismatchedPairs',sum([p.PairValid]&~[p.FeatureMatched]),'Interpretation',scope(r.Dataset));
        [z.MeanDifference,z.SampleSD]=describe(v);[z.Lower95,z.Upper95]=bootstrap_mean(v,20261105+k);
        if strcmp(r.Metric,'ACC'),z.WinsLeft=sum(v>0);z.LossesLeft=sum(v<0);end
        % For ESS, rejection and runtime, direction counts are descriptive, not universal quality rankings.
        if ~any(strcmp(r.Metric,{'NRE','ErrSubNorm','ACC'})),z.Interpretation=[z.Interpretation '; sign counts are numeric directions only'];end
        summary=append(summary,z);
    end
end

function summary=whole_grid(pairs)
    summary=struct([]);if isempty(pairs),return;end
    pairs=pairs(strcmp({pairs.Dataset},'SYN'));if isempty(pairs),return;end
    keys=arrayfun(@(x)sprintf('%s|%s|%.17g|%s|%s',x.Module,x.Dataset,x.NoiseSigma,x.Contrast,x.Metric),pairs,'UniformOutput',false);
    uk=unique(keys,'stable');
    for k=1:numel(uk)
        p=pairs(strcmp(keys,uk{k}));r=p(1);conditions=unique({p.Condition});reps=unique([p.Repeat]);
        v=[];excluded=0;
        for rep=reps
            b=p([p.Repeat]==rep);
            complete=numel(b)==numel(conditions)&&all([b.PairValid])&&numel(unique({b.Condition}))==numel(conditions);
            if complete,v(end+1)=mean([b.Difference]);else,excluded=excluded+1;end %#ok<AGROW>
        end
        z=struct('Module',r.Module,'Dataset',r.Dataset,'NoiseSigma',r.NoiseSigma,'Contrast',r.Contrast, ...
            'Metric',r.Metric,'ConditionsPerBlock',numel(conditions),'CompleteRepeatBlocks',numel(v), ...
            'ExcludedRepeatBlocks',excluded,'MeanDifference',NaN,'SampleSD',NaN,'Lower95',NaN,'Upper95',NaN, ...
            'Interpretation','equal-condition means within repeat; pointwise paired-seed bootstrap');
        [z.MeanDifference,z.SampleSD]=describe(v);[z.Lower95,z.Upper95]=bootstrap_mean(v,20271000+k);
        summary=append(summary,z);
    end
end

function [lo,hi]=bootstrap_mean(v,seed)
    lo=NaN;hi=NaN;v=v(isfinite(v));n=numel(v);if n<2,return;end
    stream=RandStream('mt19937ar','Seed',seed);ix=randi(stream,n,n,2000);b=mean(reshape(v(ix),n,2000),1);
    lo=percentile(b,.025);hi=percentile(b,.975);
end

function q=percentile(v,p)
    v=sort(v(:));n=numel(v);h=1+(n-1)*p;l=floor(h);u=ceil(h);q=v(l)+(h-l)*(v(u)-v(l));
end

function [mu,sd,med,mn,mx]=describe(v)
    v=v(isfinite(v));mu=NaN;sd=NaN;med=NaN;mn=NaN;mx=NaN;
    if isempty(v),return;end
    mu=mean(v);med=median(v);mn=min(v);mx=max(v);
    if numel(v)>1,sd=sqrt(sum((v-mu).^2)/(numel(v)-1));end
end

function value=number(r,field)
    value=NaN;if isfield(r,field),v=r.(field);if (isnumeric(v)||islogical(v))&&isscalar(v),value=double(v);end,end
end

function tf=zero_weight_degenerate(r)
    tf=number(r,'RAZeroWeightDegenerate')==1||strcmp(terminal_status(r),'zero_weight_degenerate')|| ...
        strcmp(stop_reason(r),'zero_weight_degenerate');
end

function value=baseline_usable(r)
    value=number(r,'BaselineUsable');
    if ~any(value==[0 1]),value=NaN;end
    if zero_weight_degenerate(r)||number(r,'RARankDeficient')==1||number(r,'RASelectionDegenerate')==1,value=0;end
end

function s=astext(v)
    if ischar(v),s=v;
    elseif isstring(v)&&isscalar(v),s=char(v);
    elseif iscell(v)&&isscalar(v),s=astext(v{1});
    else,s=jsonencode(v);end
end

function k=record_key(r)
    k=[case_key(r) '|' astext(r.Method)];
end

function k=case_key(r)
    k=sprintf('%s|%s|%s|%.17g',astext(r.Module),astext(r.Dataset),astext(r.Condition),r.Repeat);
end

function k=condition_key(r)
    k=[astext(r.Module) '|' astext(r.Dataset) '|' astext(r.Condition) '|' astext(r.Method)];
end

function z=base_condition(r)
    z=struct('Module',astext(r.Module),'Dataset',astext(r.Dataset),'Condition',astext(r.Condition),'Method',astext(r.Method));
end

function s=terminal_status(r)
    s='';if isfield(r,'Status'),s=astext(r.Status);end
    if isempty(s)&&isfield(r,'StopReason'),s=astext(r.StopReason);end
    if isempty(s),s='UNSPECIFIED';end
end

function s=stop_reason(r)
    s='';if isfield(r,'StopReason'),s=astext(r.StopReason);end
end

function s=outcome_class(r)
    status=terminal_status(r);
    if zero_weight_degenerate(r),s='zero_weight_degenerate';
    elseif number(r,'RASelectionDegenerate')==1,s='development_selection_degenerate';
    elseif number(r,'RARankDeficient')==1,s='rank_deficient_degenerate';
    elseif baseline_usable(r)==0,s='baseline_unusable';
    elseif strcmp(status,'numerically_stable'),s='native_verified_stability';
    elseif strcmp(status,'relative_residual_stable'),s='external_native_criterion_stable';
    elseif any(strcmp(status,{'budget_exhausted','iteration_limit','time_limit','timecap'})),s='resource_limit';
    elseif contains(status,'failed_search'),s='search_failure';
    elseif contains(status,'degenerate'),s='degenerate_state';
    else,s='recorded_other';end
end

function tf=same_number(a,b)
    tf=(isnan(a)&&isnan(b))||isequal(a,b);
end

function s=scope(dataset)
    if strcmp(dataset,'SYN'),s='paired seeds, conditional on frozen protocol';
    else,s='descriptive split variability; not independent-subject inference';end
end

function a=append(a,z)
    if isempty(a),a=z;else,a(end+1,1)=z;end
end

function write_structs(s,headers,file)
    if isempty(s),write_cells(cell(0,numel(headers)),headers,file);
    else,T=struct2table(s,'AsArray',true);T=T(:,headers);writetable(T,file);end
end

function write_cells(c,headers,file)
    writetable(cell2table(c,'VariableNames',headers),file);
end

function h=condition_headers()
    h={'Module','Dataset','Condition','Method','NoiseSigma','Metric','NRecords','NFinite','NNonfinite', ...
        'NBaselineUsable','NBaselineUnusable','NBaselineUnknown','NZeroWeightDegenerate','NRankDeficient','NSelectionDegenerate', ...
        'NFiniteBaselineUsable','BaselineUsableMean','BaselineUsableSampleSD','Mean','SampleSD','Median','Minimum','Maximum'};
end

function h=pair_headers()
    h={'Module','Dataset','Condition','NoiseSigma','Repeat','Seed','Contrast','Metric','Left','Right','Difference', ...
        'PairValid','Reason','InitComparable','InitMatched','LeftBaselineUsable','RightBaselineUsable', ...
        'LeftFeatureDimension','RightFeatureDimension','FeatureMatched'};
end

function h=paired_summary_headers()
    h={'Module','Dataset','Condition','NoiseSigma','Contrast','Metric','NExpectedPairs','NValidPairs','NMissingOrInvalid', ...
        'NBaselineDegenerate','NBaselineUnknown', ...
        'MeanDifference','SampleSD','Lower95','Upper95','WinsLeft','Ties','LossesLeft', ...
        'InitMatchedPairs','FeatureMatchedPairs','FeatureMismatchedPairs','Interpretation'};
end

function h=grid_headers()
    h={'Module','Dataset','NoiseSigma','Contrast','Metric','ConditionsPerBlock','CompleteRepeatBlocks', ...
        'ExcludedRepeatBlocks','MeanDifference','SampleSD','Lower95','Upper95','Interpretation'};
end
