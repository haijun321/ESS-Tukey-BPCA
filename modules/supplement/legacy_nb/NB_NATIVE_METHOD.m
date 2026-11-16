function M=NB_NATIVE_METHOD(C,id,value)
    if nargin<3,value=NaN;end
    all=P0_METHODS('core',C);
    if strcmp(id,'L2')
        M=all(1);M.id='L2';M.loss='l2';M.cutoff='none';M.etaMode='none';
    elseif strcmp(id,'TunedC')
        M=all(1);M.id=id;
    elseif strcmp(id,'TunedEta')
        M=all(2);M.id=id;M.etaValue=value;
    else
        ix=find(strcmp({all.id},id),1);assert(~isempty(ix),'NB:Method','Unknown native method %s',id);M=all(ix);
    end
end
