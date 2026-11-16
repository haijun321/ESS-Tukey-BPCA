function P0_SUMMARIZE(C,module,R,context)
% Completeness is reported explicitly. Primary inference requires ALL planned fits.
    d=fullfile(C.outputRoot,module);p=P0_IO('load',fullfile(d,'protocol.mat'));
    if nargin<4,context=p.protocol.context;end
    if nargin<3
        f=dir(fullfile(d,'fits','*','fit.mat'));R=repmat(struct(),0,1);
        for k=1:numel(f)
            z=P0_IO('load',fullfile(f(k).folder,f(k).name));
            assert(strcmp(z.metadata.protocolHash,p.hash),'P0:SummaryProtocol','Fit is from a different protocol.');
            if isempty(R),R=z.record;else,R(end+1)=z.record;end %#ok<AGROW>
        end
    end
    R=R(:);out=fullfile(d,'summary');P0_IO('mkdir',out);
    if isfield(context,'expectedFits'),expected=context.expectedFits;unit='fits';
    else,expected=context.expectedRecords;unit=context.recordUnit;end
    complete=numel(R)==expected;
    P0_IO('csv',fullfile(out,'completion.csv'), ...
        {'Module','RecordUnit','ExpectedRecords','CompletedRecords','MissingRecords','Complete','Scientific'}, ...
        {module,unit,expected,numel(R),max(0,expected-numel(R)),complete,context.scientific});
    if isempty(R),fprintf('No committed records for %s.\n',module);return;end
    id=cell(numel(R),1);for k=1:numel(R),id{k}=record_key(R(k));end
    assert(numel(unique(id))==numel(id),'P0:Duplicates','Duplicate method-case records.');
    assert(numel(R)<=expected,'P0:UnexpectedRecords','Unexpected extra records.');
    h=fieldnames(R)';raw=cell(numel(R),numel(h));
    for k=1:numel(R),raw(k,:)=struct2cell(R(k))';end
    P0_IO('csv',fullfile(out,'fit_records.csv'),h,raw);
    revised=R(strcmp({R.SolverVersion},'v2'));stable=revised(strcmp({revised.Status},'numerically_stable'));
    uncertified=0;
    if ~isempty(stable)
        uncertified=sum(~isfinite([stable.FinalRecomputedGradRelative]) ...
            |[stable.FinalRecomputedGradRelative]>[stable.GradientTolerance]*(1+1e-8));
    end
    trials=sum([revised.ConditionalChecks]);bad=sum([revised.ConditionalViolations]);qbad=sum([revised.AcceptedQViolations]);
    P0_IO('csv',fullfile(out,'numerical_checks.csv'), ...
        {'RevisedRecords','ApplicableTrialChecks','MajorizerViolations','AcceptedQViolations','UnverifiedStableLabels','NoRecordedNumericalViolations'}, ...
        {numel(revised),trials,bad,qbad,uncertified,~isempty(revised)&&bad==0&&qbad==0&&uncertified==0});
    groups=cell(numel(R),1);
    for k=1:numel(R),x=R(k);groups{k}=sprintf('%s|%s|%s|%s|%d',x.Dataset,x.Condition,x.MethodID,x.SolverVersion,x.BudgetMultiplier);end
    g=unique(groups);means=cell(0,10);stops=cell(0,8);
    fields={'NRE','ErrSubNorm','ACC','ElementROC','ElementAP','TPR0','FPR0','Precision0','ZeroExact','ESS', ...
        'ESSCombined','WeightClean','WeightCorrupt','SolverSeconds','FinalRecomputedGradRelative','AcceptedSteps','GradientAcceptedSteps'};
    for k=1:numel(g)
        ix=find(strcmp(groups,g{k}));x=R(ix(1));
        for j=1:numel(fields)
            v=[R(ix).(fields{j})];ok=isfinite(v);
            if any(ok),mu=mean(v(ok));sd=std(v(ok));else,mu=NaN;sd=NaN;end
            means(end+1,:)={x.Dataset,x.Condition,x.MethodID,x.SolverVersion,x.BudgetMultiplier,fields{j},numel(ix),sum(ok),mu,sd}; %#ok<AGROW>
        end
        labels=unique({R(ix).Status});
        for j=1:numel(labels)
            stops(end+1,:)={x.Dataset,x.Condition,x.MethodID,x.SolverVersion,x.BudgetMultiplier,labels{j},sum(strcmp({R(ix).Status},labels{j})),numel(ix)}; %#ok<AGROW>
        end
    end
    P0_IO('csv',fullfile(out,'condition_summary.csv'), ...
        {'Dataset','Condition','MethodID','Version','Budget','Metric','NRecords','NDefined','Mean','SD'},means);
    P0_IO('csv',fullfile(out,'stop_summary.csv'), ...
        {'Dataset','Condition','MethodID','Version','Budget','Status','Count','Denominator'},stops);
    pairs=contrasts(module,R,C);dataset=unique({R.Dataset});paired=cell(0,23);details=cell(0,12);
    metrics={'NRE','ErrSubNorm'};
    if strcmp(context.regime,'real'),metrics={'NRE'};end
    counter=0;
    for ds=1:numel(dataset)
        data=R(strcmp({R.Dataset},dataset{ds}));conds=expected_conditions(context);
        views=[{'GridMean'} cellfun(@(s)['Condition:' s],conds,'UniformOutput',false)];
        if strcmp(context.regime,'synthetic')
            views=[views {'PositiveRateGrid','CleanZeroRateGrid','WithoutDominantCondition'}];
        end
        for a=1:numel(pairs)
            pdef=pairs(a);
            for v=1:numel(views)
                vc=select_conditions(conds,views{v},data);
                if isempty(vc),continue;end
                for mm=1:numel(metrics)
                    metric=metrics{mm};diffs=nan(numel(C.repeats),numel(vc));nFound=0;
                    for ri=1:numel(C.repeats)
                        rep=C.repeats(ri);
                        for ci=1:numel(vc)
                            l=find_match(data,pdef.left,pdef.lv,pdef.lb,rep,vc{ci});
                            r=find_match(data,pdef.right,pdef.rv,pdef.rb,rep,vc{ci});
                            if isempty(l)||isempty(r),continue;end
                            L=data(l);T=data(r);
                            assert(strcmp(L.CaseHash,T.CaseHash),'P0:PairedCase','Paired inputs differ.');
                            if pdef.requireInit,assert(strcmp(L.InitHash,T.InitHash),'P0:PairedInit','Paired initialization differs.');end
                            z=L.(metric)-T.(metric);assert(isfinite(z),'P0:PairFinite','Nonfinite primary paired metric.');
                            diffs(ri,ci)=z;nFound=nFound+1;
                            if strcmp(views{v},'GridMean')
                                details(end+1,:)={dataset{ds},vc{ci},rep,pdef.left,pdef.right,pdef.lv,pdef.rv,pdef.lb,pdef.rb,metric,z,L.CaseHash}; %#ok<AGROW>
                            end
                        end
                    end
                    needed=numel(C.repeats)*numel(vc);pairComplete=nFound==needed;
                    counter=counter+1;
                    if pairComplete
                        block=mean(diffs,2);valid=diffs(:);
                        allowTest=context.scientific&&strcmp(context.regime,'synthetic')&&complete ...
                            &&strcmp(views{v},'GridMean');
                        st=P0_STATS(block,C,C.statisticsSeed+counter,allowTest);
                        mu=st.Mean;sd=st.SD;lo=st.Low;hi=st.High;pval=st.P;
                    else
                        valid=diffs(isfinite(diffs));block=[];mu=NaN;sd=NaN;lo=NaN;hi=NaN;pval=NaN;
                    end
                    scope='synthetic_repeat_blocks';
                    if strcmp(context.regime,'real'),scope='descriptive_repeated_splits';end
                    if ~context.scientific,scope='engineering_smoke_only';end
                    paired(end+1,:)={dataset{ds},views{v},pdef.left,pdef.right,pdef.lv,pdef.rv, ...
                        pdef.lb,pdef.rb,metric,nFound,needed,numel(block),pairComplete,mu,sd,lo,hi, ...
                        sum(valid<-C.tieTolerance),sum(abs(valid)<=C.tieTolerance),sum(valid>C.tieTolerance),pval,NaN,scope}; %#ok<AGROW>
                end
            end
        end
    end
    % Holm families: each dataset/module's prespecified GridMean contrasts/metrics.
    if ~isempty(paired)
        for ds=1:numel(dataset)
            ix=find(strcmp(paired(:,1),dataset{ds})&strcmp(paired(:,2),'GridMean'));
            q=P0_HOLM(cell2mat(paired(ix,21)));
            for j=1:numel(ix),paired{ix(j),22}=q(j);end
        end
    end
    P0_IO('csv',fullfile(out,'paired_statistics.csv'), ...
        {'Dataset','View','LeftMethod','RightMethod','LeftVersion','RightVersion','LeftBudget','RightBudget', ...
        'Metric','PairCount','ExpectedPairs','RepeatBlocks','Complete','MeanDifference','SDRepeatBlocks', ...
        'CI95Low','CI95High','WinsLeft','Ties','LossesLeft','PValueSignFlip','HolmP','InferenceScope'},paired);
    P0_IO('csv',fullfile(out,'paired_case_differences.csv'), ...
        {'Dataset','Condition','Repeat','LeftMethod','RightMethod','LeftVersion','RightVersion','LeftBudget','RightBudget','Metric','Difference','CaseHash'},details);
    if C.makePlots
        try,P0_PLOTS(C,module,R);
        catch ex,warning('P0:Plot','Fits and tables saved; plot failed: %s',ex.message);end
    end
    fprintf('SUMMARY %s: %d/%d %s committed. Complete=%d\n',module,numel(R),expected,unit,complete);
