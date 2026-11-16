function rows=NB_CHECKPOINT_METRICS(model,X,regime,D,computeACC)
% Evaluate saved bases only after the algorithm has terminated.
% Nothing returned here may be used to select an outer iteration on the probe.
% Seconds includes checkpoint-copy overhead but excludes all evaluations below.
    if nargin<5,computeACC=true;end
    assert(isfield(model,'checkpoints'),'NB:NoCheckpoints','Run NB_SOLVER_TRACE first.');
    rows=repmat(struct('Outer',0,'Seconds',0,'NRE',NaN,'ErrSubNorm',NaN,'ACC',NaN, ...
        'MetricTarget','','EvaluationSeconds',0),numel(model.checkpoints),1);
    for k=1:numel(model.checkpoints)
        z=model.checkpoints(k);U=z.U;V=z.V;tEval=tic;
        rows(k).Outer=z.Outer;rows(k).Seconds=z.Seconds;
        if strcmp(regime,'synthetic')
            total=0;
            for i=1:size(X,3)
                err=D.Xclean(:,:,i)-U*(U'*X(:,:,i)*V)*V';
                total=total+sum(err(:).^2);
            end
            rows(k).NRE=sqrt(total)/(norm(D.Xclean(:))+1e-12);
            rows(k).ErrSubNorm=.5*(norm(D.Atrue*D.Atrue'-U*U','fro')/sqrt(2*size(U,2)) ...
                +norm(D.Btrue*D.Btrue'-V*V','fro')/sqrt(2*size(V,2)));
            rows(k).MetricTarget='latent_clean_recovery_from_corrupted_projection';
        else
            assert(~isfield(D,'selectionOnly')||~D.selectionOnly, ...
                'NB:ProbeMissing','Checkpoint evaluation requires a locked evaluation split.');
            rows(k).NRE=SU_FROZEN('nre',D.probe,U,V);
            if computeACC
                rows(k).ACC=SU_FROZEN('accuracy',D.gallery,D.galleryLabels, ...
                    D.probe,D.probeLabels,U,V,D.cfg);
            end
            rows(k).MetricTarget='clean_outer_probe';
        end
        rows(k).EvaluationSeconds=toc(tEval);
        assert(isfinite(rows(k).NRE),'NB:Metric','Nonfinite checkpoint NRE.');
    end
end
