function [model,diagnostic]=CSSP_EXTERNAL(method,K,D,A,C)
%CSSP_EXTERNAL External references with a training/development-only boundary.
% Probe arrays and contamination masks are NEVER passed to external code.
% Missing dependencies remain BLOCKED; this function never substitutes an
% invented algorithm for BA2DPCA, L2p-SB-2DPCA or ROMPCA.
    method=char(method);model=[];fitClock=tic;
    diagnostic=blank_diagnostic(method);
    ready=CSSP_EXTERNAL_CHECK(method,C);diagnostic.Dependency=ready;
    if ~ready.Ready
        diagnostic.Status='BLOCKED_DEPENDENCY';diagnostic.Message=ready.Message;return;
    end
    try
        switch upper(method)
            case 'L2'
                M=NB_NATIVE_METHOD(C,'L2');
                % Solver's mask is diagnostic only. An all-false mask avoids
                % giving even diagnostic ground truth to this entry point.
                [model,~]=P0_SOLVER_V2(K.X,K.rank(1),K.rank(2),M,A,'real',K.U0,K.V0,false(size(K.X)));
                model.provenance='Frozen P0 L2 objective with common robust BPCA initialization; not a separately claimed native GLRAM implementation.';
                model.initializationHash=K.initHash;
                diagnostic.InitializationSeconds=K.InitializationSeconds;
            case {'RA2DPCA_DEV','RA2DPCA'}
                [model,diagnostic]=run_ra(K,D,A,C,diagnostic);
            case 'ROMPCA'
                [model,diagnostic]=run_rompca(K,A,C,ready,diagnostic);
            otherwise
                % Only this deliberately small, public development structure
                % crosses the adapter boundary, not D or K themselves.
                dev=struct();
                if isfield(D,'gallery'),dev.gallery=D.gallery;end
                if isfield(D,'galleryLabels'),dev.galleryLabels=D.galleryLabels;end
                info=struct('rank',K.rank,'U0',K.U0,'V0',K.V0, ...
                    'seed',K.Seed+991,'maxOuter',A.maxOuter, ...
                    'development',dev,'validationObjective','clean_gallery_NRE', ...
                    'commonInitializationIsOptional',true);
                rng(info.seed,'twister');model=feval(ready.Adapter,K.X,info);
                assert(isfield(model,'provenance')&&isfield(model,'initializationHash'), ...
                    'CSSP:ExternalProvenance','Adapter must return provenance and actual initializationHash.');
                diagnostic.InitializationSeconds=get(model,'initializationSeconds',NaN);
                diagnostic.SelectionSeconds=get(model,'selectionSeconds',NaN);
                diagnostic.SelectedValue=get(model,'selectedValue',NaN);
                if isfield(model,'selection'),diagnostic.Candidates=model.selection;end
        end
        validate_model(model,K,method);
        diagnostic.FeatureDimension=size(model.U,2)*size(model.V,2);
        diagnostic.Provenance=get(model,'provenance',diagnostic.Provenance);
        diagnostic.InitializationHash=get(model,'initializationHash','');
        if ~strcmp(diagnostic.Status,'UNUSABLE_BASELINE')
            diagnostic.Status='FINISHED';diagnostic.Usable=true;
        end
        diagnostic.StopReason=get(model,'StopReason',get(model,'stopReason',get(model,'status','external_finished')));
        diagnostic.RuntimeSeconds=toc(fitClock);
    catch e
        diagnostic.Status='FAILED_EXTERNAL';diagnostic.Usable=false;
        diagnostic.Identifier=e.identifier;diagnostic.Message=e.message;
        diagnostic.RuntimeSeconds=toc(fitClock);model=[];
    end
end

