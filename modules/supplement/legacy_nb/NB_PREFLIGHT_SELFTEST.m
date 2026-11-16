function report=NB_PREFLIGHT_SELFTEST()
% Missing dependencies must remain visible; synthetic readiness is separate.
% No frozen receipt is fabricated and no solver fit is called.
    C=P0_CONFIG();root=tempname;mkdir(root);cleanup=onCleanup(@()remove_tree(root));
    C.archiveRoot=fullfile(root,'missing_archive');C.coilPath=fullfile(root,'missing_coil');
    b=struct('Module','test','Dataset','SYN','Condition','clean','Repeat',1,'Method','C3');
    jobs=repmat(b,4,1);jobs(2).Dataset='YALE';jobs(2).Condition='Clean';
    jobs(3).Dataset='COIL20';jobs(3).Condition='Clean';jobs(4)=jobs(2);jobs(4).Method='C4';
    a=NB_PREFLIGHT(C,jobs,'basic');
    assert(numel(a.Rows)==4&&a.ReadyCount==1&&a.BlockedCount==3&&~a.AllReady, ...
        'NB:PreflightTest','Blocked tasks were omitted or reported ready.');
    assert(a.UniqueDependencyChecks==3&&a.FitsExecuted==0&&~a.NumericalSelfTestsAssessed, ...
        'NB:PreflightTest','Duplicate checks or readiness scope incorrect.');
    d=NB_PREFLIGHT(C,jobs(1),'deep');
    assert(d.AllReady&&d.ReadyCount==1&&d.COILInitializationChecks==0, ...
        'NB:PreflightTest','Synthetic-only deep preflight should need no external source.');
    for folder={'cache','splits','calibration','jobs'},mkdir(fullfile(root,'archive',folder{1}));end
    C.archiveRoot=fullfile(root,'archive');
    a=NB_PREFLIGHT(C,jobs(2),'deep');
    assert(~a.AllReady&&contains(a.Rows.Reason,'normalized.mat'), ...
        'NB:PreflightTest','An empty folder tree was treated as a frozen archive.');
    bad=1;save(fullfile(root,'bad_coil.mat'),'bad');C.coilPath=fullfile(root,'bad_coil.mat');
    a=NB_PREFLIGHT(C,jobs(3),'basic');
    assert(~a.AllReady&&contains(a.Rows.Reason,'X(p,q,n)'), ...
        'NB:PreflightTest','An unrelated MAT was accepted as COIL data.');
    rejected=false;try,NB_PREFLIGHT(C,jobs,'guess');catch e,rejected=strcmp(e.identifier,'NB:PreflightMode');end
    assert(rejected,'NB:PreflightTest','Unknown preflight mode accepted.');
    % Regression: valid COIL deep checks exercise BOTH typed caches and reuse.
    X=randn(12,10,24);labels=[ones(12,1);2*ones(12,1)];
    C.coilPath=fullfile(root,'valid_coil.mat');C.coilRank=3;
    save(C.coilPath,'X','labels');
    coilJobs=repmat(jobs(3),4,1);
    coilJobs(1).Condition='Clean';coilJobs(2).Condition='I10';
    coilJobs(3).Condition='B10';coilJobs(4)=coilJobs(1);coilJobs(4).Method='C4';
    a=NB_PREFLIGHT(C,coilJobs,'deep');
    assert(a.AllReady&&a.ReadyCount==4&&a.UniqueDependencyChecks==3&&a.COILInitializationChecks==1, ...
        'NB:PreflightTest','Valid COIL cache insertion/reuse failed.');
    empty=NB_PREFLIGHT(C,repmat(b,0,1),'basic');
    assert(empty.AllReady&&empty.PlannedTasks==0&&isempty(empty.Rows), ...
        'NB:PreflightTest','Empty typed task list returned invalid status.');
    report=struct('Pass',true,'EngineeringOnly',true,'Checks',7, ...
        'BlockedTasksRetained',true,'FitsExecuted',0);
    fprintf('NB_PREFLIGHT_SELFTEST PASS: typed caches, mixed plans, valid COIL reuse and explicit schemas.\n');
    clear cleanup;
end
function remove_tree(root)
    if exist(root,'dir')==7,rmdir(root,'s');end
end
