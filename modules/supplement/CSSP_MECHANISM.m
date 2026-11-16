function rows=CSSP_MECHANISM(K,A,C)
% Frozen common-initialization residual audit; this never evaluates probe data.
% Each candidate is evaluated once. C2/C3/C4/C5 read the same residual,
% severity-memory input and grid. Selected follows the native first-minimum
% rule. R0Operational uses |e|>tau; R0Exact counts actual zero weights.
% This is a calibration-mechanism diagnostic, not a refitted-outcome result.
    assert(isstruct(K)&&all(isfield(K,{'X','U0','V0'})), ...
        'CSSP:MechanismInput','K requires X, U0 and V0.');
    assert(all(isfinite(K.X(:))),'CSSP:MechanismFinite','Nonfinite training input.');
    E=SU_FROZEN('residual',K.X,K.U0,K.V0);
    a=abs(E(:));
    if isfield(K,'regime'),regime=char(K.regime);
    elseif isfield(K,'Regime'),regime=char(K.Regime);
    elseif isfield(K,'Dataset')&&strcmpi(char(K.Dataset),'SYN'),regime='synthetic';
    else,regime='real';end
    assert(any(strcmp(regime,{'real','synthetic'})),'CSSP:MechanismRegime','Unknown regime.');
    memory=0;if isfield(K,'MechanismMemory'),memory=K.MechanismMemory;end
    assert(isscalar(memory)&&isfinite(memory)&&memory>=0,'CSSP:MechanismMemory','Invalid memory.');
    localC=C;localC.includeFixedEtaNoZero=true;
    allMethods=P0_METHODS('core',localC);ids={'C2','C3','C4','C5'};
    states=cell(4,1);memories=zeros(4,1);
    for j=1:4
        hit=find(strcmp({allMethods.id},ids{j}),1);
        assert(~isempty(hit),'CSSP:MechanismMethod','Missing %s.',ids{j});
        m=allMethods(hit);
        assert(~m.cleanGuard&&~m.sampleMode&&m.commonSeverity, ...
            'CSSP:MechanismComponents','Mechanism audit requires matched CORE.');
        [states{j},memories(j)]=P0_STATE(E,m,A,regime,memory);
    end
    for j=2:4
        assert(isequaln(states{1}.current,states{j}.current)&& ...
            isequaln(states{1}.severity,states{j}.severity)&& ...
            isequaln(memories(1),memories(j)), ...
            'CSSP:MechanismState','The frozen residual did not share severity/memory.');
    end
    shortcut=isempty(a)||max(a)<A.eps0;
    if shortcut
        grid=1;
    else
        sorted=sort(a);pos=1+.002*(numel(a)-1);lo=floor(pos);hi=ceil(pos);
        amin=max(sorted(lo)+(pos-lo)*(sorted(hi)-sorted(lo)),A.eps0);amax=max(a);
        grid=unique([linspace(amin,1.05*amax+A.eps0,A.essGridSize)'; ...
            logspace(log10(amin+A.eps0),log10(5*amax+A.eps0),A.essGridSize)'; ...
            10*amax+A.eps0]);
        grid=grid(isfinite(grid)&grid>A.eps0);
    end
    assert(~isempty(grid),'CSSP:MechanismGrid','No finite candidate.');
    stats=repmat(struct('ESSOperational',NaN,'ESSExact',NaN, ...
        'R0Operational',NaN,'R0Exact',NaN,'CVPositiveSquared',NaN, ...
        'ESSIdentityError',NaN,'PositiveWeightCount',0),numel(grid),1);
    for k=1:numel(grid),stats(k)=candidate_stats(a,grid(k),A,regime);end
    rows=repmat(empty_row(),4*numel(grid),1);at=0;
    residualHash=P0_IO('hashnumeric',E);
    for j=1:4
        S=states{j};hit=find(strcmp({allMethods.id},ids{j}),1);M=allMethods(hit);
        target=S.severity;
        if isnan(target),target=max(0,1-S.eta);end
        target=min(max(target,0),.40);
        lower=A.zeroLowerFactor*target;upper=A.zeroUpperFactor*target;
        penalties=zeros(numel(grid),1);scores=zeros(numel(grid),1);
        for k=1:numel(grid)
            if M.useZeroCalibration&&target>0
                penalties(k)=A.zeroUnderPenalty*max(0,lower-stats(k).R0Operational)+ ...
                    A.zeroOverPenalty*max(0,stats(k).R0Operational-upper);
            end
            scores(k)=abs(stats(k).ESSOperational-S.eta)+penalties(k);
        end
        [~,pick]=min(scores);
        scale=max(1,abs(S.tau));
        assert(abs(grid(pick)-S.tau)<=1e-10*scale, ...
            'CSSP:MechanismSelectorMismatch', ...
            'Audit and native selector differ for %s; do not plot this as verified.',M.id);
        for k=1:numel(grid)
            at=at+1;r=empty_row();
            r.Dataset=text_field(K,'Dataset',regime);r.Condition=text_field(K,'Condition','');
            r.Repeat=number_field(K,'Repeat',NaN);r.CaseHash=text_field(K,'caseHash','');
            r.InitHash=text_field(K,'initHash','');r.ResidualHash=residualHash;
            r.Method=M.id;r.TargetMode=M.etaMode;r.ZeroPenaltyEnabled=M.useZeroCalibration;
            r.CandidateIndex=k;r.CandidateCount=numel(grid);r.Tau=grid(k);
            r.MemoryEntering=memory;r.MemoryAfter=memories(j);
            r.CurrentSeverity=S.current;r.Severity=S.severity;r.TargetEta=S.eta;
            r.R0LowerPreference=lower;r.R0UpperPreference=upper;
            f=fieldnames(stats(k));for u=1:numel(f),r.(f{u})=stats(k).(f{u});end
            r.ESSMismatch=abs(r.ESSOperational-S.eta);r.ZeroPenalty=penalties(k);
            r.Score=scores(k);r.Selected=k==pick;r.NativeSelectedTau=S.tau;
            r.DegenerateResidualShortcut=shortcut;rows(at)=r;
        end
    end
