function report = NB_COIL_SELFTEST()
% Exercise COIL's explicit MAT protocol without third-party data.
% The fixture is not a scientific result and is deleted after verification.
    C=P0_CONFIG();C.coilRank=3;
    C.syntheticBudget=[2 1 2];C.syntheticTimeLimit=30;
    fixture=[tempname '.mat'];cleanup=onCleanup(@()remove_fixture(fixture));
    old=rng;restore=onCleanup(@()rng(old));rng(802711,'twister');
    X=randn(12,10,24);labels=[ones(12,1);2*ones(12,1)];save(fixture,'X','labels');
    C.coilPath=fixture;
    [K,D,A,regime]=NB_COIL_CASE(C,1,'I10');
    [K2,D2]=NB_COIL_CASE(C,1,'I10');
    [Kclean,Dclean]=NB_COIL_CASE(C,1,'Clean');
    [Kb,Db]=NB_COIL_CASE(C,1,'B10');
    [~,Dother]=NB_COIL_CASE(C,2,'Clean');
    assert(strcmp(regime,'synthetic')&&strcmp(D.evaluation,'real'));
    assert(strcmp(K.caseHash,K2.caseHash)&&strcmp(K.initHash,K2.initHash));
    assert(strcmp(D.splitHash,D2.splitHash)&&strcmp(D.splitHash,Dclean.splitHash)&&strcmp(D.splitHash,Db.splitHash));
    assert(~strcmp(D.splitHash,Dother.splitHash));
    assert(size(K.X,3)==8&&size(D.gallery,3)==6&&size(D.probe,3)==10);
    assert(isempty(intersect(D.subIDs,D.probeIDs))&&isempty(intersect(D.galleryIDs,D.probeIDs)));
    assert(~any(Kclean.mask(:))&&any(K.mask(:))&&any(Kb.mask(:)));
    assert(A.useSeverityMemory==false&&abs(A.etaMapSlope+1.03921233145835)<1e-12);
    for j=1:size(Kclean.X,3)
        Z=Kclean.X(:,:,j);assert(abs(mean(Z(:)))<1e-12);
        assert(abs(norm(Z,'fro')-sqrt(numel(Z)))<1e-10);
    end
    report=struct('Pass',true,'Protocol','synthetic-rule COIL transfer', ...
        'RealDataUsed',false,'FixtureClasses',2,'Checks',11);
    clear restore cleanup;
end
function remove_fixture(path)
    if exist(path,'file')==2,delete(path);end
end
