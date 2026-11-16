function paths=NB_SETUP_PATHS(options,settingsFile)
% Persist file LOCATIONS without editing or invalidating scientific source.
% NB_SETUP_PATHS() opens optional pickers; cancelling preserves saved values.
% NB_SETUP_PATHS(struct('archiveRoot',p,'coilPath',q,'outputRoot',r)) is headless.
% An explicit empty value removes that override and restores NB_CONFIG default.
% settingsFile is injectable only for engineering tests or isolated setups.
    if nargin<2||isempty(settingsFile)
        settingsFile=fullfile(fileparts(mfilename('fullpath')),'NB_LOCAL_PATHS.mat');
    end
    previous=NB_LOCAL_PATHS(settingsFile);
    if nargin<1
        assert(usejava('desktop'),'NB:PathGUI', ...
            'No desktop available. Use NB_SETUP_PATHS(struct(...)) instead.');
        options=gui_options(previous);
    end
    assert(isstruct(options)&&isscalar(options),'NB:PathOptions','Pass one options struct.');
    allowed={'archiveRoot','coilPath','outputRoot'};fields=fieldnames(options);
    assert(all(ismember(fields,allowed)),'NB:PathOptions', ...
        'Only archiveRoot, coilPath and outputRoot are accepted here.');
    paths=previous;
    for i=1:numel(fields)
        value=options.(fields{i});
        assert(ischar(value)&&(isempty(value)||isrow(value))||isstring(value)&&isscalar(value), ...
            'NB:PathType','%s must be a character vector or scalar string.',fields{i});
        value=char(value);
        if isempty(value)
            if isfield(paths,fields{i}),paths=rmfield(paths,fields{i});end
        else
            assert(is_absolute(value),'NB:PathAbsolute','Use an absolute %s: %s',fields{i},value);
            validate_location(fields{i},value);paths.(fields{i})=value;
        end
    end
    if isfield(paths,'outputRoot')&&exist(paths.outputRoot,'dir')~=7
        [ok,message]=mkdir(paths.outputRoot);assert(ok,'NB:PathOutput','%s',message);
    end
    parent=fileparts(settingsFile);
    if isempty(parent),parent=pwd;settingsFile=fullfile(parent,settingsFile);end
    if exist(parent,'dir')~=7,[ok,message]=mkdir(parent);assert(ok,'NB:PathSettingsIO','%s',message);end
    temp=[tempname(parent) '.mat'];cleanup=onCleanup(@()remove_temp(temp));
    save(temp,'paths','-v7');
    [ok,message]=movefile(temp,settingsFile,'f');assert(ok,'NB:PathSettingsIO','%s',message);clear cleanup;
    fprintf('Saved local location settings. Scientific algorithm settings were not edited.\n');
    for i=1:numel(allowed)
        key=allowed{i};
        if isfield(paths,key),fprintf('  %s: %s\n',key,paths.(key));
        else,fprintf('  %s: NB_CONFIG default / not supplied\n',key);end
    end
    fprintf('Run CHECK_READY before starting a data-dependent window.\n');
end

function options=gui_options(previous)
    options=struct();base=pwd;
    if isfield(previous,'archiveRoot')&&exist(previous.archiveRoot,'dir')==7,base=previous.archiveRoot;end
    selected=uigetdir(base,'Select TC archive root (cache/splits/calibration/jobs); Cancel keeps existing');
    if ~isequal(selected,0),options.archiveRoot=selected;end
    choice=questdlg('Select optional COIL20 input. Cancel or Skip keeps the existing setting.', ...
        'COIL20 input','Directory','MAT file','Skip','Skip');
    if strcmp(choice,'Directory')
        base=pwd;if isfield(previous,'coilPath')&&exist(previous.coilPath,'dir')==7,base=previous.coilPath;end
        selected=uigetdir(base,'Select COIL20 grayscale objN__angle.png directory');
        if ~isequal(selected,0),options.coilPath=selected;end
    elseif strcmp(choice,'MAT file')
        [name,folder]=uigetfile('*.mat','Select MAT with top-level X(p,q,n), labels');
        if ~isequal(name,0),options.coilPath=fullfile(folder,name);end
    end
    base=pwd;if isfield(previous,'outputRoot')&&exist(previous.outputRoot,'dir')==7,base=previous.outputRoot;end
    selected=uigetdir(base,'Select output directory; Cancel keeps NB_CONFIG default / existing');
    if ~isequal(selected,0),options.outputRoot=selected;end
end

function validate_location(key,path)
    switch key
        case 'archiveRoot'
            assert(exist(path,'dir')==7,'NB:PathArchive','Archive root does not exist: %s',path);
            for name={'cache','splits','calibration','jobs'}
                assert(exist(fullfile(path,name{1}),'dir')==7,'NB:PathArchive', ...
                    'Selected root lacks %s. Choose the TC archive root, not raw images or a CSV result directory.',name{1});
            end
            for dataset={'YALE','ORL'}
                file=fullfile(path,'cache',[dataset{1} '_normalized.mat']);
                assert(exist(file,'file')==2,'NB:PathArchive', ...
                    'Selected archive lacks %s. Both YALE/ORL caches are required by the standard plan.',file);
            end
        case 'coilPath'
            if exist(path,'file')==2
                [~,~,extension]=fileparts(path);
                assert(strcmpi(extension,'.mat'),'NB:PathCOIL','COIL file input must be MAT with X and labels.');
                fields=whos('-file',path);names={fields.name};
                assert(all(ismember({'X','labels'},names)),'NB:PathCOIL','COIL MAT needs top-level X and labels.');
            else
                assert(exist(path,'dir')==7,'NB:PathCOIL','COIL input does not exist: %s',path);
                files=[dir(fullfile(path,'**','*.png'));dir(fullfile(path,'**','*.PNG'))];found=false;
                for i=1:numel(files)
                    if ~isempty(regexpi(files(i).name,'^obj\d+__-?\d+(?:\.\d+)?\.png$','once')),found=true;break;end
                end
                assert(found,'NB:PathCOIL','No objN__angle.png files found; provide the correct directory or explicit X,labels MAT.');
            end
        case 'outputRoot'
            assert(exist(path,'file')~=2,'NB:PathOutput','Output location is an existing file: %s',path);
            sourceFile=java.io.File(fileparts(mfilename('fullpath')));targetFile=java.io.File(path);
            source=char(sourceFile.getCanonicalPath());target=char(targetFile.getCanonicalPath());
            assert(~strcmpi(source,target)&&~startsWith(lower(source),[lower(target) filesep]), ...
                'NB:PathOutput','Choose a results subfolder, not the code directory or its ancestor.');
    end
end

function yes=is_absolute(path)
    yes=startsWith(path,'/')||startsWith(path,'\\')|| ...
        ~isempty(regexp(path,'^[A-Za-z]:[\\/]','once'));
end
function remove_temp(path)
    if exist(path,'file')==2,delete(path);end
end
