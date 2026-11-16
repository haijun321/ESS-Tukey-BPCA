function varargout=SMPV_P0_IO(action,varargin)
    switch action
        case {'save','load','write','mkdir','hashtext','hashnumeric','hashfile','checkstop'}
            [varargout{1:nargout}]=SMPV_SU_UTIL(action,varargin{:});
        case 'sources'
            root=varargin{1};f=[dir(fullfile(root,'*.m'));dir(fullfile(root,'frozen','*.m'))];
            a=cell(numel(f),2);
            for k=1:numel(f)
                p=fullfile(f(k).folder,f(k).name);rel=p(numel(root)+2:end);
                a(k,:)={strrep(rel,'\','/'),SMPV_SU_UTIL('hashfile',p)};
            end
            [~,ix]=sort(a(:,1));varargout{1}=a(ix,:);
        case 'freeze'
            C=varargin{1};module=varargin{2};context=varargin{3};
            sources=SMPV_P0_IO('sources',C.packageRoot);sh=SMPV_P0_IO('hashtext',jsonencode(sources));
            SMPV_P0_IO('mkdir',C.outputRoot);manifest=fullfile(C.outputRoot,'source_manifest.mat');
            if exist(manifest,'file')
                old=SMPV_P0_IO('load',manifest);
                assert(strcmp(old.hash,sh),'P0:ChangedSource','Source changed; use a NEW outputRoot.');
            else,SMPV_P0_IO('save',manifest,struct('hash',sh,'sources',{sources}));end
            protocol=struct('config',C,'module',module,'context',context,'sourceHash',sh);
            h=SMPV_P0_IO('hashtext',jsonencode(protocol));d=fullfile(C.outputRoot,module);SMPV_P0_IO('mkdir',d);
            file=fullfile(d,'protocol.mat');
            if exist(file,'file')
                old=SMPV_P0_IO('load',file);
                assert(strcmp(old.hash,h),'P0:ChangedProtocol','Module settings changed; use a NEW outputRoot.');
            else,SMPV_P0_IO('save',file,struct('hash',h,'protocol',protocol));end
            SMPV_P0_IO('csv',fullfile(d,'source_hashes.csv'),{'File','SHA256'},sources);
            SMPV_P0_IO('csv',fullfile(d,'trace_codes.csv'),{'Column','Code','Meaning'},SMPV_P0_TRACE_CODES());
            varargout{1}=h;
        case 'csv'
            SMPV_SU_CSV(varargin{:});
        otherwise,error('P0:IO','Unknown IO action.');
    end
end
