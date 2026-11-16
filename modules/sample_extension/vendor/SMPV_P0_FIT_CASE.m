function R=SMPV_P0_FIT_CASE(C,module,K,D,M,A,regime,version,budget,protocolHash,scientific)
% Resume validates source/config/case/init signatures and never overwrites fits.
    SMPV_P0_IO('checkstop',C.stopFile);tAll=tic;tInit=tic;
    if strcmp(M.loss,'l2')
        a=A;a.initMode='l2';
        if strcmp(regime,'real'),[U0,V0]=SMPV_SU_FROZEN('initialize',K.X,K.rank(1),K.rank(2),M,a);
        else,[U0,V0]=SMPV_SU_SYN_FROZEN('initialize',K.X,K.rank(1),K.rank(2),M,a);end
        K.initHash=SMPV_P0_IO('hashtext',[SMPV_P0_IO('hashnumeric',U0) SMPV_P0_IO('hashnumeric',V0)]);
    else,U0=K.U0;V0=K.V0;end
    initSeconds=toc(tInit)+K.InitializationSeconds;
    meta=struct('protocolHash',protocolHash,'caseHash',K.caseHash,'initHash',K.initHash, ...
        'rank',K.rank,'method',M,'alg',A,'regime',regime,'version',version,'budget',budget);
    signature=SMPV_P0_IO('hashtext',jsonencode(meta));
    id=sprintf('%s_r%03d_%s_%s_%s_B%d',K.Dataset,K.Repeat,K.Condition,M.id,version,budget);
    folder=fullfile(C.outputRoot,module,'fits',id);file=fullfile(folder,'fit.mat');
    if exist(file,'file')
        saved=SMPV_P0_IO('load',file);
        assert(strcmp(saved.signature,signature),'P0:Resume','Cached fit signature differs: %s',id);
        R=saved.record;fprintf('SKIP %s\n',id);return;
    end
    fprintf('FIT %s | %d x %d x %d | rank %d x %d\n',id,size(K.X,1),size(K.X,2),size(K.X,3),K.rank);
    if strcmp(version,'legacy')
        assert(strcmp(M.loss,'tukey'),'P0:Legacy','Legacy paired experiment is limited to Tukey methods.');
        delta=[];if isfield(D,'Delta'),delta=D.Delta;end
        model=SMPV_SU_SOLVER(K.X,K.rank(1),K.rank(2),M,A,regime,U0,V0,K.mask,delta,[]);
        S=legacy_state(K.X,model,A);
        if isempty(model.innerTrace),model.LWouldVetoCount=0;
        else
            z=model.innerTrace;model.LWouldVetoCount=sum(z(:,6)<=z(:,5)+A.mmAcceptTol*(1+abs(z(:,5))) ...
                &z(:,8)>z(:,7)+A.mmAcceptTol*(1+abs(z(:,7))));
        end
    else
        [model,S]=SMPV_P0_SOLVER_V2(K.X,K.rank(1),K.rank(2),M,A,regime,U0,V0,K.mask);
    end
    metrics=SMPV_P0_METRICS(K.X,K.mask,model,S,regime,D);
    R=SMPV_P0_RECORD(module,K,M,A,model,metrics,version,budget,signature,initSeconds,toc(tAll)+K.InitializationSeconds,scientific);
    saved=struct('signature',signature,'metadata',meta,'record',R,'model',model);
    SMPV_P0_IO('mkdir',folder);
    % Export traces before committing fit.mat; a committed fit has complete traces.
    if strcmp(version,'v2')
        SMPV_P0_IO('csv',fullfile(folder,'inner_trace.csv'),SMPV_P0_TRACE_HEADERS('inner'),model.innerTrace);
        SMPV_P0_IO('csv',fullfile(folder,'outer_trace.csv'),SMPV_P0_TRACE_HEADERS('outer'),model.outerTrace);
    else
        h={'Outer','Inner','Trial','Step','QBefore','QTrial','LBefore','LTrial','FTrial', ...
            'QAnchor','FAnchor','AnchorUpper','Accepted','MajorizerApplicable','MajorizerViolation','CandidateMove'};
        SMPV_P0_IO('csv',fullfile(folder,'legacy_inner_trace.csv'),h,model.innerTrace);
    end
    SMPV_P0_IO('csv',fullfile(folder,'record.csv'),fieldnames(R)',struct2cell(R)');
    SMPV_P0_IO('save',file,saved);
    fprintf('SAVED %s | %s | NRE %.6f | Esub %.6f | accepted %d\n', ...
        id,R.Status,R.NRE,R.ErrSubNorm,R.AcceptedSteps);
end

function S=legacy_state(X,model,A)
    E=SMPV_SU_FROZEN('residual',X,model.U,model.V);
    if model.finalGuard,we=ones(size(E));else,we=SMPV_SU_FROZEN('tukeyweights',E,model.finalTau);end
    a=model.finalSampleWeights(:).^A.sampleWeightAlpha;w=we;
    for i=1:size(X,3),w(:,:,i)=w(:,:,i)*a(i);end
    S=struct('We',we,'W',w,'a',a,'Ws',model.finalSampleWeights,'guard',model.finalGuard, ...
        'tau',model.finalTau,'eta',model.finalEta,'current',model.finalCurrentTailSeverity, ...
        'severity',model.finalTailSeverity,'scale',SMPV_SU_FROZEN('mad',E(:),A.eps0));
end
