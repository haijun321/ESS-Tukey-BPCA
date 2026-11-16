function P0_SUMMARIZE_ALL(C)
    f=dir(C.outputRoot);
    for k=1:numel(f)
        if ~f(k).isdir||strcmp(f(k).name,'.')||strcmp(f(k).name,'..'),continue;end
        module=f(k).name;file=fullfile(C.outputRoot,module,'protocol.mat');
        if ~exist(file,'file'),continue;end
        p=P0_IO('load',file);cfg=p.protocol.config;cfg.makePlots=C.makePlots;cfg.exportTIFF=C.exportTIFF;
        if strcmp(module,'tune_real')
            a=dir(fullfile(C.outputRoot,module,'evaluations','*.mat'));R=repmat(struct(),0,1);
            for j=1:numel(a)
                z=P0_IO('load',fullfile(a(j).folder,a(j).name));
                if isempty(R),R=z.records;else,R=[R z.records];end %#ok<AGROW>
            end
            P0_SUMMARIZE(cfg,module,R,p.protocol.context);
        else,P0_SUMMARIZE(cfg,module);end
    end
end
