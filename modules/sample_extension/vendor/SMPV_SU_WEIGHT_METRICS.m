function D=SMPV_SU_WEIGHT_METRICS(W,M,E,tau,zeroTol)
% Exact element weights only. Undefined ratios remain NaN.
    assert(isequal(size(W),size(M))&&isequal(size(W),size(E)),'SU:Mask','Mask/weight shape mismatch');
    assert(all(isfinite(W(:)))&&all(isfinite(E(:)))&&all(W(:)>=0)&all(W(:)<=1),'SU:Finite','Invalid weights/residual');
    M=logical(M);Z=(W==0);ZN=(W<=zeroTol);P=sum(M(:));N=sum(~M(:));
    TP=sum(Z(:)&M(:));FP=sum(Z(:)&~M(:));NZ=sum(Z(:));
    D=struct('PositiveCount',P,'NegativeCount',N,'TP0',TP,'FP0',FP,'ZeroCount',NZ, ...
        'TPR0',ratio(TP,P),'FPR0',ratio(FP,N),'Precision0',ratio(TP,NZ), ...
        'ZeroExact',mean(Z(:)),'ZeroNear',mean(ZN(:)),'ZeroOperational',mean(abs(E(:))>tau), ...
        'BoundaryCount',sum(abs(E(:))==tau),'WeightClean',masked_mean(W,~M),'WeightCorrupt',masked_mean(W,M), ...
        'ResidualClean',masked_mean(abs(E),~M),'ResidualCorrupt',masked_mean(abs(E),M),'ESS',ess(W));
    n=size(W,3);D.perImage=zeros(n,5);
    for i=1:n,m=M(:,:,i);z=Z(:,:,i);D.perImage(i,:)=[sum(m(:)),sum(~m(:)),sum(z(:)&m(:)),sum(z(:)&~m(:)),sum(z(:))];end
    q=P/numel(M);
    if P>0&&N>0,assert(abs(D.ZeroExact-q*D.TPR0-(1-q)*D.FPR0)<1e-12,'SU:Identity','Rejection identity failed');end
end
function v=ratio(a,b)
    if b==0,v=NaN;else,v=a/b;end
end
function v=masked_mean(X,M)
    if ~any(M(:)),v=NaN;else,v=mean(X(M));end
end
function v=ess(W)
    s=sum(W(:));s2=sum(W(:).^2);if s2==0,v=NaN;else,v=s^2/s2/numel(W);end
end
