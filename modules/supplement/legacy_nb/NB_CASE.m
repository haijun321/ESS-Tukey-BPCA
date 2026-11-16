function [K,D,A,regime]=NB_CASE(C,job)
% Never reconstruct an archived real split from reordered raw images.
    if strcmp(job.Dataset,'COIL20')
        [K,D,A,regime]=NB_COIL_CASE(C,job.Repeat,job.Condition);return;
    end
    if strcmp(job.Dataset,'SYN')
        regime='synthetic';[A,S]=P0_ALG(C,regime);S.noiseSigma=job.NoiseSigma;
        cs=job.Case;seed=100000+cs.StrengthIndex*20000+cs.TypeIndex*3000+cs.RateIndex*100+job.Repeat;
        if ~strcmp(job.Module,'A_trajectory'),seed=seed+C.syntheticSeedOffset;end
        rng(seed,'twister');data=SU_SYN_FROZEN('generate',S,cs.NominalRate,cs.Type,cs.Strength);
        rng(seed+123,'twister');t=tic;
        [U0,V0]=SU_SYN_FROZEN('initialize',data.X,S.r0,S.c0,struct('id','INIT'),A);
        initSeconds=toc(t);K=cs;K.Condition=job.Condition;K.Repeat=job.Repeat;K.Seed=seed;
        K.X=data.X;K.mask=data.mask;K.rank=[S.r0 S.c0];K.U0=U0;K.V0=V0;
        K.InitializationSeconds=initSeconds;
        D=struct('Atrue',data.A,'Btrue',data.B,'Xclean',data.X0, ...
            'Delta',data.X-data.Xbase,'evaluation','synthetic','noiseSigma',S.noiseSigma);
    else
        regime='real';D=SU_DATA(C,job.Dataset,job.Repeat);kk=SU_CASE(C,D,job.Condition);
        fold=D.F.cfg.alg;fold.realTail=D.cfg.tailReference.(job.Dataset);
        fold.realSample=D.cfg.sampleReference.(job.Dataset);[A,~]=P0_ALG(C,regime,fold,1);
        if strcmp(job.Dataset,'YALE'),idx=1;else,idx=2;end
        seed=190920260+idx*1000000+job.Repeat*10000+5000;
        r=D.F.selectedRank;rng(seed,'twister');t=tic;
        methods=P0_METHODS('core',C);[U0,V0]=SU_FROZEN('initialize',kk.X,r,r,methods(1),A);
        K=struct('Dataset',job.Dataset,'Condition',job.Condition,'Type',char(kk.case.job.Type), ...
            'NominalRate',kk.case.job.Rate,'Strength',kk.case.job.Strength, ...
            'Repeat',job.Repeat,'Seed',seed,'X',kk.X,'mask',kk.mask,'rank',[r r], ...
            'U0',U0,'V0',V0,'InitializationSeconds',toc(t));
        D.evaluation='real';D.Delta=kk.delta;
    end
    K.caseHash=P0_IO('hashtext',[P0_IO('hashnumeric',K.X) P0_IO('hashnumeric',K.mask)]);
    K.initHash=P0_IO('hashtext',[P0_IO('hashnumeric',K.U0) P0_IO('hashnumeric',K.V0)]);
end
