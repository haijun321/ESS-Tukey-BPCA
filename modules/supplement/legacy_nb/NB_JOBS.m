function jobs=NB_JOBS(C,window,stage)
% Explicit frozen plans. Pilot is engineering-only and has a different seed family.
    b=struct('Module','','Dataset','','Condition','','Repeat',0,'Method','', ...
        'NoiseSigma',NaN,'Case',struct(),'Stage',stage);
    jobs=repmat(b,0,1);reps=C.syntheticReps;rr=C.realReps;tr=C.traceReps;
    if strcmp(stage,'pilot'),reps=1;rr=1;tr=1;end
    cases=P0_CASES(C,true);
    switch upper(window)
        case 'A',module='A_trajectory';methods={'C1','C2','C3','C4'};reps=tr;rr=tr;
        case 'B'
            module='B_comparison';methods={'L2','C1','C2','C3','RA2DPCA_dev'};
            if C.runTuned,methods=[methods {'TunedC','TunedEta'}];end
            if ~isempty(C.externalAdapter),methods=[methods {C.externalName}];end
        case 'C',module='C_factorial';methods={'C2','C3','C4','C5'};cases=cases([2 4]);
        case 'D',module='D_transfer';methods={'C1','C2','C3'};cases=cases([2 4]);
        case 'E',module='E_coil';methods={'L2','C1','C2','C3','C4','RA2DPCA_dev'};
        otherwise,error('NB:Window','Choose A,B,C,D,E');
    end
    if ~strcmpi(window,'E')&&C.runSynthetic
        if strcmpi(window,'D'),sigmas=[.05 .20];else,sigmas=.10;end
        for s=sigmas
            for a=1:numel(cases)
                cs=cases(a);condition=cs.Condition;
                if strcmpi(window,'D'),condition=sprintf('%s_sigma%03d',condition,round(100*s));end
                mm=methods;
                if strcmpi(window,'B')&&C.runDimensionCurves&&any(a==[2 4])
                    for level=C.raDimensionFactors
                        mm=[mm {sprintf('C3_dim%d',level),sprintf('RA_dim%d',level)}]; %#ok<AGROW>
                    end
                end
                for r=reps
                    for m=1:numel(mm)
                        z=b;z.Module=module;z.Dataset='SYN';z.Condition=condition;
                        z.Repeat=r;z.Method=mm{m};z.NoiseSigma=s;z.Case=cs;jobs(end+1)=z; %#ok<AGROW>
                    end
                end
            end
        end
    end
    if strcmpi(window,'E')
        datasets={'COIL20'};conditions={'Clean','I10','B10'};
    elseif strcmpi(window,'D')||~C.runReal
        datasets={};conditions={};
    elseif strcmpi(window,'A')
        datasets={'YALE','ORL'};conditions={};
    elseif strcmpi(window,'C')
        datasets={'YALE','ORL'};conditions={'I30','B10','B30'};
    else,datasets={'YALE','ORL'};conditions={'Clean','I10','I30','B10','B30'};
    end
    for d=1:numel(datasets)
        if strcmpi(window,'A')
            if strcmp(datasets{d},'YALE'),cc={'Clean','B30'};else,cc={'I30','B10'};end
        else,cc=conditions;end
        for a=1:numel(cc)
            mm=methods;
            if strcmpi(window,'B')&&C.runDimensionCurves&& ...
                    ((strcmp(datasets{d},'YALE')&&strcmp(cc{a},'I30'))|| ...
                    (strcmp(datasets{d},'ORL')&&strcmp(cc{a},'B10')))
                for level=C.raDimensionFactors
                    mm=[mm {sprintf('C3_dim%d',level),sprintf('RA_dim%d',level)}]; %#ok<AGROW>
                end
            end
            for r=rr
                for m=1:numel(mm)
                    z=b;z.Module=module;z.Dataset=datasets{d};z.Condition=cc{a};
                    z.Repeat=r;z.Method=mm{m};jobs(end+1)=z; %#ok<AGROW>
                end
            end
        end
    end
end
