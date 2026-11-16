function K=SU_CASE(C,D,condition,explicitCase)
    if nargin<4
        if strcmp(condition,'Clean'),typ='clean';rate=0;strength=0;
        else,rate=str2double(condition(2:end))/100;if condition(1)=='I',typ='impulse';else,typ='block';end
            if strcmp(D.dataset,'YALE'),strength=6;else,strength=4.5;end
        end
        cs=find_case(C.archiveRoot,D.dataset,D.repeat,typ,rate,strength);
        assert(~isempty(cs),'SU:Case','Missing archived %s/%d/%s case.mat',D.dataset,D.repeat,condition);
    else,cs=explicitCase;typ=char(cs.job.Type);rate=cs.job.Rate;strength=cs.job.Strength;end
    assert(strcmp(cs.dataHash,D.dataHash)&&strcmp(cs.splitHash,D.S.hash)&&strcmp(cs.protocolHash,D.F.protocolHash),'SU:CaseHash','Archived case signature differs');
    assert(isequal(cs.trainingIDs,D.S.sub)&&isequal(cs.galleryIDs,D.S.gallery)&&isequal(cs.probeIDs,D.S.probe),'SU:IDs','Case IDs differ');
    if strcmp(typ,'clean'),X=D.X0;mask=false(size(X));actual=0;
    else
        P=TC_PROTOCOL();plan=SU_FROZEN('plan',D.X0,typ,P.planMaximumRate,cs.planSeed,D.cfg);
        [X,mask,actual]=SU_FROZEN('apply',D.X0,plan,rate,strength,D.cfg);
    end
    h=SU_UTIL('hashtext',[SU_UTIL('hashnumeric',X) SU_UTIL('hashnumeric',mask)]);
    assert(strcmp(h,cs.caseHash)&&abs(actual-cs.actualRate)<1e-12,'SU:CaseReplay','Corruption replay does not match original case');
    K=struct('X',X,'mask',mask,'delta',X-D.X0,'actualRate',actual,'caseHash',h,'case',cs);
end
function cs=find_case(root,ds,rep,typ,rate,strength)
    persistent cachedRoot cases
    if isempty(cachedRoot)||~strcmp(cachedRoot,root)
        fs=dir(fullfile(root,'jobs','*','case.mat'));cases=cell(numel(fs),1);
        for k=1:numel(fs),cases{k}=SU_UTIL('load',fullfile(fs(k).folder,fs(k).name));end
        cachedRoot=root;
    end
    cs=[];
    for k=1:numel(cases)
        z=cases{k};j=z.job;
        if strcmp(char(j.Dataset),ds)&&j.Repeat==rep&&strcmp(char(j.Type),typ)&&abs(j.Rate-rate)<1e-12&&abs(j.Strength-strength)<1e-12
            if isempty(cs),cs=z;else,assert(strcmp(cs.caseHash,z.caseHash),'SU:ConflictingCase','Same condition has different archive cases');end
        end
    end
end
