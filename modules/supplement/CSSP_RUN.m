function report=CSSP_RUN(stage,options)
% Complete runner for the five agreed experiments. All probe readout is post-fit.
if nargin<1,stage='paper';end
if nargin<2,options=struct();end
C=CSSP_SETUP(stage,options);[C.sourceHash,sources]=CSSP_SOURCE('all',C);
C.coreHash=CSSP_SOURCE('core',C);jobs=CSSP_JOBS(C);
folder=fullfile(C.outputRoot,C.stage);P0_IO('mkdir',folder);
manifest=struct2table(rmfield(jobs,'Case'),'AsArray',true);
writetable(manifest,fullfile(folder,'expected_manifest.csv'));
fprintf('\nCSSP five-experiment supplement | %s | %d evaluation records\n',C.stage,numel(jobs));
fprintf('Archive: %s\nOutput: %s\n',C.archiveRoot,C.outputRoot);
dep=NB_PREFLIGHT(C,jobs,'deep');
writetable(struct2table(dep.Rows,'AsArray',true),fullfile(folder,'data_readiness.csv'));
externalChecks=struct();
for k=1:numel(C.externalMethods)
    name=C.externalMethods{k};if strcmp(name,'L2'),continue;end
    externalChecks.(name)=CSSP_EXTERNAL_CHECK(name,C);
end
if ~isempty(fieldnames(externalChecks))
    P0_IO('write',fullfile(folder,'external_readiness.json'),jsonencode(externalChecks));
end
report=struct('Stage',C.stage,'PlannedRecords',numel(jobs),'CommittedRecords',0, ...
    'ReusedRecords',0,'NativeNewFits',0,'NativeCacheHits',0,'BlockedRecords',0, ...
    'FailedRecords',0,'AllPlannedCommitted',false,'NumericalSelfTestsPassed',false, ...
    'ReadyForScientificReview',false,'Status','PLANNED');
if strcmp(C.stage,'plan')
    report.Status='PLAN_ONLY_NO_FITS';P0_IO('write',fullfile(folder,'run_status.json'),jsonencode(report));
    disp(report);return;
end
lock=java.io.File(fullfile(folder,'RUNNING.lock'));
assert(lock.createNewFile(),'CSSP:Running', ...
    'This stage is already running or has an interrupted lock. Verify no MATLAB process is running before removing RUNNING.lock.');
lockCleanup=onCleanup(@()remove_lock(lock));
if C.requireNativeSelfTest
    t=CSSP_SELFTEST(C);assert(t.Pass,'CSSP:SelfTest','MATLAB self-test failed.');
    report.NumericalSelfTestsPassed=true;
    P0_IO('save',fullfile(folder,['selftest_' datestr(now,'yyyymmddTHHMMSSFFF') '.mat']),t);
end
science=C;
drop=intersect(fieldnames(science),{'archiveRoot','outputRoot','cacheRoot','stopFile','rscriptPath', ...
    'rompcaSource','rLibraryPath','externalAdapters','sourceHash','coreHash','packageRoot','nbRoot','csspRoot', ...
    'coilPath','externalAdapter','externalDependencies','priorResultRoots'});science=rmfield(science,drop);
protocol=struct('Version',C.version,'Stage',C.stage,'Science',science,'SourceHash',C.sourceHash,'Jobs',jobs);
ph=P0_IO('hashtext',jsonencode(protocol));pf=fullfile(folder,'protocol.mat');
if exist(pf,'file')==2
    old=P0_IO('load',pf);assert(strcmp(old.hash,ph),'CSSP:ChangedProtocol', ...
        'Scientific configuration or source changed. Use a new outputRoot; never silently mix results.');
else,P0_IO('save',pf,struct('hash',ph,'protocol',protocol));end
P0_IO('csv',fullfile(folder,'source_hashes.csv'),{'File','SHA256'},sources);
row=struct('Module','','Dataset','','Condition','','Repeat',0,'Method','','Budget','', ...
    'Status','','Reason','','FitFile','');status=repmat(row,0,1);
