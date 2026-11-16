% Request a stop AFTER the current fit. Remove STOP_SAMPLE.txt before resuming.
sample_extension_stop(fileparts(mfilename('fullpath')));

function sample_extension_stop(root)
    previousPath=path;
    restorePath=onCleanup(@() path(previousPath)); %#ok<NASGU>
    addpath(root,'-begin'); C=SMP_CONFIG();
    if ~isfolder(C.outputRoot),mkdir(C.outputRoot);end
    f=fopen(fullfile(C.outputRoot,'STOP_SAMPLE.txt'),'w');
    assert(f>=0,'SMP:StopFile','Cannot write stop request.');
    fprintf(f,'Stop requested at %s\n',datestr(now,30)); fclose(f);
    fprintf('Stop requested. The running fit will finish before stopping.\n');
end
