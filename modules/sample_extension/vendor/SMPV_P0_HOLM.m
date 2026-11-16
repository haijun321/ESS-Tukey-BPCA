function q=SMPV_P0_HOLM(p)
    q=nan(size(p));valid=find(isfinite(p));[s,ix]=sort(p(valid));last=0;m=numel(s);
    for j=1:m,last=max(last,(m-j+1)*s(j));q(valid(ix(j)))=min(1,last);end
end
