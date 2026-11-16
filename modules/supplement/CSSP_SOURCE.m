function [h,rows]=CSSP_SOURCE(mode,C)
% Hash numerical dependencies separately from the full delivered program.
if nargin<1,mode='all';end
if strcmp(mode,'core')
    fs=[dir(fullfile(C.packageRoot,'*.m'));dir(fullfile(C.packageRoot,'frozen','*.m')); ...
        dir(fullfile(C.nbRoot,'instrumented','NB_SOLVER_TRACE.m'))];
else
    % Downloaded third-party dependencies have separate per-method hashes.
    % Installing them later must not invalidate already completed native fits.
    fs=[dir(fullfile(C.csspRoot,'*.m'));dir(fullfile(C.csspRoot,'*.R')); ...
        dir(fullfile(C.nbRoot,'**','*.m'));dir(fullfile(C.nbRoot,'**','*.R'))];
end
rows=cell(0,2);
for k=1:numel(fs)
    p=fullfile(fs(k).folder,fs(k).name);
    if startsWith(p,[C.outputRoot filesep]),continue;end
    if strcmp(fs(k).name,'CSSP_USER_CONFIG.m'),continue;end % location overrides are not scientific source
    rel=p(numel(C.csspRoot)+2:end);
    rows(end+1,:)={strrep(rel,'\','/'),P0_IO('hashfile',p)}; %#ok<AGROW>
end
if ~isempty(rows),rows=sortrows(rows,1);end
h=P0_IO('hashtext',jsonencode(rows));
end