end

function s=record_key(x)
    s=sprintf('%s|%s|%d|%s|%s|%d',x.Dataset,x.Condition,x.Repeat,x.MethodID,x.SolverVersion,x.BudgetMultiplier);
end
function c=expected_conditions(context)
    if isfield(context,'cases'),c={context.cases.Condition};else,c=context.conditions;end
end
function vc=select_conditions(conds,view,data)
    if strncmp(view,'Condition:',10),vc={view(11:end)};return;end
    vc=conds;
    if strcmp(view,'WithoutDominantCondition'),vc=conds(~strcmp(conds,'block_coherent_k4_p010'));return;end
    if strcmp(view,'PositiveRateGrid')||strcmp(view,'CleanZeroRateGrid')
        keep=false(size(conds));
        for k=1:numel(conds)
            token=regexp(conds{k},'_p([0-9]+)$','tokens','once');
            assert(~isempty(token),'P0:ConditionRate','Synthetic condition rate suffix missing.');
            positive=str2double(token{1})>0;
            if strcmp(view,'PositiveRateGrid'),keep(k)=positive;else,keep(k)=~positive;end
        end
        vc=conds(keep);
    end
end
function ix=find_match(R,id,ver,budget,rep,condition)
    ix=find(strcmp({R.MethodID},id)&strcmp({R.SolverVersion},ver)&[R.BudgetMultiplier]==budget ...
        &[R.Repeat]==rep&strcmp({R.Condition},condition));
    assert(numel(ix)<=1,'P0:PairDuplicate','Ambiguous paired record.');
