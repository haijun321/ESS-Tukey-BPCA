function Z=P0_METRICS(X,mask,model,S,regime,D)
% Synthetic NRE projects CONTAMINATED observations and compares with latent X0.
% Real NRE evaluates the CLEAN held-out probe; these are different targets.
    Z=struct('NRE',NaN,'ErrSubNorm',NaN,'ACC',NaN,'GalleryNRE',NaN,'MetricTarget','', ...
        'OracleCleanProjectionNRE',NaN,'ElementROC',NaN,'ElementAP',NaN, ...
        'CombinedROC',NaN,'CombinedAP',NaN,'ESSCombined',NaN,'Absorption',NaN);
    w=S.W(:);sw2=sum(w.^2);
    if sw2>0,Z.ESSCombined=sum(w)^2/sw2/numel(w);end
    if any(mask(:))&&any(~mask(:))
        Z.ElementROC=SU_FROZEN('oldauc',1-S.We(:),mask(:));
        Z.ElementAP=ap(1-S.We(:),mask(:));
        Z.CombinedROC=SU_FROZEN('oldauc',1-S.W(:),mask(:));
        Z.CombinedAP=ap(1-S.W(:),mask(:));
    end
    if strcmp(regime,'synthetic')
        Z.MetricTarget='latent_clean_recovery_from_corrupted_projection';
        U=model.U;V=model.V;
        Z.ErrSubNorm=.5*(norm(D.Atrue*D.Atrue'-U*U','fro')/sqrt(2*size(U,2)) ...
            +norm(D.Btrue*D.Btrue'-V*V','fro')/sqrt(2*size(V,2)));
        s=0;oracle=0;absorbed=0;deltaEnergy=0;
        for i=1:size(X,3)
            xh=U*(U'*X(:,:,i)*V)*V';d=D.Xclean(:,:,i)-xh;s=s+sum(d(:).^2);
            xc=D.Xclean(:,:,i);er=xc-U*(U'*xc*V)*V';oracle=oracle+sum(er(:).^2);
            if isfield(D,'Delta')
                de=D.Delta(:,:,i);p=U'*de*V;absorbed=absorbed+sum(p(:).^2);deltaEnergy=deltaEnergy+sum(de(:).^2);
            end
        end
        den=norm(D.Xclean(:))+1e-12;Z.NRE=sqrt(s)/den;Z.OracleCleanProjectionNRE=sqrt(oracle)/den;
        if deltaEnergy>0,Z.Absorption=absorbed/deltaEnergy;end
    else
        Z.GalleryNRE=SU_FROZEN('nre',D.gallery,model.U,model.V);
        if isfield(D,'selectionOnly')&&D.selectionOnly
            assert(~isfield(D,'probe')&&~isfield(D,'probeLabels'),'P0:SelectionLeakage','Remove probe fields before candidate fits.');
            Z.NRE=Z.GalleryNRE;Z.MetricTarget='clean_gallery_validation_only';
        else
            Z.NRE=SU_FROZEN('nre',D.probe,model.U,model.V);
            Z.ACC=SU_FROZEN('accuracy',D.gallery,D.galleryLabels,D.probe,D.probeLabels,model.U,model.V,D.cfg);
            Z.MetricTarget='clean_outer_probe';
        end
    end
    assert(isfinite(Z.NRE),'P0:Metric','Nonfinite primary NRE; do not silently drop this fit.');
end

function z=ap(score,y)
    [s,ix]=sort(score(:),'descend');y=double(y(ix));p=sum(y);
    if p==0||p==numel(y),z=NaN;return;end
    ends=find([diff(s)~=0;true]);tp=cumsum(y);rec=tp(ends)/p;prec=tp(ends)./ends;
    z=sum(diff([0;rec]).*prec);
end
