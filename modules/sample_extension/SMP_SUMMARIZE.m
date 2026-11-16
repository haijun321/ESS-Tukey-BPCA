function SMP_SUMMARIZE(C,phase)
%SMP_SUMMARIZE Summarize paired seed-level sample-extension experiments.
% No Statistics and Machine Learning Toolbox is required. Time-capped and
% budget-limited finite fits remain outcomes; runtime failures remain visible.
    phase=char(string(phase));
    assert(ismember(phase,{'precheck','formal'}),'SMP:Phase','Unknown phase.');
    base=fullfile(C.outputRoot,phase);
    out=fullfile(base,'summary');
    if ~exist(out,'dir'),mkdir(out);end
    if strcmp(phase,'formal'),reps=C.formalRepeats(:)';
    else,reps=C.precheckRepeats(:)';end
    conditions={'Clean','CellOnly','CaseOnly','Mixed'};
    methods={'E','ES'};
    file=fullfile(base,'fit_records.csv');
    if ~exist(file,'file')
        warning('SMP:NoRecords','No fit_records.csv yet: %s',file);return;
    end
    F=readtable(file,'TextType','string','VariableNamingRule','preserve');
    required={'Repeat','Condition','Method','Status','ErrSubNorm', ...
        'ProbeCleanNRE','CaseHash','InitHash'};
    assert(all(ismember(required,F.Properties.VariableNames)), ...
        'SMP:SummaryColumns','Fit table lacks required summary columns.');
    F.Repeat=numcol(F,'Repeat');
    F.Condition=string(F.Condition);F.Method=string(F.Method);
    F.Status=string(F.Status);
    if ismember('Phase',F.Properties.VariableNames)
        assert(all(string(F.Phase)==string(phase)), ...
            'SMP:MixedPhase','Records from different phases must not be pooled.');
    end
    assert(all(ismember(F.Condition,string(conditions))) && ...
        all(ismember(F.Method,string(methods))) && all(ismember(F.Repeat,reps)), ...
        'SMP:UnplannedRecords','Unplanned condition, method, or repetition in records.');
    key=F.Condition+"|"+string(F.Repeat)+"|"+F.Method;
    assert(numel(unique(key))==height(F),'SMP:DuplicateRecords', ...
        'Duplicate fit identifiers in fit_records.csv; resolve before summarizing.');
    I=table();if exist(fullfile(base,'initialization_records.csv'),'file')
        I=readtable(fullfile(base,'initialization_records.csv'),'TextType','string', ...
            'VariableNamingRule','preserve');
        if ~isempty(I)
            I.Repeat=numcol(I,'Repeat');I.Condition=string(I.Condition);
            ik=I.Condition+"|"+string(I.Repeat);
            assert(numel(unique(ik))==height(I),'SMP:DuplicateInit', ...
                'Duplicate initialization records.');
        end
    end
    metrics={'ErrSubNorm','ProbeCleanNRE','TrainNRE','NonCaseNRE', ...
        'SampleESS','CaseMeanA','NonCaseMeanA','NonCaseDownweight95', ...
        'TimeSeconds','OuterIters','AcceptedSteps','FinalGrad'};
    oldRng=rng;cleanup=onCleanup(@()rng(oldRng)); %#ok<NASGU>
    rng(C.statsSeed+1000*strcmp(phase,'formal'),'twister');
    if isfield(C,'tieTolerance'),tol=C.tieTolerance;else,tol=1e-10;end
    rows=struct([]);completion=struct([]);
    for ic=1:numel(conditions)
        for im=1:numel(methods)
            X=F(F.Condition==string(conditions{ic}) & F.Method==string(methods{im}),:);
            ok=fit_ok(X);
            q=struct('Phase',string(phase),'Condition',string(conditions{ic}), ...
                'Method',string(methods{im}),'PlannedFits',numel(reps), ...
                'ObservedFits',height(X),'CompleteFits',sum(ok), ...
                'FailedFits',sum(~ok),'MissingFits',numel(reps)-height(X));
            completion=append(completion,q);
            for k=1:numel(metrics)
                a=numcol(X,metrics{k});a(~ok)=NaN;
                [av,sd,n]=describe(a);
                q.([metrics{k} 'Mean'])=av;q.([metrics{k} 'SD'])=sd;
                q.([metrics{k} 'N'])=n;
            end
            rows=append(rows,q);
        end
    end
    CT=struct2table(rows);CP=struct2table(completion);
    writetable(CT,fullfile(out,'condition_summary.csv'));
    writetable(CP,fullfile(out,'completion.csv'));
    write_stops(F,out,phase);

    % Differences retain a row for every planned pair, including missing pairs.
    pairMetrics={'ErrSubNorm','ProbeCleanNRE','TrainNRE','NonCaseNRE', ...
        'SampleESS','TimeSeconds'};
    D=struct([]);
    for ic=1:numel(conditions)
        cond=conditions{ic};
        for rep=reps
            e=F(F.Condition==string(cond)&F.Repeat==rep&F.Method=="E",:);
            es=F(F.Condition==string(cond)&F.Repeat==rep&F.Method=="ES",:);
            init=table();
            if ~isempty(I),init=I(I.Condition==string(cond)&I.Repeat==rep,:);end
            for k=1:numel(pairMetrics)
                D=append(D,pair_row(phase,cond,rep,'ES_minus_E',pairMetrics{k},es,e,false));
            end
            for k=1:2
                D=append(D,pair_row(phase,cond,rep,'E_minus_INIT',pairMetrics{k},e,init,true));
                D=append(D,pair_row(phase,cond,rep,'ES_minus_INIT',pairMetrics{k},es,init,true));
            end
        end
    end
    DT=struct2table(D);writetable(DT,fullfile(out,'paired_differences.csv'));
    P=struct([]);contrasts={'ES_minus_E','E_minus_INIT','ES_minus_INIT'};
    for ic=1:numel(conditions)
        for iz=1:numel(contrasts)
            if iz==1,mset=pairMetrics;else,mset=pairMetrics(1:2);end
            for k=1:numel(mset)
                ix=DT.Condition==string(conditions{ic}) & ...
                    DT.Contrast==string(contrasts{iz}) & DT.Metric==string(mset{k});
                z=DT(ix,:);v=z.Difference(z.CompletePair);
                [av,sd,n]=describe(v);
                [lo,hi]=bootstrap_mean(v,C.bootstrapResamples);
                p=struct('Phase',string(phase),'Condition',string(conditions{ic}), ...
                    'Contrast',string(contrasts{iz}),'Metric',string(mset{k}), ...
                    'PrimaryComparison',iz==1 && strcmp(mset{k},'ErrSubNorm') && ...
                        ismember(conditions{ic},{'CaseOnly','Mixed'}), ...
                    'PlannedPairs',numel(reps),'CompletePairs',n, ...
                    'MissingOrInvalidPairs',numel(reps)-n, ...
                    'MeanDifference',av,'SDDifference',sd,'CI95Low',lo,'CI95High',hi, ...
                    'LowerCount',sum(v < -tol),'TieCount',sum(abs(v)<=tol), ...
                    'HigherCount',sum(v > tol),'AllPairsComplete',n==numel(reps), ...
                    'InferenceUnit',"independent_seed_block", ...
                    'Interpretation',"negative means left metric is lower; not all metrics are benefits");
                P=append(P,p);
            end
        end
    end
    PT=struct2table(P);writetable(PT,fullfile(out,'paired_summary.csv'));
    write_main_tex(CT,PT,out,numel(reps),phase);
    if strcmp(phase,'formal')&&isfield(C,'makePlots')&&C.makePlots
        try,make_plot(F,DT,conditions,out);
        catch ME,warning('SMP:Plot','CSV summaries saved; figure failed: %s',ME.message);end
    end
    fid=fopen(fullfile(out,'INTERPRETATION.txt'),'w');
    if fid>=0
        cl=onCleanup(@()fclose(fid)); %#ok<NASGU>
        fprintf(fid,['This is a paired descriptive analysis of %d planned independent seed blocks per condition.\n' ...
            'CaseOnly and Mixed ErrSubNorm ES-minus-E contrasts are the prespecified primary comparisons.\n' ...
            'Clean and CellOnly characterize possible costs to normal observations.\n' ...
            'Negative error differences favor the left method; lower sample ESS alone is not evidence of benefit.\n' ...
            'Budget-limited and time-capped finite outputs remain observations, not convergence certificates.\n' ...
            'Runtime failures and missing fits are counted; incomplete-pair estimates are conditional on available pairs and must not be called complete results.\n' ...
            'Bootstrap intervals use paired seed differences, not pixels, training matrices or probe matrices.\n' ...
            'No p-values or success/acceptance claims are produced.\n' ...
            'Precheck outputs are computational checks only and must not be pooled with formal outcomes.\n'],numel(reps));
    end
    fprintf('SUMMARY %s: %d/%d finite endpoint fits, %d failed, %d missing.\n', ...
        phase,sum(CP.CompleteFits),sum(CP.PlannedFits),sum(CP.FailedFits),sum(CP.MissingFits));
