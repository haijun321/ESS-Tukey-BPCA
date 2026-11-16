function gamma=NB_RA_DEFAULT_GAMMA(X)
% Author RE.R uses R quantile(x_train,.9), whose default is type 7.
% MATLAB quantile conventions can differ, so interpolate explicitly.
    validateattributes(X,{'numeric'},{'real','finite','nonempty'});
    values=sort(double(X(:)));position=1+.9*(numel(values)-1);
    lower=floor(position);upper=ceil(position);fraction=position-lower;
    gamma=(1-fraction)*values(lower)+fraction*values(upper);
    assert(isfinite(gamma)&&gamma>0,'NB:RAGamma', ...
        'Author training Q90 gamma is nonpositive; do not silently replace it.');
end
