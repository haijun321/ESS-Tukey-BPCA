function [S,memory] = SMPV_P0_STATE(E,M,A,regime,memory)
% Calibration sees observed residuals only; no mask or latent truth is passed.
    if strcmp(M.loss,'tukey')
        [S,memory]=SMPV_SU_STATE(E,M,A,regime,memory);return;
    end
    S=struct(); S.scale=SMPV_SU_FROZEN('mad',E(:),A.eps0);
    S.current=NaN;S.severity=NaN;S.eta=NaN;S.guard=false;
    switch M.loss
        case 'l2',S.tau=NaN;S.We=ones(size(E));
        case 'huber'
            S.tau=A.huberC*S.scale;S.We=ones(size(E));q=abs(E)>S.tau;
            S.We(q)=S.tau./abs(E(q));
        case 'welsch',S.tau=A.welschC*S.scale;S.We=exp(-(E./S.tau).^2);
        otherwise,error('P0:Loss','Unsupported loss %s.',M.loss);
    end
    S.Ws=ones(size(E,3),1);S.a=ones(size(S.Ws));S.W=S.We;
end
