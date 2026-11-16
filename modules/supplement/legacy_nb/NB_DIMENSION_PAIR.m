function [r,c,k,exact]=NB_DIMENSION_PAIR(p,q,level)
%NB_DIMENSION_PAIR Match native bilateral and right-single-sided dimensions.
% Right-single-sided RA-2DPCA with k=level has p*k feature entries.
% Find integer ranks 1<=r<p, 1<=c<q with r*c=p*k. Among feasible
% factorizations, prefer the most balanced r,c; ties prefer smaller r.
% Equality concerns feature size, not projection parameter count or runtime.
% Raises NB:DimensionInfeasible when exact matching is impossible. Never
% silently assigns approximately matching dimensions or full-rank bases.
    validateattributes(p,{'numeric'},{'scalar','real','finite','integer','>=',2});
    validateattributes(q,{'numeric'},{'scalar','real','finite','integer','>=',2});
    validateattributes(level,{'numeric'},{'scalar','real','finite','integer','>=',1,'<',q});
    k=double(level);budget=double(p)*k;
    candidate=zeros(0,3);
    for left=1:double(p)-1
        if mod(budget,left)~=0,continue;end
        right=budget/left;
        if right<1||right>=double(q),continue;end
        candidate(end+1,:)=[abs(log(left)-log(right)),left,right]; %#ok<AGROW>
    end
    assert(~isempty(candidate),'NB:DimensionInfeasible', ...
        'No ranks r<p,c<q give r*c=p*k for p=%d,q=%d,k=%d.',p,q,k);
    candidate=sortrows(candidate,[1 2 3]);
    r=candidate(1,2);c=candidate(1,3);exact=(r*c==budget);
    assert(exact,'NB:DimensionInternal','Exact feature-dimension match failed.');
end
