function [h,manifest]=NB_SOURCE_HASH(C)
    fs=dir(fullfile(C.nbRoot,'**','*.m'));manifest=cell(0,2);
    for i=1:numel(fs)
        p=fullfile(fs(i).folder,fs(i).name);
        if startsWith(p,[C.outputRoot filesep]),continue;end
        rel=p(numel(C.nbRoot)+2:end);manifest(end+1,:)={strrep(rel,'\','/'),P0_IO('hashfile',p)}; %#ok<AGROW>
    end
    if ~isempty(C.externalAdapter)
        p=which(C.externalAdapter);
        assert(~isempty(p),'NB:ExternalMissing','External adapter is not on the MATLAB path');
        manifest(end+1,:)={['EXTERNAL_ADAPTER:' C.externalAdapter],P0_IO('hashfile',p)};
    end
    for i=1:numel(C.externalDependencies)
        p=C.externalDependencies{i};assert(exist(p,'file')==2,'NB:ExternalDependency','Missing external dependency: %s',p);
        manifest(end+1,:)={['EXTERNAL_DEPENDENCY:' p],P0_IO('hashfile',p)}; %#ok<AGROW>
    end
    [~,ix]=sort(manifest(:,1));manifest=manifest(ix,:);h=P0_IO('hashtext',jsonencode(manifest));
end
