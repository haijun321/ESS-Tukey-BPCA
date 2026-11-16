function M = SMPV_P0_METHODS(family,C)
% CORE fixed/auto use the SAME severity rule and zero preferences given E.
% MAIN/solver retain legacy complete-configuration calibration choices.
    b=struct('id','','name','','loss','tukey','cutoff','ess','etaMode','auto', ...
        'etaValue',NaN,'sampleMode',false,'sampleGuard',true,'cleanGuard',false, ...
        'useZeroCalibration',true,'commonSeverity',true);
    switch family
        case 'core'
            M=repmat(b,1,4);
            ids={'C1','C2','C3','C4'};
            names={'FixedTukey_noSW_noGuard','FixedEta_matched_noSW_noGuard', ...
                'Auto_matched_noSW_noGuard','Auto_noZero_noSW_noGuard'};
            for k=1:4,M(k).id=ids{k};M(k).name=names{k};end
            M(1).cutoff='fixed';M(1).etaMode='none';M(1).commonSeverity=false;
            M(2).etaMode='fixed';M(2).etaValue=.85;
            M(4).useZeroCalibration=false;
            if C.includeFixedEtaNoZero
                x=M(2);x.id='C5';x.name='FixedEta_matched_noZero_noSW_noGuard';
                x.useZeroCalibration=false;M(end+1)=x;
            end
        case {'main','solver'}
            M=repmat(b,1,6);
            ids={'L2','Huber','Welsch','FixedTukey','FixedEta','Auto'};
            names={'L2_BPCA','Huber_BPCA','Welsch_BPCA','FixedTukey_BPCA', ...
                'ESS_fixedEta_complete','ESS_auto_complete'};
            for k=1:6
                M(k).id=ids{k};M(k).name=names{k};M(k).commonSeverity=false;M(k).cleanGuard=true;
            end
            M(1).loss='l2';M(1).cutoff='none';M(1).etaMode='none';
            M(2).loss='huber';M(2).cutoff='fixed';M(2).etaMode='none';
            M(3).loss='welsch';M(3).cutoff='fixed';M(3).etaMode='none';
            M(4).cutoff='fixed';M(4).etaMode='none';
            M(5).etaMode='fixed';M(5).etaValue=.85;M(5).sampleMode=true;
            M(6).sampleMode=true;
            if strcmp(family,'solver'),M=M([4 5 6]);end
        case {'extension','pilot'}
            K=SMPV_P0_METHODS('core',C); x=K(3);
            x.id='R5';x.name='Auto_matched_Guard_noSW';x.cleanGuard=true;
            y=x;y.id='R6';y.name='Auto_matched_Guard_SW';y.sampleMode=true;
            z=x;z.id='R7';z.name='Auto_matched_Guard_noZero_noSW';z.useZeroCalibration=false;
            if strcmp(family,'extension'),M=[x y z];else,M=[K x y z];end
        otherwise,error('P0:Family','Unknown method family.');
    end
end
