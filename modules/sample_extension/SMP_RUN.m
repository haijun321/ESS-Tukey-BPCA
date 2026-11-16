function SMP_RUN(mode,options)
%SMP_RUN Independent synthetic experiment. Default: precheck, then 80 fits.
% SMP_RUN('all'); SMP_RUN('formal'); SMP_RUN('precheck'); SMP_RUN('summary');
    if nargin<1,mode='all';end
    if nargin<2,options=struct();end
    mode=char(mode);assert(ismember(mode,{'all','formal','precheck','summary'}),'SMP:Mode','Unknown mode.');
    previousPath=path;restorePath=onCleanup(@() path(previousPath)); %#ok<NASGU>
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'vendor'),'-begin');addpath(root,'-begin');
    C=SMP_CONFIG();names=fieldnames(options);
    for j=1:numel(names)
        assert(isfield(C,names{j}),'SMP:Option','Unknown option: %s',names{j});C.(names{j})=options.(names{j});
    end
    C.packageRoot=root;C.outputRoot=char(C.outputRoot);
    if ~isfolder(C.outputRoot),mkdir(C.outputRoot);end
    stopFile=fullfile(C.outputRoot,'STOP_SAMPLE.txt');
    if isfile(stopFile)
        fprintf('Paused: remove %s before resuming.\n',stopFile);return;
    end
    runLock=SMP_IO('lock',C.outputRoot); %#ok<NASGU>
    logFile=fullfile(C.outputRoot,'console_log.txt');diary(logFile);
    restoreDiary=onCleanup(@() diary('off')); %#ok<NASGU>
    fprintf('\n============================================================\n');
    fprintf('%s | MATLAB %s\n',C.protocolVersion,version);
    fprintf('Output: %s\n',C.outputRoot);
    fprintf('Formal plan: 4 conditions x %d repeats x 2 methods = %d fits.\n', ...
        numel(C.formalRepeats),8*numel(C.formalRepeats));
    fprintf('Truth labels are not passed to calibration or the solver.\n');
    [sources,sourceHash]=SMP_IO('sources',root);
    scientific=C;
    scientific=rmfield(scientific,{'packageRoot','outputRoot','makePlots'});
    configurationHash=SMP_IO('hash',scientific);
    protocol=struct('C',C,'ConfigurationHash',configurationHash,'SourceHash',sourceHash, ...
        'Created',datestr(now,30),'MatlabVersion',version,'Sources',sources);
    protocolFile=fullfile(C.outputRoot,'protocol.mat');
    if isfile(protocolFile)
        old=SMP_IO('loadmat',protocolFile);
        assert(strcmp(old.ConfigurationHash,configurationHash)&&strcmp(old.SourceHash,sourceHash), ...
            'SMP:ProtocolChanged','Source or settings changed. Use a NEW outputRoot; do not mix results.');
    else
        SMP_IO('savemat',protocolFile,protocol);
        SMP_IO('csv',fullfile(C.outputRoot,'source_hashes.csv'),sources);
        serialProtocol=protocol;serialProtocol.Sources=table2struct(sources);
        SMP_IO('text',fullfile(C.outputRoot,'protocol.json'),jsonencode(serialProtocol,'PrettyPrint',true));
    end
    SMP_SELFTEST(C);
    if strcmp(mode,'summary')
        rebuild_records(C,'precheck');rebuild_records(C,'formal');
        SMP_SUMMARIZE(C,'precheck');SMP_SUMMARIZE(C,'formal');SMP_PACKAGE_RESULTS(C);return;
    end
    if ismember(mode,{'all','precheck'})
        stopped=run_phase(C,'precheck',configurationHash,sourceHash,stopFile);
        SMP_SUMMARIZE(C,'precheck');
        if stopped,announce_pause(stopFile);return;end
        assert_precheck(C);
    elseif strcmp(mode,'formal')
        assert_precheck(C);
    end
    if ismember(mode,{'all','formal'})
        stopped=run_phase(C,'formal',configurationHash,sourceHash,stopFile);
        SMP_SUMMARIZE(C,'formal');SMP_PACKAGE_RESULTS(C);
        if stopped,announce_pause(stopFile);return;end
        F=readtable(fullfile(C.outputRoot,'formal','fit_records.csv'),'TextType','string');
        failed=sum(string(F.Status)=="runtime_error");
        fprintf('\nFormal records: %d / %d; runtime-error records: %d.\n', ...
            height(F),8*numel(C.formalRepeats),failed);
        fprintf('Time/iteration limits are outcomes, not convergence certificates.\n');
        fprintf('Review bundle: %s\n',fullfile(C.outputRoot,'sample_results_for_review.zip'));
    end
