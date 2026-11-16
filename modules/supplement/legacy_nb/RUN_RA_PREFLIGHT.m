function report=RUN_RA_PREFLIGHT(options)
% Training-only activation checks; no probe, clean target or favorable-score search.
    if nargin<1,options=struct();end
    C=NB_BOOTSTRAP(options);[sh,~]=NB_SOURCE_HASH(C);
    f=fullfile(C.outputRoot,'MATLAB_SELFTEST_PASS.mat');
    assert(exist(f,'file')==2,'NB:Selftest','Run START_HERE first');
    a=load(f,'report');assert(a.report.Pass&&strcmp(a.report.SourceHash,sh),'NB:Selftest','Run START_HERE after source changes');
    folder=fullfile(C.outputRoot,'ra_preflight');P0_IO('mkdir',folder);
    [~,S]=P0_ALG(C,'synthetic');types={'sample','impulse','block_coherent'};rates=[0 .1 .1];
    seeds=[880000001 880000002];rows=struct([]);groupReady=[];
    for rep=1:numel(seeds)
        for t=1:numel(types)
            seed=seeds(rep)+t*100;rng(seed,'twister');
            d=SU_SYN_FROZEN('generate',S,rates(t),types{t},4);X=d.X;
            gamma=NB_RA_DEFAULT_GAMMA(X);k=max(1,ceil(S.r0*S.c0/S.p));healthy=false;
            for lambda=C.raLambdaGrid
                fprintf('RA preflight seed=%d type=%s lambda=%g\n',seed,types{t},lambda);
                m=NB_RA2DPCA(X,k,gamma,lambda,struct('maxOuter',C.raMaxOuter, ...
                    'tolerance',C.raTolerance,'timeLimit',Inf,'center',true));
                q=NB_RA_DIAGNOSTICS(X,m);
                good=~m.ZeroWeightDegenerate&&~q.FinalAllWeightsZero&& ...
                    ~q.FinalZeroCovariance&&q.FinalCovarianceRank>=k;
                healthy=healthy||good;
                z=struct('Seed',seed,'Type',types{t},'Lambda',lambda,'Gamma',gamma, ...
                    'NativeRank',k,'FeatureDimension',size(X,1)*k, ...
                    'InitialNonzeroFraction',q.InitialRowNonzeroFraction, ...
                    'FinalNonzeroFraction',q.FinalRowNonzeroFraction, ...
                    'FinalCovarianceRank',q.FinalCovarianceRank,'Iterations',m.iterations, ...
                    'Status',m.stopReason,'HealthyActivation',good,'ScientificResult',false);
                if isempty(rows),rows=z;else,rows(end+1)=z;end %#ok<AGROW>
            end
            groupReady(end+1)=healthy; %#ok<AGROW>
        end
    end
    report=struct('Ready',all(groupReady),'SourceHash',sh,'RAConfigHash',NB_RA_CONFIG_HASH(C), ...
        'TrainingOnly',true,'ProbeUsed',false,'LatentCleanTargetsUsed',false, ...
        'ComparisonSuperiorityAssessed',false,'Rows',rows,'CheckedAt',datestr(now,30));
    writetable(struct2table(rows,'AsArray',true),fullfile(folder,'activation_diagnostics.csv'));
    tmp=[tempname(C.outputRoot) '.mat'];save(tmp,'report','-v7');
    movefile(tmp,fullfile(C.outputRoot,'RA_PREFLIGHT.mat'),'f');
    fprintf('RA activation check Ready=%d. This does not establish competitive accuracy.\n',report.Ready);
    if ~report.Ready
        fprintf(2,'At least one training-only case has no healthy candidate. Inspect diagnostics before B/E paper.\n');
    end
end
