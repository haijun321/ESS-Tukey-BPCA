function report=CSSP_SETUP_ROMPCA(action,C)
% Explicit, separate setup. Scientific runs never download/install software.
% CSSP_SETUP_ROMPCA('download', C) downloads the inspected original source.
% CSSP_SETUP_ROMPCA('install', C) explicitly installs original R dependencies.
% CSSP_SETUP_ROMPCA('check', C) checks source pin and R dependency readiness.
    if nargin<1,action='check';end
    if nargin<2,C=struct();end
    root=fileparts(mfilename('fullpath'));folder=fullfile(root,'external_original');
    source=get(C,'rompcaSource','');if isempty(source),source=fullfile(folder,'ROMPCA_Code_JCGS.R');end
    expectedZip='4b28e46b76257bbc6e71da9319b4014f05c41d69a049eaab1a146d14111f177b';
    expectedSource='e0817d038ce9da2754228e7a875b2b5004fb103295675650f45c72527883e171';
    switch lower(char(action))
        case 'download'
            if ~isfolder(folder),mkdir(folder);end
            if exist(source,'file')==2
                assert(strcmpi(hash_file(source),expectedSource),'CSSP:ROMPCASource','Existing source differs; do not overwrite it automatically.');
            else
                work=tempname;mkdir(work);clean=onCleanup(@()rmdir(work,'s'));
                zipPath=fullfile(work,'Code_ROMPCA.zip');
                websave(zipPath,'https://fabiocentofanti.github.io/files/Code_ROMPCA.zip',weboptions('Timeout',60));
                assert(strcmpi(hash_file(zipPath),expectedZip),'CSSP:ROMPCASource','Official ZIP changed; review new author release before changing the source pin.');
                unzip(zipPath,work);original=fullfile(work,'ROMPCA_Code_JCGS.R');
                assert(exist(original,'file')==2&&strcmpi(hash_file(original),expectedSource), ...
                    'CSSP:ROMPCASource','Original R source does not match inspected version.');
                parent=fileparts(source);if ~isfolder(parent),mkdir(parent);end
                copyfile(original,source);clear clean;
            end
            report=struct('Status','ORIGINAL_SOURCE_DOWNLOADED','Source',source,'SHA256',expectedSource);
        case 'install'
            if ~isfolder(folder),mkdir(folder);end
            % Resolve Rscript without changing the R or MATLAB environment.
            if ~isfield(C,'rompcaSource')||isempty(C.rompcaSource),C.rompcaSource=source;end
            ready=CSSP_EXTERNAL_CHECK('ROMPCA',C);
            assert(~isempty(ready.Rscript),'CSSP:MissingR','Install R or set C.rscriptPath before installing packages.');
            work=tempname;mkdir(work);clean=onCleanup(@()rmdir(work,'s'));
            bridge=fullfile(root,'CSSP_ROMPCA_BRIDGE.R');
            cmd=[quote_arg(ready.Rscript) ' --vanilla ' quote_arg(bridge) ' install ' quote_arg(source) ...
                ' ' quote_arg(work) ' ' quote_arg(ready.Library) ' 2>&1'];
            [status,log]=system(cmd);fprintf('%s\n',log);
            assert(status==0,'CSSP:RInstall','R package installation failed; see preceding log.');
            report=CSSP_EXTERNAL_CHECK('ROMPCA',C);clear clean;
        case 'check'
            report=CSSP_EXTERNAL_CHECK('ROMPCA',C);
        otherwise,error('CSSP:SetupAction','Use download, install or check.');
    end
    disp(report);
end
function h=hash_file(path)
    f=fopen(path,'r');assert(f>=0,'CSSP:ExternalIO','Cannot read source');c=onCleanup(@()fclose(f));b=fread(f,Inf,'*uint8');
    md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(b(:),'int8'));
    h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));clear c;
end
function s=quote_arg(s)
    s=char(s);assert(~any(s==char(0)|s==char(10)|s==char(13)),'CSSP:CommandPath','Invalid command argument');
    if ispc,assert(~any(s=='"'|s=='%'|s=='!'),'CSSP:CommandPath','Unsupported shell character in Windows path');s=['"' s '"'];
    else,a=char(39);s=[a strrep(s,a,[a char(34) a char(34) a]) a];end
end
function v=get(s,k,f)
    if isfield(s,k),v=s.(k);else,v=f;end
end
