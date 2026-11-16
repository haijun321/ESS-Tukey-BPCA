function report=NB_RA_SELFTEST()
% Compare MATLAB to deterministic scalar-recurrence fixtures.
% This does not claim bitwise agreement with an R runtime.
    root=fileparts(mfilename('fullpath'));report=zeros(3,3);
    for j=1:3
        f=load(fullfile(root,sprintf('ra_fixture_%d.mat',j)));
        m=NB_RA2DPCA(f.X,f.k,f.gamma,f.lam,struct());
        p=m.V*m.V';err=norm(p-f.expectedProjector,'fro');
        assert(err<1e-8,'NB:RAParity','RA projector differs from scalar reference.');
        assert(size(m.history,1)==size(f.expectedHistory,1),'NB:RAParity','RA iteration count differs.');
        z=abs(m.history(:,1:3)-f.expectedHistory);herr=max(z(:));
        assert(herr<1e-7,'NB:RAParity','RA trajectory differs from scalar reference.');
        assert(norm(m.V'*m.V-eye(f.k),'fro')<1e-10,'NB:RAOrtho','RA basis lost orthogonality.');
        assert(m.featureDimension==size(f.X,1)*f.k,'NB:RADimension','Incorrect native dimension.');
        report(j,:)=[j err herr];
    end
    fprintf('RA MATLAB/scalar-reference fixture checks PASS (%d cases).\n',size(report,1));
    % Deliberate numerical failure must remain a labelled failure, not an
    % arbitrary zero-covariance eigenbasis or apparent stationarity.
    X=zeros(3,4,2);X(:,:,1)=[0 2 3 4;0 3 4 5;0 4 5 6];X(:,:,2)=-X(:,:,1);
    failed=NB_RA2DPCA(X,1,1,1e-9,struct('center',false,'maxOuter',3));
    assert(strcmp(failed.stopReason,'zero_weight_degenerate')&&failed.ZeroWeightDegenerate, ...
        'NB:RADegenerateTest','All-zero weights were not explicitly diagnosed.');
    assert(norm(failed.V-eye(4,1),'fro')==0&&failed.InitialNonzeroFraction==0, ...
        'NB:RADegenerateTest','Degenerate update changed the previous basis.');
    assert(failed.weightTrace(1).AllWeightsZero&&failed.weightTrace(1).CovarianceRank==0, ...
        'NB:RADegenerateTest','Degenerate trace incorrect.');
    healthy=NB_RA2DPCA(X,1,1,20,struct('center',false,'maxOuter',3));
    assert(~healthy.ZeroWeightDegenerate&&healthy.InitialNonzeroFraction>0, ...
        'NB:RAHealthyTest','Positive-weight control was rejected.');
    assert(all([healthy.weightTrace.CovarianceFrobenius]>0), ...
        'NB:RAHealthyTest','Healthy update has zero covariance.');
    fprintf('RA training-weight diagnostics PASS (degenerate and positive-weight controls).\n');
end
