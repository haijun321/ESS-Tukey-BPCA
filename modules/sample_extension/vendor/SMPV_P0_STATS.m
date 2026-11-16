function B=SMPV_P0_STATS(d,C,seed,allowTest)
% Bootstrap independent synthetic repeat blocks; real split intervals descriptive.
% Sign-flip test is exact for <=20 blocks, under symmetric paired-difference null.
    d=d(:);assert(all(isfinite(d)),'P0:Stats','Do not silently discard nonfinite primary pairs.');
    B=struct('Mean',mean(d),'SD',std(d),'Low',NaN,'High',NaN,'P',NaN);
    if isempty(d),return;end
    if numel(d)<2,return;end
    old=rng;cleanup=onCleanup(@()rng(old));rng(seed,'twister');
    n=numel(d);v=zeros(C.bootstrapResamples,1);chunk=max(1,min(5000,floor(1000000/n)));
    for k=1:chunk:C.bootstrapResamples
        stop=min(C.bootstrapResamples,k+chunk-1);idx=randi(n,n,stop-k+1);
        v(k:stop)=mean(d(idx),1)';
    end
    v=sort(v);B.Low=quant(v,.025);B.High=quant(v,.975);
    if allowTest
        target=abs(mean(d));tol=1e-14*max(1,target);
        if n<=20
            total=2^n;above=0;
            for start=0:4096:total-1
                code=(start:min(total-1,start+4095))';s=ones(numel(code),n);
                for j=1:n,s(:,j)=2*double(bitget(uint32(code),j))-1;end
                x=abs(s*d/n);above=above+sum(x>=target-tol);
            end
            B.P=above/total;
        else
            total=C.bootstrapResamples;above=0;
            for k=1:total,s=2*(rand(n,1)>.5)-1;above=above+(abs(mean(s.*d))>=target-tol);end
            B.P=(above+1)/(total+1);
        end
    end
    clear cleanup;
end

function x=quant(v,p)
    k=1+p*(numel(v)-1);lo=floor(k);hi=ceil(k);x=v(lo)+(k-lo)*(v(hi)-v(lo));
end
