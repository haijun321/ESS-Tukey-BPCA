function R=RUN_WINDOW_B_COMPARISON(stage,options)
    if nargin<1,stage='pilot';end
    if nargin<2,options=struct();end
    R=NB_RUN('B',stage,options);
end
