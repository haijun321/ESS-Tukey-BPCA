function varargout = P0_MATH(action,varargin)
% Qcode = sum(W .* E.^2) = 2 * the manuscript's Q.
    switch action
        case 'evaluate'
            varargout{1}=evaluate(varargin{:});
        case 'qf'
            [Q,R]=qr(varargin{1},0);s=sign(diag(R));s(s==0)=1;
            varargout{1}=Q*diag(s);
        case 'align'
            current=varargin{1};candidate=varargin{2};
            [L,~,R]=svd(candidate'*current,'econ');varargout{1}=candidate*(L*R');
        case 'move'
            U=varargin{1};V=varargin{2};Ut=varargin{3};Vt=varargin{4};
            varargout{1}=norm(U*U'-Ut*Ut','fro')/sqrt(2*size(U,2)) ...
                +norm(V*V'-Vt*Vt','fro')/sqrt(2*size(V,2));
        case 'statechange'
            a=varargin{1};b=varargin{2};
            d=norm(a.W(:)-b.W(:))/max(1,norm(a.W(:)));
            d=max(d,norm(a.a-b.a)/max(1,norm(a.a)));
            if a.guard~=b.guard,d=Inf;end
            if isfinite(a.tau)&&isfinite(b.tau),d=max(d,abs(a.tau-b.tau)/max(1,abs(a.tau)));end
            if isfinite(a.eta)&&isfinite(b.eta),d=max(d,abs(a.eta-b.eta));end
            if isfinite(a.severity)&&isfinite(b.severity),d=max(d,abs(a.severity-b.severity));end
            varargout{1}=d;
        case 'shortstate'
            varargout{1}=rmfield(varargin{1},{'W','We'});
        case 'gradient_search'
            [varargout{1:nargout}]=gradient_search(varargin{:});
        otherwise,error('P0:Math','Unknown mathematical action %s.',action);
    end
end

function B=evaluate(X,U,V,S,M,needGradient)
    if nargin<6,needGradient=false;end
    B=struct('Qcode',0,'F',0,'L',0,'gU',[],'gV',[],'GradNorm',NaN,'GradRelative',NaN);
    GU=zeros(size(U));GV=zeros(size(V));
    for i=1:size(X,3)
        Xi=X(:,:,i);Ei=Xi-U*(U'*Xi*V)*V';Wi=S.W(:,:,i);
        B.Qcode=B.Qcode+sum(Wi(:).*(Ei(:).^2));
        if S.guard || strcmp(M.loss,'l2')
            B.F=B.F+.5*S.a(i)*sum(Ei(:).^2);
        else
            B.F=B.F+S.a(i)*sum(rho(Ei(:),M.loss,S.tau));
        end
        B.L=B.L+SU_FROZEN('loss',Ei,M.loss,S.tau);
        if needGradient
            H=Wi.*Ei;
            % Algebraically equivalent to -(H PV X'+X PV H') U for Q.
            % The factor 2 here differentiates Qcode, not Q.
            GU=GU-2*((H*V)*(V'*(Xi'*U))+(Xi*V)*(V'*(H'*U)));
            GV=GV-2*((H'*U)*(U'*(Xi*V))+(Xi'*U)*(U'*(H*V)));
        end
    end
    if needGradient
        B.gU=GU-U*(U'*GU);B.gV=GV-V*(V'*GV);
        B.GradNorm=sqrt(sum(B.gU(:).^2)+sum(B.gV(:).^2));
        B.GradRelative=B.GradNorm/max(1,abs(B.Qcode));
    end
end

function z=rho(e,name,tau)
    switch name
        case 'tukey'
            inside=abs(e)<=tau;z=repmat(tau^2/6,size(e));
            r2=(e(inside)./tau).^2;
            % Stable expansion avoids subtraction of two nearly equal ones.
            z(inside)=e(inside).^2.*(.5-.5*r2+r2.^2/6);
        case 'huber'
            ae=abs(e);z=.5*e.^2;out=ae>tau;z(out)=tau*ae(out)-.5*tau^2;
        case 'welsch',z=-(tau^2/2)*expm1(-(e./tau).^2);
        otherwise,error('P0:Rho','Unsupported rho.');
    end
end

function [Ut,Vt,accepted,status,trials]=gradient_search(X,U,V,S,M,A,tStart)
    B=evaluate(X,U,V,S,M,true);Ut=U;Vt=V;accepted=false;status='failed_search';
    trials=struct('trial',{},'step',{},'B',{},'accepted',{},'move',{});
    if B.GradRelative<=A.gradientTolerance,status='surrogate_stationary';return;end
    beta=min(A.gradientStepMax,1/max(1,B.GradNorm));
    for ls=0:A.gradientBacktracks
        if toc(tStart)>A.maxTimePerMethod,status='timecap';return;end
        u=P0_MATH('qf',U-beta*B.gU);v=P0_MATH('qf',V-beta*B.gV);
        T=evaluate(X,u,v,S,M,false);mv=P0_MATH('move',U,V,u,v);
        allowance=A.mmAcceptTol*(1+abs(B.Qcode));
        ok=isfinite(T.Qcode)&&isfinite(T.F)&&mv>A.minimumAcceptedMove ...
            &&T.Qcode<=B.Qcode-A.armijoConstant*beta*B.GradNorm^2+allowance;
        trials(end+1)=struct('trial',ls,'step',beta,'B',T,'accepted',ok,'move',mv); %#ok<AGROW>
        if ok,Ut=u;Vt=v;accepted=true;status='accepted_gradient';return;end
        beta=beta*A.mmShrink;
    end
end
