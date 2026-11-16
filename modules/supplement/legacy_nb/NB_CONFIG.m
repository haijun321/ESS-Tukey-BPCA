function C=NB_CONFIG()
% User-editable paths live in NB_USER_CONFIG.m, never in the frozen vendor.
    root=fileparts(mfilename('fullpath'));C=P0_CONFIG();
    C.packageRoot=fullfile(root,'vendor');C.nbRoot=root;
    C.archiveRoot='';C.coilPath='';C.outputRoot=fullfile(root,'results_NB_V2_FIX2_20261109');
    C.includeFixedEtaNoZero=true;C.syntheticSeedOffset=600000000;
    C.syntheticTimeLimit=Inf;C.realTimeLimit=Inf;
    C.coilRank=8;C.checkpointEvery=1;C.traceOuter=200;
    C.etaGrid=[.82 .85 .88 .91 .94 .97];C.cGrid=[2.5 3.5 4.685 6 8];
    C.raLambdaGrid=[.1 1 10];C.raDimensionFactors=[1 2];C.runDimensionCurves=true;
    C.raMaxOuter=100;C.raTolerance=1e-4;
    C.runReal=true;C.runSynthetic=true;C.runTuned=true;
    C.externalAdapter='';C.externalName='BA2DPCA';C.externalDependencies={};
    C.allowPartial=false;C.scope='all';C.preflightMode='deep';
    C.requirePilotBeforePaper=true;C.requireRACheckBeforePaper=true;
    C.pilotRAOuter=100;C.progressEveryOuter=10;
    C.traceReps=1:5;C.syntheticReps=1:30;C.realReps=1:10;
    C.bootstrapResamples=2000;C.statisticsSeed=20261105;
end
