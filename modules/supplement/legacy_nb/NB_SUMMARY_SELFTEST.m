function report=NB_SUMMARY_SELFTEST()
% Meaningful checks for missing pairs, initialization hashes and sample SD.
% Uses a private temporary output tree and removes it after verification.
    root=tempname;mkdir(root);cleanup=onCleanup(@()remove_tree(root));
    stage='pilot';window=fullfile(root,stage,'windowC');mkdir(window);
    methods={'C2','C3','C4','C5','RA2DPCA_dev','C3_dim1','RA_dim1','C3_dim2','RA_dim2'};conditions={'case_a','case_b'};
    expected=cell(0,5);
    for c=1:2
        for rep=1:3
            for m=1:numel(methods)
                method=methods{m};expected(end+1,:)={'C_factorial','SYN',conditions{c},rep,method}; %#ok<AGROW>
                if c==2&&rep==3&&strcmp(method,'C4'),continue;end
                offsets=[.4 .3 .5 .45 .35 .2 .25 .15 .18];
                r=struct('Module','C_factorial','Stage',stage,'Dataset','SYN','Condition',conditions{c}, ...
                    'Repeat',rep,'Seed',100+rep,'Method',method,'Status','budget_exhausted', ...
                    'CaseHash',sprintf('case%d_rep%d',c,rep),'InitHash','common_init', ...
                    'NRE',offsets(m)+.01*rep,'ErrSubNorm',.1,'ACC',NaN,'RuntimeSeconds',2, ...
                    'NoiseSigma',.1,'FeatureDimension',12,'ESS',.9,'ZeroFraction',.1, ...
                    'TPR0',.5,'FPR0',.001,'FinalGradient',.01,'BaselineUsable',true, ...
                    'RAInitialNonzeroFraction',NaN,'RAFinalNonzeroFraction',NaN,'RAZeroWeightDegenerate',false);
                if c==1&&rep==2&&strcmp(method,'C2'),r.InitHash='mismatched_init';end
                if strcmp(method,'RA2DPCA_dev'),r.InitHash='external_native_init';r.FeatureDimension=15;end
                if any(strcmp(method,{'RA_dim1','RA_dim2'})),r.InitHash='external_native_init';end
                if contains(method,'dim1'),r.FeatureDimension=12;end
                if contains(method,'dim2'),r.FeatureDimension=24;end
                if strcmp(method,'RA_dim1'),r.Status='relative_residual_stable';end
                folder=fullfile(window,'fits',sprintf('%d_%d_%s',c,rep,method));mkdir(folder);
                payload=struct('record',r);save(fullfile(folder,'fit.mat'),'payload','-v7');
            end
        end
    end
    T=cell2table(expected,'VariableNames',{'Module','Dataset','Condition','Repeat','Method'});
    writetable(T,fullfile(window,'expected_manifest.csv'));
    result=NB_SUMMARIZE(root,stage);out=result.OutputDirectory;
    assert(result.CommittedRecords==53&&result.MissingRecords==1,'NB:SummaryTest','Completion count.');
    P=readtable(fullfile(out,'paired_differences.csv'),'TextType','string');
    q=P.Contrast=="C3-C2"&P.Metric=="NRE";
    assert(sum(q)==6&&sum(P.PairValid(q))==5,'NB:SummaryTest','Hash mismatch must invalidate pair.');
    q=P.Contrast=="C3-C4"&P.Metric=="NRE";
    assert(sum(q)==6&&sum(P.PairValid(q))==5,'NB:SummaryTest','Missing planned fit must remain counted.');
    q=P.Contrast=="C3-RA2DPCA_dev"&P.Metric=="NRE";
    assert(sum(q)==6&&all(P.PairValid(q))&&~any(P.InitMatched(q)), ...
        'NB:SummaryTest','External native initialization policy.');
    q=(P.Contrast=="C3_dim1-RA_dim1"|P.Contrast=="C3_dim2-RA_dim2")&P.Metric=="NRE";
    assert(sum(q)==12&&all(P.PairValid(q))&&all(P.FeatureMatched(q))&&~any(P.InitComparable(q)), ...
        'NB:SummaryTest','Feature-matched external native initialization policy.');
    G=readtable(fullfile(out,'whole_grid_paired_statistics.csv'),'TextType','string');
    q=G.Contrast=="C3-C2"&G.Metric=="NRE";
    assert(sum(q)==1&&G.CompleteRepeatBlocks(q)==2&&G.ExcludedRepeatBlocks(q)==1, ...
        'NB:SummaryTest','Only complete repetition blocks may enter whole-grid mean.');
    assert(abs(G.MeanDifference(q)+.1)<1e-12,'NB:SummaryTest','Paired mean arithmetic.');
    S=readtable(fullfile(out,'condition_summary.csv'),'TextType','string');
    q=S.Method=="C3"&S.Condition=="case_a"&S.Metric=="NRE";
    assert(abs(S.SampleSD(q)-.01)<1e-12,'NB:SummaryTest','Sample SD must use n-1.');
    q=S.Method=="C3"&S.Condition=="case_a"&S.Metric=="ACC";
    assert(S.NFinite(q)==0&&S.NNonfinite(q)==3,'NB:SummaryTest','Undefined metrics must be explicit.');
    SC=readtable(fullfile(out,'status_counts.csv'),'TextType','string');
    q=SC.Method=="RA_dim1";
    assert(all(SC.OutcomeClass(q)=="external_native_criterion_stable"), ...
        'NB:SummaryTest','External stability cannot be labelled native verified-gradient stability.');
    degeneration_checks(root,stage);
    duplicate_checks(root,stage);
    report=struct('Pass',true,'Checks',25,'Runtime','MATLAB');
    fprintf('NB_SUMMARY_SELFTEST PASS: completion, pairing, baseline degeneration, duplicate guards, block means and sample SD.\n');
    clear cleanup;
