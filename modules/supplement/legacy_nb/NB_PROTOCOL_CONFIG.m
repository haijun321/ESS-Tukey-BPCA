function S=NB_PROTOCOL_CONFIG(C)
% Location changes do not change science. Actual data/reference hashes still do.
    S=C;
    fields={'archiveRoot','coilPath','outputRoot','nbRoot','packageRoot','stopFile', ...
        'allowPartial','preflightMode','requirePilotBeforePaper','requireRACheckBeforePaper'};
    for i=1:numel(fields),if isfield(S,fields{i}),S=rmfield(S,fields{i});end,end
end
