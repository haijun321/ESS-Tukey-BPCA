function R=CSSP_EXTERNAL_CHECK(method,C)
% Dependency checks only. No downloads, package installation or scientific fits.
    R=check_dependencies(method,C);R.Reason=R.Message;R.SourceHash=R.SourceSHA256;
    if isfield(R,'RuntimeFingerprint')&&~isempty(R.RuntimeFingerprint)
        R.SourceHash=hash_bytes(uint8([R.SourceSHA256 ':' R.RuntimeFingerprint]));
    end
    if isfield(R,'DependencyHashes')&&~isempty(R.DependencyHashes)
        R.SourceHash=hash_bytes(uint8(unicode2native([R.SourceHash ':' jsonencode(R.DependencyHashes)],'UTF-8')));
    end
    if strcmpi(method,'ROMPCA')
        R.Provenance='Original author R implementation, independently written binary bridge; source pin required.';
    elseif any(strcmpi(method,{'RA2DPCA','RA2DPCA_dev'}))
        R.Provenance='MATLAB port of author RA2DPCA R recurrence; not official MATLAB software.';
    else,R.Provenance='Configured external adapter; scientific provenance validated at fit time.';end
end
function R=check_dependencies(method,C)
    method=char(method);R=struct('Method',method,'Ready',false,'Status','BLOCKED_DEPENDENCY', ...
        'Message','','Adapter','','Source','','SourceSHA256','','Rscript','','Library','');
    root=fileparts(mfilename('fullpath'));
    switch upper(method)
        case 'L2'
            R.Ready=exist('P0_SOLVER_V2','file')==2;R.Message='Frozen P0 L2 objective reference.';
        case {'RA2DPCA','RA2DPCA_DEV'}
            R.Ready=exist('NB_RA2DPCA','file')==2&&exist('NB_RA_DIAGNOSTICS','file')==2;
            R.Message='Existing independently implemented MATLAB port, not official MATLAB source.';
        case 'ROMPCA'
            R.Source=get(C,'rompcaSource','');
            if isempty(R.Source),R.Source=fullfile(root,'external_original','ROMPCA_Code_JCGS.R');end
            R.Library=get(C,'rLibraryPath',fullfile(root,'external_original','R_library'));
            R.Rscript=resolve_rscript(get(C,'rscriptPath',''));
            if isempty(R.Rscript),R.Message='Rscript not found. Set rscriptPath or install R; see EXTERNAL_SETUP_CN.txt.';return;end
            if exist(R.Source,'file')~=2,R.Message='Official ROMPCA source is absent. Run CSSP_SETUP_ROMPCA(''download'',C).';return;end
            R.SourceSHA256=hash_file(R.Source);
            expected='e0817d038ce9da2754228e7a875b2b5004fb103295675650f45c72527883e171';
            if ~strcmpi(R.SourceSHA256,expected)
                R.Message='ROMPCA source hash differs from the inspected author version. Review the new source and update the pin explicitly.';return;
            end
            work=tempname;mkdir(work);cleanup=onCleanup(@()rmdir(work,'s'));
            bridge=fullfile(root,'CSSP_ROMPCA_BRIDGE.R');
            cmd=[quote_arg(R.Rscript) ' --vanilla ' quote_arg(bridge) ' check ' quote_arg(R.Source) ...
                ' ' quote_arg(work) ' ' quote_arg(R.Library) ' 2>&1'];
            [status,log]=system(cmd);R.Ready=status==0;R.RuntimeFingerprint='';
            if R.Ready,R.RuntimeFingerprint=hash_bytes(uint8(unicode2native(log,'UTF-8')));end
            if R.Ready,R.Message='Official source hash and R dependencies available. A pilot fit is still required.';
            else,R.Message=['R dependency check failed: ' log];end
            clear cleanup;
        otherwise
            adapters=get(C,'externalAdapters',struct());
            if isstruct(adapters)&&isfield(adapters,method),R.Adapter=adapters.(method);end
            if isempty(R.Adapter)&&strcmp(get(C,'externalName',''),method),R.Adapter=get(C,'externalAdapter','');end
            if isempty(R.Adapter)
                R.Message=['No verified ' method ' adapter configured. No substitute algorithm will be used.'];return;
            end
            if isa(R.Adapter,'function_handle'),p=which(func2str(R.Adapter));else,p=which(char(R.Adapter));end
            if isempty(p),R.Message='Configured adapter is not on the MATLAB path.';return;end
            R.Source=p;R.SourceSHA256=hash_file(p);
            deps=get(C,'externalDependencies',{});
            if isstruct(deps)
                if isfield(deps,method),deps=deps.(method);else,deps={};end
            end
            if isstring(deps),deps=cellstr(deps);end
            R.DependencyHashes=cell(numel(deps),2);
            for k=1:numel(deps)
                if exist(deps{k},'file')~=2,R.Message=['External dependency absent: ' deps{k}];return;end
                R.DependencyHashes(k,:)={deps{k},hash_file(deps{k})};
            end
            R.Ready=true;R.Message='Configured adapter exists; ranks/provenance are checked at fit time.';
    end
    if R.Ready,R.Status='DEPENDENCIES_FOUND_NOT_A_FIT_VALIDATION';end
end
function p=resolve_rscript(p)
    if ~isempty(p)
        if exist(p,'file')~=2,p='';end
        return;
    end
    if ispc
        roots={getenv('ProgramFiles'),getenv('ProgramW6432')};files=[];
        for j=1:numel(roots)
            if ~isempty(roots{j}),files=[files;dir(fullfile(roots{j},'R','R-*','bin','Rscript.exe'))];end %#ok<AGROW>
        end
        if ~isempty(files),[~,ix]=sort({files.folder});f=files(ix(end));p=fullfile(f.folder,f.name);return;end
        [status,out]=system('where Rscript 2>nul');
    else,[status,out]=system('command -v Rscript 2>/dev/null');end
    if status==0,lines=regexp(strtrim(out),'\r?\n','split');p=strtrim(lines{1});else,p='';end
end
function h=hash_file(path)
    f=fopen(path,'r');assert(f>=0,'CSSP:ExternalIO','Cannot read source');c=onCleanup(@()fclose(f));b=fread(f,Inf,'*uint8');
    h=hash_bytes(b);clear c;
end
function h=hash_bytes(b)
    md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(uint8(b(:)),'int8'));
    h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
function s=quote_arg(s)
    s=char(s);assert(~any(s==char(0)|s==char(10)|s==char(13)),'CSSP:CommandPath','Invalid command argument');
    if ispc,assert(~any(s=='"'|s=='%'|s=='!'),'CSSP:CommandPath','Unsupported shell character in Windows path');s=['"' s '"'];
    else,a=char(39);s=[a strrep(s,a,[a char(34) a char(34) a]) a];end
end
function v=get(s,k,f)
    if isfield(s,k),v=s.(k);else,v=f;end
end
