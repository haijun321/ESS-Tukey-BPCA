function reports=CHECK_READY(options)
% Show dependencies separately from engineering selftests; no scientific fits.
    if nargin<1,options=struct();end
    C=NB_BOOTSTRAP(options);reports=struct();
    for w='ABCDE'
        jobs=NB_JOBS(C,w,'paper');
        if strcmp(C.scope,'synthetic'),jobs=jobs(strcmp({jobs.Dataset},'SYN'));
        elseif strcmp(C.scope,'real'),jobs=jobs(~strcmp({jobs.Dataset},'SYN'));end
        if isempty(jobs),continue;end
        q=NB_PREFLIGHT(C,jobs,'basic');reports.(w)=q;
        fprintf('Window %s / %s: %d ready, %d BLOCKED, %d planned\n',w,C.scope,q.ReadyCount,q.BlockedCount,q.PlannedTasks);
        if ~q.AllReady
            r=q.Rows(~[q.Rows.Ready]);why=unique({r.Reason});
            for i=1:numel(why),fprintf('  %s\n',why{i});end
        end
    end
end
