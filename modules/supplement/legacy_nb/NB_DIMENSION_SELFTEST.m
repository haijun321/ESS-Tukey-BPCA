function report=NB_DIMENSION_SELFTEST()
% Geometries used by this supplement. Does not run expensive fits.
    geometries=[40 30;121 160;112 92;64 64];levels=[1 2 4];
    report=zeros(size(geometries,1)*numel(levels),7);row=0;
    for a=1:size(geometries,1)
        p=geometries(a,1);q=geometries(a,2);
        for b=1:numel(levels)
            [r,c,k,exact]=NB_DIMENSION_PAIR(p,q,levels(b));row=row+1;
            assert(exact&&r*c==p*k,'NB:DimensionSelftest','Feature counts differ.');
            assert(r<p&&c<q&&k<q,'NB:DimensionSelftest','Rank violates bounds.');
            report(row,:)=[p q k r c r*c p*k];
        end
    end
    rejected=false;
    try,NB_DIMENSION_PAIR(2,2,1);catch e,rejected=strcmp(e.identifier,'NB:DimensionInfeasible');end
    assert(rejected,'NB:DimensionSelftest','Infeasible geometry was not rejected.');
    fprintf('Feature-dimension pair checks PASS (%d feasible cases + infeasible case).\n',row);
end
