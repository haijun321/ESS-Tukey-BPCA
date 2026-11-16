function U=CSSP_USER_CONFIG()
% Edit locations here only. No scientific run asks interactive questions.
% archiveRoot must contain cache/, splits/, calibration/, jobs/.
% The raw ORL/YALE image directory is NOT an archive.
U=struct();
U.archiveRoot=''; % empty: TUKEY_ARCHIVE_ROOT, known old path, or unambiguous nearby archive
% U.archiveRoot='H:\Students\Jiang_haijun\Tukey BPCA\results_Tukey_CONFIRM_v1';
% U.outputRoot='H:\Students\Jiang_haijun\Tukey BPCA\results_CSSP_20261115';
U.rscriptPath=''; % full Rscript.exe path, or empty to detect Rscript on PATH
U.externalAdapters=struct('BA2DPCA','','L2pSB2DPCA','');
% U.priorResultRoots={'H:\your_path\results_P0_V2_FIX1'};
% An adapter must implement the documented source-faithful external API.
end