lastCase='';K=[];D=[];A=[];caseError=[];
for i=1:numel(jobs)
    P0_IO('checkstop',C.stopFile);j=jobs(i);s=row;
    for f={'Module','Dataset','Condition','Repeat','Method','Budget'},s.(f{1})=j.(f{1});end
    id=sprintf('%s_%s_r%03d_%s_%s',j.Dataset,j.Condition,j.Repeat,j.Method,j.Budget);
    out=fullfile(folder,j.Module,'fits',id);ff=fullfile(out,'fit.mat');s.FitFile=ff;
    fprintf('\n[%d/%d] %s / %s\n',i,numel(jobs),j.Module,id);
    try
        if ~dep.Rows(i).Ready
            error('CSSP:DataBlocked','%s',dep.Rows(i).Reason);
        end
        if isfield(externalChecks,j.Method)&&~externalChecks.(j.Method).Ready
            error('CSSP:ExternalBlocked','%s',externalChecks.(j.Method).Reason);
        end
        key=sprintf('%s|%s|%d',j.Dataset,j.Condition,j.Repeat);
        if ~strcmp(key,lastCase)
            lastCase=key;caseError=[];
            try
                [K,D,A,regime]=NB_CASE(C,j);K.regime=regime;
            catch e,caseError=e;end
        end
        if ~isempty(caseError),throw(caseError);end
        a=A;
        if strcmp(j.Budget,'B2')
            caps=[100 10 24];
            if strcmp(C.stage,'pilot'),caps=2*C.realBudget;end
            a.maxOuter=caps(1);a.maxInner=caps(2);a.mmLineSearchMax=caps(3);
            a.gradientBacktracks=2*A.gradientBacktracks;
        end
        a.maxTimePerMethod=Inf;
        inputs=struct('Protocol',ph,'Job',j,'CaseHash',K.caseHash,'InitHash',K.initHash, ...
            'DataHash',D.dataHash,'SplitHash',D.S.hash,'FoldHash',P0_IO('hashtext',jsonencode(D.F)), ...
            'Algorithm',a,'ExternalAdapters',struct(),'RSource','');
        if isfield(externalChecks,j.Method)
            inputs.ExternalAdapters=C.externalAdapters;inputs.RSource=C.rompcaSource;
            inputs.ExternalReadiness=externalChecks.(j.Method);
        end
        signature=P0_IO('hashtext',jsonencode(inputs));
        if exist(ff,'file')==2
            saved=P0_IO('load',ff);assert(strcmp(saved.signature,signature),'CSSP:Resume','Saved evaluation signature changed.');
            report.ReusedRecords=report.ReusedRecords+1;s.Status='REUSED';
        else
            fitClock=tic;selection=[];receipt=[];S=[];nativeInfo=[];diagnostic=struct();
            if strcmp(j.Method,'INIT')
                model=struct('U',K.U0,'V',K.V0,'status','initialization_only','StopReason','no_optimization', ...
                    'AcceptedSteps',0,'TimeSeconds',0,'outerIters',0,'FinalRecomputedGradRelative',NaN);
            elseif any(strcmp(j.Method,{'TunedC','TunedEta'}))
                [model,S,selection,receipt]=CSSP_SELECTION(C,K,D,a,j.Method);
                report.NativeNewFits=report.NativeNewFits+sum(~[selection.CacheHit]);
                report.NativeCacheHits=report.NativeCacheHits+sum([selection.CacheHit]);
                assert(exist(receipt.LockPath,'file')==2&&~receipt.ProbeScoredBeforeLock, ...
                    'CSSP:SelectionOrder','Selection was not committed before probe evaluation.');
            elseif any(strcmp(j.Method,{'C1','C2','C3','C4','C5','L2'}))
                [model,S,nativeInfo]=CSSP_FIT_NATIVE(C,K,a,j.Method);
                report.NativeNewFits=report.NativeNewFits+~nativeInfo.CacheHit;
                report.NativeCacheHits=report.NativeCacheHits+nativeInfo.CacheHit;
            else
                [model,diagnostic]=CSSP_EXTERNAL(j.Method,K,D,a,C);
                if isfield(diagnostic,'Usable')&&~diagnostic.Usable
                    P0_IO('mkdir',out);
                    uf=fullfile(out,'external_unusable.mat');
                    if exist(uf,'file')~=2
                        P0_IO('save',uf,struct('signature',signature,'job',j,'model',model,'diagnostic',diagnostic));
                    end
                    error('CSSP:BaselineUnusable','External baseline did not produce a usable reference: %s',j.Method);
                end
            end
            preProbe=toc(fitClock);
            Z=NB_EVALUATE(K,D,model,S); % FIRST probe readout for this job, after fit/lock
            R=record(C,j,K,a,model,Z,preProbe);
            if ~isempty(nativeInfo)
                R.RuntimeSeconds=nativeInfo.FitSeconds+K.InitializationSeconds;
                R.TrainingCacheHit=nativeInfo.CacheHit;
                R.ImportedPrior=nativeInfo.ImportedPrior;R.PriorFile=nativeInfo.PriorFile;
                R.EndpointOnlyImported=nativeInfo.EndpointOnlyImported;
            end
            if ~isempty(receipt)
                R.SelectedValue=receipt.SelectedValue;R.SelectionSeconds=receipt.SelectionSeconds;
                R.SelectionHash=receipt.SelectionHash;R.SelectionLockedBeforeProbe=true;
                R.RuntimeSeconds=receipt.SelectionSeconds+K.InitializationSeconds;
            end
            if isfield(diagnostic,'SelectedValue'),R.SelectedValue=diagnostic.SelectedValue;end
            if isfield(diagnostic,'SelectionSeconds'),R.SelectionSeconds=diagnostic.SelectionSeconds;end
            if isfield(externalChecks,j.Method)
                R.RuntimeSeconds=preProbe;R.CurrentRunSeconds=preProbe;
                R.InitializationSeconds=get(diagnostic,'InitializationSeconds',NaN);
                R.InitializationProtocol='external_native_initialization';
            end
            if isfield(diagnostic,'InitializationHash'),R.InitHash=diagnostic.InitializationHash;end
            if isfield(model,'initializationHash'),R.InitHash=model.initializationHash;end
            meta=rmfield(K,{'X','mask','U0','V0'});meta.Split=D.S;meta.DataHash=D.dataHash;
            lite=model;strip=intersect(fieldnames(lite),{'innerTrace','outerTrace'});lite=rmfield(lite,strip);
            saved=struct('signature',signature,'job',j,'record',R,'metadata',meta, ...
                'algorithm',a,'model',lite,'selection',selection,'selectionLockedBeforeProbe',~isempty(receipt), ...
                'receipt',receipt,'nativeInfo',nativeInfo,'externalDiagnostic',diagnostic);
            P0_IO('mkdir',out);writetable(struct2table(R,'AsArray',true),fullfile(out,'record.csv'));
            if ~isempty(selection),writetable(struct2table(selection,'AsArray',true),fullfile(out,'selection_locked.csv'));end
            if isfield(model,'checkpoints')&&strcmp(j.Module,'01_initialization')
                metrics=NB_CHECKPOINT_METRICS(model,K.X,K.regime,D,true);
                writetable(struct2table(metrics,'AsArray',true),fullfile(out,'checkpoint_metrics.csv'));
            end
            if isfield(model,'outerTrace')&&~isempty(model.outerTrace)
                P0_IO('csv',fullfile(out,'outer_trace.csv'),P0_TRACE_HEADERS('outer'),model.outerTrace);
            end
            P0_IO('save',ff,saved);report.CommittedRecords=report.CommittedRecords+1;s.Status='COMMITTED';
        end
        if strcmp(j.Method,'INIT')
            mf=fullfile(out,'mechanism_candidates.csv');
            if exist(mf,'file')~=2
                rows=CSSP_MECHANISM(K,A,C);writetable(struct2table(rows,'AsArray',true),mf);
            end
        end
        oldFailure=fullfile(out,'FAILED_OR_BLOCKED.txt');if exist(oldFailure,'file')==2,delete(oldFailure);end
        s.Reason='Completed/reused evaluation; not a convergence or superiority claim.';
        fprintf('NRE %.6f ACC %.2f%% | %s\n',saved.record.NRE,100*saved.record.ACC,saved.record.Status);
    catch e
        s.Reason=sprintf('%s: %s',e.identifier,e.message);
        if any(strcmp(e.identifier,{'CSSP:DataBlocked','CSSP:ExternalBlocked'}))
            s.Status='BLOCKED';report.BlockedRecords=report.BlockedRecords+1;
        elseif strcmp(e.identifier,'SU:StopRequested'),rethrow(e);
        else,s.Status='FAILED';report.FailedRecords=report.FailedRecords+1;end
        fprintf(2,'%s %s\n',s.Status,s.Reason);
        P0_IO('mkdir',out);P0_IO('write',fullfile(out,'FAILED_OR_BLOCKED.txt'),s.Reason);
        if ~C.allowPartial,rethrow(e);end
    end
    status(end+1,1)=s; %#ok<AGROW>
    writetable(struct2table(status,'AsArray',true),fullfile(folder,'task_status.csv'));
    P0_IO('write',fullfile(folder,'run_status.json'),jsonencode(report));
