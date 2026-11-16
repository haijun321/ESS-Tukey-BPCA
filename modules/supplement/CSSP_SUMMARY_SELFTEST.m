function report=CSSP_SUMMARY_SELFTEST()
% Fixtures validate pairing/aggregation safeguards, without research datasets.
% This function must actually execute before its Pass field is evidence.
    folder=tempname;mkdir(folder);cleanup=onCleanup(@()remove_tree(folder));
    C=struct('outputRoot',folder,'realReps',1:2,'makePlots',false);
    conditions={'Clean','I10','I30','B10','B30'};items={};
    for rep=1:2
        for k=1:numel(conditions)
            condition=conditions{k};caseHash=sprintf('CASE_%s_%d',condition,rep);
            initialMethods={'INIT',.4,.70;'C1',.3,.71;'C3',.2,.72};
            for j=1:size(initialMethods,1)
                z=record('01_initialization',condition,rep,initialMethods{j,1},'B1', ...
                    initialMethods{j,2}+.001*rep,initialMethods{j,3},caseHash,'COMMON');
                if strcmp(z.Method,'C3')&&strcmp(condition,'Clean')&&rep==1,z.Status='failed_search';end
                items{end+1}=save_record(folder,z,[]); %#ok<AGROW>
            end
            methods={'C2',.3,.73;'C3',.2,.72;'C4',.25,.75;'C5',.4,.71};
            for j=1:size(methods,1)
                z=record('02_factorial',condition,rep,methods{j,1},'B1',methods{j,2}+.001*rep,methods{j,3},caseHash,'COMMON');
                if strcmp(condition,'I10')&&rep==2&&strcmp(z.Method,'C2'),z.CaseHash='WRONG_CASE';end
                items{end+1}=save_record(folder,z,[]); %#ok<AGROW>
            end
            z=record('03_external',condition,rep,'BA2DPCA','B1',.19+.001*rep,.71,caseHash,'NATIVE_EXTERNAL');
            items{end+1}=save_record(folder,z,[]); %#ok<AGROW>
            methods={'C1',.3,.71;'C2',.3,.73;'C3',.2,.72;'TunedC',.18,.74;'TunedEta',.19,.75};
            for j=1:size(methods,1)
                z=record('04_yale_selection',condition,rep,methods{j,1},'B1',methods{j,2}+.001*rep,methods{j,3},caseHash,'COMMON');
                selection=[];
                if strcmp(z.Method,'TunedC')
                    z.SelectedValue=2.5;
                    selection=struct('Value',{2.5,4.685},'ValidationNRE',{.21,.22},'Seconds',{1,1});
                end
                items{end+1}=save_record(folder,z,selection); %#ok<AGROW>
            end
        end
        for budget={'B1','B2'}
            value=.2;if strcmp(budget{1},'B2'),value=.19;end
            z=record('05_b10_budget','B10',rep,'C3',budget{1},value+.001*rep,.72,sprintf('CASE_B10_%d',rep),'COMMON');
            items{end+1}=save_record(folder,z,[]); %#ok<AGROW>
        end
    end
    write_manifests(folder,items);
    rootManifest=readtable(fullfile(folder,'paper','expected_manifest.csv'),'TextType','string');
    missing=rootManifest(1,:);missing.Module="03_external";missing.Method="ROMPCA";
    rootManifest=[rootManifest;missing];
    writetable(rootManifest,fullfile(folder,'paper','expected_manifest.csv'));
    Status="BLOCKED_MISSING_EXTERNAL";Task="ROMPCA";
    writetable(table(Task,Status),fullfile(folder,'paper','task_status.csv'));
    path=fullfile(folder,'paper','01_initialization','mechanism');mkdir(path);
    Dataset=repmat("YALE",4,1);Condition=repmat("Clean",4,1);Repeat=ones(4,1);
    Method=["C2";"C3";"C4";"C5"];ESSOperational=[.85;.96;.96;.85];
    R0Operational=[.1;.01;0;0];TargetEta=[.85;.96;.96;.85];Selected=ones(4,1);
    T=table(Dataset,Condition,Repeat,Method,ESSOperational,R0Operational,TargetEta,Selected);
    writetable(T,fullfile(path,'mechanism_candidates.csv'));
    a=CSSP_SUMMARIZE(C);b=CSSP_SUMMARIZE(C);
    assert(a.CommittedRecords==b.CommittedRecords&&a.MechanismRows==4&&b.MechanismRows==4, ...
        'CSSP:SummarySelftest','Repeat summary accumulated its own output.');
    assert(a.PlannedRows==numel(items)+1&&a.MissingPlannedRows==1&&a.ExecutionStatusRows==1, ...
        'CSSP:SummarySelftest','Root planned/blocked task was lost or module manifests were double counted.');
    out=fullfile(folder,'paper','summary');
    P=readtable(fullfile(out,'paired_differences.csv'),'TextType','string');
    hit=P.PairType=="InitializationIncrement"&P.LeftMethod=="C3"&P.Metric=="NRE";
    assert(sum(hit)==10&&all(P.PairValid(hit)==1)&&all(abs(P.Difference(hit)+.2)<1e-12), ...
        'CSSP:SummarySelftest','Incorrect initialization deltas.');
    hit=P.PairType=="ExternalComparison"&P.Metric=="NRE";
    assert(sum(hit)==10&&all(P.PairValid(hit)==1)&&all(P.InitMatched(hit)==0), ...
        'CSSP:SummarySelftest','External native initialization was incorrectly rejected.');
    hit=P.Module=="02_factorial"&P.Condition=="I10"&P.Repeat==2& ...
        P.LeftMethod=="C3"&P.RightMethod=="C2"&P.Metric=="NRE";
    assert(sum(hit)==1&&P.PairValid(hit)==0,'CSSP:SummarySelftest','Case mismatch entered a valid pair.');
    hit=P.PairType=="BudgetExpansion"&P.Metric=="NRE";
    assert(sum(hit)==2&&all(P.PairValid(hit)==1)&&all(abs(P.Difference(hit)+.01)<1e-12), ...
        'CSSP:SummarySelftest','Wrong budget difference sign.');
    I=readtable(fullfile(out,'factorial_interactions.csv'),'TextType','string');
    hit=I.Condition=="Clean"&I.Metric=="NRE";
    assert(sum(hit)==2&&all(I.PairValid(hit)==1)&&all(abs(I.Interaction(hit)-.05)<1e-12), ...
        'CSSP:SummarySelftest','Incorrect four-cell interaction.');
    O=readtable(fullfile(out,'overall_summary.csv'),'TextType','string');
    hit=O.Module=="01_initialization"&O.Method=="C3"&O.Metric=="NRE";
    assert(sum(hit)==1&&O.NCompleteRepeats(hit)==2&&abs(O.Mean(hit)-.2015)<1e-12, ...
        'CSSP:SummarySelftest','Overall aggregation is not repeat-first.');
    S=readtable(fullfile(out,'selection_candidates.csv'),'TextType','string');
    assert(all(S.SelectionLockedBeforeProbe==1),'CSSP:SummarySelftest','Selection lock metadata lost.');
    duplicate=fullfile(folder,'paper','duplicate','fits','copy');mkdir(duplicate);
    saved=struct('record',items{1});save(fullfile(duplicate,'fit.mat'),'saved');
    caught=false;
    try,CSSP_SUMMARIZE(C);catch e,caught=strcmp(e.identifier,'CSSP:SummaryDuplicates');end
    assert(caught,'CSSP:SummarySelftest','Duplicate committed keys were accepted.');
    report=struct('Pass',true,'Fixtures',numel(items),'MechanismRows',4, ...
        'Checks',{{'initialization_deltas','external_native_init','case_mismatch', ...
        'four_cell_interaction','budget_direction','repeat_first_overall','selection_lock', ...
        'idempotent_mechanism_collection','root_manifest_missing_and_blocked', ...
        'finite_failed_search_retained','duplicate_keys_blocked'}});
    clear cleanup;