end

function R=append(R,q)
    if isempty(R),R=q;else,R(end+1)=q;end
end

function x=numcol(T,name)
    if ~ismember(name,T.Properties.VariableNames),x=nan(height(T),1);return;end
    x=T.(name);if isnumeric(x)||islogical(x),x=double(x);else,x=str2double(string(x));end
    x=x(:);
end

function ok=fit_ok(T)
    ok=isfinite(numcol(T,'ErrSubNorm')) & isfinite(numcol(T,'ProbeCleanNRE'));
    if ismember('FailureMessage',T.Properties.VariableNames)
        raw=T.FailureMessage;x=string(raw);x(ismissing(raw)|ismissing(x))="";
        ok=ok & strlength(strtrim(x))==0;
    end
    if ismember('Status',T.Properties.VariableNames)
        st=lower(string(T.Status));
        ok=ok & ~ismember(st,["error","exception","runtime_error","failed"]);
    end
end

function q=pair_row(phase,cond,rep,contrast,metric,L,R,isInit)
    q=struct('Phase',string(phase),'Condition',string(cond),'Repeat',rep, ...
        'Contrast',string(contrast),'Metric',string(metric),'Difference',NaN, ...
        'CompletePair',false,'HashValidation',"missing_record", ...
        'LeftStatus',"missing",'RightStatus',"missing");
    if ~isempty(L)&&ismember('Status',L.Properties.VariableNames),q.LeftStatus=string(L.Status(1));end
    if isInit&&~isempty(R),q.RightStatus="initialization_readout";
    elseif ~isempty(R)&&ismember('Status',R.Properties.VariableNames),q.RightStatus=string(R.Status(1));end
    if isempty(L)||isempty(R),return;end
    assert(height(L)==1&&height(R)==1,'SMP:PairRows','Ambiguous paired records.');
    lv=numcol(L,metric);rv=numcol(R,metric);
    valid=fit_ok(L)&&isfinite(lv)&&isfinite(rv);
    if ~isInit,valid=valid&&fit_ok(R);end
    if ~valid,q.HashValidation="invalid_endpoint";return;end
    h={'CaseHash','InitHash'};allPresent=true;match=true;
    for k=1:2
        if ~ismember(h{k},R.Properties.VariableNames)||~ismember(h{k},L.Properties.VariableNames)
            allPresent=false;continue;
        end
        a=string(L.(h{k})(1));b=string(R.(h{k})(1));
        if ismissing(a)||ismissing(b)||strlength(a)==0||strlength(b)==0
            allPresent=false;
        else,match=match&&a==b;end
    end
    if ~match,q.HashValidation="hash_mismatch";return;end
    if allPresent,q.HashValidation="case_and_initialization_hash_match";
    elseif isInit,q.HashValidation="index_only_initialization_metadata_missing";
    else,q.HashValidation="missing_hash";return;end
    q.CompletePair=true;q.Difference=lv-rv;
