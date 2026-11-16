function cases=SMPV_P0_CASES(C,diagnosticOnly)
% Original 44-condition grid and original seed formula. Separate zero-rate
% tuples have distinct seeds; they are all the same no-injected-outlier regime.
    b=struct('Dataset','SYN','Condition','','Type','','TypeIndex',0,'RateIndex',0, ...
        'NominalRate',0,'Strength',0,'StrengthIndex',0);
    cases=repmat(b,0,1);types={'sample','impulse','block_random','block_coherent'};
    for si=1:2
        strength=2*si;
        for ti=1:4
            if ti==4,rates=[0 .02 .05 .10];else,rates=[0 .02 .05 .10 .15 .20];end
            for ri=1:numel(rates)
                x=b;x.Type=types{ti};x.TypeIndex=ti;x.RateIndex=ri;
                x.NominalRate=rates(ri);x.Strength=strength;x.StrengthIndex=si;
                x.Condition=sprintf('%s_k%d_p%03d',x.Type,strength,round(100*rates(ri)));
                cases(end+1,1)=x; %#ok<AGROW>
            end
        end
    end
    if diagnosticOnly
        keep=false(numel(cases),1);
        for k=1:numel(cases)
            x=cases(k);keep(k)=x.Strength==4&& ...
                ((x.TypeIndex==1&&x.NominalRate==0)||(x.TypeIndex>=2&&abs(x.NominalRate-.1)<1e-12));
        end
        cases=cases(keep);assert(numel(cases)==4,'P0:Cases','Diagnostic selection changed.');
    end
    assert(isfinite(C.syntheticSeedOffset)&&C.syntheticSeedOffset>=0&&C.syntheticSeedOffset==fix(C.syntheticSeedOffset), ...
        'P0:Seed','Invalid syntheticSeedOffset.');
end
