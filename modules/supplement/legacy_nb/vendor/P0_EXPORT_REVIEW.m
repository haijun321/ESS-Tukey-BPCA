function report=P0_EXPORT_REVIEW(C)
% Compact upload bundle: all summaries/protocols and selected diagnostic fits.
% Never copies cached image tensors. Incomplete modules keep their completion flags.
    assert(exist(C.outputRoot,'dir')==7,'P0:Export','Output directory does not exist.');
    stage=tempname(C.outputRoot);mkdir(stage);cleanup=onCleanup(@()rmdir(stage,'s'));
    bundle=fullfile(stage,'review_bundle');mkdir(bundle);
    if exist(fullfile(C.outputRoot,'source_manifest.mat'),'file'),copyfile(fullfile(C.outputRoot,'source_manifest.mat'),bundle);end
    mods=dir(C.outputRoot);copied=0;
    for k=1:numel(mods)
        if ~mods(k).isdir||strcmp(mods(k).name,'.')||strcmp(mods(k).name,'..'),continue;end
        module=mods(k).name;src=fullfile(C.outputRoot,module);
        if ~exist(fullfile(src,'protocol.mat'),'file'),continue;end
        dst=fullfile(bundle,module);mkdir(dst);copyfile(fullfile(src,'protocol.mat'),dst);
        for name={'summary','selections'}
            if exist(fullfile(src,name{1}),'dir'),copyfile(fullfile(src,name{1}),fullfile(dst,name{1}));end
        end
        for name={'source_hashes.csv','trace_codes.csv','locked_selections.csv'}
            if exist(fullfile(src,name{1}),'file'),copyfile(fullfile(src,name{1}),dst);end
        end
        figures=dir(fullfile(src,'figures','*.pdf'));
        if ~isempty(figures),mkdir(fullfile(dst,'figures'));end
        for j=1:numel(figures),copyfile(fullfile(figures(j).folder,figures(j).name),fullfile(dst,'figures'));end
        fits=dir(fullfile(src,'fits','*','fit.mat'));
        for j=1:numel(fits)
            name=folder_name(fits(j).folder);
            targetORL=strcmp(module,'solver_real')&&~isempty(regexp(name,'^ORL_r(001|002|008|010)_Clean_Auto_','once'));
            targetHard=~isempty(regexp(name,'^SYN_r001_block_coherent_k4_p010_','once'));
            targetSmoke=strncmp(module,'smoke_',6)&&j<=2;
            if targetORL||targetHard||targetSmoke
                selected=fullfile(dst,'selected_fits');
                if ~exist(selected,'dir'),mkdir(selected);end
                to=fullfile(selected,name);copyfile(fits(j).folder,to);copied=copied+1;
            end
        end
    end
    P0_IO('write',fullfile(bundle,'READ_ME.txt'), ...
        ['Summaries/protocols cover all committed records. Selected fits are diagnostic examples, ' ...
         'not an audit census. Read each completion.csv before interpreting results. ' ...
         'Smoke/pilot outputs are engineering checks. No original face-image tensors are included.']);
    file=fullfile(C.outputRoot,['P0_REVIEW_' datestr(now,'yyyymmdd_HHMMSS') '.zip']);
    n=1;while exist(file,'file'),file=fullfile(C.outputRoot,sprintf('P0_REVIEW_%s_%03d.zip',datestr(now,'yyyymmdd_HHMMSS'),n));n=n+1;end
    zip(file,{'review_bundle'},stage);clear cleanup;
    report=struct('ZipFile',file,'SelectedDiagnosticFits',copied,'ContainsOriginalImages',false);
    disp(report);
end
function n=folder_name(path)
    [~,n]=fileparts(path);
end