end

function [m,s,n]=describe(x)
    x=x(isfinite(x));n=numel(x);m=NaN;s=NaN;
    if n>0,m=mean(x);end
    if n>1,s=std(x,0);end
end

function [lo,hi]=bootstrap_mean(x,B)
    x=x(isfinite(x));lo=NaN;hi=NaN;n=numel(x);
    if n<2,return;end
    b=mean(reshape(x(randi(n,n,B)),n,B),1);
    b=sort(b);lo=percentile_sorted(b,.025);hi=percentile_sorted(b,.975);
end

function y=percentile_sorted(x,p)
    n=numel(x);t=1+(n-1)*p;i=floor(t);j=ceil(t);
    y=x(i)+(t-i)*(x(j)-x(i));
end

function write_stops(F,out,phase)
    X=struct([]);conds=unique(F.Condition,'stable');methods=unique(F.Method,'stable');
    for ic=1:numel(conds)
        for im=1:numel(methods)
            T=F(F.Condition==conds(ic)&F.Method==methods(im),:);
            st=unique(T.Status,'stable');
            for k=1:numel(st)
                q=struct('Phase',string(phase),'Condition',conds(ic), ...
                    'Method',methods(im),'Status',st(k),'Count',sum(T.Status==st(k)));
                X=append(X,q);
            end
        end
    end
    if ~isempty(X),writetable(struct2table(X),fullfile(out,'stopping_summary.csv'));end
