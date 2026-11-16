function P = TC_PROTOCOL()
% Freeze before formal evaluation. This is a NEW evaluation protocol, not V1.7b.
    P.version='Tukey-CONFIRM-v1.0.0';
    P.datasets={'YALE','ORL'};
    P.repeats=10;
    P.seedBase=190920260;
    P.outerRatios=[0.4 0.3 0.3];
    P.rankCandidates=[4 6 8 10 12 16];
    P.rankDraws=5; P.rankACCTolerance=0.01;
    P.tailDraws=12; P.sampleDraws=50;
    P.tailQuantile=95; P.sampleQuantiles=[95 99.5];
    P.mechStrength=6; P.mechRates=[0.1 0.3];
    P.mainStrength=4.5; P.mainRates=[0.1 0.2 0.3];
    P.tuneStrength=4.5; P.tuneRate=0.1;
    P.etaGrid=[0.82 0.85 0.88 0.91 0.94 0.97];
    P.cGrid=[2.5 3.5 4.685 6 8];
    P.planMaximumRate=0.3;
    P.selectionMetric='clean_gallery_NRE';
    P.selectionTieRule='first exact minimum in ascending configured grid';
    P.nominalMainFits=490; P.nominalMechFits=250; P.nominalTuneFits=360;
    P.totalCoreFits=1100; % external RA-2DPCA is NOT included or impersonated
    P.budgetRepeats=1:3; P.budgetMultiplier=2;
    P.spectrumRepeats=[1 2]; P.spectrumOuter=[1 5 10];
    P.primaryMetric='NRE_on_clean_outer_probe';
    P.secondaryMetric='ACC_on_clean_outer_probe';
    P.noAccuracyGate=true;
    P.nanAUCPolicy='not_defined_for_single_class_or_missing_scores';
    P.statistics='paired split-level descriptions; repeated image splits are dependent';
    P.prDefinition='trapezoidal PR with initial (recall=0, precision=1), constant-score prevalence convention';
    P.apDefinition='sum(delta recall * precision at end of tied threshold group)';
    P.oldResultsPolicy='read-only snapshot; NEVER imported as new-confirmation results';
    P.scope='MECH + MAIN + TUNE. BUDGET optional. RA2DPCA / R3 / R4 / synthetic repeats not marked completed.';
end
