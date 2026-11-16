function SMPV_P0_RUN_REAL(C,module)
    versions={'v2'};budgets=1;conditions=C.realConditions;datasets=C.realDatasets;
    switch module
        case 'solver_real',family='solver';versions={'legacy','v2'};conditions={'Clean'};
        case 'main_real',family='main';conditions=C.realMainConditions;datasets=C.realMainDatasets;
        case 'extension_real',family='extension';
        case 'pilot_real',family='pilot';
        case 'budget_real',family='core';budgets=C.budgetMultipliers;conditions={'Clean','I30','B30'};
        otherwise,family='core';
    end
    M=SMPV_P0_METHODS(family,C);
    if strcmp(family,'extension')
        k=SMPV_P0_METHODS('core',C);M=[k(3) M]; % C3 reference rerun under same module/protocol
    end
    scientific=~strcmp(module,'pilot_real');
    context=struct('regime','real','scientific',scientific,'datasets',{datasets}, ...
        'conditions',{conditions},'methods',M,'versions',{versions},'budgets',budgets, ...
        'expectedFits',numel(datasets)*numel(conditions)*numel(C.repeats)*numel(M)*numel(versions)*numel(budgets), ...
        'evidenceRole','matched_frozen_splits','inferenceScope','repeated-split descriptions, not independent subjects');
    ph=SMPV_P0_IO('freeze',C,module,context);
    fprintf('Module %s: %d planned fits. Scientific=%d\n',module,context.expectedFits,scientific);
    for id=1:numel(datasets)
        ds=datasets{id};
        for rep=C.repeats
            D=SMPV_SU_DATA(C,ds,rep);r=D.F.selectedRank;
            fold=D.F.cfg.alg;fold.realTail=D.cfg.tailReference.(ds);fold.realSample=D.cfg.sampleReference.(ds);
            if strcmp(ds,'YALE'),datasetIndex=1;else,datasetIndex=2;end
            seed=190920260+datasetIndex*1000000+rep*10000+5000;
            for ic=1:numel(conditions)
                condition=conditions{ic};kk=SMPV_SU_CASE(C,D,condition);
                [A,~]=SMPV_P0_ALG(C,'real',fold,1);
                tInit=tic;rng(seed,'twister');[U0,V0]=SMPV_SU_FROZEN('initialize',kk.X,r,r,M(1),A);
                K=struct('Dataset',ds,'Condition',condition,'Type',char(kk.case.job.Type), ...
                    'NominalRate',kk.case.job.Rate,'Strength',kk.case.job.Strength,'Repeat',rep, ...
                    'Seed',seed,'X',kk.X,'mask',kk.mask,'rank',[r r],'U0',U0,'V0',V0, ...
                    'InitializationSeconds',toc(tInit),'caseHash',kk.caseHash, ...
                    'initHash',SMPV_P0_IO('hashtext',[SMPV_P0_IO('hashnumeric',U0) SMPV_P0_IO('hashnumeric',V0)]));
                for b=budgets
                    [Ab,~]=SMPV_P0_ALG(C,'real',fold,b);
                    for im=1:numel(M)
                        for iv=1:numel(versions)
                            SMPV_P0_FIT_CASE(C,module,K,D,M(im),Ab,'real',versions{iv},b,ph,scientific);
                        end
                    end
                end
            end
        end
    end
    SMPV_P0_SUMMARIZE(C,module);
end
