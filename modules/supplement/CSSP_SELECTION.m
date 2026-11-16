function [model,S,selection,receipt]=CSSP_SELECTION(C,K,D,A,family)
% All candidates see only training and clean gallery. Commit lock BEFORE probe.
assert(any(strcmp(family,{'TunedEta','TunedC'})),'CSSP:Family','Unknown tuning family.');
development=struct('gallery',D.gallery); % deliberately does not retain D.probe
if strcmp(family,'TunedEta'),grid=C.etaGrid;else,grid=C.cGrid;end
assert(all(diff(grid)>0),'CSSP:TuningGrid','Candidate grid must be ascending.');
selection=repmat(struct('Value',NaN,'ValidationNRE',NaN,'Seconds',0,'CacheHit',false, ...
    'OptimizationSeconds',0,'ValidationSeconds',0,'FitSignature','','FitFile','','Selected',false),numel(grid),1);
allClock=tic;
for i=1:numel(grid)
    t=tic;[m,~,info]=CSSP_FIT_NATIVE(C,K,A,family,grid(i));
    validationClock=tic;value=gallery_nre(development.gallery,m);validationSeconds=toc(validationClock);
    assert(isfinite(value),'CSSP:Validation','Nonfinite validation NRE.');
    row=selection(i);row.Value=grid(i);row.ValidationNRE=value;row.Seconds=toc(t);
    row.CacheHit=info.CacheHit;row.FitSignature=info.Signature;row.FitFile=info.SourceFile;
    row.OptimizationSeconds=info.FitSeconds;row.ValidationSeconds=validationSeconds;
    selection(i)=row;
end
[~,pick]=min([selection.ValidationNRE]);selection(pick).Selected=true;
locked=struct('Family',family,'CaseHash',K.caseHash,'InitHash',K.initHash, ...
    'GalleryHash',P0_IO('hashnumeric',development.gallery),'Candidates',selection, ...
    'ChosenIndex',pick,'SelectedValue',grid(pick),'ProbeScoredBeforeLock',false);
% Timing/path differences do not alter the immutable scientific selection.
identity=rmfield(locked,'Candidates');identity.Values=grid;identity.ValidationNRE=[selection.ValidationNRE];
identity.CandidateSignatures={selection.FitSignature};
sh=P0_IO('hashtext',jsonencode(identity));
lp=fullfile(C.outputRoot,C.stage,'selection_locks',[sh '.mat']);
if exist(lp,'file')==2
    old=P0_IO('load',lp);assert(strcmp(old.SelectionHash,sh),'CSSP:SelectionLock','Lock differs.');
else,locked.SelectionHash=sh;P0_IO('save',lp,locked);end
receipt=struct('LockPath',lp,'SelectionHash',sh,'ProbeScoredBeforeLock',false, ...
    'SelectedValue',grid(pick),'SelectedIndex',pick, ...
    'SelectionSeconds',sum([selection.OptimizationSeconds])+sum([selection.ValidationSeconds]), ...
    'SelectionWallSecondsThisRun',toc(allClock));
[model,S]=CSSP_FIT_NATIVE(C,K,A,family,grid(pick));
end
function z=gallery_nre(G,m)
mu=zeros(size(G,1),size(G,2));if isfield(m,'mean'),mu=m.mean;end
v=0;for i=1:size(G,3)
    a=G(:,:,i)-mu;e=G(:,:,i)-(mu+m.U*(m.U'*a*m.V)*m.V');v=v+sum(e(:).^2);
end
z=sqrt(v)/max(norm(G(:)),eps);
end
