function [A,M]=SMP_ALGORITHM(C,phase)
% Reuse the revised solver and frozen element calibration; only sampleMode differs.
    base=SMPV_P0_CONFIG();
    base.syntheticDimensions=[C.n C.p C.q C.r C.c];
    base.syntheticBudget=C.syntheticBudget;
    base.syntheticTimeLimit=C.syntheticTimeLimit;
    [A,~]=SMPV_P0_ALG(base,'synthetic');
    if strcmp(phase,'precheck')
        A.maxOuter=C.precheckBudget(1); A.maxInner=C.precheckBudget(2);
        A.mmLineSearchMax=C.precheckBudget(3);A.maxTimePerMethod=C.precheckTimeLimit;
    end
    A.sampleWeightAlpha=C.sampleWeightAlpha; A.sampleWeightMin=C.sampleWeightMin;
    A.sampleTauC=C.sampleTauC; A.useSampleWeight=true;
    core=SMPV_P0_METHODS('core',base);M=repmat(core(3),1,2);
    M(1).id='E';M(1).name='C3_element_only';M(1).sampleMode=false;
    M(2).id='ES';M(2).name='C3_plus_existing_sample_layer';M(2).sampleMode=true;
    M(1).cleanGuard=false;M(2).cleanGuard=false;
    assert(M(1).useZeroCalibration&&M(2).useZeroCalibration,'SMP:Element','Element rule changed.');
    a=M(1);b=M(2);a.id='';b.id='';a.name='';b.name='';a.sampleMode=false;b.sampleMode=false;
    assert(isequaln(a,b),'SMP:Pair','Methods must differ only in sampleMode and identifiers.');
    assert(C.sampleQuantile==0.85,'SMP:Frozen','Existing sample function uses the 85th percentile.');
end
