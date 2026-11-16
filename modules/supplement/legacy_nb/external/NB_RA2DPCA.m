function model = NB_RA2DPCA(X,k,gamma,lambda,opts)
%NB_RA2DPCA MATLAB implementation of the authors' RA-2DPCA recurrence.
% This is a MATLAB port, NOT official MATLAB software. The original authors
% supply R code. Provenance and deviations are in RA_PROVENANCE.txt.
% X is p-by-q-by-n; the native feature has p*k entries (one-sided projection).
% model.mean MUST be subtracted before projection and added for reconstruction.
% Default centering matches the author's RE_RA_2DPCA wrapper. Core RA_2DPCA
% can be selected with opts.center=false for already centered input.
% Optional opts: center, maxOuter, tolerance, timeLimit.
    if nargin<5,opts=struct();end
    validateattributes(X,{'numeric'},{'real','finite','nonempty'});
    X=double(X);[p,q,n]=size(X);
    validateattributes(k,{'numeric'},{'scalar','integer','>=',1,'<=',q});
    validateattributes(gamma,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(lambda,{'numeric'},{'scalar','real','finite','positive'});
    centered=getopt(opts,'center',true);limit=getopt(opts,'maxOuter',100);
    tolerance=getopt(opts,'tolerance',1e-4);timeLimit=getopt(opts,'timeLimit',Inf);
    validateattributes(limit,{'numeric'},{'scalar','integer','positive'});
    validateattributes(tolerance,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(timeLimit,{'numeric'},{'scalar','real','positive'});
    solverClock=tic;
    if centered,mu=mean(X,3);else,mu=zeros(p,q);end
    Y=X-mu;V=eye(q,k);previous=1;history=zeros(limit,4);
    weightTrace=repmat(struct('Iteration',0,'RowNonzeroFraction',NaN, ...
        'CovarianceFrobenius',NaN,'CovarianceRank',NaN,'AllWeightsZero',false, ...
        'ZeroCovariance',false,'WeightMaximum',NaN),limit,1);
    status='iteration_limit';iterations=0;
    for t=1:limit
        if toc(solverClock)>=timeLimit,status='time_limit';break;end
        covariance=zeros(q,q);nonzeroRows=0;maximumWeight=0;
        for i=1:n
            Z=Y(:,:,i);residual=Z-(Z*V)*V';
            residualNorm=sqrt(sum(residual.^2,2));
            rowNorm=sqrt(sum(Z.^2,2));
            omega=max(0,lambda-residualNorm/gamma);
            weights=omega./(rowNorm.*residualNorm+1e-4);
            nonzeroRows=nonzeroRows+sum(weights>0);
            maximumWeight=max(maximumWeight,max(weights));
            covariance=covariance+Z'*(Z.*weights);
        end
        covarianceFrobenius=norm(covariance,'fro');
        weightTrace(t)=struct('Iteration',t,'RowNonzeroFraction',nonzeroRows/(p*n), ...
            'CovarianceFrobenius',covarianceFrobenius,'CovarianceRank',rank(covariance), ...
            'AllWeightsZero',nonzeroRows==0,'ZeroCovariance',covarianceFrobenius==0, ...
            'WeightMaximum',maximumWeight);
        if nonzeroRows==0||covarianceFrobenius==0
            % The recurrence supplies no direction. Keep the previous basis
            % and report the degeneracy rather than diagonalizing a zero
            % covariance and labelling the arbitrary basis as convergence.
            status='zero_weight_degenerate';iterations=t;totalResidual=0;
            for i=1:n
                Z=Y(:,:,i);totalResidual=totalResidual+norm(Z-(Z*V)*V','fro');
            end
            history(t,:)=[t,totalResidual,NaN,toc(solverClock)];break;
        end
        [basis,values]=eig((covariance+covariance')/2);
        [~,order]=sort(real(diag(values)),'descend');V=real(basis(:,order(1:k)));
        totalResidual=0;
        for i=1:n
            Z=Y(:,:,i);totalResidual=totalResidual+norm(Z-(Z*V)*V','fro');
        end
        iterations=t;
        if totalResidual==0
            relativeChange=NaN;status='zero_residual_degenerate';
        else
            relativeChange=abs(totalResidual-previous)/totalResidual;
        end
        history(t,:)=[t,totalResidual,relativeChange,toc(solverClock)];
        if totalResidual==0,break;end
        if relativeChange<=tolerance,status='relative_residual_stable';break;end
        previous=totalResidual;
    end
    model=struct('U',eye(p),'V',V,'mean',mu,'representation','one_sided_right', ...
        'featureDimension',p*k,'history',history(1:iterations,:), ...
        'weightTrace',weightTrace(1:iterations,:), ...
        'stopReason',status,'elapsedSeconds',toc(solverClock),'iterations',iterations, ...
        'gamma',gamma,'lambda',lambda,'centered',logical(centered), ...
        'tolerance',tolerance,'maxOuter',limit,'timeLimit',timeLimit, ...
        'implementation','MATLAB_port_of_author_R_recurrence', ...
        'sourceCommit','84d54472cc5b615611b605f330df2501d00401d0');
    diagnostics=NB_RA_DIAGNOSTICS(X,model);
    model.InitialNonzeroFraction=diagnostics.InitialRowNonzeroFraction;
    model.FinalNonzeroFraction=diagnostics.FinalRowNonzeroFraction;
    model.ZeroWeightDegenerate=strcmp(status,'zero_weight_degenerate');
    model.diagnostics=diagnostics;
end

function value=getopt(opts,key,default)
    if isfield(opts,key),value=opts.(key);else,value=default;end
end