end

function degeneration_checks(root,stage)
    scopedRoot=fullfile(root,'degenerate_fixture');
    windows={'windowA_SYN','windowA_REAL'};datasets={'SYN','COIL20'};
    for d=1:2
        window=fullfile(scopedRoot,stage,windows{d});mkdir(window);expected=cell(0,5);
        for rep=1:2
            for m=1:2
                methods={'C3','RA2DPCA_dev'};method=methods{m};
                r=struct('Module','B_comparison','Stage',stage,'Dataset',datasets{d},'Condition','ra_guard', ...
                    'Repeat',rep,'Seed',rep,'Method',method,'Status','budget_exhausted','StopReason','iteration_limit', ...
                    'CaseHash',sprintf('%s_rep%d',datasets{d},rep),'InitHash','native_init', ...
                    'NRE',.1,'NoiseSigma',.1,'FeatureDimension',12,'BaselineUsable',true, ...
                    'RAInitialNonzeroFraction',NaN,'RAFinalNonzeroFraction',NaN,'RAZeroWeightDegenerate',false, ...
                    'RAInitialCovarianceRank',NaN,'RAFinalCovarianceRank',NaN,'RARankDeficient',false,'RASelectionDegenerate',false);
                if m==2
                    r.InitHash='external_init';r.NRE=.2;
                    r.RAInitialNonzeroFraction=.8;r.RAFinalNonzeroFraction=.5;
                    r.RAInitialCovarianceRank=12;r.RAFinalCovarianceRank=12;
                    if rep==2
                        r.NRE=.6;r.BaselineUsable=false;
                        if d==1
                            r.RAZeroWeightDegenerate=true;r.RARankDeficient=true;r.RAFinalCovarianceRank=0;
                            r.RAFinalNonzeroFraction=0;r.Status='zero_weight_degenerate';r.StopReason='zero_weight_degenerate';
                        else
                            r.RASelectionDegenerate=true;r.Status='relative_residual_stable';r.StopReason='relative_residual_stable';
                        end
                    end
                end
                expected(end+1,:)={r.Module,r.Dataset,r.Condition,r.Repeat,r.Method}; %#ok<AGROW>
                save_fixture(window,r,sprintf('%d_%s',rep,method));
            end
        end
        writetable(cell2table(expected,'VariableNames',{'Module','Dataset','Condition','Repeat','Method'}), ...
            fullfile(window,'expected_manifest.csv'));
    end
    result=NB_SUMMARIZE(scopedRoot,stage);out=result.OutputDirectory;
    assert(result.CommittedRecords==8&&result.MissingRecords==0,'NB:SummaryTest','SYN/REAL window suffix discovery.');
    S=readtable(fullfile(out,'condition_summary.csv'),'TextType','string');
    q=S.Dataset=="SYN"&S.Method=="RA2DPCA_dev"&S.Metric=="NRE";
    assert(sum(q)==1&&S.NRecords(q)==2&&S.NFinite(q)==2&&abs(S.Mean(q)-.4)<1e-12, ...
        'NB:SummaryTest','Degenerate finite outputs must remain in raw condition means.');
    assert(S.NBaselineUsable(q)==1&&S.NBaselineUnusable(q)==1&&S.NBaselineUnknown(q)==0&&S.NZeroWeightDegenerate(q)==1, ...
        'NB:SummaryTest','Usable/unusable baseline counts must be explicit.');
    assert(S.NFiniteBaselineUsable(q)==1&&abs(S.BaselineUsableMean(q)-.2)<1e-12, ...
        'NB:SummaryTest','Usable-only summaries must exclude degenerate outputs.');
    q=S.Dataset=="SYN"&S.Method=="RA2DPCA_dev"&S.Metric=="RAFinalNonzeroFraction";
    assert(sum(q)==1&&abs(S.Mean(q)-.25)<1e-12,'NB:SummaryTest','RA weight diagnostics must be summarized.');
    q=S.Dataset=="SYN"&S.Method=="RA2DPCA_dev"&S.Metric=="RAFinalCovarianceRank";
    assert(sum(q)==1&&abs(S.Mean(q)-6)<1e-12&&S.NRankDeficient(q)==1, ...
        'NB:SummaryTest','Rank diagnostics and deficiency counts must remain visible.');
    q=S.Dataset=="COIL20"&S.Method=="RA2DPCA_dev"&S.Metric=="NRE";
    assert(sum(q)==1&&S.NBaselineUnusable(q)==1&&S.NSelectionDegenerate(q)==1&& ...
        S.NZeroWeightDegenerate(q)==0&&S.NRankDeficient(q)==0, ...
        'NB:SummaryTest','Selection degeneration must count even when final activation and rank are healthy.');
    P=readtable(fullfile(out,'paired_differences.csv'),'TextType','string');
    q=P.Dataset=="SYN"&P.Metric=="NRE"&P.Repeat==2;
    assert(sum(q)==1&&~P.PairValid(q)&&P.Reason(q)=="BASELINE_DEGENERATE"&& ...
        abs(P.Right(q)-.6)<1e-12&&abs(P.Difference(q)+.5)<1e-12, ...
        'NB:SummaryTest','Degenerate pair must retain raw outputs and be excluded from inference.');
    q=P.Dataset=="COIL20"&P.Metric=="NRE"&P.Repeat==2;
    assert(sum(q)==1&&~P.PairValid(q)&&P.Reason(q)=="BASELINE_DEGENERATE", ...
        'NB:SummaryTest','A degenerate selected development candidate must invalidate a healthy final fit.');
    PS=readtable(fullfile(out,'paired_statistics.csv'),'TextType','string');
    q=PS.Dataset=="SYN"&PS.Metric=="NRE";
    assert(sum(q)==1&&PS.NExpectedPairs(q)==2&&PS.NValidPairs(q)==1&&PS.NBaselineDegenerate(q)==1&& ...
        abs(PS.MeanDifference(q)+.1)<1e-12,'NB:SummaryTest','Invalid baseline pairs cannot affect paired means.');
    SC=readtable(fullfile(out,'status_counts.csv'),'TextType','string');
    q=SC.Dataset=="SYN"&SC.Status=="zero_weight_degenerate";
    assert(sum(q)==1&&SC.OutcomeClass(q)=="zero_weight_degenerate"&&SC.Count(q)==1, ...
        'NB:SummaryTest','Zero-weight degeneration must have an explicit outcome class.');
    q=SC.Dataset=="COIL20"&SC.Status=="relative_residual_stable";
    assert(sum(q)==1&&SC.OutcomeClass(q)=="development_selection_degenerate"&&SC.Count(q)==1, ...
        'NB:SummaryTest','Development degeneration must override final-fit stable status.');
    G=readtable(fullfile(out,'whole_grid_paired_statistics.csv'),'TextType','string');
    q=G.Metric=="NRE";
    assert(sum(q)==1&&G.CompleteRepeatBlocks(q)==1&&G.ExcludedRepeatBlocks(q)==1, ...
        'NB:SummaryTest','Degenerate RA pairs must invalidate the corresponding whole-grid block.');
