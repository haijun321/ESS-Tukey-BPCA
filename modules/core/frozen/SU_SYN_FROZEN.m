function varargout=SU_SYN_FROZEN(action,varargin)
% Local functions extracted verbatim from the user's frozen P0 source.
    switch action
        case 'generate', [varargout{1:nargout}]=generate_synthetic_matrix_data_v7(varargin{:});
        case 'fit', [varargout{1:nargout}]=train_method_bpca_v7(varargin{:});
        case 'initialize', [varargout{1:nargout}]=initialize_bpca_v7(varargin{:});
        case 'sampleweights', [varargout{1:nargout}]=sample_level_weights_v7(varargin{:});
        case 'severity', [varargout{1:nargout}]=estimate_tail_severity_v7(varargin{:});
        case 'weights', [varargout{1:nargout}]=weights_for_method_v7(varargin{:});
        case 'warm', [varargout{1:nargout}]=bpca_warm_alt_update_v7(varargin{:});
        case 'qf', [varargout{1:nargout}]=qf_retraction(varargin{:});
        case 'select', [varargout{1:nargout}]=select_tukey_tau_by_ess_v7(varargin{:});
        case 'evaluate', [varargout{1:nargout}]=evaluate_model_v7(varargin{:});
        case 'reconstruct', [varargout{1:nargout}]=reconstruct_tensor(varargin{:});
        otherwise, error('SU:API','Unknown synthetic action');
    end
end

function methods = make_method_list_v7()
    methods(1) = struct('name','L2-BPCA',              'loss','l2',    'cutoff','none',  'etaMode','none', 'etaValue',NaN,'sampleMode',false,'cleanGuard',true);
    methods(2) = struct('name','Huber-BPCA',           'loss','huber', 'cutoff','fixed', 'etaMode','none', 'etaValue',NaN,'sampleMode',false,'cleanGuard',true);
    methods(3) = struct('name','Welsch-BPCA',          'loss','welsch','cutoff','fixed', 'etaMode','none', 'etaValue',NaN,'sampleMode',false,'cleanGuard',true);
    methods(4) = struct('name','Fixed-Tukey-BPCA',     'loss','tukey', 'cutoff','fixed', 'etaMode','none', 'etaValue',NaN,'sampleMode',false,'cleanGuard',true);
    methods(5) = struct('name','ESS-Tukey-BPCA-auto',  'loss','tukey', 'cutoff','ess',   'etaMode','auto', 'etaValue',NaN,'sampleMode',true, 'cleanGuard',true);
    methods(6) = struct('name','ESS-Tukey-BPCA-eta85', 'loss','tukey', 'cutoff','ess',   'etaMode','fixed','etaValue',0.85,'sampleMode',true,'cleanGuard',true);
end

function methods = make_ablation_method_list_v7()
    methods(1) = struct('name','Fixed-Tukey-noSW',    'loss','tukey','cutoff','fixed','etaMode','none', 'etaValue',NaN, 'sampleMode',false,'cleanGuard',true);
    methods(2) = struct('name','Fixed-Tukey-SW',      'loss','tukey','cutoff','fixed','etaMode','none', 'etaValue',NaN, 'sampleMode',true, 'cleanGuard',true);
    methods(3) = struct('name','ESS-eta85-noSW',      'loss','tukey','cutoff','ess',  'etaMode','fixed','etaValue',0.85,'sampleMode',false,'cleanGuard',true);
    methods(4) = struct('name','ESS-eta85-SW',        'loss','tukey','cutoff','ess',  'etaMode','fixed','etaValue',0.85,'sampleMode',true, 'cleanGuard',true);
    methods(5) = struct('name','ESS-auto-noSW',       'loss','tukey','cutoff','ess',  'etaMode','auto', 'etaValue',NaN, 'sampleMode',false,'cleanGuard',true);
    methods(6) = struct('name','ESS-auto-SW',         'loss','tukey','cutoff','ess',  'etaMode','auto', 'etaValue',NaN, 'sampleMode',true, 'cleanGuard',true);
    methods(7) = struct('name','ESS-auto-SW-noGuard', 'loss','tukey','cutoff','ess',  'etaMode','auto', 'etaValue',NaN, 'sampleMode',true, 'cleanGuard',false);
end

function methods = make_matched_sw_method_list_v7()
    methods(1) = struct('name','Huber-BPCA-SW',          'loss','huber', 'cutoff','fixed','etaMode','none','etaValue',NaN,'sampleMode',true,'cleanGuard',true);
    methods(2) = struct('name','Welsch-BPCA-SW',         'loss','welsch','cutoff','fixed','etaMode','none','etaValue',NaN,'sampleMode',true,'cleanGuard',true);
    methods(3) = struct('name','Fixed-Tukey-BPCA-SW',    'loss','tukey', 'cutoff','fixed','etaMode','none','etaValue',NaN,'sampleMode',true,'cleanGuard',true);
    methods(4) = struct('name','ESS-Tukey-BPCA-auto-SW', 'loss','tukey', 'cutoff','ess',  'etaMode','auto','etaValue',NaN,'sampleMode',true,'cleanGuard',true);
end

function method = make_fixed_eta_method_v7(etaVal,sampleMode,cleanGuard)
    method = struct('name',sprintf('ESS-Tukey-eta%.3f',etaVal),'loss','tukey', ...
        'cutoff','ess','etaMode','fixed','etaValue',etaVal, ...
        'sampleMode',logical(sampleMode),'cleanGuard',logical(cleanGuard));
end

function method = get_method_by_name(methods,name)
    for k = 1:numel(methods)
        if strcmp(methods(k).name,name), method = methods(k); return; end
    end
    error('Method not found: %s',name);
end

function rates = main_rates_for_type_v7(cfg,contamType)
    if strcmpi(contamType,'block_coherent')
        rates = cfg.syn.coherentMainRates;
    else
        rates = cfg.syn.primaryRates;
    end
end

