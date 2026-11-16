function [S,memory]=SU_STATE(E,M,A,regime,memory)
% Frozen architecture; commonSeverity only changes the NEW factorial controls.
    S.scale=SU_FROZEN('mad',E(:),A.eps0);
    current=NaN;h=NaN;
    if strcmp(M.cutoff,'ess')
        if M.commonSeverity || strcmp(M.etaMode,'auto')
            if strcmp(regime,'real'),current=SU_FROZEN('severity',E,A);else,current=SU_SYN_FROZEN('severity',E(:),A);end
            if strcmp(regime,'real')&&A.useSeverityMemory,memory=max(memory,current);h=memory;else,h=current;end
        end
        if strcmp(M.etaMode,'fixed'),eta=M.etaValue;
        elseif strcmp(regime,'real'),eta=SU_FROZEN('eta',h,A);
        elseif h==0,eta=A.essEtaDefaultClean;
        else,eta=min(A.essEtaMaxContam,max(A.essEtaMin,A.etaMapIntercept+A.etaMapSlope*h));end
        guard=M.cleanGuard&&isfinite(h)&&h==0;
        if guard,tau=max(abs(E(:)))*10+A.eps0;We=ones(size(E));
        else
            a=A;a.useZeroCalibration=M.useZeroCalibration;
            if strcmp(regime,'real'),tau=SU_FROZEN('select',E(:),eta,h,a);else,tau=SU_SYN_FROZEN('select',E(:),eta,h,a);end
            We=SU_FROZEN('tukeyweights',E,tau);
        end
    else,eta=NaN;guard=false;tau=A.fixedTukeyC*S.scale;We=SU_FROZEN('tukeyweights',E,tau);end
    Ws=ones(size(E,3),1);
    if M.sampleMode&&A.useSampleWeight
        if strcmp(regime,'real'),Ws=SU_FROZEN('sampleweights',E,A,M.sampleGuard);
        elseif ~(strcmp(M.etaMode,'auto')&&M.cleanGuard&&A.cleanGuardSampleWeight&&isfinite(h)&&h==0)
            Ws=SU_SYN_FROZEN('sampleweights',E,A);
        end
    end
    a=Ws(:).^A.sampleWeightAlpha;W=We;
    for i=1:size(E,3),W(:,:,i)=W(:,:,i)*a(i);end
    S.We=We;S.W=W;S.Ws=Ws;S.a=a;S.tau=tau;S.eta=eta;
    S.current=current;S.severity=h;S.guard=guard;
end
