function [jobs,suffix]=NB_SCOPE_JOBS(C,jobs)
    suffix='';
    switch C.scope
        case 'all'
        case 'synthetic',jobs=jobs(strcmp({jobs.Dataset},'SYN'));suffix='_SYN';
        case 'real',jobs=jobs(~strcmp({jobs.Dataset},'SYN'));suffix='_REAL';
        otherwise,error('NB:Scope','Unknown scope');
    end
    assert(~isempty(jobs),'NB:EmptyScope','No tasks in this window for scope %s',C.scope);
end
