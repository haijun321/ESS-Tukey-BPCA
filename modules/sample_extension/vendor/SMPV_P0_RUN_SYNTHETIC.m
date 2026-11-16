function SMPV_P0_RUN_SYNTHETIC(C,module)
    isSmoke=strncmp(module,'smoke_',6);isSolver=~isempty(strfind(module,'solver')); %#ok<STREMP>
    isBudget=strcmp(module,'budget_synthetic');
    diagnostic=isSmoke||isSolver||isBudget;cases=SMPV_P0_CASES(C,diagnostic);
    if isSolver,family='solver';versions={'legacy','v2'};
    elseif strcmp(module,'main_synthetic'),family='main';versions={'v2'};
    else,family='core';versions={'v2'};end
    M=SMPV_P0_METHODS(family,C);budgets=1;
    if isBudget,budgets=C.budgetMultipliers;end
    context=struct('regime','synthetic','scientific',~isSmoke,'cases',cases,'methods',M, ...
        'versions',{versions},'budgets',budgets,'expectedFits',numel(cases)*numel(C.repeats)*numel(M)*numel(versions)*numel(budgets), ...
        'primaryContrasts',{{'C2-C1','C3-C2','C3-C4'}},'dominantCondition','block_coherent_k4_p010');
    if C.syntheticSeedOffset==0,context.evidenceRole='matched_reevaluation';
    else,context.evidenceRole='new_seeds_with_frozen_map';end
    if C.includeFixedEtaNoZero
        context.primaryContrasts=[context.primaryContrasts {'C5-C1','C2-C5'}];
    end
    ph=SMPV_P0_IO('freeze',C,module,context);[A,S]=SMPV_P0_ALG(C,'synthetic');
    if isSmoke,A.essGridSize=16;end
    fprintf('Module %s: %d planned fits. Scientific=%d\n',module,context.expectedFits,context.scientific);
    for ic=1:numel(cases)
        cs=cases(ic);
        for rep=C.repeats
            SMPV_P0_IO('checkstop',C.stopFile);
            seed=100000+cs.StrengthIndex*20000+cs.TypeIndex*3000+cs.RateIndex*100+rep+C.syntheticSeedOffset;
            assert(seed<2^32,'P0:Seed','Seed exceeds Twister range.');
            rng(seed,'twister');data=SMPV_SU_SYN_FROZEN('generate',S,cs.NominalRate,cs.Type,cs.Strength);
            x=struct('id','INIT','name','common_robust_initialization');tInit=tic;
            rng(seed+123,'twister');[U0,V0]=SMPV_SU_SYN_FROZEN('initialize',data.X,S.r0,S.c0,x,A);
            initSeconds=toc(tInit);
            K=cs;K.Repeat=rep;K.Seed=seed;K.X=data.X;K.mask=data.mask;K.rank=[S.r0 S.c0];
            K.U0=U0;K.V0=V0;K.InitializationSeconds=initSeconds;
            K.caseHash=SMPV_P0_IO('hashtext',[SMPV_P0_IO('hashnumeric',data.X) SMPV_P0_IO('hashnumeric',data.mask)]);
            K.initHash=SMPV_P0_IO('hashtext',[SMPV_P0_IO('hashnumeric',U0) SMPV_P0_IO('hashnumeric',V0)]);
            D=struct('Atrue',data.A,'Btrue',data.B,'Xclean',data.X0,'Delta',data.X-data.Xbase);
            for b=budgets
                [Ab,~]=SMPV_P0_ALG(C,'synthetic',[],b);if isSmoke,Ab.essGridSize=16;end
                for im=1:numel(M)
                    for iv=1:numel(versions)
                        SMPV_P0_FIT_CASE(C,module,K,D,M(im),Ab,'synthetic',versions{iv},b,ph,context.scientific);
                    end
                end
            end
        end
    end
    SMPV_P0_SUMMARIZE(C,module);
end
