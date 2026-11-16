function report=NB_CONTROL_SELFTEST()
% Tests resume identity and readiness gates, never scientific outcomes.
    C=NB_CONFIG();a=NB_PROTOCOL_CONFIG(C);B=C;
    B.archiveRoot=fullfile(tempdir,'different_archive');B.coilPath=fullfile(tempdir,'different_coil');
    B.outputRoot=fullfile(tempdir,'different_results');B.stopFile=fullfile(B.outputRoot,'REQUEST_STOP.flag');
    assert(strcmp(jsonencode(a),jsonencode(NB_PROTOCOL_CONFIG(B))),'NB:ControlTest','Location changes alter science identity');
    B=C;B.syntheticBudget(1)=B.syntheticBudget(1)+1;
    assert(~strcmp(jsonencode(a),jsonencode(NB_PROTOCOL_CONFIG(B))),'NB:ControlTest','Scientific budget changes were ignored');
    P=NB_STAGE_CONFIG(C,'pilot');
    assert(isequal(P.raLambdaGrid,C.raLambdaGrid)&&P.raMaxOuter==C.pilotRAOuter, ...
        'NB:ControlTest','Pilot dropped RA activation candidates or budget');
    jobs=NB_JOBS(C,'A','paper');B=C;B.scope='synthetic';[s,ss]=NB_SCOPE_JOBS(B,jobs);
    B.scope='real';[r,rs]=NB_SCOPE_JOBS(B,jobs);
    assert(numel(s)+numel(r)==numel(jobs)&&strcmp(ss,'_SYN')&&strcmp(rs,'_REAL'), ...
        'NB:ControlTest','Explicit task scopes do not partition the plan');
    K=struct('rank',[2 2],'caseHash','fixture_data','initHash','fixture_init');
    D=struct('dataHash','data_v1','splitHash','split_v1','cfg',struct('reference',.2));
    sig=NB_FIT_SIGNATURE('fixture_protocol',K,D,struct('maxOuter',3),jobs(1));
    D.dataHash='data_v2';
    assert(~strcmp(sig,NB_FIT_SIGNATURE('fixture_protocol',K,D,struct('maxOuter',3),jobs(1))), ...
        'NB:ControlTest','Changed data did not invalidate cached fit');
    D.dataHash='data_v1';D.cfg.reference=.3;
    assert(~strcmp(sig,NB_FIT_SIGNATURE('fixture_protocol',K,D,struct('maxOuter',3),jobs(1))), ...
        'NB:ControlTest','Changed calibration did not invalidate cached fit');
    root=tempname;mkdir(root);cleanup=onCleanup(@()remove_tree(root));
    C.outputRoot=root;C.requireRACheckBeforePaper=false;
    folder=fullfile(root,'pilot','windowA_SYN');mkdir(folder);
    z=struct('ReadyForPaper',false,'SourceHash','fixture_source','FamilyHash','fixture_family');
    write_status(folder,z);rejected=false;
    try,NB_PAPER_GATE(C,'A','_SYN','fixture_source','fixture_family');
    catch e,rejected=strcmp(e.identifier,'NB:PilotNotReady');end
    assert(rejected,'NB:ControlTest','Incomplete pilot was accepted');
    z.ReadyForPaper=true;write_status(folder,z);
    NB_PAPER_GATE(C,'A','_SYN','fixture_source','fixture_family');
    rejected=false;
    try,NB_PAPER_GATE(C,'A','_SYN','fixture_source','changed_family');
    catch e,rejected=strcmp(e.identifier,'NB:PilotNotReady');end
    assert(rejected,'NB:ControlTest','Changed settings passed old pilot gate');
    w=fullfile(root,'paper','windowA_SYN');mkdir(w);
    writetable(struct2table(rmfield(s,'Case')),fullfile(w,'expected_manifest.csv'));
    NB_SCOPE_GUARD(fullfile(root,'paper'),fullfile(root,'paper','windowA_REAL'),r);
    rejected=false;
    try,NB_SCOPE_GUARD(fullfile(root,'paper'),fullfile(root,'paper','windowA'),jobs);
    catch e,rejected=strcmp(e.identifier,'NB:OverlappingScope');end
    assert(rejected,'NB:ControlTest','Overlapping scopes were accepted');
    report=struct('Pass',true,'EngineeringOnly',true,'LocationIndependentIdentity',true, ...
        'ScientificChangesDetected',true,'ExplicitScopePartition',true,'IncompletePilotRejected',true);
    clear cleanup;
end
function write_status(folder,z)
    f=fopen(fullfile(folder,'RUN_STATUS.json'),'w');assert(f>=0);g=onCleanup(@()fclose(f));
    fprintf(f,'%s',jsonencode(z));clear g;
end
function remove_tree(root)
    if exist(root,'dir'),rmdir(root,'s');end
end