end

function write_main_tex(C,P,out,planned,phase)
    file=fullfile(out,'main_results.tex');fid=fopen(file,'w');
    assert(fid>=0,'SMP:Write','Cannot write %s',file);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%% Generated from phase %s. Values are not claims of convergence.\n',phase);
    fprintf(fid,'\\begin{table}[tbp]\\centering\\small\n');
    fprintf(fid,'\\caption{Incremental effect of the sample layer over %d paired repetitions per condition.}\n',planned);
    fprintf(fid,'\\resizebox{\\linewidth}{!}{\\begin{tabular}{llrrrrr}\\hline\n');
    fprintf(fid,'Condition & Metric & E & E+S & Mean $\\Delta$ & 95\\%% CI & Pairs\\\\\\hline\n');
    conditions={'Clean','CellOnly','CaseOnly','Mixed'};metrics={'ErrSubNorm','ProbeCleanNRE'};
    labels={'$E_{\\mathrm{sub}}$','Clean-probe NRE'};
    for ic=1:4
        for k=1:2
            e=C(C.Condition==string(conditions{ic})&C.Method=="E",:);
            es=C(C.Condition==string(conditions{ic})&C.Method=="ES",:);
            p=P(P.Condition==string(conditions{ic})&P.Contrast=="ES_minus_E"&P.Metric==string(metrics{k}),:);
            ef=mean_sd(e.([metrics{k} 'Mean']),e.([metrics{k} 'SD']));
            sf=mean_sd(es.([metrics{k} 'Mean']),es.([metrics{k} 'SD']));
            d=tex_number(p.MeanDifference);ci='--';
            if isfinite(p.CI95Low)&&isfinite(p.CI95High)
                ci=sprintf('[%.6f, %.6f]',p.CI95Low,p.CI95High);
            end
            fprintf(fid,'%s & %s & %s & %s & %s & %s & %d/%d\\\\\n', ...
                tex_escape(conditions{ic}),labels{k},ef,sf,d,ci,p.CompletePairs,planned);
        end
    end
    fprintf(fid,'\\hline\\end{tabular}}\n');
    fprintf(fid,['\\par\\smallskip\\begin{minipage}{0.98\\linewidth}\\footnotesize\n' ...
        '$\\Delta$ denotes E+S minus E; negative error differences favor E+S. ' ...
        'Intervals summarize paired seed differences. Missing or invalid fits remain in the accounting; ' ...
        'a smaller pair count marks incomplete evidence.\\end{minipage}\n\\end{table}\n']);
end

function s=mean_sd(m,d)
    if ~isfinite(m),s='--';elseif ~isfinite(d),s=sprintf('%.6f',m);
    else,s=sprintf('$%.6f\\pm%.6f$',m,d);end
end