end
report.AllPlannedCommitted=report.CommittedRecords+report.ReusedRecords==numel(jobs) ...
    &&report.BlockedRecords==0&&report.FailedRecords==0;
report.ReadyForScientificReview=report.AllPlannedCommitted&&strcmp(C.stage,'paper')&&report.NumericalSelfTestsPassed;
if report.ReadyForScientificReview,report.Status='EXECUTION_COMPLETE_NOT_A_SUPERIORITY_CLAIM';
else,report.Status='INCOMPLETE_OR_ENGINEERING_ONLY_SEE_TASK_STATUS';end
P0_IO('write',fullfile(folder,'run_status.json'),jsonencode(report));
if strcmp(C.stage,'paper'),CSSP_SUMMARIZE(C);
else,fprintf('Pilot records remain engineering-only; not pooled into paper summaries.\n');end
disp(report);clear lockCleanup;
end
function R=record(C,j,K,A,m,Z,seconds)
R=struct('CodeVersion',C.version,'Module',j.Module,'Dataset',j.Dataset,'Condition',j.Condition, ...
    'Repeat',j.Repeat,'Method',j.Method,'Budget',j.Budget,'Stage',C.stage, ...
    'Scientific',strcmp(C.stage,'paper'),'CaseHash',K.caseHash,'InitHash',K.initHash, ...
    'CommonInputInitHash',K.initHash,'SourceHash',C.sourceHash,'Status',get(m,'status',get(m,'stopReason','external_finished')), ...
    'StopReason',get(m,'StopReason',get(m,'stopReason','external_finished')), ...
    'SelectedValue',NaN,'SelectionSeconds',0,'SelectionHash','','SelectionLockedBeforeProbe',false, ...
    'RuntimeSeconds',seconds+K.InitializationSeconds,'CurrentRunSeconds',seconds+K.InitializationSeconds, ...
    'TrainingCacheHit',false,'ImportedPrior',false,'PriorFile','','EndpointOnlyImported',false, ...
    'OptimizationSeconds',get(m,'TimeSeconds',get(m,'elapsedSeconds',NaN)), ...
    'InitializationProtocol','common_robust_BPCA','InitializationSeconds',K.InitializationSeconds, ...
    'CommonInitializationSeconds',K.InitializationSeconds,'AcceptedSteps',get(m,'AcceptedSteps',NaN), ...
    'FinalGradient',get(m,'FinalRecomputedGradRelative',NaN),'OuterIterations',get(m,'outerIters',get(m,'iterations',NaN)), ...
    'OuterCap',A.maxOuter,'InnerCap',A.maxInner,'BacktrackCap',A.mmLineSearchMax,'TimeCap',A.maxTimePerMethod, ...
    'RankRow',size(m.U,2),'RankColumn',size(m.V,2),'ActualRate',mean(K.mask(:)), ...
    'InferenceScope','descriptive paired repeated splits; overlapping images are not independent subjects');
names=fieldnames(Z);for k=1:numel(names),R.(names{k})=Z.(names{k});end
end
function v=get(s,n,d)
if isfield(s,n),v=s.(n);else,v=d;end
end
function remove_lock(f)
if f.exists(),f.delete();end
end
