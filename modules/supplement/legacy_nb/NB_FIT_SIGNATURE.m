function signature=NB_FIT_SIGNATURE(protocolHash,K,D,A,job)
% Persisted identity depends on actual inputs/references, not their location.
    dep=struct('algorithm',A,'rank',K.rank);
    for f={'dataHash','splitHash','cfg','protocol'}
        if isfield(D,f{1}),dep.(f{1})=D.(f{1});end
    end
    signature=P0_IO('hashtext',[protocolHash K.caseHash K.initHash jsonencode(job) jsonencode(dep)]);
end
