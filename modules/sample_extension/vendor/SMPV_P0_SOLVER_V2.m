function [model,Sfinal]=SMPV_P0_SOLVER_V2(X,r,c,M,A,regime,U,V,mask)
% Version 2. Frozen Q acceptance and honest stopping labels.
% No global convergence claim; numerical stability is checked at a fresh anchor.
    assert(all(isfinite(X(:)))&&isreal(X),'P0:Finite','Nonfinite/complex observations.');
    assert(isequal(size(X),size(mask)),'P0:Mask','Mask shape mismatch.');
    assert(r<size(X,1)&&c<size(X,2),'P0:Rank','Invalid rank.');
    tStart=tic;memory=0;A.regime=regime;
    innerTrace=zeros(0,numel(SMPV_P0_TRACE_HEADERS('inner')));
    outerTrace=zeros(0,numel(SMPV_P0_TRACE_HEADERS('outer')));
    status='budget_exhausted';reason='outer_iteration_limit';totalAccepted=0;gradientAccepted=0;
    lastAccepted=false;lastUsed=[];lastState=[];lastGrad=NaN;nextGrad=NaN;
    % Read-only sample diagnostics; no calibration or acceptance rule is changed.
    lastUsedA=ones(size(X,3),1);lastUsedV=lastUsedA;lastUsedD=nan(size(X,3),1);
    lastAcceptedA=ones(size(X,3),1);lastAcceptedD=nan(size(X,3),1);lastAcceptedV=lastAcceptedA;lastAcceptedOuter=NaN;
    sampleTrace=zeros(0,7);
    for outer=1:A.maxOuter
        if toc(tStart)>A.maxTimePerMethod,status='timecap';reason='time_limit';break;end
        E=SMPV_SU_FROZEN('residual',X,U,V);[S,memory]=SMPV_P0_STATE(E,M,A,regime,memory);
        lastUsed=hide_truth_labels(SMPV_SU_WEIGHT_METRICS(S.We,mask,E,S.tau,A.zeroTol));
        lastState=SMPV_P0_MATH('shortstate',S);
        lastUsedA=S.a(:);lastUsedV=S.Ws(:);
        lastUsedD=sqrt(mean(reshape(E,[],size(X,3)).^2,1)).';
        sa=sum(lastUsedA);sa2=sum(lastUsedA.^2);
        sampleTrace(end+1,:)=[outer sa^2/(numel(lastUsedA)*max(sa2,realmin)) ...
            min(lastUsedA) mean(lastUsedA) mean(lastUsedA<0.95) ...
            mean(lastUsedV<=A.sampleWeightMin+1e-12) toc(tStart)]; %#ok<AGROW>
        clear E;
        anchor=SMPV_P0_MATH('evaluate',X,U,V,S,M,true);Ub=U;Vb=V;
        [U,V,T,trace]=SMPV_P0_INNER(X,U,V,S,M,A,tStart,outer,anchor);
        if T.accepted>0
            lastAcceptedA=lastUsedA;lastAcceptedD=lastUsedD;lastAcceptedV=lastUsedV;lastAcceptedOuter=outer;
        end
        innerTrace=[innerTrace;trace]; %#ok<AGROW>
        after=SMPV_P0_MATH('evaluate',X,U,V,S,M,true);
        totalAccepted=totalAccepted+T.accepted;gradientAccepted=gradientAccepted+T.gradientAccepted;
        lastAccepted=T.lastAccepted;lastGrad=after.GradRelative;
        mv=SMPV_P0_MATH('move',Ub,Vb,U,V);
        rel=abs(after.F-anchor.F)/max(1,abs(anchor.F));stateChange=NaN;nextGrad=NaN;
        stable=false;
        eligible=T.accepted>0||strcmp(T.status,'surrogate_stationary');
        if eligible&&~strcmp(T.status,'failed_search')&&~strcmp(T.status,'timecap') ...
                &&rel<=A.tolOuter&&mv<=A.projectorTolerance
            E=SMPV_SU_FROZEN('residual',X,U,V);
            % Preview does not commit an extra severity-memory update.
            [Sn,~]=SMPV_P0_STATE(E,M,A,regime,memory);clear E;
            stateChange=SMPV_P0_MATH('statechange',S,Sn);
            fresh=SMPV_P0_MATH('evaluate',X,U,V,Sn,M,true);nextGrad=fresh.GradRelative;
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
        clear S;
        if strcmp(T.status,'timecap'),status='timecap';reason='time_limit';break;end
        if strcmp(T.status,'failed_search'),status='failed_search';reason=T.reason;break;end
        if stable,status='numerically_stable';reason='stable_state_and_verified_next_anchor_gradient';break;end
    end
    E=SMPV_SU_FROZEN('residual',X,U,V);[Sfinal,~]=SMPV_P0_STATE(E,M,A,regime,memory);
    D=hide_truth_labels(SMPV_SU_WEIGHT_METRICS(Sfinal.We,mask,E,Sfinal.tau,A.zeroTol));clear E;
    Bfinal=SMPV_P0_MATH('evaluate',X,U,V,Sfinal,M,true);
    assert(norm(U'*U-eye(r),'fro')<1e-7&&norm(V'*V-eye(c),'fro')<1e-7,'P0:Orthogonal','Invalid final bases.');
    model=struct('solverVersion','v2','U',U,'V',V,'status',status,'StopReason',reason, ...
        'LastAttemptAccepted',lastAccepted,'AcceptedSteps',totalAccepted,'GradientAcceptedSteps',gradientAccepted, ...
        'outerIters',size(outerTrace,1),'TimeSeconds',toc(tStart),'finalTau',Sfinal.tau, ...
        'lastAcceptedA',lastAcceptedA,'lastAcceptedV',lastAcceptedV,'lastAcceptedD',lastAcceptedD,'lastAcceptedOuter',lastAcceptedOuter, ...
        'lastUsedA',lastUsedA,'lastUsedV',lastUsedV,'lastUsedD',lastUsedD,'sampleTrace',sampleTrace, ...
        'finalEta',Sfinal.eta,'finalGuard',Sfinal.guard,'finalTailSeverity',Sfinal.severity, ...
        'finalCurrentTailSeverity',Sfinal.current,'finalSampleWeights',Sfinal.Ws, ...
        'finalDiagnostics',D,'lastUsedDiagnostics',lastUsed,'lastUsedState',lastState, ...
        'finalState',SMPV_P0_MATH('shortstate',Sfinal),'outerTrace',{outerTrace},'innerTrace',{innerTrace}, ...
        'finalConditionalObjective',Bfinal.F,'finalQuadraticCode',Bfinal.Qcode,'finalObj',Bfinal.L, ...
        'FinalRecomputedGradRelative',Bfinal.GradRelative,'LastFrozenGradRelative',lastGrad, ...
        'NextAnchorGradRelative',nextGrad);
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

function D=hide_truth_labels(D)
% Solver sees no truth labels. These conditional fields are unavailable.
    fields={'PositiveCount','NegativeCount','TP0','FP0','TPR0','FPR0','Precision0', ...
        'WeightClean','WeightCorrupt','ResidualClean','ResidualCorrupt'};
    for k=1:numel(fields),D.(fields{k})=NaN;end
    D.perImage(:,1:4)=NaN;
end
