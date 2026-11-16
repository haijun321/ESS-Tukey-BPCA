function R=RUN_WINDOW_C_FACTORIAL(stage,options)
    if nargin<1,stage='pilot';end
    if nargin<2,options=struct();end
    R=NB_RUN('C',stage,options);
end
