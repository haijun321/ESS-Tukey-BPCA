function report=NB_A_ACC_REPLAY(mode)
% Reevaluate saved A bases with the frozen NB_EVALUATE endpoint protocol.
% Place this file outside the original source tree (or inside outputRoot).
% NB_A_ACC_REPLAY('selftest') checks a tiny known-label fixture.
% NB_A_ACC_REPLAY() evaluates initial and final checkpoints only.
% NB_A_ACC_REPLAY('all') evaluates all checkpoints and can take much longer.
% No solver is called and no original fit, protocol, CSV or source is edited.
    if nargin<1,mode='endpoints';end
    mode=lower(char(mode));
    assert(any(strcmp(mode,{'selftest','endpoints','all'})), ...
        'NB:ReplayMode','Use selftest, endpoints, or all.');
    C=NB_BOOTSTRAP();
    sourceFile=java.io.File(C.nbRoot);src=char(sourceFile.getCanonicalPath());
    thisFile=java.io.File([mfilename('fullpath') '.m']);here=char(thisFile.getCanonicalPath());
    outputFile=java.io.File(C.outputRoot);output=char(outputFile.getCanonicalPath());
    inSource=startsWith(lower(here),[lower(src) filesep]);
    inOutput=startsWith(lower(here),[lower(output) filesep]);
    assert(~inSource||inOutput,'NB:ReplayLocation', ...
        'Move this tool outside the frozen source tree or into outputRoot before running.');
    if strcmp(mode,'selftest'),report=fixture();disp(report);return;end
    window=fullfile(C.outputRoot,'paper','windowA');
    assert(~isfile(fullfile(window,'WINDOW_RUNNING.lock')), ...
        'NB:ReplayRunning','Wait until the A task has stopped.');
    p=P0_IO('load',fullfile(window,'protocol.mat'));
    [sourceHash,~]=NB_SOURCE_HASH(C);
    assert(strcmp(sourceHash,p.protocol.sourceHash),'NB:ReplaySource', ...
        'The frozen source differs from the fitted source. Restore the original FIX2 source.');
    fs=dir(fullfile(window,'fits','*','fit.mat'));
    assert(numel(fs)==160,'NB:ReplayPlan','This A audit expects the complete 160-fit plan.');
    folder=fullfile(C.outputRoot,['posthoc_A_ACC_native_' datestr(now,'yyyymmddTHHMMSS')]);
    mkdir(folder);
    rows=repmat(row_template(),0,1);lastKey='';D=[];done=0;
    for i=1:numel(fs)
        s=P0_IO('load',fullfile(fs(i).folder,fs(i).name));r=s.record;
        if strcmp(r.Dataset,'SYN'),continue;end
        assert(any(strcmp(r.Dataset,{'YALE','ORL'}))&&any(strcmp(r.Method,{'C1','C2','C3','C4'})), ...
            'NB:ReplayScope','Unexpected dataset or method.');
        assert(strcmp(r.SourceHash,sourceHash),'NB:ReplaySource','Fit source hash differs.');
        key=sprintf('%s|%d',r.Dataset,r.Repeat);
        if ~strcmp(key,lastKey)
            D=SU_DATA(C,r.Dataset,r.Repeat);D.evaluation='real';lastKey=key;
        end
        assert(strcmp(D.dataHash,s.metadata.dataHash),'NB:ReplayData','Data hash differs.');
        assert(strcmp(D.S.hash,s.metadata.split.hash)&& ...
            isequal(D.S.gallery,s.metadata.split.gallery)&&isequal(D.S.probe,s.metadata.split.probe), ...
            'NB:ReplaySplit','Gallery/probe split differs.');
        % NB_EVALUATE uses K.X only for image dimensions in the real-data branch.
        K=struct('X',zeros(size(D.gallery,1),size(D.gallery,2),1));
        cp=s.model.checkpoints;
        if strcmp(mode,'all'),ix=1:numel(cp);else,ix=unique([1 numel(cp)]);end
        for q=ix
            model=struct('U',cp(q).U,'V',cp(q).V);
            if isfield(s.model,'mean'),model.mean=s.model.mean;end
            Z=NB_EVALUATE(K,D,model,[]);
            t=row_template();t.Dataset=r.Dataset;t.Condition=r.Condition;t.Repeat=r.Repeat;
            t.Method=r.Method;t.Outer=cp(q).Outer;t.NativeNRE=Z.NRE;t.NativeACC=Z.ACC;
            t.SourceHash=sourceHash;t.DataHash=D.dataHash;t.SplitHash=D.S.hash;
            old=find([s.checkpointMetrics.Outer]==cp(q).Outer,1);
            if ~isempty(old),t.LegacyCheckpointACC=s.checkpointMetrics(old).ACC;end
            t.Terminal=q==numel(cp);
            if t.Terminal
                assert(norm(cp(q).U-s.model.U,'fro')<1e-12&& ...
                    norm(cp(q).V-s.model.V,'fro')<1e-12,'NB:ReplayBasis','Final bases differ.');
                t.StoredRecordNRE=r.NRE;t.StoredRecordACC=r.ACC;
                t.EndpointNREMatches=abs(Z.NRE-r.NRE)<=1e-10*max(1,abs(r.NRE));
                t.EndpointACCMatches=abs(Z.ACC-r.ACC)<=1e-12;
            end
            rows(end+1,1)=t; %#ok<AGROW>
        end
        done=done+1;
        if mod(done,10)==0,fprintf('Native ACC replay: %d / 80 saved real fits evaluated.\n',done);end
    end
    assert(done==80,'NB:ReplayPlan','Expected 80 real-data fits.');
    T=struct2table(rows,'AsArray',true);
    writetable(T,fullfile(folder,'native_checkpoint_replay.csv'));
    terminal=T(T.Terminal,:);initial=T(T.Outer==0,:);
    assert(height(terminal)==80,'NB:ReplayPlan','Terminal rows missing.');
    pairs=initial(:,{'Dataset','Condition','Repeat','Method','NativeNRE','NativeACC'});
    pairs.Properties.VariableNames(end-1:end)={'InitialNRE','InitialACC'};
    endpoint=terminal(:,{'Dataset','Condition','Repeat','Method','NativeNRE','NativeACC'});
    endpoint.Properties.VariableNames(end-1:end)={'FinalNRE','FinalACC'};
    pairs=innerjoin(pairs,endpoint,'Keys',{'Dataset','Condition','Repeat','Method'});
    pairs.FinalMinusInitialNRE=pairs.FinalNRE-pairs.InitialNRE;
    pairs.FinalMinusInitialACC=pairs.FinalACC-pairs.InitialACC;
    writetable(pairs,fullfile(folder,'native_initial_vs_final.csv'));
    report=struct('Mode',mode,'RealFits',done,'Rows',height(T), ...
        'EndpointNREMatches',all(terminal.EndpointNREMatches==1), ...
        'EndpointACCMatches',all(terminal.EndpointACCMatches==1), ...
        'LegacyTerminalACCMismatches',sum(abs(terminal.NativeACC-terminal.LegacyCheckpointACC)>1e-12), ...
        'MaximumLegacyACCDifference',max(abs(terminal.NativeACC-terminal.LegacyCheckpointACC)), ...
        'SourceHash',sourceHash,'ReplayToolHash',P0_IO('hashfile',[mfilename('fullpath') '.m']), ...
        'MetricProtocol','NB_EVALUATE_native_bases_no_extra_orth_gallery_zscore', ...
        'ScientificFitsExecuted',0,'OutputDirectory',folder,'Generated',datestr(now,30));
    report.Ready=report.EndpointNREMatches&&report.EndpointACCMatches;
    save(fullfile(folder,'ACC_REPLAY_REPORT.mat'),'report','-v7');
    fid=fopen(fullfile(folder,'ACC_REPLAY_REPORT.json'),'w');assert(fid>=0);g=onCleanup(@()fclose(fid));
    fprintf(fid,'%s',jsonencode(report));clear g;
    disp(report);
    fprintf('Upload this posthoc audit folder: %s\n',folder);
