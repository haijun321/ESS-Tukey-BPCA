function report=CSSP_IMPORT_SELFTEST(C)
% Engineering fixtures only. Never read or alter a user result directory.
before=rng;cleanupRng=onCleanup(@()rng(before));
root=tempname;mkdir(root);cleanupDir=onCleanup(@()remove_fixture(root));
C.priorResultRoots={root};C.includeFixedEtaNoZero=true;
[A,~]=P0_ALG(C,'synthetic');A.maxOuter=2;A.maxInner=1;A.maxTimePerMethod=Inf;
A.mmLineSearchMax=5;A.gradientBacktracks=8;
rng(84671,'twister');X=randn(7,6,9);mask=false(size(X));mask(1,1,1)=true;
[U0,~]=qr(randn(7,2),0);[V0,~]=qr(randn(6,2),0);
K=struct('Dataset','SYN','Condition','TEST','Repeat',1,'X',X,'mask',mask, ...
    'U0',U0,'V0',V0,'rank',[2 2]);
K.caseHash=P0_IO('hashtext',[P0_IO('hashnumeric',X) P0_IO('hashnumeric',mask)]);
K.initHash=P0_IO('hashtext',[P0_IO('hashnumeric',U0) P0_IO('hashnumeric',V0)]);
M=NB_NATIVE_METHOD(C,'C3');
[model,S]=P0_SOLVER_V2(X,2,2,M,A,'synthetic',U0,V0,mask);
sources=P0_IO('sources',C.packageRoot);sourceHash=P0_IO('hashtext',jsonencode(sources));
P0_IO('save',fullfile(root,'source_manifest.mat'),struct('hash',sourceHash,'sources',{sources}));
metadata=struct('protocolHash','fixture_only','caseHash',K.caseHash,'initHash',K.initHash, ...
    'rank',K.rank,'method',M,'alg',A,'regime','synthetic','version','v2','budget',1);
record=struct('IsScientificRun',true,'CaseHash',K.caseHash,'InitHash',K.initHash);
file=fullfile(root,'fixture','fits','SYN_r001_TEST_C3_v2_B1','fit.mat');
P0_IO('save',file,struct('signature',P0_IO('hashtext',jsonencode(metadata)), ...
    'metadata',metadata,'record',record,'model',model));
z=CSSP_IMPORT_PRIOR(C,K,A,M,'synthetic');
assert(z.Found&&z.EndpointOnlyImported,'CSSP:ImportTest','Exact prior endpoint was not imported.');
assert(isequal(z.model.U,model.U)&&isequal(z.model.V,model.V), ...
    'CSSP:ImportTest','Import changed native bases.');
assert(norm(z.state.We(:)-S.We(:))<1e-12,'CSSP:ImportTest','Frozen final weights changed.');
assert(z.model.checkpoints(1).Outer==0&&isequal(z.model.checkpoints(1).U,U0), ...
    'CSSP:ImportTest','Initialization checkpoint is not the true input.');
assert(numel(z.model.checkpoints)<=2&&z.model.checkpoints(end).Outer==model.outerIters, ...
    'CSSP:ImportTest','Invented intermediate checkpoints.');
assert(z.FitSeconds==model.TimeSeconds,'CSSP:ImportTest','Historical fit cost was replaced by cache I/O time.');
% Logging-only changes remain compatible; scientific parameter changes do not.
logging=A;logging.nbTraceEvery=17;logging.nbProgressEvery=0;
z=CSSP_IMPORT_PRIOR(C,K,logging,M,'synthetic');
assert(z.Found,'CSSP:ImportTest','Logging-only field unexpectedly invalidated endpoint.');
changed=A;changed.maxInner=A.maxInner+1;
z=CSSP_IMPORT_PRIOR(C,K,changed,M,'synthetic');
assert(~z.Found,'CSSP:ImportTest','Scientific budget mismatch was reused.');
changedCase=K;changedCase.X(1)=changedCase.X(1)+0.125;
z=CSSP_IMPORT_PRIOR(C,changedCase,A,M,'synthetic');
assert(~z.Found,'CSSP:ImportTest','Changed input with stale labels was reused.');
changedInit=K;changedInit.U0(:,1)=-changedInit.U0(:,1);
z=CSSP_IMPORT_PRIOR(C,changedInit,A,M,'synthetic');
assert(~z.Found,'CSSP:ImportTest','A changed basis orientation was silently imported.');
% Change an owned fixture manifest, leaving its internal receipt consistent.
badSources=sources;badSources{1,2}=repmat('0',1,64);
delete(fullfile(root,'source_manifest.mat'));
P0_IO('save',fullfile(root,'source_manifest.mat'), ...
    struct('hash',P0_IO('hashtext',jsonencode(badSources)),'sources',{badSources}));
z=CSSP_IMPORT_PRIOR(C,K,A,M,'synthetic');
assert(~z.Found&&~isempty(z.RejectedRoots),'CSSP:ImportTest','Source mismatch was imported.');
report=struct('Pass',true,'Checks',8,'Evidence','MATLAB engineering fixtures; not a paper experiment');
clear cleanupDir cleanupRng;
end
function remove_fixture(root)
if exist(root,'dir')==7,rmdir(root,'s');end
end
