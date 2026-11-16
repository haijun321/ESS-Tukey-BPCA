function Z=NB_EVALUATE(K,D,model,S)
% Mean-aware reconstruction, native-dimensional classification, no toolbox.
    U=model.U;V=model.V;mu=zeros(size(K.X,1),size(K.X,2));
    if isfield(model,'mean'),mu=model.mean;end
    Z=struct('NRE',NaN,'ErrSubNorm',NaN,'ACC',NaN,'GalleryNRE',NaN, ...
        'FeatureDimension',size(U,2)*size(V,2),'ESS',NaN,'ZeroFraction',NaN, ...
        'TPR0',NaN,'FPR0',NaN,'Tau',NaN,'TargetEta',NaN,'CurrentSeverity',NaN);
    if strcmp(D.evaluation,'synthetic')
        Z.NRE=nre(K.X,D.Xclean,U,V,mu);
        if size(U,2)==size(D.Atrue,2)&&size(V,2)==size(D.Btrue,2)
            Z.ErrSubNorm=.5*(norm(D.Atrue*D.Atrue'-U*U','fro')/sqrt(2*size(U,2)) ...
                +norm(D.Btrue*D.Btrue'-V*V','fro')/sqrt(2*size(V,2)));
        end
    else
        Z.NRE=nre(D.probe,D.probe,U,V,mu);
        Z.GalleryNRE=nre(D.gallery,D.gallery,U,V,mu);
        G=features(D.gallery,U,V,mu);P=features(D.probe,U,V,mu);
        if D.cfg.classifier.zscoreFeatures
            a=mean(G,2);s=std(G,0,2);s(s<1e-10)=1;G=(G-a)./s;P=(P-a)./s;
        end
        distance=max(0,sum(G.^2,1)'+sum(P.^2,1)-2*(G'*P));
        [~,idx]=min(distance,[],1);labels=D.galleryLabels(:);
        Z.ACC=mean(labels(idx(:))==D.probeLabels(:));
    end
    assert(isfinite(Z.NRE),'NB:Metric','Nonfinite primary metric');
    if ~isempty(S)
        w=S.We(:);sw2=sum(w.^2);if sw2>0,Z.ESS=sum(w)^2/sw2/numel(w);end
        z=w==0;y=K.mask(:);Z.ZeroFraction=mean(z);
        if any(y),Z.TPR0=mean(z(y));end
        if any(~y),Z.FPR0=mean(z(~y));end
        Z.Tau=S.tau;Z.TargetEta=S.eta;Z.CurrentSeverity=S.current;
    end
end
function z=nre(X,Y,U,V,mu)
    total=0;
    for i=1:size(X,3)
        a=X(:,:,i)-mu;h=mu+U*(U'*a*V)*V';e=Y(:,:,i)-h;total=total+sum(e(:).^2);
    end
    z=sqrt(total)/max(norm(Y(:)),eps);
end
function F=features(X,U,V,mu)
    F=zeros(size(U,2)*size(V,2),size(X,3));
    for i=1:size(X,3),z=U'*(X(:,:,i)-mu)*V;F(:,i)=z(:);end
end
