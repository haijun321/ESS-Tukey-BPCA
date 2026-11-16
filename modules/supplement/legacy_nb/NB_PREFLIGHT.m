function report=NB_PREFLIGHT(C,jobs,mode)
% Dependency readiness is separate from numerical/engineering self-tests.
% Every planned task gets a row; blocked tasks are never silently discarded.
% basic: paths/file membership only. deep: frozen real replay checks, with
% no solver fits; COIL deep validates one clean split per repeat through its
% loader and initialization API, without fitting or evaluating a probe.
    if nargin<3,mode='basic';end
    mode=lower(char(mode));
    assert(any(strcmp(mode,{'basic','deep'})),'NB:PreflightMode','Use basic or deep.');
    assert(isstruct(jobs),'NB:PreflightJobs','jobs must be the planned job struct array.');
    required={'Module','Dataset','Condition','Repeat','Method'};
    assert(isempty(jobs)||all(isfield(jobs,required)),'NB:PreflightJobs','Job key fields are missing.');
    blank=struct('Module','','Dataset','','Condition','','Repeat',0,'Method','', ...
        'Ready',false,'Reason','','CheckDepth',mode);
    % Empty caches must already carry the same fields as inserted statuses.
    statusTemplate=struct('Ready',false,'Reason','');
    rows=repmat(blank,numel(jobs),1);keys={};results=repmat(statusTemplate,0,1);
    coilKeys={};coilResults=repmat(statusTemplate,0,1);coilInitializationChecks=0;
    for i=1:numel(jobs)
        j=jobs(i);z=blank;
        for k=1:numel(required),z.(required{k})=j.(required{k});end
        key=sprintf('%s|%d|%s',char(j.Dataset),j.Repeat,char(j.Condition));
        hit=find(strcmp(keys,key),1);
        if ~isempty(hit)
            result=results(hit);
        else
            result=statusTemplate;
            try
                ds=char(j.Dataset);
                if strcmp(ds,'SYN')
                    result.Ready=true;
                    result.Reason='READY: generated synthetic data require no external archive.';
                elseif any(strcmp(ds,{'YALE','ORL'}))
                    real_basic(C,ds,j.Repeat);
                    if strcmp(mode,'deep')
                        D=SU_DATA(C,ds,j.Repeat);
                        SU_CASE(C,D,char(j.Condition));
                        result.Reason='READY: frozen data, split, calibration and corruption replay verified.';
                    else
                        result.Reason='READY_BASIC: required archive files exist; hashes/replay require deep preflight.';
                    end
                    result.Ready=true;
                elseif strcmp(ds,'COIL20')
                    coil_basic(C);
                    assert(any(strcmp(char(j.Condition),{'Clean','I10','B10'})), ...
                        'NB:PreflightCOILCondition','Unsupported COIL condition: %s',char(j.Condition));
                    if strcmp(mode,'deep')
                        ck=sprintf('COIL20|%d',j.Repeat);ch=find(strcmp(coilKeys,ck),1);
                        if isempty(ch)
                            cr=statusTemplate;
                            try
                                NB_COIL_CASE(C,j.Repeat,'Clean');
                                coilInitializationChecks=coilInitializationChecks+1;
                                cr.Ready=true;cr.Reason='READY: COIL source, dimensions, rank and disjoint split verified.';
                            catch e
                                cr.Reason=explain(e,'COIL20');
                            end
                            coilKeys{end+1}=ck;coilResults(end+1,1)=cr; %#ok<AGROW>
                        else,cr=coilResults(ch);end
                        result=cr;
                    else
                        result.Ready=true;
                        result.Reason='READY_BASIC: COIL path/schema exist; image values and split require deep preflight.';
                    end
                else
                    error('NB:PreflightDataset','Unsupported dataset: %s',ds);
                end
            catch e
                result.Ready=false;result.Reason=explain(e,char(j.Dataset));
            end
            keys{end+1}=key;results(end+1,1)=result; %#ok<AGROW>
        end
        z.Ready=result.Ready;z.Reason=result.Reason;rows(i)=z;
    end
    report=struct('Mode',mode,'Rows',rows,'AllReady',all([rows.Ready]), ...
        'PlannedTasks',numel(jobs),'ReadyCount',sum([rows.Ready]), ...
        'BlockedCount',sum(~[rows.Ready]),'UniqueDependencyChecks',numel(keys), ...
        'NumericalSelfTestsAssessed',false,'FitsExecuted',0, ...
        'COILInitializationChecks',coilInitializationChecks,'CheckedAt',datestr(now,30));
    fprintf('DEPENDENCY %s: %d ready / %d planned; %d blocked. No fits executed.\n', ...
        mode,report.ReadyCount,report.PlannedTasks,report.BlockedCount);
