function R=RUN_WINDOW_D_TRANSFER(stage,options)
    if nargin<1,stage='pilot';end
    if nargin<2,options=struct();end
    R=NB_RUN('D',stage,options);
end