function [Tcal,Tmap,etaMap] = calibrate_eta_map_v7(cfg)
    rows = {}; id = 0;
    for ct = 1:numel(cfg.calib.types)
        type = cfg.calib.types{ct};
        for rr = 1:numel(cfg.calib.rates)
            rate = cfg.calib.rates(rr);
            for rep = 1:cfg.repeatsCalibration
                seed = cfg.calib.seedBase + ct*10000 + rr*100 + rep;
                rng(seed,'twister');
                data = generate_synthetic_matrix_data_v7(cfg.syn,rate,type,cfg.calib.strength);
                tail0 = initial_tail_severity_v7(data.X,cfg.target.r,cfg.target.c,cfg.alg);

                etaErr = nan(numel(cfg.calib.etaGrid),1);
                for ee = 1:numel(cfg.calib.etaGrid)
                    etaVal = cfg.calib.etaGrid(ee);
                    meth = make_fixed_eta_method_v7(etaVal,true,true);
                    model = train_method_bpca_v7(data.X,cfg.target.r,cfg.target.c,meth,cfg.alg);
                    etaErr(ee) = 0.5*( ...
                        subspace_error_normalized_v7(data.A,model.U) + ...
                        subspace_error_normalized_v7(data.B,model.V));
                end
                [oracleErr,jj] = min(etaErr);
                oracleEta = cfg.calib.etaGrid(jj);
                id = id + 1;
                rows(id,:) = {type,rate,cfg.calib.strength,rep,seed,tail0,oracleEta,oracleErr}; %#ok<AGROW>
            end
        end
    end

    Tcal = cell2table(rows,'VariableNames',{ ...
        'ContamType','NominalRate','Strength','Repeat','Seed', ...
        'InitialTailSeverity','OracleEta','OracleErr'});

    S = Tcal.InitialTailSeverity;
    y = Tcal.OracleEta;
    valid = isfinite(S) & isfinite(y);
    etaMap = struct('intercept',NaN,'slope',NaN,'rmse',NaN,'valid',false,'N',sum(valid));

    if sum(valid) >= 2 && std(S(valid)) > 1e-10
        X = [ones(sum(valid),1),S(valid)];
        beta = X\y(valid);
        % ESS target should not become less robust as tail severity increases.
        beta(2) = min(beta(2),0);
        yhat = X*beta;
        etaMap.intercept = beta(1);
        etaMap.slope = beta(2);
        etaMap.rmse = sqrt(mean((y(valid)-yhat).^2));
        etaMap.valid = all(isfinite(beta));
    end

    Tmap = table(etaMap.N,etaMap.intercept,etaMap.slope,etaMap.rmse,etaMap.valid, ...
        'VariableNames',{'NCalibration','Intercept','Slope','RMSE','Valid'});
end

function tailSeverity = initial_tail_severity_v7(X,r,c,alg)
    dummy = struct('loss','tukey','cutoff','ess','etaMode','auto','etaValue',NaN,'sampleMode',true,'cleanGuard',true);
    [U,V] = initialize_bpca_v7(X,r,c,dummy,alg);
    E = residual_tensor(X,U,V);
    tailSeverity = estimate_tail_severity_v7(E(:),alg);
end

function data = generate_synthetic_matrix_data_v7(cfgSyn,nominalRate,contamType,strength)
    n=cfgSyn.n; p=cfgSyn.p; q=cfgSyn.q; r0=cfgSyn.r0; c0=cfgSyn.c0;
    A = orth(randn(p,r0));
    B = orth(randn(q,c0));
    X0 = zeros(p,q,n);
    Xnoise = zeros(p,q,n);
    diagStrength = linspace(3.0,1.2,min(r0,c0));

    for i=1:n
        S = 0.35*randn(r0,c0);
        for k=1:min(r0,c0), S(k,k)=diagStrength(k)*randn(); end
        X0(:,:,i)=A*S*B';
        Xnoise(:,:,i)=cfgSyn.noiseSigma*randn(p,q);
    end
    Xbase = X0 + Xnoise;

    cleanScale = robust_mad_scale(Xbase(:),1e-12);
    if strcmpi(cfgSyn.contamScaleMode,'robust_scale')
        appliedAmplitude = strength*cleanScale;
    else
        appliedAmplitude = strength;
    end

    [X,mask] = contaminate_tensor_v7(Xbase,nominalRate,contamType, ...
        appliedAmplitude,cfgSyn.blockRatio,cfgSyn.sampleOutlierScale);

    data = struct('X0',X0,'Xbase',Xbase,'X',X,'mask',mask,'A',A,'B',B, ...
        'cleanRobustScale',cleanScale,'appliedAmplitude',appliedAmplitude);
end

function [Xc,mask] = contaminate_tensor_v7(X,nominalRate,contamType,amplitude,blockRatio,sampleScale)
    [p,q,n]=size(X); Xc=X; mask=false(p,q,n);
    if nominalRate<=0 || strcmpi(contamType,'none'), return; end

    switch lower(contamType)
        case 'impulse'
            totalN=p*q*n; m=min(max(round(nominalRate*totalN),0),totalN);
            idx=randperm(totalN,m); tmp=Xc(:); tm=mask(:);
            signs=2*(rand(m,1)>0.5)-1;
            vals=amplitude*signs.*(0.5+rand(m,1));
            tmp(idx)=tmp(idx)+vals; tm(idx)=true;
            Xc=reshape(tmp,p,q,n); mask=reshape(tm,p,q,n);

        case 'sample'
            ns=min(max(round(nominalRate*n),0),n); idx=randperm(n,ns);
            for kk=1:numel(idx)
                i=idx(kk);
                Delta=sampleScale*amplitude*randn(p,q);
                Xc(:,:,i)=Xc(:,:,i)+Delta; mask(:,:,i)=true;
            end

        case {'block_random','block_coherent','block'}
            bh=max(2,round(blockRatio*p)); bw=max(2,round(blockRatio*q));
            blockArea=bh*bw; targetElems=round(nominalRate*p*q*n);
            numBlocks=max(1,round(targetElems/blockArea));
            for b=1:numBlocks
                i=randi(n); a0=randi([1,max(1,p-bh+1)]); b0=randi([1,max(1,q-bw+1)]);
                rows=a0:min(p,a0+bh-1); cols=b0:min(q,b0+bw-1);
                if strcmpi(contamType,'block_random')
                    Delta=amplitude*randn(numel(rows),numel(cols));
                else
                    sgn=2*(rand>0.5)-1;
                    Delta=amplitude*sgn*(0.8+0.4*rand)*ones(numel(rows),numel(cols));
                end
                Xc(rows,cols,i)=Xc(rows,cols,i)+Delta;
                mask(rows,cols,i)=true;
            end

        otherwise
            error('Unknown contamination type: %s',contamType);
    end