end

function duplicate_checks(root,stage)
    duplicateRoot=fullfile(root,'duplicate_fixture');
    r=struct('Module','B_comparison','Stage',stage,'Dataset','SYN','Condition','duplicate', ...
        'Repeat',1,'Method','C3','CaseHash','same_case','InitHash','same_init','BaselineUsable',true);
    save_fixture(fullfile(duplicateRoot,stage,'windowA_SYN'),r,'one');
    save_fixture(fullfile(duplicateRoot,stage,'windowB_SYN'),r,'two');
    caught=false;
    try,NB_SUMMARIZE(duplicateRoot,stage);
    catch e,caught=strcmp(e.identifier,'NB:DuplicateCommittedKey');end
    assert(caught,'NB:SummaryTest','Duplicate committed keys must be fatal before aggregation.');
    out=fullfile(duplicateRoot,stage,'summary');
    assert(exist(fullfile(out,'duplicate_committed_keys.csv'),'file')==2&& ...
        exist(fullfile(out,'raw_fit_records.csv'),'file')==0, ...
        'NB:SummaryTest','Duplicate diagnostic must be emitted without aggregate summaries.');
end

function save_fixture(window,r,id)
    folder=fullfile(window,'fits',id);mkdir(folder);
    payload=struct('record',r);save(fullfile(folder,'fit.mat'),'payload','-v7');
end

function remove_tree(root)
    if exist(root,'dir'),rmdir(root,'s');end
end