end

function d=candidate_stats(a,tau,A,regime)
    n=numel(a);sw=0;sw2=0;nzero=0;nout=0;positive=0;
    if strcmp(regime,'real')
        bs=200000;
        if isfield(A,'memoryBlockSize')&&~isempty(A.memoryBlockSize)
            bs=max(1000,round(A.memoryBlockSize));
        end
    else,bs=max(1,n);end
    for start=1:bs:n
        ab=a(start:min(n,start+bs-1));w=(1-(ab./tau).^2).^2;
        out=ab>tau;w(out)=0;w(w<0)=0;w(w>1)=1;
        sw=sw+sum(w);
        if strcmp(regime,'real'),sw2=sw2+dot(w,w);else,sw2=sw2+sum(w.^2);end
        nzero=nzero+sum(w==0);nout=nout+sum(out);positive=positive+sum(w>0);
    end
    d=struct('ESSOperational',NaN,'ESSExact',NaN,'R0Operational',NaN, ...
        'R0Exact',NaN,'CVPositiveSquared',NaN,'ESSIdentityError',NaN,'PositiveWeightCount',positive);
    if n==0,return;end
    d.ESSOperational=0;
    if sw2>A.eps0,d.ESSOperational=(sw^2/sw2)/n;end
    if sw2>0,d.ESSExact=(sw^2/sw2)/n;end
    d.R0Operational=nout/n;d.R0Exact=nzero/n;
    if positive>0&&sw>0
        d.CVPositiveSquared=max(0,positive*sw2/sw^2-1);
        rhs=(1-d.R0Exact)/(1+d.CVPositiveSquared);
        d.ESSIdentityError=abs(d.ESSExact-rhs);
        assert(d.ESSIdentityError<1e-9,'CSSP:MechanismIdentity','ESS identity check failed.');
    end
end

function r=empty_row()
    r=struct('EvidenceType','FrozenCommonInitializationResidual_NoTaskOutcome', ...
        'Dataset','','Condition','','Repeat',NaN,'CaseHash','','InitHash','','ResidualHash','', ...
        'Method','','TargetMode','','ZeroPenaltyEnabled',false,'CandidateIndex',0, ...
        'CandidateCount',0,'Tau',NaN,'MemoryEntering',0,'MemoryAfter',NaN, ...
        'CurrentSeverity',NaN,'Severity',NaN,'TargetEta',NaN, ...
        'R0LowerPreference',NaN,'R0UpperPreference',NaN,'ESSOperational',NaN, ...
        'ESSExact',NaN,'R0Operational',NaN,'R0Exact',NaN,'CVPositiveSquared',NaN, ...
        'ESSIdentityError',NaN,'PositiveWeightCount',0,'ESSMismatch',NaN, ...
        'ZeroPenalty',NaN,'Score',NaN,'Selected',false,'NativeSelectedTau',NaN, ...
        'DegenerateResidualShortcut',false);
end

function v=text_field(s,f,fallback)
    v=fallback;if isfield(s,f),v=char(string(s.(f)));end
end

function v=number_field(s,f,fallback)
    v=fallback;if isfield(s,f),v=double(s.(f));end
end
