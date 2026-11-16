function varargout=SMP_IO(action,varargin)
% Atomic local output and exact resume signatures; no network access.
    switch action
        case 'hash'
            varargout{1}=digest(getByteStreamFromArray(varargin{1}));
        case 'filehash'
            f=fopen(varargin{1},'rb');assert(f>=0,'SMP:Read','Cannot open file.');
            cleanup=onCleanup(@() fclose(f)); %#ok<NASGU>
            varargout{1}=digest(fread(f,Inf,'*uint8'));
        case 'sources'
            root=varargin{1}; folders={root,fullfile(root,'vendor')}; rows={};
            for j=1:numel(folders)
                fs=dir(fullfile(folders{j},'*.m'));
                for k=1:numel(fs)
                    file=fullfile(folders{j},fs(k).name);
                    if j==1,name=fs(k).name;else,name=['vendor/' fs(k).name];end
                    rows(end+1,:)={name,SMP_IO('filehash',file)}; %#ok<AGROW>
                end
            end
            rows=sortrows(rows,1);
            varargout{1}=cell2table(rows,'VariableNames',{'File','SHA256'});
            varargout{2}=SMP_IO('hash',rows);
        case 'savemat'
            file=varargin{1};payload=varargin{2};parent=fileparts(file);
            if ~isfolder(parent),mkdir(parent);end
            tmp=[tempname(parent) '.mat'];
            cleanup=onCleanup(@() remove_file(tmp)); %#ok<NASGU>
            save(tmp,'payload','-v7.3');
            [ok,msg]=movefile(tmp,file,'f');assert(ok,'SMP:Commit','%s',msg);
        case 'loadmat'
            z=load(varargin{1},'payload');assert(isfield(z,'payload'),'SMP:Cache','Invalid cache.');
            varargout{1}=z.payload;
        case 'csv'
            file=varargin{1};T=varargin{2};parent=fileparts(file);
            if ~isfolder(parent),mkdir(parent);end
            tmp=[tempname(parent) '.csv'];
            cleanup=onCleanup(@() remove_file(tmp)); %#ok<NASGU>
            writetable(T,tmp,'Encoding','UTF-8');
            [ok,msg]=movefile(tmp,file,'f');assert(ok,'SMP:Commit','%s',msg);
        case 'text'
            file=varargin{1};s=varargin{2};parent=fileparts(file);
            if ~isfolder(parent),mkdir(parent);end
            tmp=[tempname(parent) '.txt'];
            f=fopen(tmp,'w','n','UTF-8');assert(f>=0,'SMP:Write','Cannot write %s',tmp);
            fprintf(f,'%s',s);fclose(f);
            [ok,msg]=movefile(tmp,file,'f');assert(ok,'SMP:Commit','%s',msg);
        case 'lock'
            folder=varargin{1};lockdir=fullfile(folder,'.sample_run_lock');
            jf=javaObject('java.io.File',lockdir);
            assert(jf.mkdir(),'SMP:Locked', ...
                ['Output directory is locked. Do not start two writers. If MATLAB crashed, ' ...
                 'verify no run is active, then remove %s manually.'],lockdir);
            SMP_IO('text',fullfile(lockdir,'owner.txt'),sprintf('PID=%d\nStarted=%s\n',feature('getpid'),datestr(now,30)));
            varargout{1}=onCleanup(@() release_lock(lockdir));
        otherwise,error('SMP:IO','Unknown IO action: %s',action);
    end
end

function h=digest(bytes)
    md=javaMethod('getInstance','java.security.MessageDigest','SHA-256');
    md.update(typecast(uint8(bytes(:)),'int8'));
    b=typecast(md.digest(),'uint8');
    h=lower(reshape(dec2hex(b,2).',1,[]));
end
function remove_file(file)
    if isfile(file),delete(file);end
end
function release_lock(folder)
    if isfolder(folder),rmdir(folder,'s');end
end
