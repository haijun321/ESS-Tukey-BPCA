function R=RUN_WINDOW_E_COIL20(stage,options)
    if nargin<1,stage='pilot';end
    if nargin<2,options=struct();end
    R=NB_RUN('E',stage,options);
end
