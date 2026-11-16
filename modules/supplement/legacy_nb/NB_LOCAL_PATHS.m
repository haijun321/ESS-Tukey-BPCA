function paths=NB_LOCAL_PATHS(settingsFile)
% Load location overrides only. Missing/empty values keep NB_CONFIG defaults.
% Availability checks belong to NB_PREFLIGHT, so unavailable external drives
% do not prevent source-only engineering self-tests.
    if nargin<1||isempty(settingsFile)
        settingsFile=fullfile(fileparts(mfilename('fullpath')),'NB_LOCAL_PATHS.mat');
    end
    paths=struct();
    if exist(settingsFile,'file')~=2,return;end
    saved=load(settingsFile,'paths');
    assert(isfield(saved,'paths')&&isstruct(saved.paths)&&isscalar(saved.paths), ...
        'NB:PathSettingsSchema','Invalid local settings file: %s',settingsFile);
    allowed={'archiveRoot','coilPath','outputRoot'};fields=fieldnames(saved.paths);
    assert(all(ismember(fields,allowed)),'NB:PathSettingsSchema', ...
        'Local settings may contain only archiveRoot, coilPath and outputRoot.');
    for i=1:numel(fields)
        value=saved.paths.(fields{i});
        assert(ischar(value)&&(isempty(value)||isrow(value))||isstring(value)&&isscalar(value), ...
            'NB:PathSettingsSchema','Location values must be character vectors or scalar strings.');
        value=char(value);
        if isempty(value),continue;end
        assert(is_absolute(value),'NB:PathAbsolute','Saved location must be absolute: %s',value);
        paths.(fields{i})=value;
    end
end

function yes=is_absolute(path)
    yes=startsWith(path,'/')||startsWith(path,'\\')|| ...
        ~isempty(regexp(path,'^[A-Za-z]:[\\/]','once'));
end
