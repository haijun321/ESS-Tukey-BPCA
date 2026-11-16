function C = SMP_CONFIG()
% Frozen protocol defaults. Change scientific settings only in a NEW output root.
    C.protocolVersion = 'Tukey-Sample-Extension-v1-20261115';
    C.packageRoot = fileparts(mfilename('fullpath'));
    C.outputRoot = fullfile(C.packageRoot,'results_sample_extension_v1');
    C.n=240; C.p=40; C.q=30; C.r=5; C.c=4; C.nProbe=240;
    C.noiseSigma=0.1; C.kappa=4; C.cellRate=0.10; C.caseRate=0.10;
    C.formalRepeats=1:10; C.precheckRepeats=1;
    C.formalSeed=371000; C.precheckSeed=391000;
    C.syntheticBudget=[60 10 20]; C.syntheticTimeLimit=180;
    C.precheckBudget=[6 2 6]; C.precheckTimeLimit=30;
    C.bootstrapResamples=10000; C.statsSeed=20261115;
    C.makePlots=true;
    C.conditions={'Clean','CellOnly','CaseOnly','Mixed'};
    C.primaryConditions={'CaseOnly','Mixed'};
    C.primaryMetric='ErrSubNorm';
    C.normalDownweightThreshold=0.95;
    C.sampleWeightAlpha=0.35; C.sampleWeightMin=0.20;
    C.sampleTauC=3; C.sampleQuantile=0.85;
end
