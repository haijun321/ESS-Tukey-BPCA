function RUN_ALL_SUMMARIES(stage,options)
    if nargin<1,stage='paper';end
    if nargin<2,options=struct();end
    C=NB_BOOTSTRAP(options);
    locks=dir(fullfile(C.outputRoot,stage,'window*','WINDOW_RUNNING.lock'));
    assert(isempty(locks),'NB:Running','Wait for windows to finish before combined summary.');
    NB_SUMMARIZE(C.outputRoot,stage);
    NB_PLOTS(C.outputRoot,stage);
end
