function [R,T] = SMP_METRICS(D,K,model,S)
%SMP_METRICS Evaluate one fit without feeding truth back to the algorithm.
% SampleAUROC/AP use the upper-tail raw RMS residual score Dfinal for BOTH
% E and E+S. They are read-only diagnostics, not the two-sided sample rule.
% SampleESS/MeanA/etc use coefficients of the last ACCEPTED outer update; terminal
% recomputed coefficients are separately retained in the per-sample table.
% CombinedESS is computed from the terminal recomputed element*sample weights.
    U=model.U; V=model.V; n=size(K.X,3);
    assert(isequal(size(K.X),size(D.X0)),'SMP:MetricSize','Training sizes differ.');
    assert(numel(K.caseLabels)==n,'SMP:LabelSize','Invalid case labels.');
    labels=logical(K.caseLabels(:)); noncase=~labels;
    assert(norm(U'*U-eye(size(U,2)),'fro')<1e-6&& ...
        norm(V'*V-eye(size(V,2)),'fro')<1e-6, ...
        'SMP:MetricOrthogonal','Projection bases are not orthonormal.');
    R=struct();
    R.ErrSubNorm=0.5*(norm(D.Atrue*D.Atrue'-U*U','fro')/sqrt(2*size(U,2))+ ...
        norm(D.Btrue*D.Btrue'-V*V','fro')/sqrt(2*size(V,2)));
    probeError=0;
    for j=1:size(D.Xprobe0,3)
        x=D.Xprobe0(:,:,j); er=x-project(x,U,V);
        probeError=probeError+sum(er(:).^2);
    end
    R.ProbeCleanNRE=sqrt(probeError)/max(norm(D.Xprobe0(:)),1e-12);
    fullError=0; normalError=0; normalEnergy=0; signalError=0;
    retainedPerturbation=0; dFinal=zeros(n,1);
    for i=1:n
        x=K.X(:,:,i); x0=D.X0(:,:,i);
        px=project(x,U,V); er=x0-px;
        fullError=fullError+sum(er(:).^2);
        if noncase(i)
            normalError=normalError+sum(er(:).^2);
            normalEnergy=normalEnergy+sum(x0(:).^2);
        end
        sig=x0-project(x0,U,V);
        signalError=signalError+sum(sig(:).^2);
        perturbation=project(x-x0,U,V);
        retainedPerturbation=retainedPerturbation+sum(perturbation(:).^2);
        residual=x-px;
        dFinal(i)=norm(residual,'fro')/sqrt(numel(residual));
    end
    energy=sum(D.X0(:).^2); den=max(energy,1e-24);
    R.TrainNRE=sqrt(fullError/den);
    if any(noncase), R.NonCaseNRE=sqrt(normalError/max(normalEnergy,1e-24));
    else, R.NonCaseNRE=NaN; end
    R.TrainSignalNRE=sqrt(signalError/den);
    R.RetainedPerturbationNRE2=retainedPerturbation/den;

    aFinal=S.a(:); vFinal=S.Ws(:);
    assert(numel(aFinal)==n&&numel(vFinal)==n, ...
        'SMP:WeightSize','Terminal sample coefficient sizes differ.');
    aUsed=aFinal;
    if isfield(model,'lastAcceptedA')&&~isempty(model.lastAcceptedA)
        aUsed=model.lastAcceptedA(:);
    elseif isfield(model,'lastUsedA')&&~isempty(model.lastUsedA)
        aUsed=model.lastUsedA(:);
    end
    assert(numel(aUsed)==n&&all(isfinite(aUsed))&&all(aUsed>=0), ...
        'SMP:UsedWeights','Invalid actual sample coefficients.');
    assert(all(isfinite(aFinal))&&all(isfinite(dFinal)), ...
        'SMP:FinalWeights','Invalid terminal diagnostics.');
    R.SampleESS=ess_ratio(aUsed);
    R.SampleMeanA=mean(aUsed);
    if isfield(D,'sampleCoefficientFloor'), floorA=D.sampleCoefficientFloor;
    else, floorA=0.20^0.35; end
    R.SampleFloorFraction=mean(aUsed<=floorA+1e-12);
    [R.SampleAUROC,R.SampleAP]=ranking_metrics(dFinal,labels);
    if any(noncase)
        R.NonCaseDownweight95=mean(aUsed(noncase)<0.95);
        R.NonCaseMeanA=mean(aUsed(noncase));
    else
        R.NonCaseDownweight95=NaN; R.NonCaseMeanA=NaN;
    end
    if any(labels), R.CaseMeanA=mean(aUsed(labels)); else, R.CaseMeanA=NaN; end
    R.CombinedESS=ess_ratio(S.W(:));

    cellFraction=sum(reshape(K.cellMask,[],n),1)'/(size(K.X,1)*size(K.X,2));
    T=table((1:n)',labels,cellFraction,dFinal,aFinal,aUsed,vFinal, ...
        'VariableNames',{'Sample','CaseLabel','LocalCellFraction', ...
        'Dfinal','Afinal','Aused','Vfinal'});
    if isfield(model,'lastAcceptedD')&&~isempty(model.lastAcceptedD)
        dUsed=model.lastAcceptedD(:);
    elseif isfield(model,'lastUsedD')&&~isempty(model.lastUsedD)
        dUsed=model.lastUsedD(:);
        assert(numel(dUsed)==n,'SMP:UsedScore','Invalid used-score size.');
    else
        dUsed=nan(n,1);
    end
    T.Dused=dUsed;
    if isfield(model,'lastUsedA')
        T.Aattempted=model.lastUsedA(:);T.Dattempted=model.lastUsedD(:);
    else
        T.Aattempted=aUsed;T.Dattempted=dUsed;
    end
    values=struct2cell(R);
    required=[R.ErrSubNorm R.ProbeCleanNRE R.TrainNRE ...
        R.TrainSignalNRE R.RetainedPerturbationNRE2 R.SampleESS];
    assert(all(isfinite(required)),'SMP:MetricNonfinite','Nonfinite main metric.');
    assert(all(cellfun(@(x)isnumeric(x)&&isscalar(x),values)), ...
        'SMP:MetricScalar','All summary metrics must be numeric scalars.');
    assert(abs(R.TrainNRE^2-R.TrainSignalNRE^2- ...
        R.RetainedPerturbationNRE2)<1e-7*max(1,R.TrainNRE^2), ...
        'SMP:Decomposition','Orthogonal error decomposition failed.');
end

function y=project(x,U,V)
    y=U*(U'*x*V)*V';
end

function z=ess_ratio(w)
    w=w(:);
    assert(all(isfinite(w))&&all(w>=0),'SMP:ESSWeights','ESS needs finite nonnegative weights.');
    sw2=sum(w.^2);
    if isempty(w)||sw2<=0, z=NaN; else, z=sum(w)^2/(numel(w)*sw2); end
end

function [auc,averagePrecision]=ranking_metrics(score,label)
% Tie-aware AUROC (average ranks) and grouped-threshold average precision.
    score=score(:); label=logical(label(:));
    assert(numel(score)==numel(label)&&all(isfinite(score)), ...
        'SMP:Ranking','Invalid ranking data.');
    n=numel(score); p=sum(label); q=n-p;
    if p==0||q==0, auc=NaN; averagePrecision=NaN; return; end
    [s,order]=sort(score,'ascend'); ranks=zeros(n,1);
    first=1;
    while first<=n
        last=first;
        while last<n&&s(last+1)==s(first), last=last+1; end
        ranks(order(first:last))=(first+last)/2;
        first=last+1;
    end
    auc=(sum(ranks(label))-p*(p+1)/2)/(p*q);
    [s,order]=sort(score,'descend'); yy=double(label(order));
    ends=find([diff(s)~=0;true]); tp=cumsum(yy);
    recall=tp(ends)/p; precision=tp(ends)./ends;
    averagePrecision=sum(diff([0;recall]).*precision);
end
