function report=NB_TRACE_SELFTEST()
% Small engineering-only parity check; never count these arrays as experiments.
% Requires original P0 code and frozen source folders on the MATLAB path.
    C=P0_CONFIG();C.syntheticDimensions=[18 9 7 2 2];
    C.syntheticBudget=[3 2 8];C.syntheticTimeLimit=Inf;
    [A,Syn]=P0_ALG(C,'synthetic');A.essGridSize=16;A.nbTraceEvery=2;
    C.includeFixedEtaNoZero=true;methods=P0_METHODS('core',C);
    rng(2026110501,'twister');D=SU_SYN_FROZEN('generate',Syn,.1,'block_coherent',4);
    % Generator uses X0/A/B; metric API deliberately uses explicit truth names.
    Deval=struct('Xclean',D.X0,'Atrue',D.A,'Btrue',D.B,'Delta',D.X-D.Xbase);
    [U0,V0]=SU_SYN_FROZEN('initialize',D.X,2,2,methods(3),A);
    maxError=0;
    for j=1:numel(methods)
        M=methods(j);
        [base,~]=P0_SOLVER_V2(D.X,2,2,M,A,'synthetic',U0,V0,D.mask);
        [traced,S]=NB_SOLVER_TRACE(D.X,2,2,M,A,'synthetic',U0,V0,D.mask);
        err=norm(base.U*base.U'-traced.U*traced.U','fro') ...
            +norm(base.V*base.V'-traced.V*traced.V','fro');
        maxError=max(maxError,err);
        assert(err<1e-10&&strcmp(base.status,traced.status), ...
            'NB:TraceParity','Instrumented solver changes bases or termination label.');
        assert(base.AcceptedSteps==traced.AcceptedSteps&& ...
            isequaln(base.finalTau,traced.finalTau),'NB:TraceParity','Solver decisions changed.');
        assert(norm(traced.checkpoints(1).U-U0,'fro')==0&& ...
            traced.checkpoints(1).Outer==0,'NB:InitialCheckpoint','Initial checkpoint incorrect.');
        last=traced.checkpoints(end);
        assert(last.Outer==traced.outerIters&&norm(last.U-traced.U,'fro')==0&& ...
            norm(last.V-traced.V,'fro')==0,'NB:FinalCheckpoint','Final checkpoint missing.');
        rows=NB_CHECKPOINT_METRICS(traced,D.X,'synthetic',Deval,false);
        metric=P0_METRICS(D.X,D.mask,traced,S,'synthetic',Deval);
        assert(abs(rows(end).NRE-metric.NRE)<1e-12&& ...
            abs(rows(end).ErrSubNorm-metric.ErrSubNorm)<1e-12, ...
            'NB:MetricParity','Posthoc checkpoint metrics do not match official metrics.');
        if j==3
            audit=NB_MECHANISM(struct('X',D.X),methods,A,'synthetic',traced.checkpoints);
            assert(numel(audit)<=12&&all([audit.OnObjectiveAtOn]<=[audit.OnObjectiveAtOff]+1e-9), ...
                'NB:MechanismObjective','Penalized selector does not minimize its scored candidates.');
            assert(all([audit.OffObjectiveAtOff]<=[audit.OffObjectiveAtOn]+1e-9), ...
                'NB:MechanismObjective','Unpenalized selector does not minimize target mismatch.');
            % A real-protocol preview must retain historical severity memory.
            % Complete engineering fixture for the actual real severity,
            % eta and candidate selector APIs. This is not data calibration.
            Ar=A;Ar.useSeverityMemory=true;Ar.realTailReferenceEnabled=true;
            Ar.severityMemoryMode='max';
            Ar.sampleTailQuantile=90;Ar.memoryBlockSize=50000;
            Ar.essTailK1=2.25;Ar.essTailK2=3;Ar.essTailK3=4;
            Ar.tailSeverityCap=.40;Ar.tailSeverityCleanThreshold=.002;
            Ar.essEtaDefaultClean=.99;Ar.essEtaMin=.82;Ar.essEtaMaxContam=.96;
            Ar.etaGuard=.005;Ar.essTailGamma=.65;Ar.useSampleWeight=false;
            Ar.realTail=struct('enabled',true,'baselineFeatures',[1 1 1 1],'severityThreshold',1);
            q=traced.checkpoints(1);q.Memory=.30;
            realAudit=NB_MECHANISM(struct('X',D.X),methods,Ar,'real',q);
            assert(all([realAudit.Severity]>=q.Memory)&& ...
                all([realAudit.MemoryEnteringPreview]==q.Memory), ...
                'NB:MechanismMemory','Common-state audit discarded severity memory.');
        end
    end
    report=struct('Pass',true,'EngineeringOnly',true,'Methods',numel(methods), ...
        'MaximumProjectorDifference',maxError,'CommonStateMechanismAudit',true, ...
        'RealSeverityMemoryPreserved',true,'FiniteWallCapParityClaimed',false);
    disp(report);
end
