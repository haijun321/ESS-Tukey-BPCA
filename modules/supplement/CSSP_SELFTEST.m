function report=CSSP_SELFTEST(C)
% Engineering checks on generated arrays. Never produces paper observations.
% Run this function in MATLAB; a static-parser pass is not this test's pass.
    if nargin<1||isempty(C)
        C=CSSP_SETUP('pilot',struct('archiveRoot','ENGINEERING_SELFTEST_NO_ARCHIVE_USED'));
    end
    oldRng=rng;restoreRng=onCleanup(@()rng(oldRng));
    rng(2026111501,'twister');
    Q=C;Q.includeFixedEtaNoZero=true;
    Q.syntheticBudget=[4 2 8];Q.syntheticTimeLimit=Inf;
    Q.syntheticDimensions=[12 9 7 2 2];
    [A,~]=P0_ALG(Q,'synthetic');A.essGridSize=16;
    A.nbTraceEvery=1;A.nbProgressEvery=0;
    methods=P0_METHODS('core',Q);
    assert(isequal({methods.id},{'C1','C2','C3','C4','C5'}), ...
        'CSSP:SelftestFactorial','The complete C1--C5 plan is unavailable.');
    assert(strcmp(methods(5).etaMode,'fixed')&&methods(5).etaValue==.85 ...
        &&~methods(5).useZeroCalibration&&~methods(5).cleanGuard ...
        &&~methods(5).sampleMode,'CSSP:SelftestFactorial','C5 is not fixed-eta/no-zero.');
    assert(~methods(4).useZeroCalibration&&methods(2).useZeroCalibration ...
        &&methods(3).useZeroCalibration,'CSSP:SelftestFactorial','Factorial controls changed.');

    % Verify the actual MATLAB gradient using directional finite differences.
    maximumGradientError=0;
    for trial=1:6
        Xg=randn(7,6,4);ug=P0_MATH('qf',randn(7,3));vg=P0_MATH('qf',randn(6,2));
        St=struct('We',rand(size(Xg)),'a',.2+.8*rand(4,1),'guard',false,'tau',2);
        St.W=St.We;for k=1:4,St.W(:,:,k)=St.We(:,:,k)*St.a(k);end
        actual=P0_MATH('evaluate',Xg,ug,vg,St,methods(3),true);
        du=randn(size(ug));du=du-ug*(ug'*du);
        dv=randn(size(vg));dv=dv-vg*(vg'*dv);h=1e-6;
        plus=P0_MATH('evaluate',Xg,ug+h*du,vg+h*dv,St,methods(3),false);
        minus=P0_MATH('evaluate',Xg,ug-h*du,vg-h*dv,St,methods(3),false);
        fd=(plus.Qcode-minus.Qcode)/(2*h);
        derivative=sum(actual.gU(:).*du(:))+sum(actual.gV(:).*dv(:));
        maximumGradientError=max(maximumGradientError, ...
            abs(fd-derivative)/max([1 abs(fd) abs(derivative)]));
    end
    assert(maximumGradientError<2e-6,'CSSP:SelftestGradient', ...
        'Native weighted-projector gradient failed a finite-difference check.');

    % Construct a small low-rank signal with sparse additive contamination.
    Utrue=P0_MATH('qf',randn(9,2));Vtrue=P0_MATH('qf',randn(7,2));
    clean=zeros(9,7,12);
    for i=1:12,clean(:,:,i)=Utrue*randn(2)*Vtrue';end
    X=clean+.02*randn(size(clean));mask=false(size(X));mask(1:2,3:4,4)=true;
    X(mask)=X(mask)+8;
    [U0,V0]=SU_SYN_FROZEN('initialize',X,2,2,methods(3),A);
    K=struct('X',X,'mask',mask,'U0',U0,'V0',V0,'rank',[2 2], ...
        'caseHash','generated_engineering_case','initHash','generated_engineering_init', ...
        'InitializationSeconds',0,'Dataset','SELFTEST','Condition','fixture', ...
        'Repeat',1,'Seed',2026111501,'Regime','synthetic','regime','synthetic');
    mechanism=CSSP_MECHANISM(K,A,Q);
    assert(sum([mechanism.Selected])==4 ...
        &&numel(unique({mechanism.ResidualHash}))==1, ...
        'CSSP:SelftestMechanism','The four scoring rules did not share one residual.');
    for id={'C2','C3','C4','C5'}
        local=mechanism(strcmp({mechanism.Method},id{1}));
        chosen=local([local.Selected]);
        assert(isscalar(chosen)&&abs(chosen.Score-min([local.Score]))<1e-12, ...
            'CSSP:SelftestMechanism','An indicated cutoff is not a candidate-score minimum.');
    end
    zeroCase=K;zeroCase.X=zeros(size(K.X));
    zeroMechanism=CSSP_MECHANISM(zeroCase,A,Q);
    assert(sum([zeroMechanism.Selected])==4&&all([zeroMechanism.ESSExact]==1) ...
        &&all([zeroMechanism.Tau]==1), ...
        'CSSP:SelftestMechanismZero','Zero-residual shortcut does not match native selection.');
    Ds=struct('evaluation','synthetic','Xclean',clean,'Atrue',Utrue,'Btrue',Vtrue);
    initMetric=NB_EVALUATE(K,Ds,struct('U',U0,'V',V0),[]);
    assert(isfinite(initMetric.NRE)&&isfinite(initMetric.ErrSubNorm), ...
        'CSSP:SelftestInitialMetric','Initial metrics are not finite.');

    maxReplayError=0;
    for j=1:numel(methods)+1
        if j<=numel(methods),M=methods(j);else,M=NB_NATIVE_METHOD(Q,'L2');end
        [model,S]=P0_SOLVER_V2(X,2,2,M,A,'synthetic',U0,V0,mask);
        metric=NB_EVALUATE(K,Ds,model,S);
        assert(isfinite(metric.NRE)&&isfinite(model.finalQuadraticCode), ...
            'CSSP:SelftestFinite','A native method returned a nonfinite fit.');
        assert(norm(model.U'*model.U-eye(2),'fro')<1e-8 ...
            &&norm(model.V'*model.V-eye(2),'fro')<1e-8, ...
            'CSSP:SelftestOrthogonal','A native method lost orthogonality.');
        assert(any(strcmp(model.status,{'budget_exhausted','timecap', ...
            'failed_search','numerically_stable'})), ...
            'CSSP:SelftestStop','An unknown or unqualified convergence label was returned.');
        assert(model.AcceptedSteps<=A.maxOuter*A.maxInner, ...
            'CSSP:SelftestAccepted','Accepted updates exceed the configured maximum.');
        assert(model.ConditionalViolations==0&&model.AcceptedQViolations==0, ...
            'CSSP:SelftestMajorizer','A recorded update violated its acceptance condition.');
        if strcmp(model.status,'numerically_stable')
            assert(model.FinalRecomputedGradRelative<=A.gradientTolerance*(1+1e-8), ...
                'CSSP:SelftestStable','Stable label lacks a freshly checked gradient.');
        end
    end

    % The mask is a diagnostic input, not information allowed to alter fitting.
    [base,~]=P0_SOLVER_V2(X,2,2,methods(3),A,'synthetic',U0,V0,mask);
    [noMask,~]=P0_SOLVER_V2(X,2,2,methods(3),A,'synthetic',U0,V0,false(size(mask)));
    maskError=projector_error(base,noMask);
    assert(maskError<1e-11,'CSSP:SelftestMask','The oracle contamination mask altered the fit.');

    [traced,~]=NB_SOLVER_TRACE(X,2,2,methods(3),A,'synthetic',U0,V0,mask);
    maxReplayError=max(maxReplayError,projector_error(base,traced));
    assert(maxReplayError<1e-10&&strcmp(base.status,traced.status) ...
        &&base.AcceptedSteps==traced.AcceptedSteps, ...
        'CSSP:SelftestTrace','Training-only instrumentation changed the fitting path.');
    first=traced.checkpoints(1);
    assert(first.Outer==0&&isequal(first.U,U0)&&isequal(first.V,V0), ...
        'CSSP:SelftestCheckpoint','Checkpoint zero is not the actual common initialization.');
    checkpoints=NB_CHECKPOINT_METRICS(traced,X,'synthetic',Ds,false);
    finalMetric=NB_EVALUATE(K,Ds,traced,[]);
    assert(abs(checkpoints(1).NRE-initMetric.NRE)<1e-11 ...
        &&abs(checkpoints(end).NRE-finalMetric.NRE)<1e-11, ...
        'CSSP:SelftestReadout','Endpoint and checkpoint metric protocols disagree.');

    % A nonzero model center must be restored in reconstruction and features.
    u=eye(9,2);v=eye(7,2);mu=zeros(9,7);mu(9,7)=5;
    Z=zeros(9,7,4);values=[-2 -1 1 2];
    for i=1:4,Z(:,:,i)=mu;Z(1,1,i)=values(i);end
    Dm=struct('evaluation','synthetic','Xclean',Z,'Atrue',u,'Btrue',v);
    Km=K;Km.X=Z;Km.mask=false(size(Z));
    centered=NB_EVALUATE(Km,Dm,struct('U',u,'V',v,'mean',mu),[]);
    missingMean=NB_EVALUATE(Km,Dm,struct('U',u,'V',v),[]);
    assert(centered.NRE<1e-12&&missingMean.NRE>.5, ...
        'CSSP:SelftestCenter','Mean-aware reconstruction is not correctly distinguished.');
    probe=repmat(mu,1,1,2);probe(1,1,1)=-1.5;probe(1,1,2)=1.5;
    Dr=struct('evaluation','real','gallery',Z,'galleryLabels',[1;1;2;2], ...
        'probe',probe,'probeLabels',[1;2], ...
        'cfg',struct('classifier',struct('zscoreFeatures',true)));
    result=NB_EVALUATE(Km,Dr,struct('U',u,'V',v,'mean',mu),[]);
    assert(result.NRE<1e-12&&result.ACC==1, ...
        'CSSP:SelftestRealReadout','Centered held-out readout is incorrect.');

    % At the Tukey cutoff the exact zero and strict operational exceedance differ.
    e=[0 .5 1 1+eps(1) 2];w=SU_FROZEN('tukeyweights',e,1);
    assert(sum(w==0)==3&&sum(abs(e)>1)==2, ...
        'CSSP:SelftestZeroBoundary','Exact and operational zero counts were conflated.');
    [operationalESS,operationalZero]=SU_FROZEN('esszero',abs(e),1,1e-12,50000);
    assert(abs(operationalESS-ess_ratio(w))<1e-12&&abs(operationalZero-.4)<1e-12, ...
        'CSSP:SelftestOperationalZero','The frozen selector does not retain strict exceedance semantics.');
    wa=[.001*ones(1,8) 0 0];wb=[ones(1,5) ones(1,5)/3];
    assert(abs(ess_ratio(wa)-.8)<1e-12&&abs(ess_ratio(wb)-.8)<1e-12, ...
        'CSSP:SelftestESS','Positive equal weights with zeros were normalized incorrectly.');

    report=struct('Pass',true,'EngineeringOnly',true, ...
        'ScientificExperimentsExecuted',false,'NativeRuntimeExecuted',true, ...
        'FactorialC5Correct',true,'NativeMethodsChecked',numel(methods)+1, ...
        'NativeGradientFiniteDifference',true,'MaximumGradientRelativeError',maximumGradientError, ...
        'FrozenResidualFourScoreAudit',true,'ZeroResidualSelectorShortcut',true, ...
        'OracleMaskFitInvariant',true,'MaximumMaskProjectorDifference',maskError, ...
        'MaximumInstrumentedProjectorDifference',maxReplayError, ...
        'ActualInitializationCheckpoint',true,'ConsistentEndpointReadout',true, ...
        'MeanAwareReconstruction',true,'ExactVersusOperationalZero',true, ...
        'ESSWithZeroWeights',true,'Environment',version);
    % New-driver cache and selection checks are added after its dependencies exist.
    if exist('CSSP_FIT_NATIVE','file')==2&&exist('CSSP_SELECTION','file')==2 ...
            &&exist('CSSP_SOURCE','file')==2
        report.Driver=driver_checks(C,K,A,Dr);
    else
        error('CSSP:SelftestIncompletePackage', ...
            'CSSP_FIT_NATIVE, CSSP_SELECTION, and CSSP_SOURCE must be available.');
    end
    report.Summary=CSSP_SUMMARY_SELFTEST();
    report.Import=CSSP_IMPORT_SELFTEST(C);
    fprintf('CSSP_SELFTEST PASS: engineering arrays only; no paper experiment executed.\n');
    clear restoreRng;
end

function q=driver_checks(C,K,A,Dr)
    out=tempname;mkdir(out);cleanup=onCleanup(@()remove_tree(out));
    C.outputRoot=out;C.stage='pilot';C.cacheRoot=fullfile(out,'pilot','native_cache');
    C.stopFile=fullfile(out,'REQUEST_STOP.flag');
    C.priorResultRoots={}; % Engineering cache checks never inspect user results.
    C.includeFixedEtaNoZero=true;C.etaGrid=[.85 .94];C.cGrid=[2.5 4.685];
    C.coreHash=CSSP_SOURCE('core',C);
    [a,sa,ia]=CSSP_FIT_NATIVE(C,K,A,'C3');
    [b,sb,ib]=CSSP_FIT_NATIVE(C,K,A,'C3');
    assert(ib.CacheHit&&strcmp(ia.Signature,ib.Signature)&&projector_error(a,b)<1e-12, ...
        'CSSP:SelftestCache','Exact native-cache replay failed.');
    assert(isequaln(sa.We,sb.We)&&isequaln(sa.a,sb.a), ...
        'CSSP:SelftestCacheState','Cached final weights changed after reconstruction.');
    relabeled=K;relabeled.Module='different_module';relabeled.Condition='different_label';
    [~,~,relabeledInfo]=CSSP_FIT_NATIVE(C,relabeled,A,'C3');
    assert(relabeledInfo.CacheHit&&strcmp(ia.Signature,relabeledInfo.Signature), ...
        'CSSP:SelftestCacheLabels','Only relabeling a scientifically identical fit changed its identity.');
    [~,~,fixed]=CSSP_FIT_NATIVE(C,K,A,'C2');
    [~,~,equivalent]=CSSP_FIT_NATIVE(C,K,A,'TunedEta',.85);
    assert(equivalent.CacheHit&&strcmp(fixed.Signature,equivalent.Signature), ...
        'CSSP:SelftestCache','Scientifically equivalent C2 and TunedEta did not share a fit.');
    changed=K;changed.X(1)=changed.X(1)+1e-3;
    [~,~,different]=CSSP_FIT_NATIVE(C,changed,A,'C3');
    assert(~strcmp(ia.Signature,different.Signature), ...
        'CSSP:SelftestCache','A changed training array reused an old cache identity.');

    % Use a real-style engineering reference, never a raw-data archive.
    Ar=A;Ar.useSeverityMemory=true;Ar.realTailReferenceEnabled=false;
    Ar.severityMemoryMode='max';
    Ar.realTail=struct('enabled',true,'baselineFeatures',[1 1 1 1],'severityThreshold',1);
    Ar.realSample=struct('enabled',true,'neutralThreshold',.1,'fullDownweightThreshold',2);
    Kr=K;Kr.Regime='real';Kr.regime='real';
    Dr.gallery=K.X(:,:,1:4);Dr.probe=K.X(:,:,5:6);
    Dr.galleryLabels=[1;1;2;2];Dr.probeLabels=[1;2];
    [~,~,s1,r1]=CSSP_SELECTION(C,Kr,Dr,Ar,'TunedEta');
    assert(exist(r1.LockPath,'file')==2&&~r1.ProbeScoredBeforeLock, ...
        'CSSP:SelftestSelectionLock','Selection did not commit a pre-probe lock.');
    poisoned=Dr;poisoned.probe=1e6*randn(size(Dr.probe));poisoned.probeLabels=[2;1];
    [~,~,s2,r2]=CSSP_SELECTION(C,Kr,poisoned,Ar,'TunedEta');
    assert(r1.SelectedValue==r2.SelectedValue&&strcmp(r1.SelectionHash,r2.SelectionHash) ...
        &&isequaln([s1.ValidationNRE],[s2.ValidationNRE]), ...
        'CSSP:SelftestSelectionLeak','Changing held-out probe data altered parameter selection.');
    q=struct('Pass',true,'ExactCacheReplay',true,'EquivalentCandidatesReused',true, ...
        'FinalWeightReconstruction',true,'LabelsDoNotAlterScientificIdentity',true, ...
        'ChangedTrainingDataInvalidatesCache',true,'SelectionLockBeforeProbe',true, ...
        'ProbePerturbationLeavesSelectionUnchanged',true);
    clear cleanup;
end

function z=projector_error(a,b)
    z=norm(a.U*a.U'-b.U*b.U','fro')+norm(a.V*a.V'-b.V*b.V','fro');
end
function z=ess_ratio(w)
    z=sum(w)^2/sum(w.^2)/numel(w);
end
function remove_tree(folder)
    if exist(folder,'dir')==7,rmdir(folder,'s');end
end
