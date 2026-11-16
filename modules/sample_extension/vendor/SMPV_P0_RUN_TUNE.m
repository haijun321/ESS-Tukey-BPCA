function SMPV_P0_RUN_TUNE(C)
% Phase 1: fit/score all candidates on clean gallery only; freeze ALL selections.
% Phase 2: evaluate the saved, selected models on clean probe (no new fitting).
    assert(all(diff(C.tuneEtaGrid)>0)&&all(C.tuneEtaGrid>0)&all(C.tuneEtaGrid<1), ...
        'P0:TuneGrid','eta grid must be strictly increasing in (0,1).');
    assert(all(diff(C.tuneCGrid)>0)&&all(C.tuneCGrid>0),'P0:TuneGrid','c grid must be strictly increasing and positive.');
    assert(any(abs(C.tuneEtaGrid-.85)<1e-12)&&any(abs(C.tuneCGrid-4.685)<1e-12), ...
        'P0:TuneDefaults','Include eta .85 and c 4.685 for the fixed controls.');
    base=SMPV_P0_METHODS('core',C);auto=base(3);auto.id='T_Auto';auto.name='Auto_matched_noSW_noGuard';
    M=auto;etaIndex=[];cIndex=[];
    for j=1:numel(C.tuneEtaGrid)
        x=base(2);x.etaValue=C.tuneEtaGrid(j);x.id=sprintf('T_Eta%03d',round(100*x.etaValue));
        x.name=sprintf('FixedEta_%.3f_matched',x.etaValue);M(end+1)=x;etaIndex(end+1)=numel(M); %#ok<AGROW>
    end
    fixedC=zeros(1,numel(M));
    for j=1:numel(C.tuneCGrid)
        x=base(1);x.id=sprintf('T_C%05d',round(1000*C.tuneCGrid(j)));
        x.name=sprintf('FixedTukey_c%.3f',C.tuneCGrid(j));M(end+1)=x;cIndex(end+1)=numel(M); %#ok<AGROW>
        fixedC(numel(M))=C.tuneCGrid(j);
    end
    count=numel(C.tuneDatasets)*numel(C.tuneConditions)*numel(C.repeats);
    cx=struct('regime','real','scientific',true,'datasets',{C.tuneDatasets},'conditions',{C.tuneConditions}, ...
        'methods',M,'versions',{{'v2'}},'budgets',1,'expectedFits',count*numel(M), ...
        'evidenceRole','validation_only','candidateMetric','clean_gallery_NRE', ...
        'guard',false,'sampleWeights',false,'tieRule','first exact minimum in ascending fixed grid');
    ph=SMPV_P0_IO('freeze',C,'tune_candidates',cx);
    cp=struct('regime','real','scientific',true,'datasets',{C.tuneDatasets},'conditions',{C.tuneConditions}, ...
        'expectedRecords',count*5,'recordUnit','locked_probe_evaluations_of_saved_fits', ...
        'evidenceRole','locked_selection_then_probe','inferenceScope','repeated-split descriptions');
    pl=SMPV_P0_IO('freeze',C,'tune_real',cp);lockRows=cell(0,10);
    fprintf('TUNE: %d candidate fits, followed by %d saved-model probe evaluations.\n',cx.expectedFits,cp.expectedRecords);
    for id=1:numel(C.tuneDatasets)
        ds=C.tuneDatasets{id};
        for rep=C.repeats
            D=SMPV_SU_DATA(C,ds,rep);fold=D.F.cfg.alg;
            fold.realTail=D.cfg.tailReference.(ds);fold.realSample=D.cfg.sampleReference.(ds);
            [A,~]=SMPV_P0_ALG(C,'real',fold);
            if strcmp(ds,'YALE'),di=1;else,di=2;end
            seed=190920260+di*1000000+rep*10000+5000;
            % Candidate fits never receive probe arrays or probe labels.
            V=rmfield(D,{'probe','probeLabels'});V.selectionOnly=true;
            for ic=1:numel(C.tuneConditions)
                condition=C.tuneConditions{ic};kk=SMPV_SU_CASE(C,D,condition);
                tInit=tic;rng(seed,'twister');[u,v]=SMPV_SU_FROZEN('initialize',kk.X,D.F.selectedRank,D.F.selectedRank,auto,A);
                K=struct('Dataset',ds,'Condition',condition,'Type',char(kk.case.job.Type), ...
                    'NominalRate',kk.case.job.Rate,'Strength',kk.case.job.Strength,'Repeat',rep,'Seed',seed, ...
                    'X',kk.X,'mask',kk.mask,'rank',[D.F.selectedRank D.F.selectedRank],'U0',u,'V0',v, ...
                    'InitializationSeconds',toc(tInit),'caseHash',kk.caseHash, ...
                    'initHash',SMPV_P0_IO('hashtext',[SMPV_P0_IO('hashnumeric',u) SMPV_P0_IO('hashnumeric',v)]));
                rr=repmat(struct(),0,1);
                for j=1:numel(M)
                    a=A;if fixedC(j)>0,a.fixedTukeyC=fixedC(j);end
                    z=SMPV_P0_FIT_CASE(C,'tune_candidates',K,V,M(j),a,'real','v2',1,ph,true);
                    if isempty(rr),rr=z;else,rr(end+1)=z;end %#ok<AGROW>
                end
                val=[rr.GalleryNRE];[~,ie]=min(val(etaIndex));[~,icbest]=min(val(cIndex));
                bestEta=etaIndex(ie);bestC=cIndex(icbest);
                e85=etaIndex(find(abs(C.tuneEtaGrid-.85)<1e-12,1));
                c4685=cIndex(find(abs(C.tuneCGrid-4.685)<1e-12,1));
                chosen=[1 e85 bestEta c4685 bestC];
                sig=SMPV_P0_IO('hashtext',jsonencode(struct('protocolHash',pl,'candidateSignatures',{{rr.FitSignature}},'chosen',chosen)));
                lock=struct('hash',sig,'protocolHash',pl,'caseHash',K.caseHash,'dataset',ds, ...
                    'repeat',rep,'condition',condition,'chosen',chosen,'records',rr, ...
                    'etaGrid',C.tuneEtaGrid,'cGrid',C.tuneCGrid,'ProbeScoredBeforeLock',false);
                file=fullfile(C.outputRoot,'tune_real','selections',sprintf('%s_r%03d_%s.mat',ds,rep,condition));
                if exist(file,'file'),old=SMPV_P0_IO('load',file);assert(strcmp(old.hash,sig),'P0:TuneResume','Selection lock differs.');
                else,SMPV_P0_IO('save',file,lock);end
                lockRows(end+1,:)={ds,rep,condition,M(bestEta).etaValue,fixedC(bestC), ...
                    val(bestEta),val(bestC),sig,false,sum([rr.TotalSeconds])}; %#ok<AGROW>
            end
        end
    end
    SMPV_P0_IO('csv',fullfile(C.outputRoot,'tune_real','locked_selections.csv'), ...
        {'Dataset','Repeat','Condition','SelectedEta','SelectedC','EtaValidationNRE','CValidationNRE', ...
        'SelectionHash','ProbeScoredBeforeLock','AllCandidateSeconds'},lockRows);
    SMPV_P0_SUMMARIZE(C,'tune_candidates');
    % All validation choices above are committed before any probe is scored.
    R=repmat(struct(),0,1);names={'Auto','Eta085','SelectedEta','FixedC4685','SelectedC'};
    files=dir(fullfile(C.outputRoot,'tune_real','selections','*.mat'));
    assert(numel(files)==count,'P0:TuneLocks','Missing or unexpected selection locks.');
    for k=1:numel(files)
        lock=SMPV_P0_IO('load',fullfile(files(k).folder,files(k).name));
        assert(strcmp(lock.protocolHash,pl)&&~lock.ProbeScoredBeforeLock,'P0:TuneLock','Invalid selection lock.');
        D=SMPV_SU_DATA(C,lock.dataset,lock.repeat);rows=repmat(struct(),0,1);
        ef=fullfile(C.outputRoot,'tune_real','evaluations',files(k).name);
        if exist(ef,'file')
            e=SMPV_P0_IO('load',ef);assert(strcmp(e.selectionHash,lock.hash),'P0:TuneEval','Evaluation selection signature differs.');
            rows=e.records;
        else
            for j=1:5
                x=lock.records(lock.chosen(j));candidateID=x.MethodID;
                fitID=sprintf('%s_r%03d_%s_%s_v2_B1',lock.dataset,lock.repeat,lock.condition,candidateID);
                f=SMPV_P0_IO('load',fullfile(C.outputRoot,'tune_candidates','fits',fitID,'fit.mat'));
                assert(strcmp(f.signature,x.FitSignature),'P0:TuneFit','Candidate signature differs.');
                x.Module='tune_real';x.MethodID=names{j};x.Method=names{j};
                x.ValidationNRE=x.GalleryNRE;x.NRE=SMPV_SU_FROZEN('nre',D.probe,f.model.U,f.model.V);
                x.ACC=SMPV_SU_FROZEN('accuracy',D.gallery,D.galleryLabels,D.probe,D.probeLabels,f.model.U,f.model.V,D.cfg);
                x.MetricTarget='clean_outer_probe_after_locked_selection';x.CandidateMethodID=candidateID;
                x.SelectionHash=lock.hash;x.IsNewFit=false;
                if isempty(rows),rows=x;else,rows(end+1)=x;end %#ok<AGROW>
            end
            SMPV_P0_IO('save',ef,struct('selectionHash',lock.hash,'records',rows));
        end
        if isempty(R),R=rows;else,R=[R rows];end %#ok<AGROW>
    end
    SMPV_P0_SUMMARIZE(C,'tune_real',R,cp);
end
