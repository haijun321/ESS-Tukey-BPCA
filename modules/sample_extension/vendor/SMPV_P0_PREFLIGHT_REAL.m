function report=SMPV_P0_PREFLIGHT_REAL(C,tag)
% Strictly verify cached observations, split/calibration membership and cases.
% Missing archive objects are errors; the code never invents replacement splits.
    if nargin<2,tag='real';end
    clear SMPV_SU_CASE;
    assert(exist(C.archiveRoot,'dir')==7,'P0:Archive', ...
        ['Set archiveRoot to the COMPLETED results_Tukey_CONFIRM_v1 directory. ' ...
         'It must contain cache, splits, calibration and jobs. Current: %s'],C.archiveRoot);
    rows=cell(0,7);
    for d=1:numel(C.realDatasets)
        ds=C.realDatasets{d};assert(any(strcmp(ds,{'YALE','ORL'})),'P0:Dataset','Use YALE or ORL.');
        for rep=C.repeats
            D=SMPV_SU_DATA(C,ds,rep);
            assert(isscalar(D.F.selectedRank),'P0:RankSchema','Expected frozen equal row/column rank.');
            for ic=1:numel(C.realConditions)
                cond=C.realConditions{ic};K=SMPV_SU_CASE(C,D,cond);
                rows(end+1,:)={ds,rep,cond,D.F.selectedRank,D.dataHash,D.S.hash,K.caseHash}; %#ok<AGROW>
            end
            fprintf('PREFLIGHT %s split %d: rank %d; probe excluded; cases verified.\n',ds,rep,D.F.selectedRank);
        end
    end
    report=struct('Pass',true,'VerifiedDatasetSplits',numel(C.realDatasets)*numel(C.repeats), ...
        'VerifiedCases',size(rows,1),'ArchiveRoot',C.archiveRoot);
    SMPV_P0_IO('csv',fullfile(C.outputRoot,[tag '_preflight.csv']), ...
        {'Dataset','Repeat','Condition','Rank','DataHash','SplitHash','CaseHash'},rows);
    disp(report);
end