end

function z=record(module,condition,rep,method,budget,nre,acc,caseHash,initHash)
    z=struct('Module',module,'Dataset','YALE','Condition',condition,'Repeat',rep,'Method',method, ...
        'Budget',budget,'Stage','paper','Scientific',true,'CaseHash',caseHash,'InitHash',initHash, ...
        'NRE',nre,'ACC',acc,'FeatureDimension',4,'BaselineUsable',true,'Status','budget_exhausted', ...
        'RuntimeSeconds',1,'SelectedValue',NaN);
end

function r=save_record(root,r,selection)
    id=sprintf('%s_%s_r%03d_%s_%s',r.Dataset,r.Condition,r.Repeat,r.Method,r.Budget);
    path=fullfile(root,'paper',r.Module,'fits',id);mkdir(path);
    saved=struct('record',r,'selection',selection,'selectionLockedBeforeProbe',true);
    save(fullfile(path,'fit.mat'),'saved');
end

function write_manifests(root,items)
    modules=unique(cellfun(@(r)r.Module,items,'UniformOutput',false),'stable');
    for k=1:numel(modules)
        pick=cellfun(@(r)strcmp(r.Module,modules{k}),items);q=items(pick);rows=cell(numel(q),6);
        for j=1:numel(q),r=q{j};rows(j,:)={r.Module,r.Dataset,r.Condition,r.Repeat,r.Method,r.Budget};end
        T=cell2table(rows,'VariableNames',{'Module','Dataset','Condition','Repeat','Method','Budget'});
        writetable(T,fullfile(root,'paper',modules{k},'expected_manifest.csv'));
    end
    rows=cell(numel(items),6);
    for j=1:numel(items),r=items{j};rows(j,:)={r.Module,r.Dataset,r.Condition,r.Repeat,r.Method,r.Budget};end
    T=cell2table(rows,'VariableNames',{'Module','Dataset','Condition','Repeat','Method','Budget'});
    writetable(T,fullfile(root,'paper','expected_manifest.csv'));
end

function remove_tree(folder)
    if exist(folder,'dir'),rmdir(folder,'s');end
end