end

function model = train_method_bpca_v7(X,r,c,method,alg)
    tStart=tic;
    if strcmpi(method.loss,'l2')
        [U,V,objHist]=train_l2_bpca_v7(X,r,c,alg.maxOuter,alg.tolOuter);
        E=residual_tensor(X,U,V); W=ones(size(X));
        model=base_model_v7(U,V,W,NaN,NaN,NaN,NaN,NaN,1,0,sum(E(:).^2),numel(objHist),0,'ok');
        model.objHist=objHist(:); model.tauHist=nan(numel(objHist),1); model.etaHist=nan(numel(objHist),1);
        model.essElementHist=nan(numel(objHist),1); model.moveHist=nan(numel(objHist),1);
    else
        model=train_robust_bpca_irls_v7(X,r,c,method,alg,tStart);
    end
end

function model = train_robust_bpca_irls_v7(X,r,c,method,alg,tStart)
    [U,V]=initialize_bpca_v7(X,r,c,method,alg);
    objHist=nan(alg.maxOuter,1); tauHist=nan(alg.maxOuter,1); etaHist=nan(alg.maxOuter,1);
    tailHist=nan(alg.maxOuter,1); essElemHist=nan(alg.maxOuter,1); essCombHist=nan(alg.maxOuter,1);
    moveHist=nan(alg.maxOuter,1); meanWHist=nan(alg.maxOuter,1); zeroWHist=nan(alg.maxOuter,1);
    status='ok'; mmRejectCount=0; last=0;

    for outer=1:alg.maxOuter
        if toc(tStart)>alg.maxTimePerMethod, status='timecap'; break; end
        E=residual_tensor(X,U,V); scale=robust_mad_scale(E(:),alg.eps0);
        [W,Welem,tau,eta,tailSeverity,objBefore]=weights_for_method_v7(E,method,alg,scale);

        [Unew,Vnew,subStatus,rejects,move]=solve_weighted_bpca_mm_v7( ...
            X,W,U,V,method.loss,tau,alg,tStart);
        mmRejectCount=mmRejectCount+rejects;
        Enew=residual_tensor(X,Unew,Vnew);
        objAfter=robust_objective_by_loss_v7(Enew,method.loss,tau);

        U=Unew; V=Vnew; last=outer;
        objHist(outer)=objAfter; tauHist(outer)=tau; etaHist(outer)=eta; tailHist(outer)=tailSeverity;
        essElemHist(outer)=compute_weight_ess_ratio_v7(Welem,alg.eps0);
        essCombHist(outer)=compute_weight_ess_ratio_v7(W,alg.eps0);
        meanWHist(outer)=mean(W(:)); zeroWHist(outer)=mean(W(:)<=alg.zeroTol); moveHist(outer)=move;

        relchg=abs(objBefore-objAfter)/(abs(objBefore)+alg.eps0);
        if strcmp(subStatus,'timecap'), status='timecap'; break; end
        if strcmp(subStatus,'stationary')
            status='stationary'; break;
        elseif strcmp(subStatus,'mm_stalled')
            status='mm_stalled'; break;
        elseif relchg<alg.tolOuter
            status='converged'; break;
        end
    end

    if last==0, last=1; end
    objHist=objHist(1:last); tauHist=tauHist(1:last); etaHist=etaHist(1:last); tailHist=tailHist(1:last);
    essElemHist=essElemHist(1:last); essCombHist=essCombHist(1:last); moveHist=moveHist(1:last);
    meanWHist=meanWHist(1:last); zeroWHist=zeroWHist(1:last);

    Efinal=residual_tensor(X,U,V); finalScale=robust_mad_scale(Efinal(:),alg.eps0);
    [Wfinal,WelemFinal,finalTau,finalEta,finalTail,finalObj]=weights_for_method_v7(Efinal,method,alg,finalScale);
    finalESSElem=compute_weight_ess_ratio_v7(WelemFinal,alg.eps0);
    finalESSComb=compute_weight_ess_ratio_v7(Wfinal,alg.eps0);

    model=base_model_v7(U,V,Wfinal,finalTau,finalEta,finalTail,finalESSElem,finalESSComb, ...
        mean(Wfinal(:)),mean(Wfinal(:)<=alg.zeroTol),finalObj,last,mmRejectCount,status);
    model.objHist=objHist; model.tauHist=tauHist; model.etaHist=etaHist; model.tailSeverityHist=tailHist;
    model.essElementHist=essElemHist; model.essCombinedHist=essCombHist; model.moveHist=moveHist;
    model.meanWHist=meanWHist; model.zeroWHist=zeroWHist; model.finalScale=finalScale;
end

function model = base_model_v7(U,V,W,tau,eta,tail,essElem,essComb,meanW,zeroW,obj,iters,rejects,status)
    model=struct('U',U,'V',V,'W',W,'finalTau',tau,'finalEta',eta,'finalTailSeverity',tail, ...
        'finalESSElement',essElem,'finalESSCombined',essComb,'finalMeanW',meanW,'finalZeroW',zeroW, ...
        'finalObj',obj,'outerIters',iters,'mmRejectCount',rejects,'status',status);
end

function [W,Welem,tau,eta,tailSeverity,objBefore] = weights_for_method_v7(E,method,alg,scale)
    switch lower(method.loss)
        case 'tukey'
            if strcmpi(method.cutoff,'ess')
                [eta,tailSeverity]=choose_eta_v7(E(:),method,alg);
                if method.cleanGuard && ~isnan(tailSeverity) && tailSeverity==0
                    tau=max(abs(E(:)))*10+alg.eps0; Welem=ones(size(E));
                else
                    [tau,~,~]=select_tukey_tau_by_ess_v7(E(:),eta,tailSeverity,alg);
                    Welem=tukey_weights(E,tau);
                end
            else
                eta=NaN; tailSeverity=NaN; tau=alg.fixedTukeyC*scale; Welem=tukey_weights(E,tau);
            end
            W=Welem;
            if method.sampleMode && alg.useSampleWeight
                if ~(strcmpi(method.etaMode,'auto') && method.cleanGuard && alg.cleanGuardSampleWeight && ...
                        ~isnan(tailSeverity) && tailSeverity==0)
                    Ws=sample_level_weights_v7(E,alg); W=apply_sample_weights_v7(W,Ws,alg.sampleWeightAlpha);
                end
            end
            objBefore=tukey_objective(E,tau);

        case 'huber'
            eta=NaN; tailSeverity=NaN; tau=alg.huberC*scale; Welem=huber_weights(E,tau,alg.eps0); W=Welem;
            if method.sampleMode && alg.useSampleWeight
                Ws=sample_level_weights_v7(E,alg); W=apply_sample_weights_v7(W,Ws,alg.sampleWeightAlpha);
            end
            objBefore=huber_objective(E,tau);

        case 'welsch'
            eta=NaN; tailSeverity=NaN; tau=alg.welschC*scale; Welem=welsch_weights(E,tau); W=Welem;
            if method.sampleMode && alg.useSampleWeight
                Ws=sample_level_weights_v7(E,alg); W=apply_sample_weights_v7(W,Ws,alg.sampleWeightAlpha);
            end
            objBefore=welsch_objective(E,tau);

        otherwise
            error('Unknown robust loss: %s',method.loss);
    end
