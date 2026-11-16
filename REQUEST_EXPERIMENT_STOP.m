function flag = REQUEST_EXPERIMENT_STOP(module, outputRoot)
%REQUEST_EXPERIMENT_STOP Request a safe stop after the active unit of work.
% REQUEST_EXPERIMENT_STOP('sample')
% REQUEST_EXPERIMENT_STOP('core','D:\TukeyResults\p0_core')
% Remove the returned flag before restarting. This does not kill MATLAB.
    if nargin < 1, module = 'sample'; end
    root = fileparts(mfilename('fullpath'));
    module = lower(char(module));
    switch module
        case 'sample'
            tag = 'sample_extension'; name = 'STOP_SAMPLE.txt';
        case 'core'
            tag = 'p0_core'; name = 'REQUEST_STOP.flag';
        case 'supplement'
            tag = 'supplement'; name = 'REQUEST_STOP.flag';
        otherwise
            error('TUKEY:Stop','Use sample, core or supplement.');
    end
    if nargin < 2 || isempty(outputRoot), outputRoot = fullfile(root,'results',tag); end
    outputRoot = char(outputRoot);
    assert(isfolder(outputRoot),'TUKEY:Stop','The selected outputRoot does not exist.');
    flag = fullfile(outputRoot,name);
    fid = fopen(flag,'w');
    assert(fid >= 0,'TUKEY:Stop','Could not create the stop flag.');
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'Stop requested at %s\n',datestr(now,30));
    fprintf('Stop requested: %s\nRemove this file before resuming.\n',flag);
end