function [model,d]=run_ra(K,D,A,C,d)
    assert(isfield(D,'gallery'),'CSSP:RADevelopment','RA selection requires clean gallery, never probe.');
    grid=get(C,'raLambdaGrid',[.1 1 10]);gamma=NB_RA_DEFAULT_GAMMA(K.X);
    k=max(1,min(size(K.X,2)-1,ceil(prod(K.rank)/size(K.X,1))));
    limit=get(C,'raMaxOuter',100);
    if strcmpi(get(C,'stage','paper'),'pilot'),limit=min(limit,3);end
    opts=struct('center',true,'maxOuter',limit,'tolerance',get(C,'raTolerance',1e-4),'timeLimit',Inf);
    b=struct('Value',NaN,'ValidationNRE',NaN,'Seconds',NaN,'Gamma',gamma, ...
        'Degenerate',false,'ExitStatus','','FeatureDimension',size(K.X,1)*k);
    rows=repmat(b,numel(grid),1);best=Inf;model=[];pick=NaN;selection=tic;
    for j=1:numel(grid)
        t=tic;m=NB_RA2DPCA(K.X,k,gamma,grid(j),opts);
        val=gallery_nre(D.gallery,m);q=NB_RA_DIAGNOSTICS(K.X,m);
        rows(j)=b;rows(j).Value=grid(j);rows(j).ValidationNRE=val;rows(j).Seconds=toc(t);
        rows(j).ExitStatus=m.stopReason;
        rows(j).Degenerate=m.ZeroWeightDegenerate||q.FinalAllWeightsZero||q.FinalZeroCovariance||q.FinalCovarianceRank<k;
        if val<best,best=val;model=m;pick=j;end
    end
    assert(~isempty(model),'CSSP:RASelection','No finite validation candidate.');
    d.SelectionSeconds=toc(selection);d.SelectedValue=grid(pick);d.Candidates=rows;
    d.InitializationSeconds=NaN; % Native mean/identity initialization is inside each candidate fit.
    model.provenance=['Independent MATLAB port of author R recurrence; commit ' ...
        '84d54472cc5b615611b605f330df2501d00401d0; native mean and identity right basis; ' ...
        'lambda selected only by clean-gallery NRE; k=ceil(bilateral feature dimension / image rows).'];
    model.initializationHash=P0_IO('hashtext',[P0_IO('hashnumeric',eye(size(K.X,2),k)) P0_IO('hashnumeric',model.mean)]);
    d.Provenance=model.provenance;
    d.CapacityNote='One-sided p*k features. This dimension is reported, not claimed equal to bilateral r*c.';
    if rows(pick).Degenerate
        d.Status='UNUSABLE_BASELINE';d.Usable=false;
        d.Message='Validation-selected RA candidate has zero/degenerate weights or insufficient covariance rank; retained, not silently rescued.';
    end
end