end

function [eta,tailSeverity] = choose_eta_v7(evec,method,alg)
    if strcmpi(method.etaMode,'fixed')
        eta=method.etaValue; tailSeverity=NaN; return;
    end
    tailSeverity=estimate_tail_severity_v7(evec,alg);
    if tailSeverity==0
        eta=alg.essEtaDefaultClean; return;
    end
    if alg.useCalibratedEtaMap
        etaRaw=alg.etaMapIntercept + alg.etaMapSlope*tailSeverity;
    else
        etaRaw=1-alg.etaGuard-alg.essTailGamma*tailSeverity;
    end
    eta=min(etaRaw,alg.essEtaMaxContam);
    eta=max(eta,alg.essEtaMin);
end

function tailSeverity = estimate_tail_severity_v7(evec,alg)
    evec=evec(:); evec=evec(isfinite(evec));
    if isempty(evec), tailSeverity=0; return; end
    medv=median(evec); s=robust_mad_scale(evec,alg.eps0);
    if s<=alg.eps0, tailSeverity=0; return; end
    z=abs(evec-medv)./s;
    p1=mean(z>alg.essTailK1); p2=mean(z>alg.essTailK2); p3=mean(z>alg.essTailK3);
    ex1=max(0,p1-0.025); ex2=max(0,p2-0.003); ex3=max(0,p3-0.0001);
    tailSeverity=max([ex1,1.3*ex2,1.6*ex3]);
    if tailSeverity<alg.tailSeverityCleanThreshold, tailSeverity=0; end
    tailSeverity=min(max(tailSeverity,0),alg.tailSeverityCap);
end

function [tau,bestESS,bestZero] = select_tukey_tau_by_ess_v7(evec,eta,tailSeverity,alg)
    a=abs(evec(:)); a=a(isfinite(a));
    if isempty(a) || max(a)<alg.eps0, tau=1; bestESS=1; bestZero=0; return; end
    amin=max(local_percentile(a,0.2),alg.eps0); amax=max(a);
    linGrid=linspace(amin,amax*1.05+alg.eps0,alg.essGridSize);
    logGrid=logspace(log10(amin+alg.eps0),log10(amax*5+alg.eps0),alg.essGridSize);
    grid=unique([linGrid(:);logGrid(:);amax*10+alg.eps0]);
    grid=grid(isfinite(grid)&grid>alg.eps0);
    if isnan(tailSeverity), zeroTarget=max(0,1-eta); else, zeroTarget=tailSeverity; end
    zeroTarget=min(max(zeroTarget,0),0.40);
    zlo=alg.zeroLowerFactor*zeroTarget; zhi=alg.zeroUpperFactor*zeroTarget;
    bestScore=Inf; tau=grid(end); bestESS=1; bestZero=0;
    for k=1:numel(grid)
        tk=grid(k); w=(1-(a./tk).^2).^2; w(a>tk)=0; w=max(0,min(1,w));
        sw=sum(w); sw2=sum(w.^2);
        if sw2<=alg.eps0, ess=0; else, ess=(sw^2/sw2)/numel(a); end
        zw=mean(a>tk); score=abs(ess-eta);
        if alg.useZeroCalibration && zeroTarget>0
            score=score+alg.zeroUnderPenalty*max(0,zlo-zw)+alg.zeroOverPenalty*max(0,zw-zhi);
        end
        if score<bestScore, bestScore=score; tau=tk; bestESS=ess; bestZero=zw; end
    end
end

function Ws = sample_level_weights_v7(E,alg)
    [~,~,n]=size(E); sc=zeros(n,1);
    for i=1:n, sc(i)=norm(E(:,:,i),'fro')/sqrt(numel(E(:,:,i))); end
    medv=median(sc); s=robust_mad_scale(sc,alg.eps0);
    if s<=alg.eps0, Ws=ones(n,1); return; end
    z=abs(sc-medv)./s; tauS=max(alg.sampleTauC,local_percentile(z,85));
    Ws=(1-(z./tauS).^2).^2; Ws(z>tauS)=0; Ws=max(Ws,alg.sampleWeightMin);
end

function W2 = apply_sample_weights_v7(W,Ws,alpha)
    [~,~,n]=size(W); W2=W;
    for i=1:n, W2(:,:,i)=W(:,:,i)*(Ws(i)^alpha); end
end

function [U,V,status,rejects,move] = solve_weighted_bpca_mm_v7(X,W,U,V,lossName,tau,alg,tStart)
    status='ok'; rejects=0; move=0;
    for inner=1:alg.maxInner
        if toc(tStart)>alg.maxTimePerMethod, status='timecap'; return; end
        Ecur=residual_tensor(X,U,V);
        Qcur=sum(W(:).*Ecur(:).^2);
        Fcur=robust_objective_by_loss_v7(Ecur,lossName,tau);
        Xhat=reconstruct_tensor(X,U,V);
        Ximp=W.*X+(1-W).*Xhat;
        [Uc,Vc]=bpca_warm_alt_update_v7(Ximp,U,V,alg.fastBpcaSteps);
        moveCand=projection_move_v7(U,V,Uc,Vc);

        [ok,Qc,Fc]=mm_accept_v7(X,W,Uc,Vc,lossName,tau,Qcur,Fcur,alg); %#ok<ASGLU>
        if ok
            U=Uc; V=Vc; move=max(move,moveCand); continue;
        end

        accepted=false;
        for ls=1:alg.mmLineSearchMax
            alpha=alg.mmShrink^ls;
            Ut=qf_retraction((1-alpha)*U+alpha*Uc);
            Vt=qf_retraction((1-alpha)*V+alpha*Vc);
            [ok,~,~]=mm_accept_v7(X,W,Ut,Vt,lossName,tau,Qcur,Fcur,alg);
            if ok
                move=max(move,projection_move_v7(U,V,Ut,Vt));
                U=Ut; V=Vt; accepted=true; break;
            end
            rejects=rejects+1;
        end

        if ~accepted
            relQ=abs(Qc-Qcur)/(abs(Qcur)+alg.eps0);
            relF=abs(Fc-Fcur)/(abs(Fcur)+alg.eps0);
            if moveCand<alg.mmStationaryMoveTol || max(relQ,relF)<alg.mmStationaryRelTol
                status='stationary';
            else
                status='mm_stalled';
            end
            return;
        end
    end
