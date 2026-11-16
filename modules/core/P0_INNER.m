function [U,V,T,trace]=P0_INNER(X,U,V,S,M,A,tStart,outer,anchor)
% One frozen-state inner solve: imputation proposal, alignment, Q acceptance,
% and projected-gradient fallback. Small step fractions never certify stationarity.
    trace=zeros(0,numel(P0_TRACE_HEADERS('inner')));
    T=struct('status','inner_budget','reason','inner_iteration_limit','accepted',0, ...
        'gradientAccepted',0,'lastAccepted',false,'fixedGradRelative',NaN);
    for inner=1:A.maxInner
        if toc(tStart)>A.maxTimePerMethod,T.status='timecap';T.reason='time_limit';return;end
        B=P0_MATH('evaluate',X,U,V,S,M,true);T.fixedGradRelative=B.GradRelative;
        if B.GradRelative<=A.gradientTolerance
            T.status='surrogate_stationary';T.reason='verified_frozen_quadratic_gradient';return;
        end
        Ximp=zeros(size(X));
        for i=1:size(X,3)
            Xi=X(:,:,i);xh=U*(U'*Xi*V)*V';wi=S.W(:,:,i);
            Ximp(:,:,i)=wi.*Xi+(1-wi).*xh;
        end
        if strcmp(A.regime,'real'),[Uc,Vc]=SU_FROZEN('warm',Ximp,U,V,A.fastBpcaSteps);
        else,[Uc,Vc]=SU_SYN_FROZEN('warm',Ximp,U,V,A.fastBpcaSteps);end
        clear Ximp;
        Uc=P0_MATH('align',U,Uc);Vc=P0_MATH('align',V,Vc);
        accepted=false;
        for ls=0:A.mmLineSearchMax
            if toc(tStart)>A.maxTimePerMethod,T.status='timecap';T.reason='time_limit';return;end
            beta=A.mmShrink^ls;
            if ls==0,Ut=Uc;Vt=Vc;
            else,Ut=P0_MATH('qf',(1-beta)*U+beta*Uc);Vt=P0_MATH('qf',(1-beta)*V+beta*Vc);end
            Bt=P0_MATH('evaluate',X,Ut,Vt,S,M,false);mv=P0_MATH('move',U,V,Ut,Vt);
            qPass=isfinite(Bt.Qcode)&&Bt.Qcode<=B.Qcode+A.mmAcceptTol*(1+abs(B.Qcode));
            ok=qPass&&isfinite(Bt.F)&&mv>A.minimumAcceptedMove;
            trace(end+1,:)=row(outer,inner,'aligned_proposal',ls,beta,B,Bt,anchor,ok,mv,A,tStart); %#ok<AGROW>
            if ok,U=Ut;V=Vt;accepted=true;break;end
            if mv<=A.minimumAcceptedMove,break;end
        end
        if ~accepted
            [Ut,Vt,accepted,st,search]=P0_MATH('gradient_search',X,U,V,S,M,A,tStart);
            for j=1:numel(search)
                x=search(j);
                trace(end+1,:)=row(outer,inner,'gradient_fallback',x.trial,x.step,B,x.B,anchor,x.accepted,x.move,A,tStart); %#ok<AGROW>
            end
            if accepted
                U=Ut;V=Vt;T.gradientAccepted=T.gradientAccepted+1;
            else
                T.status=st;T.reason='no_acceptable_gradient_step';T.lastAccepted=false;
                if strcmp(st,'surrogate_stationary'),T.reason='verified_frozen_quadratic_gradient';end
                if strcmp(st,'timecap'),T.reason='time_limit';end
                return;
            end
        end
        T.accepted=T.accepted+1;T.lastAccepted=true;
    end
    B=P0_MATH('evaluate',X,U,V,S,M,true);T.fixedGradRelative=B.GradRelative;
end

function R=row(outer,inner,path,ls,beta,B,Bt,anchor,accepted,mv,A,tStart)
    upper=anchor.F+.5*(Bt.Qcode-anchor.Qcode);
    applicable=isfinite(Bt.F)&&isfinite(upper);
    violation=applicable&&Bt.F>upper+A.majorizerTolerance*(1+abs(anchor.F)+abs(upper));
    qPass=isfinite(Bt.Qcode)&&Bt.Qcode<=B.Qcode+A.mmAcceptTol*(1+abs(B.Qcode));
    lVeto=~isfinite(Bt.L)||Bt.L>B.L+A.mmAcceptTol*(1+abs(B.L));
    if strcmp(path,'aligned_proposal'),pathCode=1;else,pathCode=2;end
    R=[outer inner pathCode ls beta B.Qcode Bt.Qcode B.L Bt.L Bt.F ...
        anchor.Qcode anchor.F upper accepted qPass lVeto mv B.GradRelative applicable violation toc(tStart)];
end
