function model=SU_SOLVER(X,r,c,M,A,regime,U,V,mask,Cdelta,snapshotOuter)
% Instrumented supplement. Proposal/acceptance and stopping follow each frozen engine.
% No global convergence claim. Output stores summaries, not dense weight histories.
    assert(all(isfinite(X(:)))&&r<size(X,1)&&c<size(X,2),'SU:Input','Invalid input/rank');
    if nargin<11,snapshotOuter=[1 5 10];end
    t=tic;memory=0;outerRows=[];innerRows=[];
    % MATLAB requires matching top-level fields for indexed struct assignment.
    snapshots=struct('outer',{},'U',{},'V',{},'memory',{},'state',{});
    lastUsed=[];status='budget_exhausted';reason='outer_budget';lastAccepted=false;totalAccepted=0;
    for outer=1:A.maxOuter
        if toc(t)>A.maxTimePerMethod,status='timecap';reason='time_limit';break;end
        E=SU_FROZEN('residual',X,U,V);[S,memory]=SU_STATE(E,M,A,regime,memory);
        D=SU_WEIGHT_METRICS(S.We,mask,E,S.tau,A.zeroTol);lastUsed=D;
        feat=SU_FROZEN('tailfeatures',E,A);
        before=loss(E,S.tau);Qanchor=sum(S.W(:).*E(:).^2);Fanchor=frozen_loss(E,S.tau,S.a);
        outerRows(end+1,:)=[outer,S.scale,median(E(:)),feat,S.current,S.severity,S.guard,S.eta,S.tau, ...
            D.ESS,D.ZeroExact,D.ZeroNear,D.TPR0,D.FPR0,D.WeightClean,D.WeightCorrupt, ...
            D.ResidualClean,D.ResidualCorrupt,absorption(Cdelta,U,V),mean(S.Ws),zeros(1,5)]; %#ok<AGROW>
        if outer==1||ismember(outer,snapshotOuter)
            snapshots(end+1)=struct('outer',outer,'U',U,'V',V,'memory',memory,'state',rmfield(S,{'We','W','Ws','a'})); %#ok<AGROW>
        end
        clear E D;
        sub='ok';subReason='inner_budget';acceptedThis=0;moveMax=0;
        for inner=1:A.maxInner
            if toc(t)>A.maxTimePerMethod,sub='timecap';subReason='time_limit';break;end
            E0=SU_FROZEN('residual',X,U,V);q0=sum(S.W(:).*E0(:).^2);l0=loss(E0,S.tau);
            Ximp=zeros(size(X));
            for i=1:size(X,3)
                Xi=X(:,:,i);xh=U*(U'*Xi*V)*V';wi=S.W(:,:,i);Ximp(:,:,i)=wi.*Xi+(1-wi).*xh;
            end
            if strcmp(regime,'real'),[Uc,Vc]=SU_FROZEN('warm',Ximp,U,V,A.fastBpcaSteps);
            else,[Uc,Vc]=SU_SYN_FROZEN('warm',Ximp,U,V,A.fastBpcaSteps);end
            clear Ximp E0;
            candMove=movement(U,V,Uc,Vc,regime);
            if strcmp(regime,'real')&&candMove<A.stationarityTol
                sub='stationary';subReason='small_candidate_without_acceptance_test';lastAccepted=false;break;
            end
            accepted=false;alpha=1;qc=NaN;lc=NaN;
            for ls=0:A.mmLineSearchMax
                if ls==0,Ut=Uc;Vt=Vc;
                else
                    alpha=A.mmShrink^ls;
                    if strcmp(regime,'real'),Ut=SU_FROZEN('qf',(1-alpha)*U+alpha*Uc);Vt=SU_FROZEN('qf',(1-alpha)*V+alpha*Vc);
                    else,Ut=SU_SYN_FROZEN('qf',(1-alpha)*U+alpha*Uc);Vt=SU_SYN_FROZEN('qf',(1-alpha)*V+alpha*Vc);end
                end
                Et=SU_FROZEN('residual',X,Ut,Vt);qt=sum(S.W(:).*Et(:).^2);lt=loss(Et,S.tau);ft=frozen_loss(Et,S.tau,S.a);
                if ls==0,qc=qt;lc=lt;end
                ok=qt<=q0+A.mmAcceptTol*(1+abs(q0))&&lt<=l0+A.mmAcceptTol*(1+abs(l0));
                upper=Fanchor+.5*(qt-Qanchor);applicable=~S.guard;
                violation=applicable&&ok&&ft>upper+1e-8*(1+abs(Fanchor)+abs(upper));
                innerRows(end+1,:)=[outer,inner,ls,alpha,q0,qt,l0,lt,ft,Qanchor,Fanchor,upper,ok,applicable,violation,candMove]; %#ok<AGROW>
                clear Et;
                if ok
                    mv=movement(U,V,Ut,Vt,regime);moveMax=max(moveMax,mv);
                    U=Ut;V=Vt;accepted=true;acceptedThis=acceptedThis+1;totalAccepted=totalAccepted+1;break;
                end
            end
            lastAccepted=accepted;
            if ~accepted
                if strcmp(regime,'real')
                    small=(A.mmShrink^(A.mmLineSearchMax+1))*candMove<A.stationarityTol;
                else
                    small=candMove<A.mmStationaryMoveTol||max(abs(qc-q0)/(abs(q0)+A.eps0),abs(lc-l0)/(abs(l0)+A.eps0))<A.mmStationaryRelTol;
                end
                if small,sub='stationary';else,sub='mm_stalled';end
                subReason='no_acceptable_step';break;
            end
        end
        Enew=SU_FROZEN('residual',X,U,V);after=loss(Enew,S.tau);clear Enew;
        rel=abs(before-after)/(abs(before)+A.eps0);
        outerRows(end,24:28)=[before,after,acceptedThis,rel,moveMax];
        clear S;
        if strcmp(sub,'timecap'),status='timecap';reason=subReason;break;end
        if strcmp(sub,'stationary'),status='stationary';reason=subReason;break;end
        if strcmp(sub,'mm_stalled')
            status='mm_stalled';reason=subReason;
            if strcmp(regime,'synthetic')||rel<A.tolOuter,break;end
        elseif rel<A.tolOuter
            status='converged';
            if acceptedThis>0,reason='accepted_small_loss_change';else,reason='small_loss_change_without_accepted_step';end
            break;
        end
    end
    E=SU_FROZEN('residual',X,U,V);[S,memory]=SU_STATE(E,M,A,regime,memory); %#ok<ASGLU>
    D=SU_WEIGHT_METRICS(S.We,mask,E,S.tau,A.zeroTol);
    sampleMask=squeeze(any(any(mask,1),2));
    if any(sampleMask),swCorrupt=mean(S.Ws(sampleMask));else,swCorrupt=NaN;end
    if any(~sampleMask),swClean=mean(S.Ws(~sampleMask));else,swClean=NaN;end
    snapshots(end+1)=struct('outer',-1,'U',U,'V',V,'memory',memory,'state',rmfield(S,{'We','W','Ws','a'}));
    model=struct('U',U,'V',V,'finalTau',S.tau,'finalEta',S.eta,'finalTailSeverity',S.severity, ...
        'finalCurrentTailSeverity',S.current,'finalGuard',S.guard,'finalScale',S.scale, ...
        'finalSampleWeights',S.Ws,'SampleWeightClean',swClean,'SampleWeightCorrupt',swCorrupt, ...
        'finalDiagnostics',D,'lastUsedDiagnostics',lastUsed,'outerTrace',outerRows,'innerTrace',innerRows, ...
        'snapshots',snapshots,'status',status,'StopReason',reason,'LastAttemptAccepted',lastAccepted, ...
        'AcceptedSteps',totalAccepted,'outerIters',size(outerRows,1),'TimeSeconds',toc(t), ...
        'finalAbsorption',absorption(Cdelta,U,V),'finalObj',loss(E,S.tau));
    if isempty(innerRows),model.ConditionalChecks=0;model.ConditionalViolations=0;
    else,model.ConditionalChecks=sum(innerRows(:,13)&innerRows(:,14));model.ConditionalViolations=sum(innerRows(:,15));end
    assert(norm(U'*U-eye(r),'fro')<1e-6&&norm(V'*V-eye(c),'fro')<1e-6,'SU:Orthogonal','Invalid subspaces');
end
function f=loss(E,tau)
    f=SU_FROZEN('loss',E,'tukey',tau);
end
function f=frozen_loss(E,tau,a)
    f=0;for i=1:size(E,3),f=f+a(i)*loss(E(:,:,i),tau);end
end
function d=movement(U,V,Ut,Vt,regime)
    if strcmp(regime,'real'),d=norm(U*U'-Ut*Ut','fro')/sqrt(2*size(U,2))+norm(V*V'-Vt*Vt','fro')/sqrt(2*size(V,2));
    else,d=norm(U*U'-Ut*Ut','fro')+norm(V*V'-Vt*Vt','fro');end
end
function a=absorption(C,U,V)
    if isempty(C)||sum(C(:).^2)==0,a=NaN;return;end
    s=0;for i=1:size(C,3),z=U' * C(:,:,i) * V;s=s+sum(z(:).^2);end
    a=s/sum(C(:).^2);
end
