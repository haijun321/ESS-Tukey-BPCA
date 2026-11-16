function report=SMPV_P0_SELFTEST(C)
% Engineering checks only. These generated arrays are NOT paper experiments.
    rng(202610040,'twister');Q=C;Q.syntheticBudget=[4 2 8];Q.syntheticTimeLimit=Inf;
    Q.syntheticDimensions=[18 9 7 2 2];[A,Syn]=SMPV_P0_ALG(Q,'synthetic');A.essGridSize=16;
    assert(strcmp(SMPV_SU_UTIL('hashnumeric',[1,2;3,4]), ...
        '1c91458a7b7f52d140580b2b8dc2f122eb1c07d2eb9f40bff79401bd615a0148'), ...
        'P0:Hash','Frozen numeric hash format mismatch.');
    K=SMPV_P0_METHODS('core',C);gradError=0;
    for j=1:12
        X=randn(7,6,4);U=SMPV_P0_MATH('qf',randn(7,3));V=SMPV_P0_MATH('qf',randn(6,2));
        St=struct('We',rand(size(X)),'a',.2+.8*rand(4,1),'guard',false,'tau',2);
        St.W=St.We;for i=1:4,St.W(:,:,i)=St.We(:,:,i)*St.a(i);end
        B=SMPV_P0_MATH('evaluate',X,U,V,St,K(3),true);
        dU=randn(size(U));dU=dU-U*(U'*dU);dV=randn(size(V));dV=dV-V*(V'*dV);h=1e-6;
        p=SMPV_P0_MATH('evaluate',X,U+h*dU,V+h*dV,St,K(3),false);
        m=SMPV_P0_MATH('evaluate',X,U-h*dU,V-h*dV,St,K(3),false);
        fd=(p.Qcode-m.Qcode)/(2*h);an=sum(B.gU(:).*dU(:))+sum(B.gV(:).*dV(:));
        gradError=max(gradError,abs(fd-an)/max([1 abs(fd) abs(an)]));
        Ou=SMPV_P0_MATH('qf',randn(3));Ov=SMPV_P0_MATH('qf',randn(2));
        rot=SMPV_P0_MATH('evaluate',X,U*Ou,V*Ov,St,K(3),true);
        assert(abs(rot.Qcode-B.Qcode)<1e-9*(1+abs(B.Qcode)),'P0:Invariant','Basis rotation changes Q.');
        aligned=SMPV_P0_MATH('align',U,-U);
        assert(norm(aligned-U,'fro')<1e-10,'P0:Alignment','Sign alignment failed.');
    end
    assert(gradError<2e-6,'P0:Gradient','Directional derivative check failed.');
    rng(152401,'twister');data=SMPV_SU_SYN_FROZEN('generate',Syn,.1,'block_coherent',4);
    rng(152401,'twister');data2=SMPV_SU_SYN_FROZEN('generate',Syn,.1,'block_coherent',4);
    assert(isequal(data.X,data2.X)&&isequal(data.mask,data2.mask),'P0:Seed','Generator replay mismatch.');
    [U,V]=SMPV_SU_SYN_FROZEN('initialize',data.X,2,2,K(3),A);
    E=SMPV_SU_FROZEN('residual',data.X,U,V);[St,~]=SMPV_P0_STATE(E,K(3),A,'synthetic',0);
    anchor=SMPV_P0_MATH('evaluate',data.X,U,V,St,K(3),true);
    for j=1:20
        u=SMPV_P0_MATH('qf',randn(size(U)));v=SMPV_P0_MATH('qf',randn(size(V)));
        B=SMPV_P0_MATH('evaluate',data.X,u,v,St,K(3),false);upper=anchor.F+.5*(B.Qcode-anchor.Qcode);
        assert(B.F<=upper+1e-8*(1+abs(upper)),'P0:Majorizer','Tukey outer-anchor bound failed.');
    end
    for j=2:4
        [s,~]=SMPV_P0_STATE(E,K(j),A,'synthetic',0);
        assert(isequaln(s.severity,St.severity)&&~s.guard&&all(s.a==1),'P0:Core','CORE control mismatch.');
    end
    [ut,vt,ok,~,~]=SMPV_P0_MATH('gradient_search',data.X,U,V,St,K(3),A,tic);
    B=SMPV_P0_MATH('evaluate',data.X,ut,vt,St,K(3),false);
    assert(ok&&B.Qcode<=anchor.Qcode+A.mmAcceptTol*(1+abs(anchor.Qcode)),'P0:Fallback','Gradient fallback failed.');
    % Deterministic guarded counterexample: weighted Q decreases, unweighted L increases.
    X=zeros(2,2,2);X(:,:,1)=diag([3 0]);X(:,:,2)=diag([0 3.5]);
    G=struct('We',ones(size(X)),'W',ones(size(X)),'a',[1;.6],'guard',true,'tau',100);
    G.W(:,:,2)=.6;u0=[0;1];u1=[1;0];
    b=SMPV_P0_MATH('evaluate',X,u0,u0,G,K(3),true);z=SMPV_P0_MATH('evaluate',X,u1,u1,G,K(3),true);
    assert(z.Qcode<b.Qcode&&z.L>b.L&&abs(z.F-.5*z.Qcode)<1e-12, ...
        'P0:Guard','Guard objective conflict/equality check failed.');
    % A finite unsuccessful gradient search must retain a failure label.
    X=reshape(diag([10 0]),2,2,1);u=[cos(.02);sin(.02)];
    G.We=ones(size(X));G.W=G.We;G.a=1;G.guard=false;G.tau=NaN;
    L=K(1);L.loss='l2';B=A;B.gradientBacktracks=0;
    [~,~,ok,st,~]=SMPV_P0_MATH('gradient_search',X,u,u,G,L,B,tic);
    assert(~ok&&strcmp(st,'failed_search'),'P0:Stop','Failed search falsely certified stationary.');
    % Exact/near/strict-zero distinction and undefined ratios.
    e=[0 .5 1 1+eps(1) 2];w=SMPV_SU_FROZEN('tukeyweights',e,1);mask=logical([0 0 0 1 1]);
    d=SMPV_SU_WEIGHT_METRICS(w,mask,e,1,1e-12);
    assert(d.ZeroCount==3&&d.BoundaryCount==1&&d.TPR0==1&&abs(d.FPR0-1/3)<1e-12,'P0:Boundary','Zero boundary semantics differ.');
    d=SMPV_SU_WEIGHT_METRICS(ones(size(e)),false(size(e)),e,10,1e-12);
    assert(isnan(d.TPR0)&&isnan(d.Precision0),'P0:Undefined','Undefined mask ratios were replaced by zero.');
    stats=SMPV_P0_STATS(ones(4,1),C,923,true);
    assert(abs(stats.P-.125)<1e-12,'P0:SignFlip','Exact symmetric sign-flip test failed.');
    h=SMPV_P0_HOLM([.01 .04 .03 NaN]);
    assert(max(abs(h(1:3)-[.03 .06 .06]))<1e-12&&isnan(h(4)),'P0:Holm','Holm adjustment failed.');
    % Legacy instrumentation must reproduce each frozen synthetic Tukey solver.
    M=SMPV_P0_METHODS('solver',C);replayError=0;
    for j=1:numel(M)
        [u,v]=SMPV_SU_SYN_FROZEN('initialize',data.X,2,2,M(j),A);
        old=SMPV_SU_SYN_FROZEN('fit',data.X,2,2,M(j),A);
        inst=SMPV_SU_SOLVER(data.X,2,2,M(j),A,'synthetic',u,v,data.mask,data.X-data.Xbase,[]);
        err=norm(old.U*old.U'-inst.U*inst.U','fro')+norm(old.V*old.V'-inst.V*inst.V','fro');
        replayError=max(replayError,err);
        assert(err<1e-8&&abs(old.finalTau-inst.finalTau)<1e-10,'P0:LegacyReplay','Frozen synthetic replay differs.');
    end
    % Frozen real solver replay on engineering-only arrays, without loading images.
    Ar=A;Ar.useSeverityMemory=true;Ar.realTailReferenceEnabled=false;
    Ar.severityMemoryMode='max'; % Required by frozen V1.7 real solver.
    Ar.realTail=struct('enabled',true,'baselineFeatures',[1 1 1 1],'severityThreshold',1);
    Ar.realSample=struct('enabled',true,'neutralThreshold',.1,'fullDownweightThreshold',2);
    m=M(end);[u,v]=SMPV_SU_FROZEN('initialize',data.X,2,2,m,Ar);
    mf=m;mf.engine='bpca';cfg=struct('alg',Ar);
    old=SMPV_SU_FROZEN('fit',data.X,2,2,mf,cfg);
    inst=SMPV_SU_SOLVER(data.X,2,2,m,Ar,'real',u,v,data.mask,data.X-data.Xbase,[]);
    err=norm(old.U*old.U'-inst.U*inst.U','fro')+norm(old.V*old.V'-inst.V*inst.V','fro');
    assert(err<1e-8,'P0:RealReplay','Frozen real replay differs.');replayError=max(replayError,err);
    for j=1:numel(K)
        [model,~]=SMPV_P0_SOLVER_V2(data.X,2,2,K(j),A,'synthetic',U,V,data.mask);
        assert(model.ConditionalViolations==0,'P0:Trace','Conditional trace violation.');
        assert(~strcmp(model.status,'stationary')&&~strcmp(model.status,'converged'),'P0:Label','Unqualified stationarity label.');
        if strcmp(model.status,'numerically_stable')
            assert(model.FinalRecomputedGradRelative<=A.gradientTolerance*(1+1e-8),'P0:Certificate','Stable label without small fresh-anchor gradient.');
        end
    end
    report=struct('Pass',true,'MaximumGradientCheckError',gradError,'MaximumLegacyProjectorError',replayError, ...
        'TukeyMajorizerTrials',20,'GuardEqualityAndLossConflict',true,'GradientFallback',true, ...
        'HonestFailedSearch',true,'UndefinedRatiosRemainNaN',true,'CORESeverityMatchedAtFixedResiduals',true, ...
        'ExactSignFlipAndHolm',true, ...
        'EngineeringOnly',true,'ScientificExperimentsExecuted',false,'Environment',version);
    disp(report);
end