end

function real_basic(C,ds,rep)
    assert(isfield(C,'archiveRoot')&&~isempty(C.archiveRoot)&&exist(C.archiveRoot,'dir')==7, ...
        'NB:PreflightArchive','Set archiveRoot using NB_SETUP_PATHS or NB_USER_CONFIG.m; select the completed TC archive root.');
    for folder={'cache','splits','calibration','jobs'}
        assert(exist(fullfile(C.archiveRoot,folder{1}),'dir')==7, ...
            'NB:PreflightArchive','archiveRoot lacks %s/. Select the root containing cache, splits, calibration and jobs.',folder{1});
    end
    expected={fullfile(C.archiveRoot,'cache',[ds '_normalized.mat']), ...
        fullfile(C.archiveRoot,'splits',sprintf('%s_r%03d.mat',ds,rep)), ...
        fullfile(C.archiveRoot,'calibration',sprintf('%s_r%03d',ds,rep),'fold.mat')};
    for i=1:numel(expected)
        assert(exist(expected{i},'file')==2,'NB:PreflightArchiveFile', ...
            'Missing frozen archive file: %s. Restore the original file; do not create a replacement split.',expected{i});
    end
    cases=dir(fullfile(C.archiveRoot,'jobs','*','case.mat'));
    assert(~isempty(cases),'NB:PreflightArchiveCases', ...
        'No jobs/*/case.mat receipts found. A CSV-only result folder is not the TC archive.');
end

function coil_basic(C)
    assert(isfield(C,'coilPath')&&~isempty(C.coilPath),'NB:PreflightCOIL', ...
        'Set coilPath using NB_SETUP_PATHS or NB_USER_CONFIG.m.');
    p=char(C.coilPath);
    if exist(p,'file')==2
        [~,~,ext]=fileparts(p);
        assert(strcmpi(ext,'.mat'),'NB:PreflightCOIL','COIL file must be MAT with X and labels.');
        vars=whos('-file',p);names={vars.name};
        assert(all(ismember({'X','labels'},names)),'NB:PreflightCOILSchema', ...
            'COIL MAT requires top-level X(p,q,n) and labels. No variable-name or dimension guessing.');
        x=vars(strcmp(names,'X'));y=vars(strcmp(names,'labels'));
        assert(numel(x.size)==3&&all(x.size>0)&&prod(y.size)==x.size(3), ...
            'NB:PreflightCOILSchema','COIL MAT dimensions must be X(p,q,n), one label per image.');
    elseif exist(p,'dir')==7
        files=[dir(fullfile(p,'**','*.png'));dir(fullfile(p,'**','*.PNG'))];
        found=false;
        for i=1:numel(files)
            if ~isempty(regexpi(files(i).name,'^obj\d+__-?\d+(?:\.\d+)?\.png$','once'))
                found=true;break;
            end
        end
        assert(found,'NB:PreflightCOILFiles','No objN__angle.png images found under coilPath.');
    else
        error('NB:PreflightCOIL','COIL path does not exist: %s',p);
    end
end

function text=explain(e,dataset)
    text=sprintf('%s: %s',e.identifier,e.message);
    if any(strcmp(dataset,{'YALE','ORL'}))
        text=[text ' Configure NB_SETUP_PATHS or NB_USER_CONFIG.m; do not edit frozen SU source.'];
    elseif strcmp(dataset,'COIL20')
        text=[text ' Configure coilPath in NB_SETUP_PATHS or NB_USER_CONFIG.m.'];
    end
end
