function [K,D,A,regime] = NB_COIL_CASE(C,rep,condition)
% New COIL20 protocol: frozen SYNTHETIC calibration, REAL probe evaluation.
% This is not YALE/ORL archive replay and does not use their clean references.
% Accepted input: a MAT with top-level X(p,q,n), labels(n,1), or a directory
% containing grayscale objN__angle.png files. No resizing or axis guessing.
    assert(isfield(C,'coilPath') && ~isempty(C.coilPath), ...
        'NB:COILMissing','Set C.coilPath to COIL20 image directory or a MAT containing X and labels.');
    assert(isscalar(rep)&&isfinite(rep)&&rep>=1&&rep==fix(rep)&&rep<=100000, ...
        'NB:COILRepeat','Repeat must be an integer in [1,100000].');
    if ~isfield(C,'coilRank'), C.coilRank=8; end
    rank=C.coilRank;
    assert(isscalar(rank)&&isfinite(rank)&&rank>=1&&rank==fix(rank), ...
        'NB:COILRank','coilRank must be a positive integer, fixed before evaluation.');
    [X,labels,sourceHash,sourceNames] = load_coil(C.coilPath);
    assert(rank<size(X,1)&&rank<size(X,2),'NB:COILRank', ...
        'Fixed COIL rank must be smaller than each matrix axis; no automatic clipping.');
    cls=unique(labels); sub=[]; gal=[]; probe=[];
    splitSeed=731000000+rep*1000;
    oldRng=rng; restore=onCleanup(@()rng(oldRng));
    rng(splitSeed,'twister');
    for j=1:numel(cls)
        ids=find(labels==cls(j));
        assert(numel(ids)>=10,'NB:COILClassSize', ...
            'Each class requires at least ten images: class %.17g has %d.',cls(j),numel(ids));
        ids=ids(randperm(numel(ids)));
        sub=[sub;ids(1:4)]; gal=[gal;ids(5:7)]; probe=[probe;ids(8:end)]; %#ok<AGROW>
    end
    assert(isempty(intersect(sub,gal))&&isempty(intersect(sub,probe))&& ...
        isempty(intersect(gal,probe)),'NB:COILLeakage','Split membership overlaps.');
    splitHash=P0_IO('hashtext',[P0_IO('hashnumeric',sub) ...
        P0_IO('hashnumeric',gal) P0_IO('hashnumeric',probe)]);
    X0=X(:,:,sub);
    cfg=struct('blockRatio',.18,'classifier',struct('zscoreFeatures',true));
    switch char(condition)
        case 'Clean', typ='clean';rate=0;strength=0;
        case 'I10', typ='impulse';rate=.10;strength=4.5;
        case 'B10', typ='block';rate=.10;strength=4.5;
        otherwise, error('NB:COILCondition','COIL protocol supports only Clean, I10, B10.');
    end
    planSeed=splitSeed+100;
    if rate==0
        Xfit=X0; mask=false(size(Xfit)); actualRate=0;
    else
        plan=SU_FROZEN('plan',X0,typ,.30,planSeed,cfg);
        [Xfit,mask,actualRate]=SU_FROZEN('apply',X0,plan,rate,strength,cfg);
    end
    [A,~]=P0_ALG(C,'synthetic');
    % The entire mapping, including no historical maximum, is kept frozen.
    % Root dispatch must evaluate this case as REAL independently of regime.
    regime='synthetic';
    methods=P0_METHODS('core',C);
    initSeed=splitSeed+700; rng(initSeed,'twister'); t0=tic;
    [U0,V0]=SU_SYN_FROZEN('initialize',Xfit,rank,rank,methods(1),A);
    initializationSeconds=toc(t0);
    caseHash=P0_IO('hashtext',[P0_IO('hashnumeric',Xfit) P0_IO('hashnumeric',mask)]);
    initHash=P0_IO('hashtext',[P0_IO('hashnumeric',U0) P0_IO('hashnumeric',V0)]);
    K=struct('Dataset','COIL20','Condition',char(condition),'Type',typ, ...
        'NominalRate',rate,'Strength',strength,'Repeat',rep,'Seed',initSeed, ...
        'X',Xfit,'mask',mask,'rank',[rank rank],'U0',U0,'V0',V0, ...
        'InitializationSeconds',initializationSeconds,'caseHash',caseHash,'initHash',initHash);
    D=struct('dataset','COIL20','repeat',rep,'evaluation','real','cfg',cfg, ...
        'gallery',X(:,:,gal),'galleryLabels',labels(gal), ...
        'probe',X(:,:,probe),'probeLabels',labels(probe), ...
        'dataHash',sourceHash,'splitHash',splitHash,'sourceNames',{sourceNames}, ...
        'subIDs',sub,'galleryIDs',gal,'probeIDs',probe,'classIDs',cls, ...
        'splitSeed',splitSeed,'planSeed',planSeed,'actualRate',actualRate, ...
        'protocol','COIL20_frozen_synthetic_rule_cross_domain_v1', ...
        'calibrationInformation','Frozen synthetic tail reference and eta map; no COIL fit or probe outcome used for calibration.', ...
        'partitionRule','Per class: 4 fitting, 3 gallery, remainder probe; samplewise standardization.', ...
        'developmentSelection','ESS rule and rank are frozen. RA baseline lambda may be selected on gallery by NB_FIT; probe excluded.');
    clear restore;