function s=tex_number(x)
    if isfinite(x),s=sprintf('%.6f',x);else,s='--';end
end

function s=tex_escape(s)
    s=char(string(s));s=strrep(s,'_','\_');s=strrep(s,'&','\&');s=strrep(s,'%','\%');
end

function make_plot(F,D,conditions,out)
    fig=figure('Visible','off','Color','w','Position',[80 80 1150 760]);
    clean=onCleanup(@()close(fig)); %#ok<NASGU>
    names={'Clean','Cell only','Case only','Mixed'};
    metrics={'ErrSubNorm','ProbeCleanNRE'};
    titles={'Paired subspace-error difference','Paired clean-probe difference'};
    for k=1:2
        subplot(2,2,k);hold on;
        plot([.5 4.5],[0 0],'k:','HandleVisibility','off');
        for ic=1:4
            ix=D.Condition==string(conditions{ic})&D.Contrast=="ES_minus_E"& ...
                D.Metric==string(metrics{k})&D.CompletePair;
            v=D.Difference(ix);n=numel(v);
            if n>0
                if n==1,x=ic;else,x=ic+linspace(-.12,.12,n)';end
                plot(x,v,'o','Color',[.25 .45 .70],'MarkerSize',5);
                plot(ic+[-.18 .18],[mean(v) mean(v)],'k-','LineWidth',1.8);
            end
        end
        set(gca,'XTick',1:4,'XTickLabel',names);xlim([.5 4.5]);grid on;
        ylabel('E+S minus E (negative is lower)');title(titles{k});
    end
    subplot(2,2,3);hold on;
    colors=[.25 .45 .70;.80 .35 .18];methods={'E','ES'};
    for im=1:2
        for ic=1:4
            ix=F.Condition==string(conditions{ic})&F.Method==string(methods{im})&fit_ok(F);
            v=numcol(F(ix,:),'SampleESS');v=v(isfinite(v));n=numel(v);
            x=ic+(im-1.5)*.25;
            if n>0
                if n==1,j=0;else,j=linspace(-.05,.05,n)';end
                plot(x+j,v,'.','Color',colors(im,:),'MarkerSize',10);
                plot(x+[-.07 .07],[mean(v) mean(v)],'-','Color',colors(im,:),'LineWidth',2);
            end
        end
    end
    set(gca,'XTick',1:4,'XTickLabel',names);xlim([.5 4.5]);grid on;
    title('Actual sample-coefficient ESS');ylabel('Normalized sample ESS');
    h1=plot(NaN,NaN,'.','Color',colors(1,:),'MarkerSize',14);
    h2=plot(NaN,NaN,'.','Color',colors(2,:),'MarkerSize',14);legend([h1 h2],{'E','E+S'},'Location','best');
    subplot(2,2,4);hold on;
    flds={'CaseMeanA','NonCaseMeanA'};labels={'Case-contaminated','Non-case'};
    for g=1:2
        for ic=1:4
            ix=F.Condition==string(conditions{ic})&F.Method=="ES"&fit_ok(F);
            v=numcol(F(ix,:),flds{g});v=v(isfinite(v));n=numel(v);
            x=ic+(g-1.5)*.25;
            if n>0
                if n==1,j=0;else,j=linspace(-.05,.05,n)';end
                plot(x+j,v,'o','Color',colors(g,:),'MarkerSize',4);
                plot(x+[-.07 .07],[mean(v) mean(v)],'-','Color',colors(g,:),'LineWidth',2);
            end
        end
    end
    set(gca,'XTick',1:4,'XTickLabel',names);xlim([.5 4.5]);grid on;
    ylabel('Mean actual sample coefficient');title('E+S weight allocation by case label');
    h1=plot(NaN,NaN,'o','Color',colors(1,:));h2=plot(NaN,NaN,'o','Color',colors(2,:));
    legend([h1 h2],labels,'Location','best');
    exportgraphics(fig,fullfile(out,'sample_extension_diagnostics.png'),'Resolution',180);
    savefig(fig,fullfile(out,'sample_extension_diagnostics.fig'));
end