end

function [ok,Q,F] = mm_accept_v7(X,W,U,V,lossName,tau,Qcur,Fcur,alg)
    E=residual_tensor(X,U,V); Q=sum(W(:).*E(:).^2); F=robust_objective_by_loss_v7(E,lossName,tau);
    qTol=alg.mmAcceptTol*(1+abs(Qcur)); fTol=alg.mmAcceptTol*(1+abs(Fcur));
    ok=(Q<=Qcur+qTol)&&(F<=Fcur+fTol);
end

function d = projection_move_v7(U0,V0,U1,V1)
    d=norm(U0*U0'-U1*U1','fro')+norm(V0*V0'-V1*V1','fro');
end

function [U,V] = initialize_bpca_v7(X,r,c,~,alg)
    switch lower(alg.initMode)
        case 'l2'
            [U,V,~]=train_l2_bpca_v7(X,r,c,12,1e-5);
        case 'robust_l2'
            Xc=winsorize_tensor_by_mad_v7(X,alg.clipC,alg.eps0);
            [U,V,~]=train_l2_bpca_v7(Xc,r,c,12,1e-5);
        otherwise
            error('Unknown initMode: %s',alg.initMode);
    end
end

function Xc = winsorize_tensor_by_mad_v7(X,clipC,eps0)
    x=X(:); medv=median(x); s=robust_mad_scale(x,eps0);
    Xc=min(max(X,medv-clipC*s),medv+clipC*s);
end

function [U,V,objHist] = train_l2_bpca_v7(X,r,c,maxIter,tol)
    [p,q,n]=size(X); Cr=zeros(p,p); Cc=zeros(q,q);
    for i=1:n, Xi=X(:,:,i); Cr=Cr+Xi*Xi'; Cc=Cc+Xi'*Xi; end
    U=top_eigvecs_sym(Cr,r); V=top_eigvecs_sym(Cc,c); objHist=nan(maxIter,1);
    for it=1:maxIter
        PV=V*V'; SU=zeros(p,p);
        for i=1:n, Xi=X(:,:,i); SU=SU+Xi*PV*Xi'; end
        U=top_eigvecs_sym(SU,r);
        PU=U*U'; SV=zeros(q,q);
        for i=1:n, Xi=X(:,:,i); SV=SV+Xi'*PU*Xi; end
        V=top_eigvecs_sym(SV,c);
        objHist(it)=l2_bpca_objective(X,U,V);
        if it>1
            rel=abs(objHist(it)-objHist(it-1))/(abs(objHist(it-1))+1e-12);
            if rel<tol, objHist=objHist(1:it); return; end
        end
    end
end

function [U,V] = bpca_warm_alt_update_v7(X,U,V,numSteps)
    [p,q,n]=size(X); r=size(U,2); c=size(V,2);
    for step=1:numSteps
        PV=V*V'; SU=zeros(p,p);
        for i=1:n, Xi=X(:,:,i); SU=SU+Xi*PV*Xi'; end
        U=top_eigvecs_sym(SU,r);
        PU=U*U'; SV=zeros(q,q);
        for i=1:n, Xi=X(:,:,i); SV=SV+Xi'*PU*Xi; end
        V=top_eigvecs_sym(SV,c);
    end
end