end

function [X,labels,dataHash,names] = load_coil(path)
    persistent cachedKey cachedX cachedLabels cachedHash cachedNames
    path=char(path);
    if exist(path,'file')==2
        [~,~,ext]=fileparts(path);
        assert(strcmpi(ext,'.mat'),'NB:COILFormat','File input must be MAT with X and labels.');
        info=dir(path); key=sprintf('%s|%.17g|%d',path,info.datenum,info.bytes);
        names={path}; files=[];
    elseif exist(path,'dir')==7
        files=dir(fullfile(path,'**','*.png'));
        files=[files;dir(fullfile(path,'**','*.PNG'))];
        if ~isempty(files)
            paths=arrayfun(@(f)fullfile(f.folder,f.name),files,'UniformOutput',false);
            [~,keep]=unique(paths,'stable');files=files(keep);
        end
        obj=zeros(numel(files),1);angle=zeros(numel(files),1); keep=false(numel(files),1);
        for j=1:numel(files)
            tok=regexpi(files(j).name,'^obj(\d+)__(-?\d+(?:\.\d+)?)\.png$','tokens','once');
            if ~isempty(tok)
                obj(j)=str2double(tok{1});angle(j)=str2double(tok{2});keep(j)=true;
            end
        end
        files=files(keep);obj=obj(keep);angle=angle(keep);
        assert(~isempty(files),'NB:COILFiles', ...
            'No objN__angle.png files found. Other image naming schemes need an explicit MAT X,labels.');
        [~,ix]=sortrows([obj angle],[1 2]);files=files(ix);obj=obj(ix);angle=angle(ix);
        assert(size(unique([obj angle],'rows'),1)==numel(files),'NB:COILDuplicate', ...
            'Duplicate object/angle pair found; use one definitive dataset directory.');
        names=arrayfun(@(f)fullfile(f.folder,f.name),files,'UniformOutput',false);
        receipts=cell(numel(files),3);
        for j=1:numel(files),receipts(j,:)={names{j},files(j).bytes,files(j).datenum};end
        key=P0_IO('hashtext',jsonencode(receipts));
    else
        error('NB:COILMissing','COIL path does not exist: %s',path);
    end
    if ~isempty(cachedKey)&&strcmp(cachedKey,key)
        X=cachedX;labels=cachedLabels;dataHash=cachedHash;names=cachedNames;return;
    end
    if isempty(files)
        z=load(path);
        assert(isfield(z,'X')&&isfield(z,'labels'),'NB:COILMAT', ...
            'MAT must contain top-level X(p,q,n) and labels. No variable-name or dimension guessing.');
        X=z.X;labels=z.labels;
    else
        labels=obj;
        first=imread(names{1});
        assert(ismatrix(first),'NB:COILGray','COIL PNG files must be grayscale; RGB conversion is not implicit.');
        dims=size(first);X=zeros(dims(1),dims(2),numel(names));
        for j=1:numel(names)
            I=imread(names{j});
            assert(ismatrix(I)&&isequal(size(I),dims),'NB:COILImageSize', ...
                'Image dimensions differ or image is RGB: %s. No resizing is performed.',names{j});
            X(:,:,j)=double(I);
        end
    end
    assert(isnumeric(X)&&isreal(X)&&ndims(X)==3&&all(isfinite(X(:))), ...
        'NB:COILTensor','X must be a finite, real numeric p-by-q-by-n tensor.');
    assert(isnumeric(labels)&&isreal(labels)&&isvector(labels)&& ...
        numel(labels)==size(X,3)&&all(isfinite(labels(:))), ...
        'NB:COILLabels','Numeric labels must contain exactly one finite value per image.');
    labels=double(labels(:));assert(numel(unique(labels))>=2,'NB:COILClasses','At least two classes required.');
    for j=1:size(X,3)
        Z=double(X(:,:,j));Z=Z-mean(Z(:));
        assert(norm(Z,'fro')>1e-12,'NB:COILConstant','Constant image cannot be standardized; sample %d.',j);
    end
    X=SU_FROZEN('standardize',X,'sqrtmn');
    dataHash=P0_IO('hashtext',[P0_IO('hashnumeric',X) P0_IO('hashnumeric',labels)]);
    cachedKey=key;cachedX=X;cachedLabels=labels;cachedHash=dataHash;cachedNames=names;
end
