function NB_PAPER_GATE(C,window,suffix,sourceHash,familyHash)
% Gates check engineering readiness, never whether a method wins on the probe.
    if C.requirePilotBeforePaper
        p=fullfile(C.outputRoot,'pilot',['window' window suffix],'RUN_STATUS.json');
        assert(exist(fullfile(fileparts(p),'WINDOW_RUNNING.lock'),'file')~=2, ...
            'NB:PilotRunning','Matching pilot is still running; wait for it to finish');
        assert(exist(p,'file')==2,'NB:PilotRequired','Run matching-scope pilot before paper: %s',p);
        r=jsondecode(fileread(p));
        assert(isfield(r,'ReadyForPaper')&&r.ReadyForPaper&& ...
            isfield(r,'SourceHash')&&strcmp(r.SourceHash,sourceHash)&& ...
            isfield(r,'FamilyHash')&&strcmp(r.FamilyHash,familyHash), ...
            'NB:PilotNotReady','Pilot incomplete, baseline degenerate, or settings changed. Resolve and rerun pilot.');
    end
    if C.requireRACheckBeforePaper&&any(window=='BE')
        p=fullfile(C.outputRoot,'RA_PREFLIGHT.mat');
        assert(exist(p,'file')==2,'NB:RARequired','Run RUN_RA_PREFLIGHT before B/E paper');
        r=load(p,'report');r=r.report;
        assert(r.Ready&&strcmp(r.SourceHash,sourceHash)&&strcmp(r.RAConfigHash,NB_RA_CONFIG_HASH(C)), ...
            'NB:RANotReady','RA activation check not ready/current. Inspect and rerun RUN_RA_PREFLIGHT.');
    end
end
