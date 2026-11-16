function O=NB_USER_CONFIG()
% V2: prefer NB_SETUP_PATHS for locations; it avoids editing scientific source.
% Raw face folders are NOT archives. These fields remain a manual fallback.
    O=struct();
    O.archiveRoot=''; % folder containing cache/, splits/, calibration/, jobs/
    O.coilPath='';    % COIL20 grayscale PNG directory OR MAT with X,labels
    % O.outputRoot='H:\your_folder\results_Tukey_NB_20261105';
    % Optional source-faithful external adapter; see EXTERNAL_ADAPTER_CN.txt.
    O.externalAdapter='';O.externalName='BA2DPCA';
end
