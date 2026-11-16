function [model,S,info]=CSSP_FIT_NATIVE(C,K,A,method,value)
% Training-only API. No gallery, probe, labels, or held-out score is accepted.
if nargin<5,value=NaN;end
actualCaseHash=P0_IO('hashtext',[P0_IO('hashnumeric',K.X) P0_IO('hashnumeric',K.mask)]);
actualInitHash=P0_IO('hashtext',[P0_IO('hashnumeric',K.U0) P0_IO('hashnumeric',K.V0)]);
if isfield(K,'regime'),regime=K.regime;
elseif strcmp(K.Dataset,'SYN'),regime='synthetic';else,regime='real';end
M=NB_NATIVE_METHOD(C,method,value);
if strcmp(method,'TunedC'),A.fixedTukeyC=value;end
% Canonical labels make default tuning candidates reusable as C1/C2 fits.
if strcmp(method,'TunedC'),M.id='C1';M.name='canonical_fixed_tukey';
elseif strcmp(method,'TunedEta'),M.id='C2';M.name='canonical_fixed_eta';end
A.nbTraceEvery=C.checkpointEvery;A.nbProgressEvery=C.progressEveryOuter;
specM=rmfield(M,{'id','name'});specA=A;
if isfield(specA,'nbProgressEvery'),specA=rmfield(specA,'nbProgressEvery');end
if isempty(C.coreHash),C.coreHash=CSSP_SOURCE('core',C);end
spec=struct('caseHash',actualCaseHash,'initHash',actualInitHash,'rank',K.rank, ...
    'method',specM,'alg',specA,'regime',regime,'coreHash',C.coreHash);
sig=P0_IO('hashtext',jsonencode(spec));file=fullfile(C.cacheRoot,[sig '.mat']);
info=struct('CacheHit',false,'ImportedPrior',false,'PriorFile','','EndpointOnlyImported',false, ...
    'Signature',sig,'FitSeconds',0,'SourceFile',file,'TrainingSpec',spec);
if exist(file,'file')==2
    old=P0_IO('load',file);assert(strcmp(old.signature,sig),'CSSP:Cache','Training signature differs.');
    model=old.model;S=rebuild_state(old.state,K.X,model,M,A);
    info.CacheHit=true;info.FitSeconds=old.fitSeconds;
    if isfield(old,'priorFile')
        info.ImportedPrior=true;info.PriorFile=old.priorFile;
        info.EndpointOnlyImported=isfield(model,'EndpointOnlyImported')&&model.EndpointOnlyImported;
    end
    return;
end
if isfield(C,'priorResultRoots')&&~isempty(C.priorResultRoots)
    prior=CSSP_IMPORT_PRIOR(C,K,A,M,regime);
    if prior.Found
        model=prior.model;S=prior.state;short=S;
        fields=intersect(fieldnames(short),{'W','We'});short=rmfield(short,fields);
        P0_IO('save',file,struct('signature',sig,'spec',spec,'model',model,'state',short, ...
            'fitSeconds',prior.FitSeconds,'priorFile',prior.PriorFile));
        info.CacheHit=true;info.ImportedPrior=true;info.PriorFile=prior.PriorFile;
        info.EndpointOnlyImported=prior.EndpointOnlyImported;info.FitSeconds=prior.FitSeconds;
        fprintf('VERIFIED prior endpoint imported: %s\n',prior.PriorFile);return;
    end
end
P0_IO('checkstop',C.stopFile);t=tic;
[model,S]=NB_SOLVER_TRACE(K.X,K.rank(1),K.rank(2),M,A,regime,K.U0,K.V0,K.mask);
info.FitSeconds=toc(t);
short=S;fields=intersect(fieldnames(short),{'W','We'});short=rmfield(short,fields);
payload=struct('signature',sig,'spec',spec,'model',model,'state',short,'fitSeconds',info.FitSeconds);
P0_IO('save',file,payload);
end
function S=rebuild_state(S,X,model,M,A)
E=SU_FROZEN('residual',X,model.U,model.V);
if S.guard||strcmp(M.loss,'l2'),S.We=ones(size(E));
elseif strcmp(M.loss,'tukey'),S.We=SU_FROZEN('tukeyweights',E,S.tau);
elseif strcmp(M.loss,'huber')
    S.We=ones(size(E));j=abs(E)>S.tau;S.We(j)=S.tau./abs(E(j));
elseif strcmp(M.loss,'welsch'),S.We=exp(-(E./S.tau).^2);
else,error('CSSP:CacheLoss','Unknown loss.');end
S.W=S.We;
for i=1:size(X,3),S.W(:,:,i)=S.W(:,:,i)*S.a(i);end
assert(all(isfinite(S.We(:)))&&all(S.We(:)>=0),'CSSP:CacheState','Invalid cached weights.');
assert(A.eps0>0,'CSSP:Numerics','Invalid numeric floor.');
end
