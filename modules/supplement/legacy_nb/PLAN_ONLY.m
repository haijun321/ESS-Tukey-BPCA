function PLAN_ONLY(options)
    if nargin<1,options=struct();end
    C=NB_BOOTSTRAP(options);
    fprintf('Formal plan: final-fit records; tuning candidates are ADDITIONAL computation.\n');
    for w='ABCDE'
        jobs=NB_JOBS(C,w,'paper');
        if strcmp(C.scope,'synthetic'),jobs=jobs(strcmp({jobs.Dataset},'SYN'));
        elseif strcmp(C.scope,'real'),jobs=jobs(~strcmp({jobs.Dataset},'SYN'));end
        if isempty(jobs),continue;end
        calls=0;
        for i=1:numel(jobs)
            m=jobs(i).Method;syn=strcmp(jobs(i).Dataset,'SYN');
            if strcmp(m,'TunedC'),n=numel(C.cGrid)+syn;
            elseif strcmp(m,'TunedEta'),n=numel(C.etaGrid)+syn;
            elseif strcmp(m,'RA2DPCA_dev')||startsWith(m,'RA_dim'),n=numel(C.raLambdaGrid)+syn;
            else,n=1;end
            calls=calls+n;
        end
        fprintf('Window %s: %d records; SYN=%d, REAL=%d; planned solver calls=%d\n',w,numel(jobs), ...
            sum(strcmp({jobs.Dataset},'SYN')),sum(~strcmp({jobs.Dataset},'SYN')),calls);
    end
    fprintf('A: run alone for timing. B/C/D/E: fixed iteration limits, no wall-time stopping.\n');
end