end

function stopped=run_phase(C,phase,configurationHash,sourceHash,stopFile)
    stopped=false;base=fullfile(C.outputRoot,phase);
    if ~isfolder(base),mkdir(base);end
    if strcmp(phase,'formal'),reps=C.formalRepeats;else,reps=C.precheckRepeats;end
    [A,M]=SMP_ALGORITHM(C,phase);
    for rep=reps
        if isfile(stopFile),stopped=true;break;end
        dataFile=fullfile(base,'cases',sprintf('block_r%03d.mat',rep));
        if isfile(dataFile)
            block=SMP_IO('loadmat',dataFile);
            assert(strcmp(block.ConfigurationHash,configurationHash)&&strcmp(block.SourceHash,sourceHash), ...
                'SMP:DataSignature','Cached data have a different source or configuration.');
            D=block.D;
            assert(strcmp(D.phase,phase)&&D.repeat==rep,'SMP:DataIdentity','Wrong data block.');
        else
            D=SMP_DATA(C,rep,phase);
            block=struct('ConfigurationHash',configurationHash,'SourceHash',sourceHash,'D',D);
            SMP_IO('savemat',dataFile,block);clear block;
        end
        for ic=1:numel(D.cases)
            if isfile(stopFile),stopped=true;break;end
            K=D.cases(ic);
            caseHash=SMP_IO('hash',struct('X',K.X,'caseLabels',K.caseLabels,'cellMask',K.cellMask));
            folder=fullfile(base,'cases',sprintf('r%03d_%s',rep,K.id));
            initFile=fullfile(folder,'initialization.mat');
            if isfile(initFile)
                init=SMP_IO('loadmat',initFile);
                assert(strcmp(init.CaseHash,caseHash)&&strcmp(init.SourceHash,sourceHash), ...
                    'SMP:InitSignature','Initialization does not match observations.');
                U0=init.U;V0=init.V;initSeconds=init.InitializationSeconds;
            else
                previous=rng;restoreRng=onCleanup(@() rng(previous)); %#ok<NASGU>
                rng(D.seed+50+ic,'twister');fitTimer=tic;
                dummy=struct('id','INIT','name','common_robust_initialization');
                [U0,V0]=SMPV_SU_SYN_FROZEN('initialize',K.X,C.r,C.c,dummy,A);
                initSeconds=toc(fitTimer);clear restoreRng;
                init=struct('U',U0,'V',V0,'CaseHash',caseHash,'SourceHash',sourceHash, ...
                    'InitializationSeconds',initSeconds);
                SMP_IO('savemat',initFile,init);
            end
            initHash=SMP_IO('hash',struct('U',U0,'V',V0));
            initModel=struct('U',U0,'V',V0);initState=struct('a',ones(C.n,1),'Ws',ones(C.n,1),'W',ones(size(K.X)));
            [im,~]=SMP_METRICS(D,K,initModel,initState);
            I=struct('Phase',phase,'Repeat',rep,'Condition',K.id,'Method','INIT', ...
                'Status','readout','ErrSubNorm',im.ErrSubNorm,'ProbeCleanNRE',im.ProbeCleanNRE, ...
                'CaseHash',caseHash,'InitHash',initHash,'InitializationSeconds',initSeconds);
            SMP_IO('savemat',fullfile(folder,'initialization_record.mat'),I);
            for methodOrder=1:2
                % Alternate order across repeat/condition blocks to reduce timing-order bias.
                if mod(rep+ic,2)==0,mi=methodOrder;else,mi=3-methodOrder;end
                method=M(mi);
                if isfile(stopFile),stopped=true;break;end
                job=sprintf('r%03d_%s_%s',rep,K.id,method.id);
                jobFolder=fullfile(base,'fits',job);file=fullfile(jobFolder,'result.mat');
                signature=SMP_IO('hash',struct('Phase',phase,'Repeat',rep,'Condition',K.id, ...
                    'Method',method,'A',A,'CaseHash',caseHash,'InitHash',initHash, ...
                    'ConfigurationHash',configurationHash,'SourceHash',sourceHash));
                if isfile(file)
                    old=SMP_IO('loadmat',file);
                    assert(strcmp(old.signature,signature),'SMP:FitSignature','Cached fit changed: %s',job);
                    if ~strcmp(old.R.Status,'runtime_error')
                        fprintf('SKIP %s %s\n',phase,job);continue;
                    end
                    history=fullfile(jobFolder,['failed_attempt_' datestr(now,'yyyymmddTHHMMSSFFF') '.mat']);
                    copyfile(file,history);clear old;
                end
                fprintf('FIT %s %s | %d x %d x %d | rank %d x %d\n',phase,job,C.p,C.q,C.n,C.r,C.c);
                R=empty_record(phase,rep,K.id,method.id,configurationHash,caseHash,initHash);
                R.SourceHash=sourceHash;R.InitializationSeconds=initSeconds;
                R.RealizedCaseRate=K.realizedCaseRate;R.RealizedCellRateEligible=K.realizedCellRateEligible;
                R.RealizedTotalEntryRate=K.realizedTotalEntryRate;fitTimer=tic;T=table();model=[];
                try
                    % The truth mask is deliberately withheld; zero mask is diagnostic-only.
                    [model,S]=SMPV_P0_SOLVER_V2(K.X,C.r,C.c,method,A,'synthetic',U0,V0,false(size(K.X)));
                    [met,T]=SMP_METRICS(D,K,model,S);
                    fields=fieldnames(met);for z=1:numel(fields),R.(fields{z})=met.(fields{z});end
                    floorA=C.sampleWeightMin^C.sampleWeightAlpha;
                    assert(all(T.Aused>=floorA-1e-12)&&all(T.Aused<=1+1e-12), ...
                        'SMP:WeightRange','Sample coefficients out of range.');
                    if strcmp(method.id,'E')
                        assert(all(T.Aused==1)&&all(T.Afinal==1),'SMP:Disabled','E must have unit sample coefficients.');
                    end
                    R.Status=model.status;R.OuterIters=model.outerIters;
                    R.AcceptedSteps=model.AcceptedSteps;R.FinalGrad=model.FinalRecomputedGradRelative;
                    R.LastAcceptedOuter=model.lastAcceptedOuter;R.HadAcceptedUpdate=model.AcceptedSteps>0;
                    R.TimeSeconds=model.TimeSeconds;R.TotalSeconds=toc(fitTimer)+initSeconds;
                    T.Phase=repmat(string(phase),height(T),1);T.Repeat=repmat(rep,height(T),1);
                    T.Condition=repmat(string(K.id),height(T),1);T.Method=repmat(string(method.id),height(T),1);
                    SMP_IO('csv',fullfile(jobFolder,'sample_records.csv'),T);
                    trace=array2table(model.sampleTrace,'VariableNames', ...
                        {'Outer','AttemptSampleESS','AttemptMinA','AttemptMeanA','AttemptDownweight95','AttemptFloorFraction','Seconds'});
                    SMP_IO('csv',fullfile(jobFolder,'sample_trace.csv'),trace);
                    SMP_IO('csv',fullfile(jobFolder,'outer_trace.csv'),array2table(model.outerTrace, ...
                        'VariableNames',SMPV_P0_TRACE_HEADERS('outer')));
                    SMP_IO('csv',fullfile(jobFolder,'inner_trace.csv'),array2table(model.innerTrace, ...
                        'VariableNames',SMPV_P0_TRACE_HEADERS('inner')));
                    clear S;
                catch err
                    R.Status='runtime_error';R.FailureMessage=getReport(err,'extended','hyperlinks','off');
                    R.TimeSeconds=toc(fitTimer);R.TotalSeconds=R.TimeSeconds+initSeconds;
                    fprintf(2,'FAILED %s: %s\n',job,err.message);
                end
                payload=struct('signature',signature,'R',R,'model',model,'samples',T, ...
                    'MethodDefinition',method,'AlgorithmSettings',A);
                SMP_IO('savemat',file,payload);
                SMP_IO('csv',fullfile(jobFolder,'record.csv'),struct2table(R,'AsArray',true));
                rebuild_records(C,phase);
                fprintf('SAVED %s | %s | Esub %.6g | probe %.6g\n',job,R.Status,R.ErrSubNorm,R.ProbeCleanNRE);
                clear payload model T;
            end
            if stopped,break;end
        end
        clear D;
        if stopped,break;end
    end
    rebuild_records(C,phase);
