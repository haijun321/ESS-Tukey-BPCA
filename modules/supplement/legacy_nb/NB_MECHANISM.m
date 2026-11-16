function rows=NB_MECHANISM(K,M,A,regime,checkpoints)
% Same-residual counterfactual decisions, not causal fitted-outcome comparisons.
% K.X and checkpoint U,V define one common observed residual. The exact
% severity memory entering the preview is copied from the traced solver.
% At most six approximately evenly spaced checkpoints are audited.
% Input M may be a CORE method array or one CORE method struct; canonical
% fixed/automatic pairs are constructed while preserving component settings.
    assert(isstruct(K)&&isfield(K,'X'),'NB:MechanismCase','K.X is required.');
    assert(~isempty(checkpoints),'NB:MechanismCheckpoints','No checkpoints supplied.');
    if numel(M)>1
        hit=find(strcmp({M.id},'C3'),1);
        assert(~isempty(hit),'NB:MechanismMethod','CORE C3 is required.');
        template=M(hit);
    else,template=M;end
    assert(strcmp(template.loss,'tukey')&&strcmp(template.cutoff,'ess'), ...
        'NB:MechanismMethod','Audit requires Tukey ESS calibration.');
    assert(~template.cleanGuard&&~template.sampleMode, ...
        'NB:MechanismComponents','Use CORE: guard and sample weights disabled.');
    template.commonSeverity=true;template.useZeroCalibration=true;
    ix=unique(round(linspace(1,numel(checkpoints),min(6,numel(checkpoints)))));
    rows=repmat(emptyrow(),0,1);
    for j=1:numel(ix)
        q=checkpoints(ix(j));
        assert(isfield(q,'Memory'),'NB:MechanismMemory', ...
            'Exact memory is missing; regenerate checkpoints with NB_SOLVER_TRACE.');
        E=SU_FROZEN('residual',K.X,q.U,q.V);
        for mode=1:2
            on=template;
            if mode==1,on.etaMode='auto';on.etaValue=NaN;on.id='C3';offID='C4';
            else,on.etaMode='fixed';on.etaValue=.85;on.id='C2';offID='C5';end
            off=on;off.useZeroCalibration=false;off.id=offID;
            [Son,memOn]=P0_STATE(E,on,A,regime,q.Memory);
            [Soff,memOff]=P0_STATE(E,off,A,regime,q.Memory);
            assert(isequaln(Son.current,Soff.current)&&isequaln(Son.severity,Soff.severity) ...
                &&isequaln(Son.eta,Soff.eta)&&isequaln(memOn,memOff), ...
                'NB:MechanismState','Counterfactual states do not share target/severity.');
            a=describe(E,Son,A);b=describe(E,Soff,A);
            z=emptyrow();z.CheckpointIndex=ix(j);z.Outer=q.Outer;z.Seconds=q.Seconds;
            z.OnMethod=on.id;z.OffMethod=off.id;z.TargetMode=on.etaMode;
            z.MemoryEnteringPreview=q.Memory;z.MemoryAfterPreview=memOn;
            z.CurrentSeverity=Son.current;z.Severity=Son.severity;z.Eta=Son.eta;
            z.TauOn=Son.tau;z.TauOff=Soff.tau;z.TauChanged=Son.tau~=Soff.tau;
            z.ESSOn=a.ESSExact;z.ESSOff=b.ESSExact;
            z.OperationalESSOn=a.ESSOperational;z.OperationalESSOff=b.ESSOperational;
            z.R0On=a.R0Exact;z.R0Off=b.R0Exact;
            z.R0OperationalOn=a.R0Operational;z.R0OperationalOff=b.R0Operational;
            z.CVPositiveSquaredOn=a.CVPositiveSquared;z.CVPositiveSquaredOff=b.CVPositiveSquared;
            z.ESSIdentityErrorOn=a.IdentityError;z.ESSIdentityErrorOff=b.IdentityError;
            z.TargetMismatchOn=a.TargetMismatch;z.TargetMismatchOff=b.TargetMismatch;
            z.PenaltyAtOn=a.Penalty;z.PenaltyAtOff=b.Penalty;
            z.OnObjectiveAtOn=a.TargetMismatch+a.Penalty;
            z.OnObjectiveAtOff=b.TargetMismatch+b.Penalty;
            z.OffObjectiveAtOn=a.TargetMismatch;z.OffObjectiveAtOff=b.TargetMismatch;
            rows(end+1,1)=z; %#ok<AGROW>
        end
    end
end

function d=describe(E,S,A)
    w=S.We(:);sw=sum(w);sw2=sum(w.^2);
    d.ESSExact=NaN;if sw2>0,d.ESSExact=sw^2/sw2/numel(w);end
    d.ESSOperational=0;
    if sw2>A.eps0,d.ESSOperational=sw^2/sw2/numel(w);end
    d.R0Exact=mean(w==0);d.R0Operational=mean(abs(E(:))>S.tau);
    pos=w(w>0);d.CVPositiveSquared=NaN;d.IdentityError=NaN;
    if ~isempty(pos)
        mu=mean(pos);d.CVPositiveSquared=mean((pos-mu).^2)/mu^2;
        rhs=(1-d.R0Exact)/(1+d.CVPositiveSquared);
        d.IdentityError=abs(d.ESSExact-rhs);
        assert(d.IdentityError<1e-10,'NB:ESSIdentity','ESS decomposition identity failed.');
    end
    d.TargetMismatch=abs(d.ESSOperational-S.eta);d.Penalty=0;
    if isnan(S.severity),target=max(0,1-S.eta);else,target=S.severity;end
    target=min(max(target,0),.40);
    if target>0
        d.Penalty=A.zeroUnderPenalty*max(0,A.zeroLowerFactor*target-d.R0Operational) ...
            +A.zeroOverPenalty*max(0,d.R0Operational-A.zeroUpperFactor*target);
    end
end

function z=emptyrow()
    z=struct('EvidenceType','FrozenResidualCounterfactual','CheckpointIndex',0, ...
        'Outer',0,'Seconds',0,'OnMethod','','OffMethod','','TargetMode','', ...
        'MemoryEnteringPreview',NaN,'MemoryAfterPreview',NaN,'CurrentSeverity',NaN, ...
        'Severity',NaN,'Eta',NaN,'TauOn',NaN,'TauOff',NaN,'TauChanged',false, ...
        'ESSOn',NaN,'ESSOff',NaN,'OperationalESSOn',NaN,'OperationalESSOff',NaN, ...
        'R0On',NaN,'R0Off',NaN,'R0OperationalOn',NaN,'R0OperationalOff',NaN, ...
        'CVPositiveSquaredOn',NaN,'CVPositiveSquaredOff',NaN,'ESSIdentityErrorOn',NaN, ...
        'ESSIdentityErrorOff',NaN,'TargetMismatchOn',NaN,'TargetMismatchOff',NaN, ...
        'PenaltyAtOn',NaN,'PenaltyAtOff',NaN,'OnObjectiveAtOn',NaN,'OnObjectiveAtOff',NaN, ...
        'OffObjectiveAtOn',NaN,'OffObjectiveAtOff',NaN);
end
