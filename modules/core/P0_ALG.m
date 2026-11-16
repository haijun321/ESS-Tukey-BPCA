function [A,S] = P0_ALG(C,regime,foldAlg,multiplier)
% Frozen synthetic calibration; real calibration comes ONLY from archive folds.
    if nargin<3, foldAlg=[]; end
    if nargin<4, multiplier=1; end
    if strcmp(regime,'synthetic')
        A=struct();
        A.fastBpcaSteps=5; A.tolOuter=1e-6; A.eps0=1e-12; A.zeroTol=1e-12;
        A.mmShrink=.5; A.mmAcceptTol=1e-10;
        A.mmStationaryRelTol=1e-8; A.mmStationaryMoveTol=1e-7; A.stationarityTol=1e-6;
        A.essEtaMin=.82; A.essEtaMaxContam=.96; A.essEtaDefaultClean=.99;
        A.essTailK1=2.25; A.essTailK2=3; A.essTailK3=4; A.essGridSize=100;
        A.essTailGamma=.65; A.etaGuard=.005;
        A.tailSeverityCleanThreshold=.012; A.tailSeverityCap=.4;
        A.useZeroCalibration=true; A.zeroUnderPenalty=.8; A.zeroOverPenalty=.5;
        A.zeroLowerFactor=.45; A.zeroUpperFactor=1.8;
        A.useSampleWeight=true; A.sampleWeightAlpha=.35; A.sampleWeightMin=.2; A.sampleTauC=3;
        A.cleanGuardSampleWeight=true; A.fixedTukeyC=4.685; A.huberC=1.345; A.welschC=2.985;
        A.initMode='robust_l2'; A.clipC=3; A.useCalibratedEtaMap=true;
        A.etaMapIntercept=1.00372472176969; A.etaMapSlope=-1.03921233145835;
        A.useSeverityMemory=false; A.memoryBlockSize=50000; A.sampleTailQuantile=95;
        caps=C.syntheticBudget; seconds=C.syntheticTimeLimit;
        d=C.syntheticDimensions;
        assert(numel(d)==5&&all(d==fix(d))&&all(d>0)&&d(4)<d(2)&&d(5)<d(3), ...
            'P0:Geometry','Use [n p q r c] with r<p and c<q.');
        S=struct('n',d(1),'p',d(2),'q',d(3),'r0',d(4),'c0',d(5), ...
            'noiseSigma',.1,'blockRatio',.18,'sampleOutlierScale',1,'contamScaleMode','robust_scale');
    else
        assert(isstruct(foldAlg),'P0:FoldAlg','Real-data fold algorithm required.');
        A=foldAlg; caps=C.realBudget; seconds=C.realTimeLimit; S=[];
        if isempty(seconds)
            if isfield(A,'maxTimePerMethod'),seconds=A.maxTimePerMethod;else,seconds=Inf;end
        end
    end
    assert(numel(caps)==3&&all(caps>=1)&&all(caps==fix(caps)),'P0:Caps','Three integer caps required.');
    assert(isscalar(seconds)&&seconds>0,'P0:Time','Time limit must be positive or Inf.');
    A.maxOuter=caps(1)*multiplier; A.maxInner=caps(2)*multiplier;
    A.mmLineSearchMax=caps(3)*multiplier; A.maxTimePerMethod=seconds*multiplier;
    A.gradientTolerance=C.gradientTolerance; A.projectorTolerance=C.projectorTolerance;
    A.stateTolerance=C.stateTolerance; A.minimumAcceptedMove=C.minimumAcceptedMove;
    A.gradientBacktracks=C.gradientBacktracks*multiplier;
    A.armijoConstant=C.armijoConstant; A.gradientStepMax=C.gradientStepMax;
    A.majorizerTolerance=C.majorizerTolerance;
end
