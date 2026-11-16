% Full five-module run. Configure only locations in CSSP_USER_CONFIG.m.
root=fileparts(mfilename('fullpath'));addpath(root,'-begin');
CSSP_RUN('paper');
