function imported=CSSP_IMPORT_PRIOR(C,K,A,M,regime)
% Read-only, conservative reuse of scientifically matched P0 v2 endpoints.
% No CSV result, legacy TC result, short pilot, or rotated basis is imported.
imported=struct('Found',false,'model',[],'state',[],'FitSeconds',NaN, ...
    'PriorFile','','EndpointOnlyImported',false,'Reason','No prior roots configured.', ...
    'RejectedRoots',{{}},'RejectedFiles',{{}});
if ~isfield(C,'priorResultRoots')||isempty(C.priorResultRoots),return;end
roots=C.priorResultRoots;
if ischar(roots)||isstring(roots),roots=cellstr(roots);end
assert(iscell(roots),'CSSP:PriorRoots','priorResultRoots must be a cell array of result roots.');
assert(all(isfield(K,{'X','mask','U0','V0','rank','Dataset','Repeat','Condition'})), ...
    'CSSP:PriorInput','Incomplete current training case.');
caseHash=P0_IO('hashtext',[P0_IO('hashnumeric',K.X) P0_IO('hashnumeric',K.mask)]);
initHash=P0_IO('hashtext',[P0_IO('hashnumeric',K.U0) P0_IO('hashnumeric',K.V0)]);
expectedMethod=canonical_method(M);expectedAlg=canonical_alg(A);
currentSources=P0_IO('sources',C.packageRoot);matched=struct([]);endpointHashes={};
for r=1:numel(roots)
    root=char(roots{r});
    [sourceOK,sourceReason]=source_match(root,currentSources);
    if ~sourceOK
        imported.RejectedRoots{end+1,1}=sprintf('%s: %s',root,sourceReason); %#ok<AGROW>
        continue;
    end
    pattern=sprintf('%s_r%03d_%s_*_v2_B*',K.Dataset,K.Repeat,K.Condition);
    files=dir(fullfile(root,'*','fits',pattern,'fit.mat'));
    if isempty(files),continue;end
    paths=cellfun(@(a,b)fullfile(a,b),{files.folder},{files.name},'UniformOutput',false);
    paths=sort(paths);
    for k=1:numel(paths)
        file=paths{k};
        try
            old=P0_IO('load',file);
            if ~isstruct(old)||~all(isfield(old,{'metadata','record','model','signature'})),continue;end
            meta=old.metadata;record=old.record;
            need={'caseHash','initHash','rank','method','alg','regime','version'};
            if ~all(isfield(meta,need)),continue;end
            if ~strcmp(meta.version,'v2')||~strcmp(meta.regime,regime),continue;end
            if ~isfield(record,'IsScientificRun')||~isequal(record.IsScientificRun,true),continue;end
            if ~strcmp(meta.caseHash,caseHash)||~strcmp(meta.initHash,initHash),continue;end
            if ~isequal(meta.rank,K.rank),continue;end
            if ~same_struct(canonical_method(meta.method),expectedMethod),continue;end
            if ~same_struct(canonical_alg(meta.alg),expectedAlg),continue;end
            if ~strcmp(old.signature,P0_IO('hashtext',jsonencode(meta)))
                error('CSSP:PriorReceipt','Stored metadata no longer matches its signature.');
            end
            if ~isfield(record,'CaseHash')||~strcmp(record.CaseHash,caseHash) ...
                    ||~isfield(record,'InitHash')||~strcmp(record.InitHash,initHash)
                error('CSSP:PriorReceipt','Record and metadata input receipts disagree.');
            end
            [model,state,fitSeconds,endpointOnly]=validate_endpoint(old.model,K,A,M);
            z=struct('Found',true,'model',model,'state',state,'FitSeconds',fitSeconds, ...
                'PriorFile',file,'EndpointOnlyImported',endpointOnly);
            if isempty(matched),matched=z;else,matched(end+1)=z;end %#ok<AGROW>
            endpointHashes{end+1,1}=endpoint_hash(model,state); %#ok<AGROW>
        catch e
            imported.RejectedFiles{end+1,1}=sprintf('%s: %s: %s',file,e.identifier,e.message); %#ok<AGROW>
        end
    end
end
if isempty(matched)
    imported.Reason='No source-verified scientific P0 v2 endpoint matches the current input, initialization, method and algorithm.';
    return;
end
if numel(unique(endpointHashes))~=1
    imported.Reason='Conflicting endpoints have the same scientific receipts. No prior endpoint was selected.';
    imported.RejectedFiles{end+1,1}=strjoin({matched.PriorFile},' | ');
    return;
end
% Deterministic path order, and only after ALL matching endpoint identities agree.
pick=matched(1);names=fieldnames(pick);
for k=1:numel(names),imported.(names{k})=pick.(names{k});end
imported.Reason='Exact inputs, initialization, method, algorithm and source verified; prior endpoint reused without refitting.';
end