end
function p=contrasts(module,R,C)
    b=struct('left','','right','','lv','v2','rv','v2','lb',1,'rb',1,'requireInit',true);p=repmat(b,0,1);
    if ~isempty(strfind(module,'solver')) %#ok<STREMP>
        ids=unique({R.MethodID});
        for k=1:numel(ids),x=b;x.left=ids{k};x.right=ids{k};x.rv='legacy';p(end+1)=x;end %#ok<AGROW>
    elseif ~isempty(strfind(module,'budget')) %#ok<STREMP>
        ids=unique({R.MethodID});
        for k=1:numel(ids)
            for j=1:numel(C.budgetMultipliers)
                if C.budgetMultipliers(j)==1,continue;end
                x=b;x.left=ids{k};x.right=ids{k};x.lb=C.budgetMultipliers(j);p(end+1)=x; %#ok<AGROW>
            end
        end
    else
        if any(strcmp(module,{'core_synthetic','core_real','smoke_core','pilot_real'}))
            defs={'C2','C1';'C3','C2';'C3','C4'};
            if C.includeFixedEtaNoZero,defs=[defs;{'C5','C1';'C2','C5'}];end
        elseif any(strcmp(module,{'main_synthetic','main_real'}))
            defs={'Auto','L2';'Auto','Huber';'Auto','Welsch';'Auto','FixedTukey';'Auto','FixedEta'};
        elseif strcmp(module,'extension_real'),defs={'R5','C3';'R6','R5';'R5','R7'};
        elseif strcmp(module,'tune_real'),defs={'Auto','SelectedEta';'Auto','SelectedC';'Auto','Eta085';'Auto','FixedC4685'};
        else,defs=cell(0,2);end
        for k=1:size(defs,1)
            x=b;x.left=defs{k,1};x.right=defs{k,2};x.requireInit=~strcmp(x.right,'L2');p(end+1)=x; %#ok<AGROW>
        end
    end
end