function [model,d]=run_rompca(K,A,C,R,d)
    work=tempname;mkdir(work);clean=onCleanup(@()remove_work(work));
    [p,q,n]=size(K.X);limit=get(C,'rompcaMaxOuter',A.maxOuter);
    if strcmpi(get(C,'stage','paper'),'pilot'),limit=min(limit,3);end
    tolerance=get(C,'rompcaTolerance',1e-5);seed=K.Seed+991;
    f=fopen(fullfile(work,'X.bin'),'w','ieee-le');assert(f>=0,'CSSP:ExternalIO','Cannot create R input');
    closeFile=onCleanup(@()fclose(f));fwrite(f,double(K.X(:)),'double');clear closeFile;
    fid=fopen(fullfile(work,'dimensions.txt'),'w');assert(fid>=0,'CSSP:ExternalIO','Cannot create R dimensions');
    fprintf(fid,'%.17g\n',[p q n K.rank(:)' seed limit tolerance]);fclose(fid);
    bridge=fullfile(fileparts(mfilename('fullpath')),'CSSP_ROMPCA_BRIDGE.R');
    cmd=[quote_arg(R.Rscript) ' --vanilla ' quote_arg(bridge) ' fit ' quote_arg(R.Source) ...
        ' ' quote_arg(work) ' ' quote_arg(R.Library) ' 2>&1'];
    t=tic;[status,log]=system(cmd);d.BridgeSeconds=toc(t);d.Log=log;
    assert(status==0,'CSSP:ROMPCARun','ROMPCA R process failed (%d). %s',status,log);
    U=read_binary(fullfile(work,'U.bin'),[p K.rank(1)]);
    V=read_binary(fullfile(work,'V.bin'),[q K.rank(2)]);
    mu=read_binary(fullfile(work,'mean.bin'),[p q]);
    U0=read_binary(fullfile(work,'U0.bin'),[p K.rank(1)]);
    V0=read_binary(fullfile(work,'V0.bin'),[q K.rank(2)]);
    mu0=read_binary(fullfile(work,'mean0.bin'),[p q]);
    T=readtable(fullfile(work,'metadata.csv'),'TextType','string');
    conv=meta_number(T,'converged');iters=meta_number(T,'iterations');
    elapsed=meta_number(T,'algorithm_seconds');initTime=meta_number(T,'initialization_seconds');
    if conv==1,stop='native_relative_loss_stable';else,stop='native_iteration_limit';end
    provenance=['Original author ROMPCA R implementation: https://fabiocentofanti.github.io/files/Code_ROMPCA.zip; ' ...
        'ROMPCA_Code_JCGS.R SHA256=' R.SourceSHA256 '; own binary I/O wrapper; native DDC/L1 initialization; ' ...
        'original dependency installer skipped, no computational recurrence rewritten.'];
    initHash=P0_IO('hashtext',[P0_IO('hashnumeric',U0) P0_IO('hashnumeric',V0) P0_IO('hashnumeric',mu0)]);
    model=struct('U',U,'V',V,'mean',mu,'provenance',provenance, ...
        'initializationHash',initHash,'commonInitializationUsed',false, ...
        'stopReason',stop,'elapsedSeconds',elapsed,'initializationSeconds',initTime, ...
        'iterations',iters,'maxOuter',limit,'nativeConverged',logical(conv), ...
        'officialSourceSHA256',R.SourceSHA256,'meanConvention','Center.corr if returned, otherwise Center');
    model.nativeLoss=readtable(fullfile(work,'loss.csv'));
    model.packageVersions=readtable(fullfile(work,'package_versions.csv'),'TextType','string');
    d.InitializationSeconds=initTime;d.SelectionSeconds=0;d.SelectedValue=1.5;
    d.BudgetContract='Native max_itr applies to ROMPCA/L1; DDC MPCA initialization retains original defaults. No wall-clock cap.';
    d.Provenance=provenance;d.InitializationHash=initHash;d.RMetadata=T;
    clear clean;
end

function z=gallery_nre(X,m)
    mu=zeros(size(X,1),size(X,2));if isfield(m,'mean'),mu=m.mean;end
    value=0;for i=1:size(X,3),a=X(:,:,i)-mu;e=X(:,:,i)-(mu+m.U*(m.U'*a*m.V)*m.V');value=value+sum(e(:).^2);end
    z=sqrt(value)/max(norm(X(:)),eps);assert(isfinite(z),'CSSP:ExternalNRE','Nonfinite validation NRE');
end
function validate_model(m,K,method)
    assert(isstruct(m)&&all(isfield(m,{'U','V'})),'CSSP:ExternalModel','Missing U/V.');
    [p,q,~]=size(K.X);assert(size(m.U,1)==p&&size(m.V,1)==q,'CSSP:ExternalShape','Incorrect basis dimensions.');
    assert(isreal(m.U)&&isreal(m.V)&&all(isfinite(m.U(:)))&&all(isfinite(m.V(:))), ...
        'CSSP:ExternalFinite','Nonfinite/complex basis.');
    assert(norm(m.U'*m.U-eye(size(m.U,2)),'fro')<1e-6&&norm(m.V'*m.V-eye(size(m.V,2)),'fro')<1e-6, ...
        'CSSP:ExternalOrthogonal','Nonorthonormal basis; do not silently rotate or replace the original readout.');
    if ~any(strcmpi(method,{'RA2DPCA','RA2DPCA_dev'}))
        assert(isequal([size(m.U,2) size(m.V,2)],reshape(K.rank,1,[])), ...
            'CSSP:ExternalRank','External bilateral ranks differ from requested ranks.');
    end
    if isfield(m,'mean'),assert(isequal(size(m.mean),[p q])&&all(isfinite(m.mean(:))), ...
            'CSSP:ExternalMean','Missing/nonfinite mean image.');end
end
function x=read_binary(path,shape)
    f=fopen(path,'r','ieee-le');assert(f>=0,'CSSP:ExternalIO','Missing R output: %s',path);
    c=onCleanup(@()fclose(f));v=fread(f,Inf,'double=>double');
    assert(numel(v)==prod(shape),'CSSP:ExternalIO','Incorrect R output length: %s',path);x=reshape(v,shape);clear c;
end
function v=meta_number(T,key)
    k=find(string(T.Key)==string(key),1);assert(~isempty(k),'CSSP:ExternalIO','Missing metadata %s',key);
    v=str2double(string(T.Value(k)));assert(isfinite(v),'CSSP:ExternalIO','Nonfinite metadata %s',key);
end
function d=blank_diagnostic(method)
    d=struct('Method',method,'Status','NOT_STARTED','Usable',false,'Message','', ...
        'Identifier','','RuntimeSeconds',NaN,'SelectionSeconds',0,'InitializationSeconds',NaN, ...
        'SelectedValue',NaN,'Candidates',[],'Provenance','','InitializationHash','', ...
        'FeatureDimension',NaN,'StopReason','');
end
function s=quote_arg(s)
    s=char(s);assert(~any(s==char(0)|s==char(10)|s==char(13)),'CSSP:CommandPath','Invalid command argument.');
    if ispc
        assert(~any(s=='"'|s=='%'|s=='!'),'CSSP:CommandPath','Unsupported shell character in Windows path.');s=['"' s '"'];
    else
        a=char(39);s=[a strrep(s,a,[a char(34) a char(34) a]) a];
    end
end
function remove_work(work)
    if isfolder(work),rmdir(work,'s');end
end
function v=get(s,k,f)
    if isfield(s,k),v=s.(k);else,v=f;end
end
