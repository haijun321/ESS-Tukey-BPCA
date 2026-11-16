function varargout=SU_UTIL(action,varargin)
    switch action
        case 'mkdir'
            if ~exist(varargin{1},'dir'),[ok,msg]=mkdir(varargin{1});assert(ok,'SU:IO','%s',msg);end
        case 'load'
            z=load(varargin{1});
            if isfield(z,'payload'),varargout{1}=z.payload;
            else,f=fieldnames(z);assert(numel(f)==1,'SU:Schema','Ambiguous MAT: %s',varargin{1});varargout{1}=z.(f{1});end
        case 'save'
            file=varargin{1};payload=varargin{2};d=fileparts(file);SU_UTIL('mkdir',d);
            assert(~exist(file,'file'),'SU:Overwrite','Committed file exists: %s',file);
            tmp=[tempname(d) '.mat'];g=onCleanup(@()cleanup(tmp));
            if exist('OCTAVE_VERSION','builtin'),save(tmp,'payload','-mat7-binary');else,save(tmp,'payload','-v7.3');end
            [ok,msg]=movefile(tmp,file);assert(ok,'SU:IO','%s',msg);clear g;
        case 'write'
            file=varargin{1};d=fileparts(file);SU_UTIL('mkdir',d);tmp=[tempname(d) '.txt'];g=onCleanup(@()cleanup(tmp));
            fid=fopen(tmp,'w');assert(fid>=0,'SU:IO','Cannot write');fprintf(fid,'%s',varargin{2});fclose(fid);
            [ok,msg]=movefile(tmp,file,'f');assert(ok,'SU:IO','%s',msg);clear g;
        case 'hashtext',varargout{1}=bytes_hash(uint8(unicode2native(char(varargin{1}),'UTF-8')));
        case 'hashnumeric'
            x=varargin{1};prefix=uint8([class(x) ':' mat2str(size(x))]);
            if exist('OCTAVE_VERSION','builtin')
                if islogical(x),b=uint8(x(:));else,b=typecast(x(:),'uint8');end
                varargout{1}=bytes_hash([prefix(:);b(:)]);
            else
                md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(prefix(:),'int8'));
                for k=1:131072:numel(x)
                    a=x(k:min(numel(x),k+131071));if islogical(a),b=uint8(a);else,b=typecast(a(:),'uint8');end
                    md.update(typecast(uint8(b(:)),'int8'));
                end
                varargout{1}=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
            end
        case 'hashfile'
            fid=fopen(varargin{1},'rb');assert(fid>=0);g=onCleanup(@()fclose(fid));b=fread(fid,Inf,'*uint8');varargout{1}=bytes_hash(b);
        case 'sources'
            root=varargin{1};fs=[dir(fullfile(root,'*.m'));dir(fullfile(root,'vendor','*.m'));dir(fullfile(root,'vendor','*.csv'))];
            if isempty(fs),varargout{1}=cell(0,2);return;end
            [~,ix]=sort({fs.name});fs=fs(ix);a=cell(numel(fs),2);
            for k=1:numel(fs),a{k,1}=fs(k).name;a{k,2}=SU_UTIL('hashfile',fullfile(fs(k).folder,fs(k).name));end
            varargout{1}=a;
        case 'freeze'
            C=varargin{1};module=varargin{2};d=fullfile(C.outputRoot,module);SU_UTIL('mkdir',d);
            protocol=struct('config',C,'module',module,'sources',{SU_UTIL('sources',C.packageRoot)});
            h=SU_UTIL('hashtext',jsonencode(protocol));file=fullfile(d,'protocol.mat');
            if exist(file,'file'),p=SU_UTIL('load',file);assert(strcmp(p.hash,h),'SU:ChangedProtocol','Protocol/source changed. Use a NEW outputRoot.');
            else,SU_UTIL('save',file,struct('hash',h,'protocol',protocol));end
            varargout{1}=h;
        case 'checkstop',assert(~exist(varargin{1},'file'),'SU:StopRequested','Stop requested. Remove REQUEST_STOP.flag to resume.');
        otherwise,error('SU:Utility','Unknown utility %s',action);
    end
end
function h=bytes_hash(b)
    if exist('OCTAVE_VERSION','builtin'),h=hash('sha256',char(b(:).'));
    else,md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(uint8(b(:)),'int8'));h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));end
end
function cleanup(p)
    if exist(p,'file'),delete(p);end
end