end

function R=empty_record(phase,rep,condition,method,ch,dh,ih)
    R=struct('Phase',phase,'Repeat',rep,'Condition',condition,'Method',method, ...
        'Status','runtime_error','Scientific',strcmp(phase,'formal'),'FailureMessage','', ...
        'ConfigurationHash',ch,'CaseHash',dh,'InitHash',ih,'SourceHash','');
    names={'ErrSubNorm','ProbeCleanNRE','TrainNRE','NonCaseNRE','TrainSignalNRE', ...
        'RetainedPerturbationNRE2','SampleESS','SampleMeanA','SampleFloorFraction', ...
        'SampleAUROC','SampleAP','NonCaseDownweight95','CaseMeanA','NonCaseMeanA', ...
        'CombinedESS','TimeSeconds','TotalSeconds','InitializationSeconds','OuterIters', ...
        'AcceptedSteps','FinalGrad','LastAcceptedOuter','HadAcceptedUpdate','RealizedCaseRate','RealizedCellRateEligible','RealizedTotalEntryRate'};
    for j=1:numel(names),R.(names{j})=NaN;end
end

function rebuild_records(C,phase)
    base=fullfile(C.outputRoot,phase);fs=dir(fullfile(base,'fits','*','result.mat'));
    R=struct([]);T=table();I=struct([]);
    for j=1:numel(fs)
        P=SMP_IO('loadmat',fullfile(fs(j).folder,fs(j).name));
        if isempty(R),R=P.R;else,R(end+1)=P.R;end %#ok<AGROW>
        if ~isempty(P.samples),T=[T;P.samples];end %#ok<AGROW>
    end
    fs=dir(fullfile(base,'cases','*','initialization_record.mat'));
    for j=1:numel(fs)
        z=SMP_IO('loadmat',fullfile(fs(j).folder,fs(j).name));
        if isempty(I),I=z;else,I(end+1)=z;end %#ok<AGROW>
    end
    if ~isempty(R),SMP_IO('csv',fullfile(base,'fit_records.csv'),struct2table(R,'AsArray',true));end
    if ~isempty(T),SMP_IO('csv',fullfile(base,'sample_records.csv'),T);end
    if ~isempty(I),SMP_IO('csv',fullfile(base,'initialization_records.csv'),struct2table(I,'AsArray',true));end
end

function assert_precheck(C)
    f=fullfile(C.outputRoot,'precheck','fit_records.csv');
    assert(isfile(f),'SMP:PrecheckRequired','Run START_SAMPLE_EXTENSION first to complete the precheck.');
    F=readtable(f,'TextType','string');expected=8*numel(C.precheckRepeats);
    assert(height(F)==expected&&all(string(F.Status)~="runtime_error")&& ...
        all(isfinite(F.ErrSubNorm))&&all(isfinite(F.ProbeCleanNRE)), ...
        'SMP:PrecheckFailed','Precheck incomplete or failed. Review precheck fit_records.csv before formal fits.');
    fprintf('Precheck passed: %d finite paired fits. This is NOT a performance claim.\n',height(F));
end

function announce_pause(file)
    fprintf('Paused safely between fits. Remove %s and run the same entry to resume.\n',file);
end
