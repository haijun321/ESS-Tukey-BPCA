function SMP_PACKAGE_RESULTS(C)
% Small review bundle. Full data blocks/models remain in the local output tree.
    files={};root=C.outputRoot;
    top={'protocol.mat','protocol.json','source_hashes.csv','selfcheck.txt','console_log.txt'};
    for j=1:numel(top)
        if isfile(fullfile(root,top{j})),files{end+1}=top{j};end %#ok<AGROW>
    end
    for p={'precheck','formal'}
        phase=p{1};names={'fit_records.csv','sample_records.csv','initialization_records.csv'};
        for j=1:numel(names)
            rel=fullfile(phase,names{j});if isfile(fullfile(root,rel)),files{end+1}=rel;end %#ok<AGROW>
        end
        fs=dir(fullfile(root,phase,'summary','*'));
        for j=1:numel(fs)
            if ~fs(j).isdir,files{end+1}=fullfile(phase,'summary',fs(j).name);end %#ok<AGROW>
        end
    end
    if isempty(files),return;end
    readme=['Review bundle: summaries and sample-level records only.' newline ...
        'Full generated arrays, fitted bases and optimization traces remain under cases/ and fits/.' newline ...
        'Keep the complete local results directory for replay; this bundle is not the full fit archive.' newline];
    SMP_IO('text',fullfile(root,'REVIEW_BUNDLE_README.txt'),readme);
    files{end+1}='REVIEW_BUNDLE_README.txt';
    tmp=[tempname(root) '.zip'];target=fullfile(root,'sample_results_for_review.zip');
    zip(tmp,files,root);[ok,msg]=movefile(tmp,target,'f');assert(ok,'SMP:Bundle','%s',msg);
end
