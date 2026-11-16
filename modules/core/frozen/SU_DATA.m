function D=SU_DATA(C,ds,rep)
% Use normalized archive tensors and frozen DEV calibration. No re-splitting.
    assert(~isempty(C.archiveRoot)&&exist(C.archiveRoot,'dir')==7,'SU:Path','Set C.archiveRoot in SU_CONFIG.m to the completed TC output root.');
    persistent cacheKey cache
    cf=fullfile(C.archiveRoot,'cache',[ds '_normalized.mat']);
    assert(exist(cf,'file')==2,'SU:Cache','Missing normalized archive cache: %s. Restore it from the original run; do not silently reload reordered raw data.',cf);
    info=dir(cf);key=sprintf('%s|%d|%.17g',cf,info.bytes,info.datenum);
    if isempty(cacheKey)||~strcmp(cacheKey,key)
        cache=SU_UTIL('load',cf);
        dh=SU_UTIL('hashtext',[SU_UTIL('hashnumeric',cache.ds.X) SU_UTIL('hashnumeric',cache.ds.labels)]);
        assert(strcmp(dh,cache.dataHash),'SU:DataHash','Normalized data hash differs from archive.');cacheKey=key;
    end
    sf=fullfile(C.archiveRoot,'splits',sprintf('%s_r%03d.mat',ds,rep));
    ff=fullfile(C.archiveRoot,'calibration',sprintf('%s_r%03d',ds,rep),'fold.mat');
    assert(exist(sf,'file')==2&&exist(ff,'file')==2,'SU:Fold','Missing split/calibration: %s repeat %d',ds,rep);
    S=SU_UTIL('load',sf);F=SU_UTIL('load',ff);
    assert(strcmp(S.dataset,ds)&&S.repeat==rep&&strcmp(F.dataHash,cache.dataHash)&&strcmp(F.splitHash,S.hash),'SU:FoldHash','Fold/split/data signature differs');
    assert(strcmp(F.protocolHash,cache.protocolHash),'SU:Protocol','Archive protocol hashes differ');
    assert(isempty(intersect(S.dev,S.probe))&&isempty(intersect(S.sub,S.probe))&&isempty(intersect(S.gallery,S.probe)),'SU:Leakage','Probe overlap');
    assert(isfield(F,'probeExcluded')&&F.probeExcluded,'SU:Leakage','Probe exclusion receipt missing');
    assert(iscell(F.calibrationIDs)&&size(F.calibrationIDs,2)>=3,'SU:Schema','Calibration ID receipt schema');
    for kk=1:size(F.calibrationIDs,1)
        assert(isempty(intersect(F.calibrationIDs{kk,3},S.probe)),'SU:Leakage','Calibration/probe overlap');
    end
    bundled=fullfile(C.packageRoot,'archive_splits',sprintf('%s_r%03d.mat',ds,rep));
    if exist(bundled,'file')==2
        B=SU_UTIL('load',bundled);assert(strcmp(B.hash,S.hash)&&isequal(B.sub,S.sub)&&isequal(B.dev,S.dev)&&isequal(B.gallery,S.gallery)&&isequal(B.probe,S.probe),'SU:BundledSplit','Archive differs from the provided frozen split.');
    end
    cfg=F.cfg;A=cfg.alg;
    A.maxOuter=C.realBudget(1);A.maxInner=C.realBudget(2);A.mmLineSearchMax=C.realBudget(3);
    A.maxTimePerMethod=Inf;
    assert(isfield(cfg.tailReference,ds)&&isfield(cfg.sampleReference,ds),'SU:Reference','Frozen references missing');
    A.realTail=cfg.tailReference.(ds);A.realSample=cfg.sampleReference.(ds);
    D=struct('dataset',ds,'repeat',rep,'S',S,'F',F,'cfg',cfg,'A',A,'dataHash',cache.dataHash, ...
        'X0',cache.ds.X(:,:,S.sub),'gallery',cache.ds.X(:,:,S.gallery),'galleryLabels',cache.ds.labels(S.gallery), ...
        'probe',cache.ds.X(:,:,S.probe),'probeLabels',cache.ds.labels(S.probe));
end
