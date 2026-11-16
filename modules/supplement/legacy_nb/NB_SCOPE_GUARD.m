function NB_SCOPE_GUARD(stageRoot,currentFolder,jobs)
% Prevent overlapping ALL/SYN/REAL subplans and duplicate scientific records.
    files=dir(fullfile(stageRoot,'window*','expected_manifest.csv'));
    keys=arrayfun(@jobkey,jobs,'UniformOutput',false);
    for i=1:numel(files)
        if strcmpi(files(i).folder,currentFolder),continue;end
        T=readtable(fullfile(files(i).folder,files(i).name),'TextType','string');
        for k=1:height(T)
            q=struct('Module',char(T.Module(k)),'Dataset',char(T.Dataset(k)), ...
                'Condition',char(T.Condition(k)),'Repeat',T.Repeat(k),'Method',char(T.Method(k)));
            assert(~any(strcmp(keys,jobkey(q))),'NB:OverlappingScope', ...
                'This plan overlaps %s. Use SYN then REAL scopes, or a NEW outputRoot for ALL.',files(i).folder);
        end
    end
end
function s=jobkey(j)
    s=sprintf('%s|%s|%s|%d|%s',j.Module,j.Dataset,j.Condition,j.Repeat,j.Method);
end
