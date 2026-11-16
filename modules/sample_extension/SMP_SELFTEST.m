function SMP_SELFTEST(C)
% Local numerical/IO checks, not scientific experiments or model fits.
    previous=rng;restore=onCleanup(@() rng(previous)); %#ok<NASGU>
    required={'SMPV_P0_SOLVER_V2','SMPV_SU_SYN_FROZEN','SMPV_SU_STATE'};
    for j=1:numel(required)
        expected=fullfile(C.packageRoot,'vendor',[required{j} '.m']);
        assert(strcmpi(which(required{j}),expected),'SMP:Path','Unexpected function on path: %s',required{j});
    end
    assert(C.sampleWeightMin==0.20&&C.sampleWeightAlpha==0.35&&C.sampleTauC==3&& ...
        C.sampleQuantile==0.85&&C.normalDownweightThreshold==0.95, ...
        'SMP:FrozenSample','This protocol evaluates the existing .20/.35/3/Q85 sample rule.');
    tiny=C;tiny.n=20;tiny.p=10;tiny.q=8;tiny.r=3;tiny.c=2;tiny.nProbe=20;
    state=rng;D=SMP_DATA(tiny,99,'precheck');
    assert(isequaln(state,rng),'SMP:RNG','Data generator must restore the caller RNG.');
    D2=SMP_DATA(tiny,99,'precheck');assert(isequaln(D,D2),'SMP:Determinism','Data are not deterministic.');
    nc=round(tiny.n*tiny.caseRate);np=tiny.p*tiny.q;
    assert(D.cases(1).nCase==0&&D.cases(1).nCell==0,'SMP:Clean','Clean mask failed.');
    assert(D.cases(2).nCase==0&&D.cases(2).nCell==round(tiny.cellRate*tiny.n*np),'SMP:Cells','Cell-only mask failed.');
    assert(D.cases(3).nCase==nc&&nnz(D.cases(3).totalMask)==nc*np,'SMP:Cases','Case mask failed.');
    assert(D.cases(4).nCell==round(tiny.cellRate*(tiny.n-nc)*np),'SMP:Mixed','Mixed cell count failed.');
    assert(nnz(D.cases(4).totalMask)==nc*np+D.cases(4).nCell,'SMP:Union','Mixed union failed.');
    [A,M]=SMP_ALGORITHM(tiny,'precheck');rng(97531,'twister');
    E=randn(tiny.p,tiny.q,tiny.n);E(:,:,1)=20*E(:,:,1);
    [s0,~]=SMPV_SU_STATE(E,M(1),A,'synthetic',0);
    [s1,~]=SMPV_SU_STATE(E,M(2),A,'synthetic',0);
    assert(isequaln(s0.We,s1.We)&&s0.tau==s1.tau,'SMP:Factorial','Same residual must give the same element rule.');
    assert(all(s0.a==1)&&any(s1.a<1),'SMP:Switch','Sample switch is not active.');
    floorA=.20^.35;
    assert(all(s1.a>=floorA-1e-12)&&all(s1.a<=1+1e-12),'SMP:Bounds','Invalid sample coefficients.');
    ess=sum(s1.a)^2/(numel(s1.a)*sum(s1.a.^2));
    assert(ess>=4*floorA/(1+floorA)^2-1e-12,'SMP:ESSBound','Sample ESS bound failed.');
    ws=SMPV_SU_SYN_FROZEN('sampleweights',zeros(4,3,10),A);
    assert(all(ws==1),'SMP:Degenerate','Degenerate sample-score fallback failed.');
    model=struct('U',D.Atrue,'V',D.Btrue);
    S=struct('a',ones(tiny.n,1),'Ws',ones(tiny.n,1),'W',ones(size(D.X0)));
    [met,T]=SMP_METRICS(D,D.cases(1),model,S);
    assert(met.ErrSubNorm<1e-10&&met.ProbeCleanNRE<1e-10,'SMP:Oracle','True-basis metric check failed.');
    assert(isnan(met.SampleAUROC)&&isnan(met.SampleAP)&&height(T)==tiny.n,'SMP:NoPositive','No-case diagnostics must be NA.');
    tempdirLocal=tempname;mkdir(tempdirLocal);cleanup=onCleanup(@() rmdir(tempdirLocal,'s')); %#ok<NASGU>
    payload=struct('x',[1 2 3],'label','sample-selftest');f=fullfile(tempdirLocal,'io.mat');
    SMP_IO('savemat',f,payload);assert(isequaln(SMP_IO('loadmat',f),payload),'SMP:IO','MAT round trip failed.');
    f=fullfile(tempdirLocal,'io.csv');SMP_IO('csv',f,table((1:3)','VariableNames',{'Value'}));
    z=readtable(f);assert(isequal(z.Value,(1:3)'),'SMP:IO','CSV round trip failed.');
    report=sprintf(['Self-checks completed at %s\nMATLAB: %s\n' ...
        'PASS: deterministic data and restored RNG\nPASS: four contamination masks\n' ...
        'PASS: isolated sample switch\nPASS: weight range and sample ESS bound\n' ...
        'PASS: degenerate-score fallback\nPASS: true-basis metrics and no-case NA\n' ...
        'PASS: atomic MAT/CSV IO\nNo scientific model fits are counted here.\n'],datestr(now,30),version);
    SMP_IO('text',fullfile(C.outputRoot,'selfcheck.txt'),report);
    fprintf('Self-checks passed (data, switches, metrics, IO).\n');
end
