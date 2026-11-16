function jobs=CSSP_JOBS(C)
% Five agreed modules only. No new dataset, synthetic seed sweep or hidden cap.
b=struct('Module','','Dataset','','Condition','','Repeat',0,'Method','','Budget','B1', ...
    'Stage',C.stage,'NoiseSigma',NaN,'Case',struct());jobs=repmat(b,0,1);
for q=1:numel(C.modules)
    module=C.modules{q};datasets=C.realDatasets;conditions=C.realConditions;budgets={'B1'};
    switch module
        case '01_initialization',methods={'INIT','C1','C2','C3','C4'};
        case '02_factorial',methods={'C2','C3','C4','C5'};
        case '03_external',methods=[{'C1','C3'} C.externalMethods];
        case '04_yale_selection',datasets={'YALE'};methods={'C1','C2','C3','TunedC','TunedEta'};
        case '05_b10_budget',conditions={'B10'};methods={'C1','C2','C3','C4'};budgets={'B1','B2'};
        otherwise,error('CSSP:Module','Unknown module %s',module);
    end
    for d=1:numel(datasets)
        for r=C.realReps
            for a=1:numel(conditions)
                for k=1:numel(budgets)
                    for m=1:numel(methods)
                        z=b;z.Module=module;z.Dataset=datasets{d};z.Condition=conditions{a};
                        z.Repeat=r;z.Method=methods{m};z.Budget=budgets{k};jobs(end+1,1)=z; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
end
