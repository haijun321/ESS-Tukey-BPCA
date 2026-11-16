function report=START_HERE(options)
% Numerical tests do not imply data readiness or method superiority.
    if nargin<1,options=struct();end
    C=NB_BOOTSTRAP(options);
    fprintf('\nTukey BPCA supplements: engineering self-tests\n');
    report=struct();report.Original=P0_SELFTEST(C);
    report.Trace=NB_TRACE_SELFTEST();report.RA=NB_RA_SELFTEST();
    report.COIL=NB_COIL_SELFTEST();report.Summary=NB_SUMMARY_SELFTEST();
    report.Pipeline=NB_PIPELINE_SELFTEST();
    report.DependencyChecks=NB_PREFLIGHT_SELFTEST();
    report.PathSettings=NB_PATHS_SELFTEST();
    report.ExecutionControls=NB_CONTROL_SELFTEST();
    for dims={[40 30],[121 160],[112 92],[64 64]}
        for level=C.raDimensionFactors
            [r,c,k]=NB_DIMENSION_PAIR(dims{1}(1),dims{1}(2),level);
            assert(r*c==dims{1}(1)*k,'NB:Dimension','Feature budget mismatch');
        end
    end
    report.Pass=true;report.EngineeringOnly=true;report.MATLABVersion=version;
    report.Computer=computer;report.Generated=datestr(now,30);
    [report.SourceHash,~]=NB_SOURCE_HASH(C);
    P0_IO('mkdir',C.outputRoot);
    report.DataReadiness=CHECK_READY(options);
    tmp=[tempname(C.outputRoot) '.mat'];save(tmp,'report','-v7');
    movefile(tmp,fullfile(C.outputRoot,'MATLAB_SELFTEST_PASS.mat'),'f');
    fprintf('\nNUMERICAL SELFTEST PASS. Data readiness is reported separately.\n');
    fprintf('PLAN_ONLY reports exact task counts. Pilot and paper use separate folders.\n');
end
