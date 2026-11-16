function saved=NB_FIT(C,job,K,D,A,regime,signature)
% Candidate selection is completed and locked before any probe metric.
    fitClock=tic;selectionSeconds=0;candidates=[];selectedValue=NaN;selectedCandidateDegenerate=false;
    commonInitSeconds=K.InitializationSeconds;
    outsideInitSeconds=K.InitializationSeconds;methodInitSeconds=K.InitializationSeconds;
    method=job.Method;S=[];trace=strcmp(job.Module,'A_trajectory')||strcmp(job.Module,'C_factorial');
    rankToken=regexp(method,'^(C3|RA)_dim([0-9]+)$','tokens','once');
    raK=[];
    if ~isempty(rankToken)
        level=str2double(rankToken{2});[r,c,raK]=NB_DIMENSION_PAIR(size(K.X,1),size(K.X,2),level);
        K.rank=[r c];
        if strcmp(rankToken{1},'C3')
            rng(K.Seed+123,'twister');ti=tic;
            if strcmp(regime,'real'),api='SU_FROZEN';else,api='SU_SYN_FROZEN';end
            [K.U0,K.V0]=feval(api,'initialize',K.X,r,c,struct('id','INIT'),A);
            K.InitializationSeconds=toc(ti);methodInitSeconds=K.InitializationSeconds;outsideInitSeconds=0;
            K.initHash=P0_IO('hashtext',[P0_IO('hashnumeric',K.U0) P0_IO('hashnumeric',K.V0)]);
        end
    end
    if trace,A.nbTraceEvery=C.checkpointEvery;A.nbProgressEvery=C.progressEveryOuter;end
    if strcmp(job.Module,'A_trajectory'),A.maxOuter=C.traceOuter;end
    if strcmp(job.Stage,'pilot')
        A.maxOuter=3;A.maxInner=2;A.mmLineSearchMax=8;A.essGridSize=16;
    end
    A.maxTimePerMethod=Inf;
    if strcmp(method,'RA2DPCA_dev')||startsWith(method,'RA_dim')
        outsideInitSeconds=0;methodInitSeconds=0;
        ts=tic;[Kv,Dv]=development_case(C,job,K,D,A);
        lambda=C.raLambdaGrid;gamma=NB_RA_DEFAULT_GAMMA(Kv.X);
        if isempty(raK),k=max(1,min(size(K.X,2)-1,ceil(prod(K.rank)/size(K.X,1))));else,k=raK;end
        ro=struct('maxOuter',C.raMaxOuter,'tolerance',C.raTolerance,'timeLimit',Inf,'center',true);
        candidates=repmat(candidate_row(),numel(lambda),1);
        best=Inf;model=[];pick=1;
        for i=1:numel(lambda)
            tm=tic;m=NB_RA2DPCA(Kv.X,k,gamma,lambda(i),ro);
            val=validation_nre(Kv,Dv,m);q=NB_RA_DIAGNOSTICS(Kv.X,m);
            row=candidate_row();row.Value=lambda(i);row.ValidationNRE=val;row.Seconds=toc(tm);
            row.Gamma=gamma;row.InitialNonzeroFraction=q.InitialRowNonzeroFraction;
            row.FinalNonzeroFraction=q.FinalRowNonzeroFraction;
            row.CovarianceRank=q.FinalCovarianceRank;
            row.Degenerate=m.ZeroWeightDegenerate||q.FinalAllWeightsZero||q.FinalZeroCovariance||q.FinalCovarianceRank<k;
            row.ExitStatus=m.stopReason;row.Iterations=m.iterations;candidates(i)=row;
            fprintf('  RA lambda=%g gamma=%.4g active %.3f -> %.3f status=%s\n', ...
                lambda(i),gamma,row.InitialNonzeroFraction,row.FinalNonzeroFraction,m.stopReason);
            if val<best,best=val;model=m;pick=i;end
        end
        selectedValue=lambda(pick);selectedCandidateDegenerate=candidates(pick).Degenerate;selectionSeconds=toc(ts);
        if strcmp(D.evaluation,'synthetic')
            model=NB_RA2DPCA(K.X,k,NB_RA_DEFAULT_GAMMA(K.X),selectedValue,ro);
        end
        actualInitHash=P0_IO('hashtext',sprintf('RA_identity_p%d_q%d_k%d_centered',size(K.X,1),size(K.X,2),k));
        initProtocol='native_RA_identity_plus_training_mean';
    elseif strcmp(method,'TunedC')||strcmp(method,'TunedEta')
        ts=tic;[Kv,Dv]=development_case(C,job,K,D,A);
        if strcmp(method,'TunedC'),grid=C.cGrid;else,grid=C.etaGrid;end
        candidates=repmat(struct('Value',NaN,'ValidationNRE',NaN,'Seconds',NaN),numel(grid),1);
        best=Inf;model=[];pick=1;
        for i=1:numel(grid)
            M=NB_NATIVE_METHOD(C,method,grid(i));a=A;
            if strcmp(method,'TunedC'),a.fixedTukeyC=grid(i);end
            tm=tic;[m,s]=P0_SOLVER_V2(Kv.X,Kv.rank(1),Kv.rank(2),M,a,regime,Kv.U0,Kv.V0,Kv.mask);
            val=validation_nre(Kv,Dv,m);candidates(i)=struct('Value',grid(i),'ValidationNRE',val,'Seconds',toc(tm));
            if val<best,best=val;model=m;S=s;pick=i;end
        end
        selectedValue=grid(pick);selectionSeconds=toc(ts);
        if strcmp(D.evaluation,'synthetic')
            M=NB_NATIVE_METHOD(C,method,selectedValue);a=A;
            if strcmp(method,'TunedC'),a.fixedTukeyC=selectedValue;end
            [model,S]=P0_SOLVER_V2(K.X,K.rank(1),K.rank(2),M,a,regime,K.U0,K.V0,K.mask);
        end
        actualInitHash=K.initHash;initProtocol='common_robust_BPCA';
    elseif ~isempty(C.externalAdapter)&&strcmp(method,C.externalName)
        % The adapter receives training and clean development ONLY, never probe.
        assert(exist(C.externalAdapter,'file')==2,'NB:ExternalMissing','External adapter not found: %s',C.externalAdapter);
        [Kv,Dv]=development_case(C,job,K,D,A);publicDev=rmfield(Kv,'mask');
        info=struct('rank',K.rank,'maxOuter',A.maxOuter, ...
            'seed',K.Seed+991,'development',Dv,'developmentCase',publicDev,'U0',K.U0,'V0',K.V0);
        rng(info.seed,'twister');
        model=feval(C.externalAdapter,K.X,info);
        assert(isfield(model,'U')&&isfield(model,'V'),'NB:ExternalSchema','Adapter must return U,V.');
        assert(norm(model.U'*model.U-eye(size(model.U,2)),'fro')<1e-7&& ...
            norm(model.V'*model.V-eye(size(model.V,2)),'fro')<1e-7,'NB:ExternalOrthogonal','Adapter bases must be orthonormal.');
        assert(isfield(model,'provenance')&&isfield(model,'initializationHash'), ...
            'NB:ExternalSchema','Adapter must record provenance and initializationHash.');
        actualInitHash=model.initializationHash;initProtocol='external_native_algorithm';
        if ~get(model,'commonInitializationUsed',false),outsideInitSeconds=0;end
        methodInitSeconds=get(model,'initializationSeconds',NaN);
    else
        nativeID=method;if startsWith(method,'C3_dim'),nativeID='C3';end
        M=NB_NATIVE_METHOD(C,nativeID);
        if trace
            [model,S]=NB_SOLVER_TRACE(K.X,K.rank(1),K.rank(2),M,A,regime,K.U0,K.V0,K.mask);
        else
            [model,S]=P0_SOLVER_V2(K.X,K.rank(1),K.rank(2),M,A,regime,K.U0,K.V0,K.mask);
        end
        actualInitHash=K.initHash;initProtocol='common_robust_BPCA';
    end
    preEvaluationSeconds=toc(fitClock);te=tic;Z=NB_EVALUATE(K,D,model,S);evaluationSeconds=toc(te);
    meta=rmfield(K,{'X','mask','U0','V0'});
    if isfield(D,'subIDs'),meta.subIDs=D.subIDs;meta.galleryIDs=D.galleryIDs;meta.probeIDs=D.probeIDs;end
    if isfield(D,'S'),meta.split=D.S;end
    if isfield(D,'dataHash'),meta.dataHash=D.dataHash;end
    if isfield(D,'protocol'),protocol=D.protocol;else,protocol=['frozen_' regime '_calibration'];end
    status=get(model,'status',get(model,'stopReason','external_finished'));
    R=struct('CodeVersion','NB_SUPPLEMENT_V2_FIX2_20261109','Module',job.Module,'Stage',job.Stage,'Scientific',strcmp(job.Stage,'paper'), ...
        'Dataset',job.Dataset,'Condition',job.Condition,'Repeat',job.Repeat,'Seed',K.Seed, ...
        'Method',method,'Regime',regime,'CalibrationProtocol',protocol,'NoiseSigma',job.NoiseSigma, ...
        'CaseHash',K.caseHash,'InitHash',actualInitHash,'CommonInputInitHash',K.initHash, ...
        'InitializationProtocol',initProtocol,'ConfigHash',signature,'Status',status, ...
        'StopReason',get(model,'StopReason',get(model,'stopReason',status)), ...
        'RuntimeSeconds',preEvaluationSeconds+outsideInitSeconds, ...
        'OptimizationSeconds',get(model,'TimeSeconds',get(model,'elapsedSeconds',NaN)), ...
        'SelectionSeconds',selectionSeconds,'EvaluationSeconds',evaluationSeconds, ...
        'InitializationSeconds',methodInitSeconds,'CommonInitializationSeconds',commonInitSeconds, ...
        'CandidateCount',numel(candidates), ...
        'SelectedValue',selectedValue,'FinalGradient',get(model,'FinalRecomputedGradRelative',NaN), ...
        'AcceptedSteps',get(model,'AcceptedSteps',NaN),'ActualRate',mean(K.mask(:)), ...
        'OuterCap',get(model,'maxOuter',A.maxOuter),'InnerCap',A.maxInner,'TimeCap',Inf);
    R.BaselineUsable=true;R.BaselineIssue='';
    R.SelectedGridBoundary=NaN;
    if ~isempty(candidates)
        ix=find([candidates.Value]==selectedValue,1);
        R.SelectedGridBoundary=double(ix==1||ix==numel(candidates));
    end
    R.RAInitialNonzeroFraction=NaN;R.RAFinalNonzeroFraction=NaN;R.RAZeroWeightDegenerate=false;
    R.RAInitialCovarianceRank=NaN;R.RAFinalCovarianceRank=NaN;
    R.RARankDeficient=false;R.RASelectionDegenerate=selectedCandidateDegenerate;
    if isfield(model,'ZeroWeightDegenerate')
        R.InnerCap=NaN;
        diagnostic=NB_RA_DIAGNOSTICS(K.X,model);
        R.RAInitialNonzeroFraction=diagnostic.InitialRowNonzeroFraction;
        R.RAFinalNonzeroFraction=diagnostic.FinalRowNonzeroFraction;
        R.RAInitialCovarianceRank=diagnostic.InitialCovarianceRank;
        R.RAFinalCovarianceRank=diagnostic.FinalCovarianceRank;
        R.RAZeroWeightDegenerate=model.ZeroWeightDegenerate||diagnostic.FinalAllWeightsZero||diagnostic.FinalZeroCovariance;
        R.RARankDeficient=diagnostic.FinalCovarianceRank<size(model.V,2);
        R.BaselineUsable=~(R.RAZeroWeightDegenerate||R.RARankDeficient||R.RASelectionDegenerate);
        if ~R.BaselineUsable
            R.BaselineIssue='RA_SELECTION_OR_FINAL_ACTIVATION_DEGENERATE';
            fprintf(2,'RA baseline degenerate: retained as an outcome; comparison is NOT ready.\n');
        end
    end
    f=fieldnames(Z);for i=1:numel(f),R.(f{i})=Z.(f{i});end
    if isempty(candidates),selectionProtocol='no_driver_candidate_selection';
    elseif strcmp(D.evaluation,'synthetic'),selectionProtocol='independent_same_condition_latent_truth_development';
    else,selectionProtocol='clean_gallery_validation_no_probe';end
    saved=struct('signature',signature,'job',job,'record',R,'metadata',meta, ...
        'model',model,'selection',candidates,'selectionLockedBeforeProbe',true,'algorithm',A);
    saved.selectionProtocol=selectionProtocol;
    if trace
        saved.checkpointMetrics=NB_CHECKPOINT_METRICS(model,K.X,D.evaluation,D,true);
        if strcmp(method,'C3')
            saved.mechanism=NB_MECHANISM(K,P0_METHODS('core',C),A,regime,model.checkpoints);
        end
    end
end
function r=candidate_row()
    r=struct('Value',NaN,'ValidationNRE',NaN,'Seconds',NaN,'Gamma',NaN, ...
        'InitialNonzeroFraction',NaN,'FinalNonzeroFraction',NaN,'Degenerate',false, ...
        'ExitStatus','','Iterations',NaN,'CovarianceRank',NaN);
end
function [Kv,Dv]=development_case(C,job,K,D,A)
% Genuine independent synthetic development realization; no evaluation truth.
    if strcmp(D.evaluation,'synthetic')
        [~,S]=P0_ALG(C,'synthetic');S.noiseSigma=job.NoiseSigma;
        seed=K.Seed+30000000;rng(seed,'twister');
        a=SU_SYN_FROZEN('generate',S,job.Case.NominalRate,job.Case.Type,job.Case.Strength);
        rng(seed+123,'twister');[U,V]=SU_SYN_FROZEN('initialize',a.X,K.rank(1),K.rank(2),struct('id','INIT'),A);
        Kv=K;Kv.X=a.X;Kv.mask=a.mask;Kv.U0=U;Kv.V0=V;
        Dv=struct('evaluation','synthetic','Xclean',a.X0,'developmentSeed',seed);
    else
        Kv=K;Dv=struct('evaluation','real','gallery',D.gallery,'cfg',D.cfg);
        % Dv intentionally contains no probe, probeLabels, or evaluation metrics.
    end
end
function z=validation_nre(K,D,m)
    mu=zeros(size(K.X,1),size(K.X,2));if isfield(m,'mean'),mu=m.mean;end
    if strcmp(D.evaluation,'synthetic'),X=K.X;Y=D.Xclean;else,X=D.gallery;Y=X;end
    v=0;
    for i=1:size(X,3),a=X(:,:,i)-mu;e=Y(:,:,i)-(mu+m.U*(m.U'*a*m.V)*m.V');v=v+sum(e(:).^2);end
    z=sqrt(v)/max(norm(Y(:)),eps);assert(isfinite(z),'NB:Selection','Nonfinite validation score');
end
function v=get(s,name,fallback)
    if isfield(s,name),v=s.(name);else,v=fallback;end
end