end

function r=row_template()
    r=struct('Dataset','','Condition','','Repeat',0,'Method','','Outer',0, ...
        'NativeNRE',NaN,'NativeACC',NaN,'LegacyCheckpointACC',NaN,'Terminal',false, ...
        'StoredRecordNRE',NaN,'StoredRecordACC',NaN,'EndpointNREMatches',NaN, ...
        'EndpointACCMatches',NaN,'SourceHash','','DataHash','','SplitHash','');
end

function report=fixture()
    % Known-label separable images entirely inside the supplied subspace.
    p=8;q=6;U=eye(p,2);V=eye(q,2);
    A=[1 0;0 .3];B=[0 1;.3 0];X=zeros(p,q,4);
    X(:,:,1)=U*A*V';X(:,:,2)=U*(1.01*A)*V';
    X(:,:,3)=U*B*V';X(:,:,4)=U*(1.01*B)*V';
    D=struct('evaluation','real','gallery',X,'galleryLabels',[1;1;2;2], ...
        'probe',X(:,:,[2 1 4 3]),'probeLabels',[1;1;2;2], ...
        'cfg',struct('classifier',struct('zscoreFeatures',true)));
    K=struct('X',zeros(p,q,1));model=struct('U',U,'V',V);
    Z=NB_EVALUATE(K,D,model,[]);
    assert(Z.ACC==1&&Z.NRE<1e-12,'NB:ReplayFixture','Native evaluator fixture failed.');
    report=struct('Pass',true,'EngineeringOnly',true,'KnownLabelAccuracy',Z.ACC,'NRE',Z.NRE);
end