function [ok,reason]=source_match(root,current)
% Cache the manifest comparison, not training outcomes. File changes invalidate it.
persistent keys answers reasons
if isempty(keys),keys={};answers=false(0,1);reasons={};end
ok=false;reason='Missing source_manifest.mat.';file=fullfile(root,'source_manifest.mat');
if exist(file,'file')~=2,return;end
info=dir(file);fingerprint=P0_IO('hashfile',file);
key=P0_IO('hashtext',jsonencode({file,info.bytes,info.datenum,fingerprint,current}));
hit=find(strcmp(keys,key),1);
if ~isempty(hit),ok=answers(hit);reason=reasons{hit};return;end
try
    manifest=P0_IO('load',file);
    assert(isstruct(manifest)&&all(isfield(manifest,{'sources','hash'})), ...
        'CSSP:PriorSource','Invalid source manifest schema.');
    sources=manifest.sources;
    assert(iscell(sources)&&size(sources,2)==2, ...
        'CSSP:PriorSource','Invalid source table.');
    assert(strcmp(manifest.hash,P0_IO('hashtext',jsonencode(sources))), ...
        'CSSP:PriorSource','Source table and its receipt disagree.');
    a=sources;b=current;
    for k=1:size(a,1),a{k,1}=strrep(char(a{k,1}),'\','/');end
    for k=1:size(b,1),b{k,1}=strrep(char(b{k,1}),'\','/');end
    a=sortrows(a,1);b=sortrows(b,1);
    assert(size(a,1)==size(b,1)&&numel(unique(a(:,1)))==size(a,1)&&isequal(a,b), ...
        'CSSP:PriorSource','The complete P0 .m/frozen .m source table is not identical.');
    ok=true;reason='Complete P0 source manifest matches.';
catch e,reason=sprintf('%s: %s',e.identifier,e.message);end
keys{end+1,1}=key;answers(end+1,1)=ok;reasons{end+1,1}=reason;
end

function x=canonical_method(x)
assert(isstruct(x)&&isscalar(x),'CSSP:PriorMethod','Invalid method schema.');
drop=intersect(fieldnames(x),{'id','name'});x=rmfield(x,drop);x=orderfields(x);
end

function x=canonical_alg(x)
assert(isstruct(x)&&isscalar(x),'CSSP:PriorAlgorithm','Invalid algorithm schema.');
% These are logging-only fields. No tolerance, budget, memory or calibration
% parameter is ignored, including finite versus infinite wall-clock limits.
drop=intersect(fieldnames(x),{'nbTraceEvery','nbProgressEvery'});x=rmfield(x,drop);x=orderfields(x);
end

function yes=same_struct(a,b)
yes=isequaln(orderfields(a),orderfields(b));
end

function [model,S,seconds,endpointOnly]=validate_endpoint(model,K,A,M)
need={'solverVersion','U','V','status','StopReason','outerIters','TimeSeconds', ...
    'AcceptedSteps','finalState','finalSampleWeights','finalTau','finalEta','finalGuard', ...
    'finalTailSeverity','finalCurrentTailSeverity','finalDiagnostics'};
assert(isstruct(model)&&all(isfield(model,need)),'CSSP:PriorEndpoint','Incomplete P0 v2 model.');
assert(strcmp(model.solverVersion,'v2'),'CSSP:PriorEndpoint','Not a v2 endpoint.');
assert(any(strcmp(model.status,{'budget_exhausted','timecap','failed_search','numerically_stable'})), ...
    'CSSP:PriorEndpoint','Unknown endpoint status.');
assert(ischar(model.StopReason)&&~isempty(model.StopReason),'CSSP:PriorEndpoint','Missing stopping reason.');
assert(isequal(size(model.U),[size(K.X,1),K.rank(1)]) ...
    &&isequal(size(model.V),[size(K.X,2),K.rank(2)]),'CSSP:PriorEndpoint','Endpoint dimensions differ.');
assert(isreal(model.U)&&isreal(model.V)&&all(isfinite(model.U(:)))&&all(isfinite(model.V(:))), ...
    'CSSP:PriorEndpoint','Invalid endpoint bases.');
assert(norm(model.U'*model.U-eye(K.rank(1)),'fro')<1e-7 ...
    &&norm(model.V'*model.V-eye(K.rank(2)),'fro')<1e-7, ...
    'CSSP:PriorEndpoint','Endpoint bases are not orthonormal.');
assert(isscalar(model.outerIters)&&isfinite(model.outerIters)&&model.outerIters>=0 ...
    &&model.outerIters==fix(model.outerIters)&&model.outerIters<=A.maxOuter, ...
    'CSSP:PriorEndpoint','Invalid outer iteration count.');
assert(isscalar(model.AcceptedSteps)&&isfinite(model.AcceptedSteps)&&model.AcceptedSteps>=0 ...
    &&model.AcceptedSteps==fix(model.AcceptedSteps), 'CSSP:PriorEndpoint','Invalid accepted-step count.');
seconds=model.TimeSeconds;
assert(isscalar(seconds)&&isfinite(seconds)&&seconds>=0,'CSSP:PriorEndpoint','Invalid historical fit duration.');
S=model.finalState;
assert(isstruct(S)&&all(isfield(S,{'scale','Ws','a','tau','eta','current','severity','guard'})), ...
    'CSSP:PriorEndpoint','Missing final frozen state.');
assert(same_number(S.tau,model.finalTau)&&same_number(S.eta,model.finalEta) ...
    &&isequal(S.guard,model.finalGuard)&&same_number(S.severity,model.finalTailSeverity) ...
    &&same_number(S.current,model.finalCurrentTailSeverity), ...
    'CSSP:PriorEndpoint','Top-level and final-state diagnostics disagree.');
assert(isequal(S.Ws(:),model.finalSampleWeights(:))&&numel(S.Ws)==size(K.X,3) ...
    &&numel(S.a)==size(K.X,3)&&all(isfinite(S.a(:)))&&all(S.a(:)>=0), ...
    'CSSP:PriorEndpoint','Sample coefficients disagree.');
assert(norm(S.a(:)-S.Ws(:).^A.sampleWeightAlpha)<=1e-12*max(1,norm(S.a(:))), ...
    'CSSP:PriorEndpoint','Stored sample coefficients do not match the fixed exponent.');
E=SU_FROZEN('residual',K.X,model.U,model.V);
if S.guard||strcmp(M.loss,'l2'),S.We=ones(size(E));
elseif strcmp(M.loss,'tukey'),S.We=SU_FROZEN('tukeyweights',E,S.tau);
elseif strcmp(M.loss,'huber')
    S.We=ones(size(E));j=abs(E)>S.tau;S.We(j)=S.tau./abs(E(j));
elseif strcmp(M.loss,'welsch'),S.We=exp(-(E./S.tau).^2);
else,error('CSSP:PriorLoss','Unsupported loss.');end
assert(all(isfinite(S.We(:)))&&all(S.We(:)>=0)&&all(S.We(:)<=1), ...
    'CSSP:PriorEndpoint','Invalid reconstructed element weights.');
S.W=S.We;for i=1:size(K.X,3),S.W(:,:,i)=S.W(:,:,i)*S.a(i);end
diag=SU_WEIGHT_METRICS(S.We,K.mask,E,S.tau,A.zeroTol);
for f={'ESS','ZeroExact','TPR0','FPR0','Precision0'}
    name=f{1};assert(isfield(model.finalDiagnostics,name) ...
        &&same_number(diag.(name),model.finalDiagnostics.(name)), ...
        'CSSP:PriorEndpoint','Stored final diagnostic %s differs from recomputation.',name);
end
endpointOnly=~isfield(model,'checkpoints')||isempty(model.checkpoints);
if endpointOnly
    model.checkpoints=struct('Outer',0,'Seconds',0,'U',K.U0,'V',K.V0,'Memory',0);
    if model.outerIters>0
        model.checkpoints(end+1)=struct('Outer',model.outerIters,'Seconds',seconds, ...
            'U',model.U,'V',model.V,'Memory',model.finalTailSeverity);
    else
        assert(isequal(model.U,K.U0)&&isequal(model.V,K.V0),'CSSP:PriorEndpoint','Zero-iteration model changed its basis.');
    end
end
model.EndpointOnlyImported=endpointOnly;
model.PriorTrainingSeconds=seconds;
model.Instrumentation='imported_P0_v2_endpoint_only_no_invented_intermediate_checkpoints';
end

function yes=same_number(a,b)
if isequaln(a,b),yes=true;return;end
yes=isscalar(a)&&isscalar(b)&&isfinite(a)&&isfinite(b) ...
    &&abs(a-b)<=1e-10*max([1 abs(a) abs(b)]);
end

function h=endpoint_hash(m,S)
identity=struct('U',P0_IO('hashnumeric',m.U),'V',P0_IO('hashnumeric',m.V), ...
    'State',rmfield(S,{'W','We'}),'Status',m.status,'StopReason',m.StopReason, ...
    'Outer',m.outerIters,'AcceptedSteps',m.AcceptedSteps);
h=P0_IO('hashtext',jsonencode(identity));
end
