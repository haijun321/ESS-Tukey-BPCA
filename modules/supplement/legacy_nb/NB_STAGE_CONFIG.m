function C=NB_STAGE_CONFIG(C,stage)
% Pilot shortens the native plumbing checks, not the RA activation checks.
    if strcmp(stage,'pilot')
        C.syntheticSeedOffset=C.syntheticSeedOffset+10000000;
        C.syntheticDimensions=[24 12 10 3 2];C.etaGrid=[.85 .97];C.cGrid=[2.5 4.685];
        C.raDimensionFactors=1;
        % Keep the declared [.1,1,10] lambda grid, including the scale-control candidate.
        C.raMaxOuter=C.pilotRAOuter;
    end
end
