function R=RUN_WINDOW_A_TRAJECTORY(stage,options)
    if nargin<1,stage='pilot';end
    if nargin<2,options=struct();end
    R=NB_RUN('A',stage,options);
end