function E = residual_tensor(X,U,V)
    [p,q,n]=size(X); E=zeros(p,q,n);
    for i=1:n, Xi=X(:,:,i); E(:,:,i)=Xi-U*(U'*Xi*V)*V'; end
end

function Xhat = reconstruct_tensor(X,U,V)
    [p,q,n]=size(X); Xhat=zeros(p,q,n);
    for i=1:n, Xi=X(:,:,i); Xhat(:,:,i)=U*(U'*Xi*V)*V'; end
end

function f = l2_bpca_objective(X,U,V)
    E=residual_tensor(X,U,V); f=sum(E(:).^2);
end

function W = tukey_weights(E,tau)
    tau=max(tau,1e-12); R=E./tau; W=(1-R.^2).^2; W(abs(E)>tau)=0; W=max(0,min(1,W));
end

function W = huber_weights(E,delta,eps0)
    delta=max(delta,eps0); A=abs(E); W=ones(size(E)); idx=A>delta; W(idx)=delta./(A(idx)+eps0);
end

function W = welsch_weights(E,sigma)
    sigma=max(sigma,1e-12); W=exp(-(E./sigma).^2);
end

function f = tukey_objective(E,tau)
    tau=max(tau,1e-12); A=abs(E); inside=A<=tau; rho=zeros(size(E)); R=E(inside)./tau;
    rho(inside)=(tau^2/6)*(1-(1-R.^2).^3); rho(~inside)=tau^2/6; f=sum(rho(:));
end

function f = huber_objective(E,delta)
    delta=max(delta,1e-12); A=abs(E); inside=A<=delta; rho=zeros(size(E));
    rho(inside)=0.5*E(inside).^2; rho(~inside)=delta*A(~inside)-0.5*delta^2; f=sum(rho(:));
end

function f = welsch_objective(E,sigma)
    sigma=max(sigma,1e-12); rho=(sigma^2/2)*(1-exp(-(E./sigma).^2)); f=sum(rho(:));
end

function f = robust_objective_by_loss_v7(E,lossName,tau)
    switch lower(lossName)
        case 'tukey', f=tukey_objective(E,tau);
        case 'huber', f=huber_objective(E,tau);
        case 'welsch', f=welsch_objective(E,tau);
        case 'l2', f=sum(E(:).^2);
        otherwise, error('Unknown loss: %s',lossName);
    end
end

function s = robust_mad_scale(x,eps0)
    x=x(:); x=x(isfinite(x));
    if isempty(x), s=eps0; return; end
    medv=median(x); s=1.4826*median(abs(x-medv))+eps0;
end

function ess = compute_weight_ess_ratio_v7(W,eps0)
    w=W(:); w=w(isfinite(w)); N=numel(w);
    if N==0, ess=NaN; return; end
    sw=sum(w); sw2=sum(w.^2);
    if sw2<=eps0, ess=0; else, ess=(sw^2/sw2)/N; end
end

function M = evaluate_model_v7(data,model,Xproj,contamType)
    M=struct();
    M.ErrU=subspace_error(data.A,model.U); M.ErrV=subspace_error(data.B,model.V); M.ErrSub=0.5*(M.ErrU+M.ErrV);
    M.ErrUNorm=subspace_error_normalized_v7(data.A,model.U); M.ErrVNorm=subspace_error_normalized_v7(data.B,model.V);
    M.ErrSubNorm=0.5*(M.ErrUNorm+M.ErrVNorm);
    [M.NRE,M.NMSE]=clean_projection_metrics_v7(data.X0,Xproj);
    [M.ElemROCAUC,M.ElemPRAUC,M.SampleROCAUC,M.SamplePRAUC]=outlier_metrics_v7(model.W,data.mask,contamType);
end

function err = subspace_error(A,U)
    A=orth(A); U=orth(U); err=norm(A*A'-U*U','fro')/sqrt(2);
end

function err = subspace_error_normalized_v7(A,U)
    A=orth(A); U=orth(U); k=min(size(A,2),size(U,2));
    if k<=0, err=NaN; else, err=norm(A*A'-U*U','fro')/sqrt(2*k); end
end

function [nre,nmse] = clean_projection_metrics_v7(Xclean,Xhat)
    den=norm(Xclean(:))+1e-12; nre=norm(Xclean(:)-Xhat(:))/den; nmse=nre^2;
end

function [elemROC,elemPR,sampROC,sampPR] = outlier_metrics_v7(W,mask,contamType)
    score=1-W; elemROC=NaN; elemPR=NaN; sampROC=NaN; sampPR=NaN;
    if any(mask(:))
        elemROC=binary_auc_tied(score(:),mask(:));
        elemPR=binary_pr_auc_v7(score(:),mask(:));
    end
    if strcmpi(contamType,'sample') && any(mask(:))
        ss=squeeze(mean(mean(score,1),2)); sl=squeeze(any(any(mask,1),2));
        sampROC=binary_auc_tied(ss(:),sl(:)); sampPR=binary_pr_auc_v7(ss(:),sl(:));
    end
end

function auc = binary_auc_tied(score,label)
    score=score(:); label=label(:)>0; v=isfinite(score); score=score(v); label=label(v);
    np=sum(label); nn=sum(~label); if np==0||nn==0, auc=NaN; return; end
    if max(score)==min(score), auc=0.5; return; end
    ranks=tied_ranks_local(score); auc=(sum(ranks(label))-np*(np+1)/2)/(np*nn);
end

function prauc = binary_pr_auc_v7(score,label)
    score=score(:); label=label(:)>0; v=isfinite(score); score=score(v); label=label(v);
    np=sum(label); N=numel(label); if np==0||np==N, prauc=NaN; return; end
    if max(score)==min(score), prauc=np/N; return; end
    [s,ord]=sort(score,'descend'); y=label(ord); tp=cumsum(y); fp=cumsum(~y);
    lastTie=[s(1:end-1)~=s(2:end);true]; tp=tp(lastTie); fp=fp(lastTie);
    rec=[0;tp/np]; prec=[1;tp./max(tp+fp,1)]; prauc=trapz(rec,prec);
end

function ranks = tied_ranks_local(x)
    [xs,order]=sort(x(:),'ascend'); n=numel(xs); rs=zeros(n,1); i=1;
    while i<=n
        j=i; while j<n && xs(j+1)==xs(i), j=j+1; end
        rs(i:j)=(i+j)/2; i=j+1;
    end
    ranks=zeros(n,1); ranks(order)=rs;
end

function val = local_percentile(x,pct)
    x=sort(x(:)); n=numel(x); if n==0, val=NaN; return; end
    pos=1+(pct/100)*(n-1); lo=floor(pos); hi=ceil(pos);
    if lo==hi, val=x(lo); else, val=x(lo)+(pos-lo)*(x(hi)-x(lo)); end
end

function U = top_eigvecs_sym(A,k)
    A=0.5*(A+A'); [V,D]=eig(A); [~,idx]=sort(diag(D),'descend'); U=qf_retraction(V(:,idx(1:k)));
end

function Q = qf_retraction(Y)
    [Q,R]=qr(Y,0); d=sign(diag(R)); d(d==0)=1; Q=Q*diag(d);
end

function Tsum = summarize_table_by_group_v7(T,groupVars,metricVars)
    n=height(T); key=strings(n,1);
    for i=1:n
        parts=strings(1,numel(groupVars));
        for g=1:numel(groupVars)
            v=T.(groupVars{g})(i);
            if iscell(v), parts(g)=string(v{1}); elseif isstring(v), parts(g)=v;
            elseif isnumeric(v), parts(g)=string(num2str(v,'%.12g')); else, parts(g)=string(v); end
        end
        key(i)=strjoin(parts,"||");
    end
    [ukey,~,gid]=unique(key,'stable'); %#ok<ASGLU>
    statsPerMetric=7; rows=cell(numel(ukey),numel(groupVars)+statsPerMetric*numel(metricVars));
    for k=1:numel(ukey)
        idx=gid==k; first=find(idx,1,'first'); col=0;
        for g=1:numel(groupVars)
            col=col+1; v=T.(groupVars{g})(first); if iscell(v), rows{k,col}=v{1}; else, rows{k,col}=v; end
        end
        for m=1:numel(metricVars)
            vals=T.(metricVars{m})(idx); vals=vals(isfinite(vals)); N=numel(vals);
            if N==0, mu=NaN; sd=NaN; se=NaN; lo=NaN; hi=NaN; md=NaN;
            else, mu=mean(vals); sd=std(vals); se=sd/sqrt(N); lo=mu-1.96*se; hi=mu+1.96*se; md=median(vals); end
            out={N,mu,sd,se,lo,hi,md};
            for z=1:numel(out), col=col+1; rows{k,col}=out{z}; end
        end
    end
    varNames=groupVars;
    suff={'_N','_Mean','_Std','_SE','_CI95Low','_CI95High','_Median'};
    for m=1:numel(metricVars), for s=1:numel(suff), varNames{end+1}=[metricVars{m},suff{s}]; end, end
    Tsum=cell2table(rows,'VariableNames',varNames);
end

function Tpair = paired_comparison_summary_v7(Traw,autoName,baselineNames)
    rows={}; id=0; metrics={'ErrSubNorm','NRE'};
    for b=1:numel(baselineNames)
        for mm=1:numel(metrics)
            metric=metrics{mm}; A=Traw(strcmp(Traw.Method,autoName),:); B=Traw(strcmp(Traw.Method,baselineNames{b}),:);
            ka=make_pair_key_v7(A); kb=make_pair_key_v7(B); [~,ia,ib]=intersect(ka,kb,'stable');
            d=B.(metric)(ib)-A.(metric)(ia); d=d(isfinite(d)); N=numel(d);
            if N==0, mu=NaN; sd=NaN; se=NaN; lo=NaN; hi=NaN; wr=NaN;
            else, mu=mean(d); sd=std(d); se=sd/sqrt(N); lo=mu-1.96*se; hi=mu+1.96*se; wr=mean(d>0); end
            id=id+1; rows(id,:)={baselineNames{b},metric,N,mu,sd,se,lo,hi,wr}; %#ok<AGROW>
        end
    end
    Tpair=cell2table(rows,'VariableNames',{'Baseline','Metric','N','MeanImprovement','Std','SE','CI95Low','CI95High','WinRate'});
end

function key = make_pair_key_v7(T)
    key=strings(height(T),1);
    for i=1:height(T)
        key(i)=sprintf('%s|%.12g|%.12g|%d',T.ContamType{i},T.NominalRate(i),T.Strength(i),T.Repeat(i));
    end
end

function Trank = average_rank_summary_v7(Traw,metricNames)
    rows={}; id=0;
    methods=unique(Traw.Method,'stable');
    conditions=unique(make_pair_key_v7(Traw),'stable');
    for mm=1:numel(metricNames)
        metric=metricNames{mm}; rankStore=cell(numel(methods),1); for m=1:numel(methods), rankStore{m}=[]; end
        for cc=1:numel(conditions)
            key=conditions(cc); vals=nan(numel(methods),1);
            for m=1:numel(methods)
                idx=strcmp(make_pair_key_v7(Traw),key) & strcmp(Traw.Method,methods{m});
                if any(idx), vals(m)=mean(Traw.(metric)(idx),'omitnan'); end
            end
            valid=isfinite(vals); if sum(valid)<2, continue; end
            rv=tied_ranks_local(vals(valid)); inds=find(valid);
            for z=1:numel(inds), rankStore{inds(z)}(end+1)=rv(z); end %#ok<AGROW>
        end
        for m=1:numel(methods)
            r=rankStore{m}; id=id+1;
            if isempty(r), ar=NaN; md=NaN; N=0; else, ar=mean(r); md=median(r); N=numel(r); end
            rows(id,:)={metric,methods{m},N,ar,md}; %#ok<AGROW>
        end
    end
    Trank=cell2table(rows,'VariableNames',{'Metric','Method','NConditions','AverageRank','MedianRank'});
end

function Tstatus = status_summary_v7(Traw)
    methods=unique(Traw.Method,'stable'); rows={}; id=0;
    for m=1:numel(methods)
        idx=strcmp(Traw.Method,methods{m}); N=sum(idx); id=id+1;
        rows(id,:)={methods{m},N,sum(strcmp(Traw.Status(idx),'converged')),sum(strcmp(Traw.Status(idx),'stationary')), ...
            sum(strcmp(Traw.Status(idx),'ok')),sum(strcmp(Traw.Status(idx),'timecap')),sum(strcmp(Traw.Status(idx),'mm_stalled')), ...
            mean(Traw.Time(idx),'omitnan'),mean(Traw.OuterIters(idx),'omitnan'),mean(Traw.MMRejectCount(idx),'omitnan')}; %#ok<AGROW>
    end
    Tstatus=cell2table(rows,'VariableNames',{'Method','N','Converged','Stationary','OK','Timecap','MMStalled','MeanTime','MeanOuterIters','MeanMMRejects'});
end

function Tbreak = empirical_breakdown_summary_v7(Tsum,threshold)
    methods=unique(Tsum.Method,'stable'); strengths=unique(Tsum.Strength,'stable'); rows={}; id=0;
    for ss=1:numel(strengths)
        for m=1:numel(methods)
            idx=Tsum.Strength==strengths(ss) & strcmp(Tsum.Method,methods{m});
            if ~any(idx), continue; end
            rates=Tsum.ActualRate_Mean(idx); errs=Tsum.ErrSubNorm_Mean(idx); [rates,ord]=sort(rates); errs=errs(ord);
            jj=find(errs>=threshold,1,'first'); if isempty(jj), br=NaN; else, br=rates(jj); end
            id=id+1; rows(id,:)={strengths(ss),methods{m},threshold,br}; %#ok<AGROW>
        end
    end
    Tbreak=cell2table(rows,'VariableNames',{'Strength','Method','ErrThreshold','EmpiricalBreakdownRate'});
end

function plot_main_curves_v7(Tsum,resultDir)
    types=unique(Tsum.ContamType,'stable'); strengths=unique(Tsum.Strength,'stable');
    for tt=1:numel(types)
        for ss=1:numel(strengths)
            idxBase=strcmp(Tsum.ContamType,types{tt}) & Tsum.Strength==strengths(ss);
            if ~any(idxBase), continue; end
            methods=unique(Tsum.Method(idxBase),'stable');
            plot_metric_ci_v7(Tsum,idxBase,methods,'ActualRate_Mean','ErrSubNorm_Mean','ErrSubNorm_CI95Low','ErrSubNorm_CI95High', ...
                'Actual contamination rate','Normalized subspace error',sprintf('%s | strength %.1f',types{tt},strengths(ss)), ...
                fullfile(resultDir,sprintf('curve_ErrSubNorm_%s_strength%.1f.png',types{tt},strengths(ss))),false);
            plot_metric_ci_v7(Tsum,idxBase,methods,'ActualRate_Mean','NRE_Mean','NRE_CI95Low','NRE_CI95High', ...
                'Actual contamination rate','NRE',sprintf('%s | strength %.1f',types{tt},strengths(ss)), ...
                fullfile(resultDir,sprintf('curve_NRE_%s_strength%.1f.png',types{tt},strengths(ss))),false);
            plot_metric_ci_v7(Tsum,idxBase,methods,'ActualRate_Mean','FinalESSElement_Mean','FinalESSElement_CI95Low','FinalESSElement_CI95High', ...
                'Actual contamination rate','Element ESS ratio',sprintf('ESS | %s | strength %.1f',types{tt},strengths(ss)), ...
                fullfile(resultDir,sprintf('curve_ESS_%s_strength%.1f.png',types{tt},strengths(ss))),false);
        end
    end
end

function plot_metric_ci_v7(Tsum,idxBase,methods,xVar,yVar,loVar,hiVar,xLab,yLab,figTitle,saveFile,identity)
    fig=figure('Color','w','Position',[100,100,800,560]); hold on; grid on; box on; names={};
    for m=1:numel(methods)
        idx=idxBase & strcmp(Tsum.Method,methods{m});
        if ~any(idx) || ~ismember(yVar,Tsum.Properties.VariableNames), continue; end
        x=Tsum.(xVar)(idx); y=Tsum.(yVar)(idx); lo=Tsum.(loVar)(idx); hi=Tsum.(hiVar)(idx);
        [x,ord]=sort(x); y=y(ord); lo=lo(ord); hi=hi(ord);
        if all(~isfinite(y)), continue; end
        errorbar(x,y,max(0,y-lo),max(0,hi-y),'-o','LineWidth',1.4,'MarkerSize',5,'CapSize',4);
        names{end+1}=methods{m}; %#ok<AGROW>
    end
    if identity, xl=xlim; xx=linspace(max(0,xl(1)),xl(2),100); plot(xx,xx,'k--'); names{end+1}='y=x'; end
    xlabel(xLab); ylabel(yLab); title(figTitle,'Interpreter','none'); if ~isempty(names), legend(names,'Location','best','Interpreter','none'); end
    saveas(fig,saveFile); close(fig);
end

function plot_eta_sensitivity_v7(T,resultDir)
    vars={'ErrSubNorm','NRE','FinalESSElement','FinalZeroW'}; ylabs={'Normalized subspace error','NRE','ESS ratio','Effective-zero ratio'};
    for k=1:numel(vars)
        y=T.([vars{k},'_Mean']); lo=T.([vars{k},'_CI95Low']); hi=T.([vars{k},'_CI95High']); x=T.Eta;
        [x,ord]=sort(x); y=y(ord); lo=lo(ord); hi=hi(ord);
        fig=figure('Color','w','Position',[100,100,760,520]); errorbar(x,y,max(0,y-lo),max(0,hi-y),'-o','LineWidth',1.7,'CapSize',5);
        grid on; box on; xlabel('eta'); ylabel(ylabs{k}); title(['Paired eta sensitivity: ',ylabs{k}]);
        saveas(fig,fullfile(resultDir,['eta_sensitivity_',vars{k},'.png'])); close(fig);
    end
end

function plot_ablation_v7(T,resultDir)
    types=unique(T.ContamType,'stable');
    for t=1:numel(types)
        idx=strcmp(T.ContamType,types{t}); y=T.ErrSubNorm_Mean(idx); lo=T.ErrSubNorm_CI95Low(idx); hi=T.ErrSubNorm_CI95High(idx); names=T.Method(idx);
        fig=figure('Color','w','Position',[100,100,1050,540]); x=1:numel(y); bar(x,y); hold on; grid on; box on;
        errorbar(x,y,max(0,y-lo),max(0,hi-y),'k.','LineWidth',1.2,'CapSize',5); xticks(x); xticklabels(names); xtickangle(25);
        ylabel('Normalized subspace error'); title(['Ablation | ',types{t}],'Interpreter','none');
        saveas(fig,fullfile(resultDir,['ablation_',types{t},'.png'])); close(fig);
    end
end

function plot_clean_efficiency_v7(T,resultDir)
    noises=unique(T.NoiseSigma,'stable');
    for j=1:numel(noises)
        idx=T.NoiseSigma==noises(j); methods=unique(T.Method(idx),'stable');
        fig=figure('Color','w','Position',[100,100,760,520]); hold on; grid on; box on;
        for m=1:numel(methods)
            ii=idx & strcmp(T.Method,methods{m}); x=T.N(ii); y=T.ErrSubNorm_Mean(ii); [x,ord]=sort(x); y=y(ord); plot(x,y,'-o','LineWidth',1.6);
        end
        xlabel('Sample size n'); ylabel('Normalized subspace error'); legend(methods,'Location','best','Interpreter','none');
        title(sprintf('Clean efficiency | noise sigma = %.2f',noises(j)),'Interpreter','none');
        saveas(fig,fullfile(resultDir,sprintf('clean_efficiency_noise%.2f.png',noises(j)))); close(fig);
    end
end

function plot_stress_v7(T,resultDir)
    strengths=unique(T.Strength,'stable');
    for ss=1:numel(strengths)
        idxBase=T.Strength==strengths(ss); methods=unique(T.Method(idxBase),'stable');
        plot_metric_ci_v7(T,idxBase,methods,'ActualRate_Mean','ErrSubNorm_Mean','ErrSubNorm_CI95Low','ErrSubNorm_CI95High', ...
            'Actual contamination rate','Normalized subspace error',sprintf('Coherent block stress | strength %.1f',strengths(ss)), ...
            fullfile(resultDir,sprintf('coherent_stress_strength%.1f.png',strengths(ss))),false);
    end
end

function plot_calibration_v7(T,resultDir)
    fig=figure('Color','w','Position',[100,100,760,520]);
    scatter(T.InitialTailSeverity,T.OracleEta,45,'filled'); grid on; box on;
    xlabel('Initial tail-severity proxy'); ylabel('Oracle eta'); title('Independent calibration: oracle eta vs tail severity');
    saveas(fig,fullfile(resultDir,'eta_calibration_scatter_v7.png')); close(fig);
end
