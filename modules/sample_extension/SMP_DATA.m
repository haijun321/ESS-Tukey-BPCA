function D = SMP_DATA(C,rep,phase)
%SMP_DATA Generate one paired four-condition synthetic repetition.
% All four conditions share latent signal, background noise and clean probe.
% Ground-truth labels/masks are for evaluation only, never for calibration.
% This function restores the caller's random-number-generator state.
    validateattributes(rep,{'numeric'},{'scalar','integer','positive'});
    phase=char(phase);
    if strcmp(phase,'formal')
        base=C.formalSeed;
    elseif strcmp(phase,'precheck')
        base=C.precheckSeed;
    else
        error('SMP:Phase','Expected phase formal or precheck.');
    end
    dims=[C.n C.p C.q C.r C.c C.nProbe];
    assert(all(isfinite(dims))&&all(dims==fix(dims))&&all(dims>0), ...
        'SMP:Dimensions','Dimensions must be positive integers.');
    assert(C.r<C.p&&C.c<C.q,'SMP:Rank','Require r<p and c<q.');
    assert(isfinite(C.noiseSigma)&&C.noiseSigma>=0, ...
        'SMP:Noise','Invalid Gaussian background scale.');
    assert(isfinite(C.kappa)&&C.kappa>0,'SMP:Amplitude','Invalid strength.');
    assert(C.caseRate>=0&&C.caseRate<1&&C.cellRate>=0&&C.cellRate<=1, ...
        'SMP:Rate','Rates must satisfy 0<=caseRate<1 and 0<=cellRate<=1.');
    previous=rng; restore=onCleanup(@()rng(previous)); %#ok<NASGU>
    offsets=1:8;
    values=double(base)+100*double(rep)+offsets;
    assert(all(values>=0)&all(values<2^32),'SMP:Seed','Invalid RNG seed.');
    names={'loadings','cores','background','probe','caseIndices', ...
        'casePerturbation','cellOnly','mixedCells'};
    seeds=cell2struct(num2cell(values),names,2);

    rng(seeds.loadings,'twister');
    A=orth(randn(C.p,C.r)); B=orth(randn(C.q,C.c));
    rng(seeds.cores,'twister');
    X0=latent_matrices(A,B,C.n);
    rng(seeds.background,'twister');
    Xbase=X0+C.noiseSigma*randn(C.p,C.q,C.n);
    rng(seeds.probe,'twister');
    Xprobe0=latent_matrices(A,B,C.nProbe);
    x=Xbase(:); center=median(x);
    scale=1.4826*median(abs(x-center))+1e-12;
    amplitude=C.kappa*scale;

    rng(seeds.caseIndices,'twister');
    nCase=round(C.caseRate*C.n);
    selected=randperm(C.n,nCase);
    caseLabels=false(C.n,1); caseLabels(selected)=true;
    caseNoise=zeros(size(Xbase));
    rng(seeds.casePerturbation,'twister');
    for k=1:numel(selected)
        i=selected(k);
        caseNoise(:,:,i)=amplitude*randn(C.p,C.q);
    end
    caseMask=repmat(reshape(caseLabels,1,1,C.n),C.p,C.q,1);
    noCells=false(size(Xbase));

    rng(seeds.cellOnly,'twister');
    [Xcell,cellOnlyMask]=inject_impulses(Xbase,true(C.n,1), ...
        C.cellRate,amplitude);
    rng(seeds.mixedCells,'twister');
    [Xmixed,mixedCellMask]=inject_impulses(Xbase+caseNoise,~caseLabels, ...
        C.cellRate,amplitude);

    prototype=struct('id','','X',[],'caseLabels',[], ...
        'cellMask',[],'totalMask',[],'nCase',0,'nCell',0, ...
        'realizedCaseRate',0,'realizedCellRateEligible',0, ...
        'realizedTotalEntryRate',0);
    cases=repmat(prototype,1,4);
    cases(1)=make_case('Clean',Xbase,false(C.n,1),noCells,noCells,C);
    cases(2)=make_case('CellOnly',Xcell,false(C.n,1), ...
        cellOnlyMask,cellOnlyMask,C);
    cases(3)=make_case('CaseOnly',Xbase+caseNoise,caseLabels, ...
        noCells,caseMask,C);
    cases(4)=make_case('Mixed',Xmixed,caseLabels, ...
        mixedCellMask,caseMask|mixedCellMask,C);
    assert(~any(mixedCellMask(caseMask)), ...
        'SMP:MaskOverlap','Mixed local cells must be outside case samples.');
    assert(isequal(cases(3).caseLabels,cases(4).caseLabels), ...
        'SMP:CasePair','CaseOnly and Mixed must use the same case samples.');
    assert(isequal(cases(3).X(:,:,caseLabels),cases(4).X(:,:,caseLabels)), ...
        'SMP:CasePair','CaseOnly and Mixed case perturbations must match.');

    D=struct('phase',phase,'repeat',rep,'seed',double(base)+100*double(rep), ...
        'seeds',seeds,'X0',X0,'Xbase',Xbase,'Xprobe0',Xprobe0, ...
        'Atrue',A,'Btrue',B,'scale',scale,'amplitude',amplitude, ...
        'geometry',[C.n C.p C.q C.r C.c],'cases',cases, ...
        'sampleWeightMin',0.20,'sampleWeightAlpha',0.35, ...
        'sampleCoefficientFloor',0.20^0.35);
end

function X=latent_matrices(A,B,n)
    r=size(A,2); c=size(B,2);
    sd=linspace(3.0,1.2,min(r,c));
    X=zeros(size(A,1),size(B,1),n);
    for i=1:n
        Z=0.35*randn(r,c);
        for k=1:min(r,c), Z(k,k)=sd(k)*randn(); end
        X(:,:,i)=A*Z*B';
    end
end

function [X,mask]=inject_impulses(X,eligible,rate,amplitude)
% Uniform sampling without replacement within eligible matrix entries.
    [p,q,n]=size(X);
    eligibleMask=repmat(reshape(logical(eligible),1,1,n),p,q,1);
    allowed=find(eligibleMask);
    count=round(rate*numel(allowed));
    mask=false(size(X));
    if count==0, return; end
    chosen=allowed(randperm(numel(allowed),count));
    signs=2*(rand(count,1)>0.5)-1;
    values=amplitude*signs.*(0.5+rand(count,1));
    X(chosen)=X(chosen)+values;
    mask(chosen)=true;
end

function K=make_case(id,X,labels,cells,total,C)
    nCase=sum(labels); nCell=nnz(cells);
    eligible=(C.n-nCase)*C.p*C.q;
    if eligible>0, cellRate=nCell/eligible; else, cellRate=NaN; end
    K=struct('id',id,'X',X,'caseLabels',logical(labels(:)), ...
        'cellMask',logical(cells),'totalMask',logical(total), ...
        'nCase',nCase,'nCell',nCell,'realizedCaseRate',nCase/C.n, ...
        'realizedCellRateEligible',cellRate, ...
        'realizedTotalEntryRate',nnz(total)/numel(total));
end
