function [model,Sfinal]=NB_SOLVER_TRACE(X,r,c,M,A,regime,U,V,mask)
% Instrumented clone of P0_SOLVER_V2 from frozen 20261031 package.
% Accepted updates, calibration, stopping rules and numerical thresholds are unchanged.
% Only basis/time checkpoints are copied; no held-out metric is evaluated online.
% A.nbTraceEvery (default 1) controls snapshot spacing in outer iterations.
% Under finite wall caps, even copying bases has overhead. For diagnostic budget
% curves use a predeclared outer cap and Inf wall cap, then compare checkpoints.
% Evaluate checkpoints after fitting; never use probe scores to choose stopping.
% Version 2. Frozen Q acceptance and honest stopping labels.
% No global convergence claim; numerical stability is checked at a fresh anchor.
    assert(all(isfinite(X(:)))&&isreal(X),'P0:Finite','Nonfinite/complex observations.');
    assert(isequal(size(X),size(mask)),'P0:Mask','Mask shape mismatch.');
    assert(r<size(X,1)&&c<size(X,2),'P0:Rank','Invalid rank.');
    tStart=tic;memory=0;A.regime=regime;
    traceEvery=1;
    if isfield(A,'nbTraceEvery'),traceEvery=A.nbTraceEvery;end
    assert(isscalar(traceEvery)&&isfinite(traceEvery)&&traceEvery>=1&&traceEvery==fix(traceEvery), ...
        'NB:TraceEvery','nbTraceEvery must be a positive integer.');
    copySeconds=0;
    checkpoints=struct('Outer',0,'Seconds',toc(tStart),'U',U,'V',V,'Memory',0);
    innerTrace=zeros(0,numel(P0_TRACE_HEADERS('inner')));
    outerTrace=zeros(0,numel(P0_TRACE_HEADERS('outer')));
    status='budget_exhausted';reason='outer_iteration_limit';totalAccepted=0;gradientAccepted=0;
    lastAccepted=false;lastUsed=[];lastState=[];lastGrad=NaN;nextGrad=NaN;
    for outer=1:A.maxOuter
        if toc(tStart)>A.maxTimePerMethod,status='timecap';reason='time_limit';break;end
        E=SU_FROZEN('residual',X,U,V);[S,memory]=P0_STATE(E,M,A,regime,memory);
        lastUsed=SU_WEIGHT_METRICS(S.We,mask,E,S.tau,A.zeroTol);
        lastState=P0_MATH('shortstate',S);clear E;
        anchor=P0_MATH('evaluate',X,U,V,S,M,true);Ub=U;Vb=V;
        [U,V,T,trace]=P0_INNER(X,U,V,S,M,A,tStart,outer,anchor);
        innerTrace=[innerTrace;trace]; %#ok<AGROW>
        after=P0_MATH('evaluate',X,U,V,S,M,true);
        totalAccepted=totalAccepted+T.accepted;gradientAccepted=gradientAccepted+T.gradientAccepted;
        lastAccepted=T.lastAccepted;lastGrad=after.GradRelative;
        mv=P0_MATH('move',Ub,Vb,U,V);
        rel=abs(after.F-anchor.F)/max(1,abs(anchor.F));stateChange=NaN;nextGrad=NaN;
        stable=false;
        eligible=T.accepted>0||strcmp(T.status,'surrogate_stationary');
        if eligible&&~strcmp(T.status,'failed_search')&&~strcmp(T.status,'timecap') ...
                &&rel<=A.tolOuter&&mv<=A.projectorTolerance
            E=SU_FROZEN('residual',X,U,V);
            % Preview does not commit an extra severity-memory update.
            [Sn,~]=P0_STATE(E,M,A,regime,memory);clear E;
            stateChange=P0_MATH('statechange',S,Sn);
            fresh=P0_MATH('evaluate',X,U,V,Sn,M,true);nextGrad=fresh.GradRelative;
            stable=stateChange<=A.stateTolerance&&nextGrad<=A.gradientTolerance;
            clear Sn;
        end
        statuses={'inner_budget','surrogate_stationary','failed_search','timecap'};
        reasons={'inner_iteration_limit','verified_frozen_quadratic_gradient','no_acceptable_gradient_step','time_limit'};
        sc=find(strcmp(statuses,T.status),1);rc=find(strcmp(reasons,T.reason),1);
        assert(~isempty(sc)&&~isempty(rc),'P0:TraceCode','Unmapped stopping code.');
        outerTrace(end+1,:)=[outer S.guard S.tau S.eta S.current S.severity ...
            anchor.Qcode after.Qcode anchor.F after.F anchor.L after.L T.accepted ...
            T.gradientAccepted mv rel stateChange after.GradRelative nextGrad sc rc ...
            toc(tStart) lastUsed.ESS lastUsed.ZeroExact lastUsed.TPR0 lastUsed.FPR0 lastUsed.Precision0]; %#ok<AGROW>
        if isfield(A,'nbProgressEvery')&&A.nbProgressEvery>0&& ...
                (outer==1||mod(outer,A.nbProgressEvery)==0||outer==A.maxOuter||stable)
            fprintf('  outer %d/%d accepted=%d frozenGrad=%.3g eta=%.4g elapsed=%.1fs\n', ...
                outer,A.maxOuter,totalAccepted,after.GradRelative,S.eta,toc(tStart));
        end
        clear S;
        if mod(outer,traceEvery)==0
            copyTimer=tic;
            checkpoints(end+1)=struct('Outer',outer,'Seconds',toc(tStart),'U',U,'V',V,'Memory',memory); %#ok<AGROW>
            copySeconds=copySeconds+toc(copyTimer);
        end
        if strcmp(T.status,'timecap'),status='timecap';reason='time_limit';break;end
        if strcmp(T.status,'failed_search'),status='failed_search';reason=T.reason;break;end
        if stable,status='numerically_stable';reason='stable_state_and_verified_next_anchor_gradient';break;end
    end
    E=SU_FROZEN('residual',X,U,V);[Sfinal,~]=P0_STATE(E,M,A,regime,memory);
    D=SU_WEIGHT_METRICS(Sfinal.We,mask,E,Sfinal.tau,A.zeroTol);clear E;
    Bfinal=P0_MATH('evaluate',X,U,V,Sfinal,M,true);
    assert(norm(U'*U-eye(r),'fro')<1e-7&&norm(V'*V-eye(c),'fro')<1e-7,'P0:Orthogonal','Invalid final bases.');
    model=struct('solverVersion','v2','U',U,'V',V,'status',status,'StopReason',reason, ...
        'LastAttemptAccepted',lastAccepted,'AcceptedSteps',totalAccepted,'GradientAcceptedSteps',gradientAccepted, ...
        'outerIters',size(outerTrace,1),'TimeSeconds',toc(tStart),'finalTau',Sfinal.tau, ...
        'finalEta',Sfinal.eta,'finalGuard',Sfinal.guard,'finalTailSeverity',Sfinal.severity, ...
        'finalCurrentTailSeverity',Sfinal.current,'finalSampleWeights',Sfinal.Ws, ...
        'finalDiagnostics',D,'lastUsedDiagnostics',lastUsed,'lastUsedState',lastState, ...
        'finalState',P0_MATH('shortstate',Sfinal),'outerTrace',{outerTrace},'innerTrace',{innerTrace}, ...
        'finalConditionalObjective',Bfinal.F,'finalQuadraticCode',Bfinal.Qcode,'finalObj',Bfinal.L, ...
        'FinalRecomputedGradRelative',Bfinal.GradRelative,'LastFrozenGradRelative',lastGrad, ...
        'NextAnchorGradRelative',nextGrad);
    % Include an exact final basis even when the spacing skipped the last outer.
    if checkpoints(end).Outer~=size(outerTrace,1)
        copyTimer=tic;
        checkpoints(end+1)=struct('Outer',size(outerTrace,1),'Seconds',model.TimeSeconds,'U',U,'V',V,'Memory',memory);
        copySeconds=copySeconds+toc(copyTimer);
    end
    model.checkpoints=checkpoints;
    model.Instrumentation='basis_and_training_diagnostic_logging_posthoc_probe_metrics';
    model.CheckpointCopySeconds=copySeconds;
    model.CheckpointEvery=traceEvery;
    if isempty(innerTrace)
        model.ConditionalChecks=0;model.ConditionalViolations=0;model.AcceptedConditionalChecks=0;
        model.LWouldVetoCount=0;model.AcceptedStepsWithLossVeto=0;
        model.AcceptedQViolations=0;
    else
        app=innerTrace(:,19);ac=innerTrace(:,14);bad=innerTrace(:,20);
        model.ConditionalChecks=sum(app);model.ConditionalViolations=sum(bad);
        model.AcceptedConditionalChecks=sum(app&ac);
        model.LWouldVetoCount=sum(innerTrace(:,15)&innerTrace(:,16));
        model.AcceptedStepsWithLossVeto=sum(ac&innerTrace(:,16));
        model.AcceptedQViolations=sum(ac&~innerTrace(:,15));
    end
end
