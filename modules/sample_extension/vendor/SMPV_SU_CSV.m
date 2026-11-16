function SMPV_SU_CSV(file,headers,rows)
% UTF-8 compatible CSV; no Statistics Toolbox, tables or Excel needed.
    if isnumeric(rows),rows=num2cell(rows);end
    if isempty(rows),rows=cell(0,numel(headers));end
    assert(size(rows,2)==numel(headers),'SU:CSV','CSV column mismatch');
    lines=cell(size(rows,1)+1,1);lines{1}=strjoin(cellfun(@encode,headers,'UniformOutput',false),',');
    for i=1:size(rows,1),lines{i+1}=strjoin(cellfun(@encode,rows(i,:),'UniformOutput',false),',');end
    SMPV_SU_UTIL('write',file,sprintf('%s\n',lines{:}));
end
function s=encode(v)
    if isnumeric(v)||islogical(v),assert(isscalar(v));s=sprintf('%.17g',v);
    else,s=['"' strrep(char(v),'"','""') '"'];end
end
