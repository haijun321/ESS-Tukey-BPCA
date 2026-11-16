function report=NB_RUN(window,stage,options)
% Numeric checks, data readiness and saved outcomes have separate statuses.
    if nargin<2,stage='pilot';end
    if nargin<3,options=struct();end
    window=upper(char(window));stage=lower(char(stage));
    assert(numel(window)==1&&any(window=='ABCDE'),'NB:Window','Use A,B,C,D,E');
    assert(any(strcmp(stage,{'pilot','paper','plan'})),'NB:Stage','Use pilot,paper,plan');
    base=NB_BOOTSTRAP(options);planStage=stage;if strcmp(stage,'plan'),planStage='paper';end
    C=NB_STAGE_CONFIG(base,planStage);[jobs,suffix]=NB_SCOPE_JOBS(C,NB_JOBS(C,window,planStage));
    folder=fullfile(C.outputRoot,planStage,['window' window suffix]);
    report=struct('Window',window,'Scope',C.scope,'Stage',stage,'Planned',numel(jobs), ...
        'NewlyCompleted',0,'Reused',0,'FailedOrBlocked',0,'UnusableBaselines',0, ...
        'AllPlannedCommitted',false,'ReadyForPaper',false);
    fprintf('\nWindow %s / %s / %s: %d planned records\nOutput %s\n',window,C.scope,stage,numel(jobs),folder);
    if strcmp(stage,'plan')
        NB_PREFLIGHT(C,jobs,'basic');disp(struct2table(rmfield(jobs,'Case'),'AsArray',true));return;
    end
    validation=fullfile(C.outputRoot,'MATLAB_SELFTEST_PASS.mat');
    assert(exist(validation,'file')==2,'NB:Selftest','Run START_HERE before experiments');
    v=load(validation,'report');[sourceHash,manifest]=NB_SOURCE_HASH(C);
    assert(v.report.Pass&&strcmp(v.report.SourceHash,sourceHash),'NB:SourceChanged','Source changed. Run START_HERE again.');
    familyHash=P0_IO('hashtext',jsonencode(NB_PROTOCOL_CONFIG(base)));
    report.SourceHash=sourceHash;report.FamilyHash=familyHash;
    P0_IO('mkdir',folder);lock=java.io.File(fullfile(folder,'WINDOW_RUNNING.lock'));
    assert(lock.createNewFile(),'NB:Locked','This output scope is running or has a stale lock; see README');
    cleanup=onCleanup(@()delete_lock(lock));
    report.Status='RUNNING_NOT_READY';
    P0_IO('write',fullfile(folder,'RUN_STATUS.json'),jsonencode(report));
    dependency=NB_PREFLIGHT(C,jobs,C.preflightMode);
    writetable(struct2table(dependency.Rows,'AsArray',true),fullfile(folder,'dependency_readiness.csv'));
    if ~dependency.AllReady&&~C.allowPartial
        report.FailedOrBlocked=dependency.BlockedCount;report.Status='BLOCKED_DEPENDENCIES_NO_FITS_STARTED';
        P0_IO('write',fullfile(folder,'RUN_STATUS.json'),jsonencode(report));
        fprintf(2,'No fits started. Use NB_SETUP_PATHS to resolve data, or explicitly select scope=synthetic.\n');
        disp(report);clear cleanup;return;
    end
    if strcmp(stage,'paper')
        try,NB_PAPER_GATE(base,window,suffix,sourceHash,familyHash);
        catch e
            report.Status='BLOCKED_PILOT_OR_RA_CHECK';
            P0_IO('write',fullfile(folder,'RUN_STATUS.json'),jsonencode(report));rethrow(e);
        end
    end
    registry=java.io.File(fullfile(C.outputRoot,stage,['WINDOW_' window '_SCOPE.lock']));
    assert(registry.createNewFile(),'NB:ScopeRegistrationBusy','A sibling scope is being registered. Retry after it starts.');
    registryCleanup=onCleanup(@()delete_lock(registry));
    NB_SCOPE_GUARD(fullfile(C.outputRoot,stage),folder,jobs);
    protocol=struct('config',NB_PROTOCOL_CONFIG(C),'window',window,'stage',stage,'sourceHash',sourceHash,'jobs',jobs);
    ph=P0_IO('hashtext',jsonencode(protocol));pf=fullfile(folder,'protocol.mat');
    if exist(pf,'file')
        old=P0_IO('load',pf);assert(strcmp(old.hash,ph),'NB:ProtocolChanged','Scientific settings changed. Use a NEW outputRoot.');
    else,P0_IO('save',pf,struct('hash',ph,'protocol',protocol));end
    P0_IO('csv',fullfile(folder,'source_hashes.csv'),{'File','SHA256'},manifest);
    writetable(struct2table(rmfield(jobs,'Case'),'AsArray',true),fullfile(folder,'expected_manifest.csv'));
    clear registryCleanup;
    failures=cell(0,7);headers={'Module','Dataset','Condition','Repeat','Method','Identifier','Message'};
    P0_IO('csv',fullfile(folder,'failures.csv'),headers,failures);
    lastKey='';caseFailure=[];K=[];D=[];A=[];regime='';
    for i=1:numel(jobs)
        P0_IO('checkstop',C.stopFile);j=jobs(i);
        id=sprintf('%s_%s_r%03d_%s',j.Dataset,j.Condition,j.Repeat,j.Method);
        out=fullfile(folder,'fits',id);P0_IO('mkdir',out);fitfile=fullfile(out,'fit.mat');
        key=sprintf('%s|%s|%d|%.17g',j.Dataset,j.Condition,j.Repeat,j.NoiseSigma);
        try
            if ~strcmp(key,lastKey)
                lastKey=key;caseFailure=[];
                try,[K,D,A,regime]=NB_CASE(C,j);catch e,caseFailure=e;end
            end
            if ~isempty(caseFailure),throw(caseFailure);end
            signature=NB_FIT_SIGNATURE(ph,K,D,A,j);
            if exist(fitfile,'file')
                saved=P0_IO('load',fitfile);assert(strcmp(saved.signature,signature),'NB:Resume','Cached input/reference signature changed');
                report.Reused=report.Reused+1;fprintf('SKIP %d/%d %s\n',i,numel(jobs),id);
            else
                fprintf('FIT %d/%d %s\n',i,numel(jobs),id);saved=NB_FIT(C,j,K,D,A,regime,signature);
                saved.record.SourceHash=sourceHash;
                writetable(struct2table(saved.record,'AsArray',true),fullfile(out,'record.csv'));
                if ~isempty(saved.selection),writetable(struct2table(saved.selection,'AsArray',true),fullfile(out,'selection_locked.csv'));end
                if isfield(saved.model,'weightTrace')
                    writetable(struct2table(saved.model.weightTrace,'AsArray',true),fullfile(out,'RA_weight_trace.csv'));
                end
                if isfield(saved,'checkpointMetrics')
                    writetable(struct2table(saved.checkpointMetrics,'AsArray',true),fullfile(out,'checkpoint_metrics.csv'));
                    P0_IO('csv',fullfile(out,'outer_trace.csv'),P0_TRACE_HEADERS('outer'),saved.model.outerTrace);
                end
                if isfield(saved,'mechanism'),writetable(struct2table(saved.mechanism,'AsArray',true),fullfile(out,'mechanism_counterfactual.csv'));end
                P0_IO('save',fitfile,saved);report.NewlyCompleted=report.NewlyCompleted+1;
                fprintf('SAVED %s NRE=%.6f %s baselineUsable=%d\n',id,saved.record.NRE,saved.record.Status,saved.record.BaselineUsable);
            end
            clear_failure(out);
            if isfield(saved.record,'BaselineUsable')&&~saved.record.BaselineUsable
                report.UnusableBaselines=report.UnusableBaselines+1;
            end
        catch e
            if strcmp(e.identifier,'SU:StopRequested'),rethrow(e);end
            failures(end+1,:)={j.Module,j.Dataset,j.Condition,j.Repeat,j.Method,e.identifier,e.message}; %#ok<AGROW>
            P0_IO('write',fullfile(out,'FAILED_OR_BLOCKED.txt'),sprintf('%s\n%s\n',e.identifier,e.message));
            P0_IO('csv',fullfile(folder,'failures.csv'),headers,failures);
            fprintf(2,'FAILED/BLOCKED %s: %s\n',id,e.message);
            report.FailedOrBlocked=size(failures,1);report.Status='FAILED_OR_BLOCKED_DURING_RUN';
            report.ReadyForPaper=false;
            P0_IO('write',fullfile(folder,'RUN_STATUS.json'),jsonencode(report));
            if ~C.allowPartial,rethrow(e);end
        end
    end
    report.FailedOrBlocked=size(failures,1);
    report.AllPlannedCommitted=report.NewlyCompleted+report.Reused==numel(jobs);
    report.ReadyForPaper=report.AllPlannedCommitted&&report.UnusableBaselines==0;
    if report.ReadyForPaper,report.Status='EXECUTION_READY_NOT_A_SUPERIORITY_CLAIM';
    else,report.Status='REVIEW_BLOCKED_TASKS_OR_BASELINE_DIAGNOSTICS';end
    P0_IO('write',fullfile(folder,'RUN_STATUS.json'),jsonencode(report));disp(report);clear cleanup;
end
function delete_lock(lock)
    if lock.exists(),lock.delete();end
end
function clear_failure(folder)
    p=fullfile(folder,'FAILED_OR_BLOCKED.txt');if exist(p,'file')==2,delete(p);end
end
