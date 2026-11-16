function report=NB_PATHS_SELFTEST()
% Tests persistence and rejection without touching the user's saved paths.
    root=tempname;mkdir(root);cleanup=onCleanup(@()remove_tree(root));
    settings=fullfile(root,'location_settings.mat');archive=fullfile(root,'archive');
    for name={'cache','splits','calibration','jobs'},mkdir(fullfile(archive,name{1}));end
    fixture=true;
    save(fullfile(archive,'cache','YALE_normalized.mat'),'fixture');
    save(fullfile(archive,'cache','ORL_normalized.mat'),'fixture');
    X=randn(4,5,8);labels=[ones(4,1);2*ones(4,1)];coil=fullfile(root,'coil.mat');save(coil,'X','labels');
    output=fullfile(root,'output');
    original=NB_SETUP_PATHS(struct('archiveRoot',archive,'coilPath',coil,'outputRoot',output),settings);
    saved=NB_LOCAL_PATHS(settings);
    assert(isequal(original,saved)&&exist(output,'dir')==7,'NB:PathsTest','Location roundtrip failed.');
    NB_SETUP_PATHS(struct(),settings);
    assert(isequal(saved,NB_LOCAL_PATHS(settings)),'NB:PathsTest','Empty update removed settings.');
    cleared=NB_SETUP_PATHS(struct('coilPath',''),settings);
    assert(~isfield(cleared,'coilPath')&&strcmp(cleared.archiveRoot,archive), ...
        'NB:PathsTest','Explicit clearing did not preserve unrelated locations.');
    before=NB_LOCAL_PATHS(settings);rejected=false;
    try,NB_SETUP_PATHS(struct('archiveRoot',fullfile(root,'missing')),settings);
    catch e,rejected=strcmp(e.identifier,'NB:PathArchive');end
    assert(rejected&&isequal(before,NB_LOCAL_PATHS(settings)), ...
        'NB:PathsTest','Invalid update modified committed settings.');
    rejected=false;
    try,NB_SETUP_PATHS(struct('outputRoot','relative_path'),settings);
    catch e,rejected=strcmp(e.identifier,'NB:PathAbsolute');end
    assert(rejected,'NB:PathsTest','Relative location accepted.');
    rejected=false;
    try,NB_SETUP_PATHS(struct('raLambdaGrid',[1 10]),settings);
    catch e,rejected=strcmp(e.identifier,'NB:PathOptions');end
    assert(rejected,'NB:PathsTest','Scientific setting accepted by location-only setter.');
    rejected=false;
    try,NB_SETUP_PATHS(struct('outputRoot',fileparts(mfilename('fullpath'))),settings);
    catch e,rejected=strcmp(e.identifier,'NB:PathOutput');end
    assert(rejected,'NB:PathsTest','Source directory accepted as output root');
    report=struct('Pass',true,'EngineeringOnly',true,'Checks',7, ...
        'Roundtrip',true,'AtomicRejectedUpdate',true,'LocationOnlySchema',true);
    clear cleanup;
end
function remove_tree(path)
    if exist(path,'dir')==7,rmdir(path,'s');end
end
