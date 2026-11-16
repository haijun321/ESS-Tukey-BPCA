function varargout = SMPV_SU_FROZEN(action,varargin)
% Read-only API over the frozen user-supplied V1.7 memoryfix implementation.
% No experiment driver, old checkpoints, or old calibration results are run.
    switch lower(char(action))
        case 'warm', [varargout{1:nargout}]=bpca_warm_alt_update_v6(varargin{:});
        case 'qf', [varargout{1:nargout}]=qf_retraction(varargin{:});
        case 'sampleweights', [varargout{1:nargout}]=sample_level_weights_v17(varargin{:});
        case 'eta', [varargout{1:nargout}]=eta_from_tail_severity_v17(varargin{:});
        case 'tukeyweights', [varargout{1:nargout}]=tukey_weights(varargin{:});
        case 'config', [varargout{1:nargout}]=make_config_real_tukey_v1(varargin{:});
        case 'load', [varargout{1:nargout}]=load_face_dataset_real_tukey_v1(varargin{:});
        case 'validate', validate_loaded_dataset_real_tukey_v1(varargin{:});
        case 'standardize', [varargout{1:nargout}]=standardize_tensor_samples_real_tukey_v1(varargin{:});
        case 'methods', [varargout{1:nargout}]=make_main_methods_real_tukey_v1();
        case 'ablation', [varargout{1:nargout}]=make_ablation_methods_real_tukey_v1();
        case 'fit', [varargout{1:nargout}]=fit_method_real_tukey_v1_core(varargin{:});
        case 'l2', [varargout{1:nargout}]=train_l2_bpca_v6(varargin{:});
        case 'initialize', [varargout{1:nargout}]=initialize_bpca_v6(varargin{:});
        case 'residual', [varargout{1:nargout}]=residual_tensor(varargin{:});
        case 'tailfeatures', [varargout{1:nargout}]=tail_features_real_tukey_v17(varargin{:});
        case 'rawseverity', [varargout{1:nargout}]=empirical_tail_severity_from_features_v17(varargin{:});
        case 'severity', [varargout{1:nargout}]=estimate_tail_severity_v6(varargin{:});
        case 'samplez', [varargout{1:nargout}]=sample_residual_z_v17(varargin{:});
        case 'percentile', [varargout{1:nargout}]=local_percentile(varargin{:});
        case 'plan', [varargout{1:nargout}]=make_element_contamination_plan_real_tukey_v1(varargin{:});
        case 'apply', [varargout{1:nargout}]=apply_element_contamination_plan_real_tukey_v1(varargin{:});
        case 'accuracy', [varargout{1:nargout}]=recognition_accuracy_real_tukey_v1(varargin{:});
        case 'nre', [varargout{1:nargout}]=projection_nre_real_tukey_v1(varargin{:});
        case 'drift', [varargout{1:nargout}]=bilateral_drift_real_tukey_v1(varargin{:});
        case 'mad', [varargout{1:nargout}]=robust_mad_scale(varargin{:});
        case 'select', [varargout{1:nargout}]=select_tukey_tau_by_ess_v6(varargin{:});
        case 'esszero', [varargout{1:nargout}]=tukey_ess_zero_from_abs_chunked_v11(varargin{:});
        case 'loss', [varargout{1:nargout}]=robust_objective_by_loss_v6(varargin{:});
        case 'oldauc', varargout{1}=binary_auc_tied(varargin{:});varargout{2}=binary_pr_auc_v6(varargin{:});
        case 'median_test', [varargout{1:nargout}]=memfix_selftest();
        otherwise, error('TC:EngineAction','Unknown engine API action: %s',char(action));
    end
end

function cfg = make_config_real_tukey_v1(mode)
    cfg = struct();
    cfg.mode = mode;
    cfg.seed = 2026;
    % V1.7 uses a fresh evaluation seed family. R0A/R0B/R0C remain development-only
    % calibration stages; R1--R8 use unseen validation/test realizations.
    cfg.evalSeedOffset = 7000000;

    candidates = { ...
        'H:\Students\Jiang_haijun\B2DLDA1111', ...
        'H:\Students\Jiang_haijun\B2DLDA111', ...
        'H:\Students\Jiang_haijun\RB2DLDA(11.29)', ...
        fullfile(pwd,'data'), ...
        fullfile(fileparts(pwd),'data'), ...
        'C:\Users\蒋海俊\Desktop\DC\DOC\BRPCA代码\L1BPCA_code\L1BPCA_code\data' ...
    };
    cfg.data_root = resolve_existing_dir_real_tukey_v1(candidates);
    if isempty(cfg.data_root)
        cfg.data_root = auto_find_face_data_root_real_tukey_v1('H:\Students\Jiang_haijun');
    end
    if isempty(cfg.data_root)
        cfg.data_root = 'H:\Students\Jiang_haijun\B2DLDA1111';
        fprintf(2,'[WARNING] Data root not found now; defaulting to %s\n',cfg.data_root);
    end

    cfg.requested_datasets = {'YALE','ORL','PIE','XM2VTS'};
    cfg.quick_datasets = {'YALE'};
    cfg.allow_skip_unavailable_datasets = true;
    cfg.min_required_datasets = 4;

    cfg.default_size.YALE = [121 160];
    cfg.default_size.ORL = [112 92];
    cfg.default_size.PIE = [64 64];
    cfg.default_size.XM2VTS = [55 51];
    cfg.expected_samples = struct('YALE',165,'ORL',400,'PIE',2924,'XM2VTS',2360);
    cfg.expected_classes = struct('YALE',15,'ORL',40,'PIE',68,'XM2VTS',295);

    cfg.foreign_pair_source.YALE = 'ORL';
    cfg.foreign_pair_source.ORL = 'YALE';
    cfg.foreign_pair_source.PIE = 'XM2VTS';
    cfg.foreign_pair_source.XM2VTS = 'PIE';

    cfg.samplewise_standardize = true;
    cfg.standardize_scale = 'sqrtmn';

    % Three-way split keeps classifier training clean.
    cfg.splitRatios = [0.40 0.30 0.30]; % subspace / gallery / probe
    cfg.heldoutIdentityFraction = 0.20;
    cfg.heldoutIdentityMinClasses = 2;

    % Dataset-level bilateral rank is calibrated ON CLEAN DEVELOPMENT DATA
    % before any contamination experiment, then frozen for all methods and
    % all contamination levels. This is a nuisance-parameter calibration,
    % not a method-specific tuning advantage.
    cfg.rank.default = [8 8];
    cfg.rank.YALE = [8 8];
    cfg.rank.ORL = [8 8];
    cfg.rank.PIE = [8 8];
    cfg.rank.XM2VTS = [8 8];
    cfg.rankCalib.enabled = true;
    if strcmpi(mode,'quick')
        cfg.rankCalib.candidates = [6 8 10];
        cfg.rankCalib.repeats.small = 1; cfg.rankCalib.repeats.large = 1;
    else
        cfg.rankCalib.candidates = [4 6 8 10 12 16];
        cfg.rankCalib.repeats.small = 5; cfg.rankCalib.repeats.large = 3;
    end
    cfg.rankCalib.fitFraction = 0.75;
    cfg.rankCalib.accTolerance = 0.01; % choose smallest k within 1 percentage point of best clean validation ACC

    % Real-face clean residuals are NOT forced to follow a Gaussian null.
    % V1.7 estimates the three standardized clean-tail probabilities
    % P(|z|>k1), P(|z|>k2), P(|z|>k3) from CLEAN DEVELOPMENT splits only.
    % Their median clean levels form a dataset-specific empirical reference.
    % A 95th-percentile clean excess-severity threshold is then frozen before
    % R1--R8.  There is deliberately NO upper cap such as 0.10: the clean
    % distribution itself determines the allowed real-data tail level.
    cfg.tailCalib.enabled = true;
    cfg.tailCalib.quantile = 95;
    cfg.tailCalib.sampleTailQuantile = 90;
    cfg.tailCalib.minSeverityThreshold = 0.002;
    if strcmpi(mode,'quick')
        % QUICK still needs several clean splits; one split cannot estimate
        % a meaningful empirical null.
        cfg.tailCalib.repeats.small = 5; cfg.tailCalib.repeats.large = 3;
    else
        cfg.tailCalib.repeats.small = 12; cfg.tailCalib.repeats.large = 6;
    end
    cfg.tailReference = struct();
    cfg.tailThreshold = struct(); % compatibility / audit copy

    % Independent SAMPLE-level clean calibration.
    %
    % V1.7 removes the dataset-level activation gate altogether.  Instead,
    % CLEAN development residual scores are pooled across many independent
    % clean splits to estimate a sample-score null distribution.  Two frozen
    % quantiles define a CLEAN NEUTRAL ZONE:
    %   c0 : scores <= c0 keep sample weight exactly 1;
    %   c1 : scores >= c1 receive the pre-specified minimum sample weight;
    %        scores between c0 and c1 are smoothly downweighted.
    % This makes sample robustness a per-sample decision rather than a
    % batch-level on/off decision.  No probe/test outcome is used.
    cfg.sampleCalib.enabled = true;
    cfg.sampleCalib.neutralQuantile = 95.0;         % pre-registered 5% clean upper-tail entry point
    cfg.sampleCalib.fullDownweightQuantile = 99.5;  % strong clean-tail reference
    cfg.sampleCalib.minTransitionGap = 0.50;        % numerical safeguard in robust-z units
    if strcmpi(mode,'quick')
        % R0C is development-only.  Use enough clean splits to estimate an
        % empirical upper tail; five split-level statistics are inadequate.
        cfg.sampleCalib.repeats.small = 30;
        cfg.sampleCalib.repeats.large = 12;
    else
        cfg.sampleCalib.repeats.small = 50;
        cfg.sampleCalib.repeats.large = 20;
    end
    cfg.sampleReference = struct();

    cfg.classifier.zscoreFeatures = true;

    % R2/R3/R4 grids. QUICK deliberately uses a tiny smoke-test grid.
    cfg.cellwiseTypes = {'impulse','block'};
    cfg.blockRatio = 0.18;
    cfg.samplewiseScenarios = {'cross_dataset'};
    cfg.runLocalOcclusion = true;
    cfg.localScenarios = {'random_block','eyes_band','lower_face'};
    if strcmpi(mode,'quick')
        cfg.cellwiseRates = [0 0.10];
        cfg.cellwiseStrengths = 6;
        cfg.samplewiseRates = [0 0.20];
        cfg.localAreaList = 0.20;
        % QUICK is a memory/syntax smoke test: only the primary local block
        % pathway is needed. PAPER restores all semantic-boundary scenarios.
        cfg.localScenarios = {'random_block'};
    else
        cfg.cellwiseRates = [0 0.02 0.05 0.10 0.20 0.30];
        cfg.cellwiseStrengths = [3 4.5 6]; % mild / moderate / severe robust-scale units
        cfg.samplewiseRates = [0 0.10 0.20 0.30 0.40];
        cfg.localAreaList = [0.10 0.20 0.30 0.40];
    end

    % R4 local occlusion.
    cfg.localSampleRatio = 0.20;
    cfg.localFillMode = 'low_quantile';

    % R6 representative ablation.
    cfg.runAblation = true;
    cfg.ablationDatasets = {'YALE','ORL'};
    cfg.ablationElementType = 'impulse';
    cfg.ablationCellRate = 0.10;
    cfg.ablationCellStrength = 6;
    cfg.ablationSampleRate = 0.20;

    % R6Z: pre-registered zero-weight calibration stress grid.  This does not
    % tune the method; it only checks whether the R0 penalty is ever an active
    % constraint under stronger elementwise contamination.
    cfg.runZeroCalGrid = true;
    cfg.zeroCalGrid.rates = [0.10 0.20 0.30];
    cfg.zeroCalGrid.strengths = [4.5 6.0];
    if strcmpi(mode,'quick')
        cfg.zeroCalGrid.rates = [0.10 0.30];
        cfg.zeroCalGrid.strengths = 6.0;
        cfg.zeroCalGrid.repeats = 1;
    else
        cfg.zeroCalGrid.repeats = 8;
    end

    % R7: real-data validation-best eta benchmark.  Eta is selected only
    % from clean gallery NRE; probe labels/accuracy are never used for eta
    % selection. The benchmark asks whether automatic ESS calibration is
    % close to a modest validation grid without requiring grid search.
    cfg.runEtaValidation = true;
    cfg.etaValidation.grid = [0.82 0.85 0.88 0.91 0.94 0.97];
    cfg.etaValidation.elementType = 'impulse';
    cfg.etaValidation.elementRate = 0.10;
    cfg.etaValidation.elementStrength = 4.5;
    % Eta controls the ELEMENT-level Tukey cutoff.  R7 therefore uses an
    % elementwise contamination regime (impulse), where the element ESS
    % mechanism is intended to operate.  Structured block/local occlusion
    % remain stress tests, and sample adaptation is evaluated in R3/R6/R8.
    cfg.etaValidation.scenarios = {'impulse'};
    if strcmpi(mode,'quick')
        cfg.etaValidation.repeats.small = 2; cfg.etaValidation.repeats.large = 1;
    else
        cfg.etaValidation.repeats.small = 8; cfg.etaValidation.repeats.large = 4;
    end

    % R8: one-dimensional sample-weight-alpha sensitivity.  Cross-dataset
    % structural sample outliers are the PRIMARY setting because held-out
    % identities need not be structural residual outliers.
    cfg.runAlphaSensitivity = true;
    cfg.alphaSensitivity.scenario = 'cross_dataset';
    if strcmpi(mode,'quick')
        cfg.alphaSensitivity.list = [0 0.35 0.70];
        cfg.alphaSensitivity.repeats.small = 2; cfg.alphaSensitivity.repeats.large = 1;
    else
        cfg.alphaSensitivity.list = [0 0.20 0.35 0.50 0.70];
        cfg.alphaSensitivity.repeats.small = 8; cfg.alphaSensitivity.repeats.large = 4;
    end
    cfg.alphaSensitivity.sampleRate = 0.20;

    cfg.primaryBaselines = {'L2-BPCA','Huber-BPCA','Welsch-BPCA', ...
        'Fixed-Tukey-BPCA','ESS-Tukey-BPCA-eta85','L1RBPCA'};

    % V6 Tukey-BPCA algorithm parameters.
    cfg.alg = struct();
    if strcmpi(mode,'paper')
        cfg.alg.maxOuter = 50;
        cfg.alg.maxInner = 5;
        cfg.alg.mmLineSearchMax = 12;
    else
        cfg.alg.maxOuter = 12;
        cfg.alg.maxInner = 3;
        cfg.alg.mmLineSearchMax = 8;
    end
    % Do not terminate a method merely because it is slower.  A hard time
    % cap biases performance comparisons by evaluating unfinished fits.
    % Runtime is still measured and reported in every experiment.
    cfg.alg.maxTimePerMethod = Inf;
    cfg.alg.tolOuter = 1e-6;
    cfg.alg.eps0 = 1e-12;
    cfg.alg.zeroTol = 1e-12;
    cfg.alg.mmShrink = 0.5;
    cfg.alg.mmAcceptTol = 1e-10;
    cfg.alg.stationarityTol = 1e-6; % normalized projector-movement tolerance

    cfg.alg.essEtaMin = 0.82;
    cfg.alg.essEtaMaxContam = 0.96;
    cfg.alg.essEtaDefaultClean = 0.99;
    cfg.alg.essTailK1 = 2.25;
    cfg.alg.essTailK2 = 3.00;
    cfg.alg.essTailK3 = 4.00;
    cfg.alg.sampleTailQuantile = cfg.tailCalib.sampleTailQuantile;
    cfg.alg.essTailGamma = 0.65;
    cfg.alg.etaGuard = 0.005;
    cfg.alg.tailSeverityCleanThreshold = 0.012; % fallback only for synthetic/Gaussian reference
    cfg.alg.tailSeverityCap = 0.40;
    cfg.alg.useSeverityMemory = true;
    cfg.alg.severityMemoryMode = 'max'; % contamination evidence cannot be forgotten
    cfg.alg.realTailReferenceEnabled = true;
    cfg.alg.essGridSize = 80;
    % Chunk size used by memory-safe ESS/objective calculations.
    % This changes only computation strategy, not the mathematical criterion.
    if strcmpi(mode,'paper')
        cfg.alg.memoryBlockSize = 100000;
    else
        cfg.alg.memoryBlockSize = 50000;
    end

    cfg.alg.useZeroCalibration = true;
    cfg.alg.zeroUnderPenalty = 0.8;
    cfg.alg.zeroOverPenalty = 0.5;
    cfg.alg.zeroLowerFactor = 0.45;
    cfg.alg.zeroUpperFactor = 1.80;

    cfg.alg.useSampleWeight = true;
    cfg.alg.sampleWeightAlpha = 0.35;
    cfg.alg.sampleWeightMin = 0.20;
    cfg.alg.sampleTauC = 3.0;
    cfg.alg.sampleStrongDownweightThreshold = 0.50;
    cfg.alg.cleanGuardSampleWeight = true; % compatibility; V1.7 uses a per-sample clean neutral zone

    cfg.alg.fixedTukeyC = 4.685;
    cfg.alg.huberC = 1.345;
    cfg.alg.welschC = 2.985;
    cfg.alg.initMode = 'robust_l2';
    cfg.alg.clipC = 3.0;
    cfg.alg.numRandomInit = 0;
    cfg.alg.fastBpcaSteps = 2;

    cfg.l1_tol = 1e-5;

    switch lower(mode)
        case 'quick'
            cfg.nRep.clean.small = 1; cfg.nRep.clean.large = 1;
            cfg.nRep.cellwise.small = 1; cfg.nRep.cellwise.large = 1;
            cfg.nRep.samplewise.small = 1; cfg.nRep.samplewise.large = 1;
            cfg.nRep.local.small = 1; cfg.nRep.local.large = 1;
            cfg.nRep.ablation = 1;
        case 'paper'
            cfg.nRep.clean.small = 30; cfg.nRep.clean.large = 10;
            cfg.nRep.cellwise.small = 30; cfg.nRep.cellwise.large = 10;
            cfg.nRep.samplewise.small = 30; cfg.nRep.samplewise.large = 10;
            cfg.nRep.local.small = 20; cfg.nRep.local.large = 8;
            cfg.nRep.ablation = 15;
    end

    cfg.makePlots = true;
    cfg.out_dir = ''; % Set by the recovery entry point.
end

%% =========================================================================
% V1.7 CLEAN DEVELOPMENT CALIBRATION: RANK + EMPIRICAL TAIL NULL
% ==========================================================================
function [cfg,Traw,Tsel] = calibrate_ranks_real_tukey_v17(allData,cfg)
    rows = {}; rid = 0; selRows = {};
    if ~cfg.rankCalib.enabled
        Traw = table(); Tsel = table(); return;
    end

    l2method = method_struct_real_tukey_v1( ...
        'L2-BPCA','bpca','l2','none','none',NaN,false,true);

    for id = 1:numel(cfg.datasets)
        dname = cfg.datasets{id}; key = safe_field_name_real_tukey_v1(dname);
        ds = allData.(key);
        large = any(strcmpi(dname,{'PIE','XM2VTS'}));
        if large, nRep = cfg.rankCalib.repeats.large; else, nRep = cfg.rankCalib.repeats.small; end
        cand = cfg.rankCalib.candidates;
        cand = cand(cand < min(size(ds.X,1),size(ds.X,2)));
        if isempty(cand), cand = min(8,min(size(ds.X,1),size(ds.X,2))-1); end

        accMat = nan(nRep,numel(cand)); nreMat = nan(nRep,numel(cand));
        for rep = 1:nRep
            seed = 1700000 + 10000*id + rep;
            [idxSub,idxGal,~] = split_threeway_by_identity_real_tukey_v1( ...
                ds.labels,cfg.splitRatios,seed);
            Xsub = ds.X(:,:,idxSub); ysub = ds.labels(idxSub);
            Xval = ds.X(:,:,idxGal); yval = ds.labels(idxGal);

            for ik = 1:numel(cand)
                k = cand(ik);
                model = fit_method_real_tukey_v1(Xsub,k,k,l2method,cfg);
                acc = recognition_accuracy_real_tukey_v1( ...
                    Xsub,ysub,Xval,yval,model.U,model.V,cfg);
                nre = projection_nre_real_tukey_v1(Xval,model.U,model.V);
                accMat(rep,ik) = acc; nreMat(rep,ik) = nre;
                rid = rid + 1;
                rows(rid,:) = {dname,rep,seed,k,acc,nre}; %#ok<AGROW>
                clear model
            end
        end

        meanAcc = mean(accMat,1,'omitnan');
        meanNRE = mean(nreMat,1,'omitnan');
        bestAcc = max(meanAcc);
        eligible = find(meanAcc >= bestAcc - cfg.rankCalib.accTolerance);
        if isempty(eligible), [~,ix] = max(meanAcc); eligible = ix; end
        % Parsimonious clean calibration: smallest k within the pre-specified
        % validation-accuracy tolerance of the best candidate.
        [~,jj] = min(cand(eligible)); selIdx = eligible(jj);
        kSel = cand(selIdx);
        cfg.rank.(key) = [kSel kSel];

        selRows(end+1,:) = {dname,kSel,bestAcc,meanAcc(selIdx),meanNRE(selIdx), ...
            nRep,cfg.rankCalib.accTolerance}; %#ok<AGROW>
        fprintf('  [R0A][%s] selected k=%d | val ACC %.4f | best %.4f | val NRE %.4f\n', ...
            dname,kSel,meanAcc(selIdx),bestAcc,meanNRE(selIdx));
    end

    Traw = cell2table(rows,'VariableNames', ...
        {'Dataset','Repeat','Seed','CandidateK','ValidationACC','ValidationNRE'});
    Tsel = cell2table(selRows,'VariableNames', ...
        {'Dataset','SelectedK','BestValidationACC','SelectedValidationACC', ...
         'SelectedValidationNRE','NRep','ACCTolerance'});
end

function [cfg,Traw,Tthr] = calibrate_clean_tail_real_tukey_v17(allData,cfg)
    % V1.7 REAL-DATA CALIBRATION
    % ---------------------------------------------------------------
    % Real-face residuals are not assumed Gaussian.  We calibrate four
    % CLEAN residual features using development splits only:
    %   F1 = P(|z| > k1)
    %   F2 = P(|z| > k2)
    %   F3 = P(|z| > k3)
    %   F4 = Q_q{ within-sample P(|z|>k1) }
    %
    % F4 is a localized tail-concentration statistic.  It is important for
    % block/occlusion corruption, which may not increase the GLOBAL tail
    % mass after a scale estimate adapts.
    %
    % For every clean split we audit both robust-L2 initialization residuals
    % and converged L2 residuals, then take their featurewise maximum as a
    % conservative clean-null realization.  No probe/test outcome is used.

    rows = {}; rid = 0; thrRows = {};

    if ~cfg.tailCalib.enabled
        ks = [cfg.alg.essTailK1 cfg.alg.essTailK2 cfg.alg.essTailK3];
        gp = [erfc(ks(1)/sqrt(2)) erfc(ks(2)/sqrt(2)) erfc(ks(3)/sqrt(2))];
        baseF = [gp gp(1)];
        for id=1:numel(cfg.datasets)
            key=safe_field_name_real_tukey_v1(cfg.datasets{id});
            ref = struct('enabled',true,'baselineFeatures',baseF, ...
                'baselineP',baseF(1:3), ...
                'severityThreshold',cfg.alg.tailSeverityCleanThreshold, ...
                'k',ks,'sampleTailQuantile',cfg.alg.sampleTailQuantile, ...
                'nRep',0,'source','Gaussian_fallback');
            cfg.tailReference.(key)=ref;
            cfg.tailThreshold.(key)=ref.severityThreshold;
        end
        Traw=table(); Tthr=table(); return;
    end

    for id = 1:numel(cfg.datasets)
        dname = cfg.datasets{id};
        key = safe_field_name_real_tukey_v1(dname);
        ds = allData.(key);
        [r,c] = get_rank_real_tukey_v1(cfg,dname,size(ds.X));

        large = any(strcmpi(dname,{'PIE','XM2VTS'}));
        if large
            nRep=cfg.tailCalib.repeats.large;
        else
            nRep=cfg.tailCalib.repeats.small;
        end

        Finit = nan(nRep,4);
        Fl2   = nan(nRep,4);
        Fnull = nan(nRep,4);

        for rep=1:nRep
            seed = 1710000 + 10000*id + rep;
            [idxSub,~,~] = split_threeway_by_identity_real_tukey_v1( ...
                ds.labels,cfg.splitRatios,seed);
            Xsub = ds.X(:,:,idxSub);

            dummy = method_struct_real_tukey_v1( ...
                'CALIB','bpca','tukey','ess','auto',NaN,true,true);

            [Ui,Vi] = initialize_bpca_v6(Xsub,r,c,dummy,cfg.alg);
            Ei = residual_tensor(Xsub,Ui,Vi);
            Finit(rep,:) = tail_features_real_tukey_v17(Ei,cfg.alg);
            clear Ei Ui Vi

            [Ul,Vl,~] = train_l2_bpca_v6(Xsub,r,c,12,1e-6);
            El = residual_tensor(Xsub,Ul,Vl);
            Fl2(rep,:) = tail_features_real_tukey_v17(El,cfg.alg);
            clear El Ul Vl

            % Conservative clean null for this split.
            Fnull(rep,:) = max(Finit(rep,:),Fl2(rep,:));

            rid=rid+1;
            rows(rid,:)={dname,rep,seed,r,c, ...
                Finit(rep,1),Finit(rep,2),Finit(rep,3),Finit(rep,4), ...
                Fl2(rep,1),Fl2(rep,2),Fl2(rep,3),Fl2(rep,4), ...
                Fnull(rep,1),Fnull(rep,2),Fnull(rep,3),Fnull(rep,4)}; %#ok<AGROW>
        end

        % Dataset-specific empirical clean reference.
        baseF = median(Fnull,1,'omitnan');

        % Estimate clean split-to-split variability around the reference.
        sev = nan(nRep,1);
        for rep=1:nRep
            sev(rep)=empirical_tail_severity_from_features_v17( ...
                Fnull(rep,:),baseF,cfg.alg);
        end

        q = local_percentile(sev,cfg.tailCalib.quantile);
        if ~isfinite(q), q=0; end
        thr = max(q,cfg.tailCalib.minSeverityThreshold);

        ref = struct();
        ref.enabled = true;
        ref.baselineFeatures = baseF;
        ref.baselineP = baseF(1:3); % compatibility / audit
        ref.severityThreshold = thr;
        ref.k = [cfg.alg.essTailK1 cfg.alg.essTailK2 cfg.alg.essTailK3];
        ref.sampleTailQuantile = cfg.alg.sampleTailQuantile;
        ref.nRep = nRep;
        ref.source = 'clean_development_empirical';
        cfg.tailReference.(key)=ref;
        cfg.tailThreshold.(key)=thr;

        thrRows(end+1,:)={dname,baseF(1),baseF(2),baseF(3),baseF(4), ...
            thr,q,cfg.tailCalib.quantile,cfg.alg.sampleTailQuantile,nRep}; %#ok<AGROW>

        fprintf(['  [R0B][%s] clean features=[%.4f %.4f %.4f %.4f] | ' ...
            'excess-severity q%.0f=%.4f -> guard threshold %.4f\n'], ...
            dname,baseF(1),baseF(2),baseF(3),baseF(4), ...
            cfg.tailCalib.quantile,q,thr);
    end

    Traw=cell2table(rows,'VariableNames',{ ...
        'Dataset','Repeat','Seed','RankR','RankC', ...
        'P1Init','P2Init','P3Init','ConcentrationInit', ...
        'P1L2','P2L2','P3L2','ConcentrationL2', ...
        'P1Null','P2Null','P3Null','ConcentrationNull'});

    Tthr=cell2table(thrRows,'VariableNames',{ ...
        'Dataset','BaselineP1','BaselineP2','BaselineP3','BaselineConcentration', ...
        'CleanSeverityThreshold','RawSeverityQuantile','QuantilePct', ...
        'SampleTailQuantile','NRep'});
end

function feat = tail_features_real_tukey_v17(E,alg)
    % Four residual-tail features.  E may be a tensor or a vector.
    evec=E(:);
    evec=evec(isfinite(evec));
    if isempty(evec)
        feat=[0 0 0 0];
        return;
    end

    medv=memfix_median(evec,[],100000);
    sc=robust_mad_scale(evec,alg.eps0);
    if sc<=alg.eps0
        feat=[0 0 0 0];
        return;
    end

    ks=[alg.essTailK1 alg.essTailK2 alg.essTailK3];
    cnt=zeros(1,3);
    N=numel(evec);

    if isfield(alg,'memoryBlockSize') && isfinite(alg.memoryBlockSize)
        bs=max(1000,round(alg.memoryBlockSize));
    else
        bs=100000;
    end

    for st=1:bs:N
        en=min(N,st+bs-1);
        z=abs(evec(st:en)-medv)./sc;
        cnt=cnt+[sum(z>ks(1)) sum(z>ks(2)) sum(z>ks(3))];
    end
    p=cnt/N;

    % Localized concentration feature.  For a true p-by-q-by-n tensor,
    % compute within-sample k1-tail fractions and use a high quantile.
    concentration=p(1);
    if ndims(E)>=3 && size(E,3)>1
        n=size(E,3);
        sf=zeros(n,1);
        for i=1:n
            Ei=E(:,:,i);
            zi=abs(Ei-medv)./sc;
            sf(i)=mean(zi(:)>ks(1));
        end
        concentration=local_percentile(sf,alg.sampleTailQuantile);
    end

    feat=[p concentration];
end

function p = tail_probabilities_real_tukey_v17(evec,alg)
    % Compatibility helper returning only global tail probabilities.
    feat=tail_features_real_tukey_v17(evec,alg);
    p=feat(1:3);
end

function s = empirical_tail_severity_from_features_v17(feat,baseF,alg)
    % Empirical excess severity.  F4 contributes to structured/localized
    % corruption detection without requiring contamination labels.
    ex=max(0,feat-baseF);
    if numel(ex)>=4
        s=max([ex(1),1.3*ex(2),1.6*ex(3),ex(4)]);
    else
        s=max([ex(1),1.3*ex(2),1.6*ex(3)]);
    end
    s=min(max(s,0),alg.tailSeverityCap);
end

function s = empirical_tail_severity_from_probs_v17(p,baseP,alg)
    % Backwards-compatible 3-feature wrapper.
    s=empirical_tail_severity_from_features_v17(p,baseP,alg);
end

function s = estimate_tail_severity_raw_v17(evec,alg)
    % Gaussian-reference statistic retained only as an audit/fallback helper.
    p=tail_probabilities_real_tukey_v17(evec,alg);
    ks=[alg.essTailK1 alg.essTailK2 alg.essTailK3];
    base=[erfc(ks(1)/sqrt(2)) erfc(ks(2)/sqrt(2)) erfc(ks(3)/sqrt(2))];
    s=empirical_tail_severity_from_probs_v17(p,base,alg);
end

function ref = tail_reference_for_tensor_real_tukey_v17(cfg,X)
    % Tensor dimensions uniquely identify datasets in this configured suite.
    ref = struct('enabled',false,'baselineFeatures',[],'baselineP',[], ...
        'severityThreshold',cfg.alg.tailSeverityCleanThreshold,'k',[], ...
        'sampleTailQuantile',cfg.alg.sampleTailQuantile,'nRep',0,'source','fallback');

    if ~isfield(cfg,'tailReference') || isempty(cfg.tailReference)
        return;
    end

    sz=size(X);
    p=sz(1); q=sz(2);
    names=fieldnames(cfg.default_size);
    for i=1:numel(names)
        nm=names{i};
        dsiz=cfg.default_size.(nm);
        if numel(dsiz)>=2 && dsiz(1)==p && dsiz(2)==q && ...
                isfield(cfg.tailReference,nm)
            ref=cfg.tailReference.(nm);
            return;
        end
    end
end

function thr = tail_threshold_for_tensor_real_tukey_v17(cfg,X)
    ref=tail_reference_for_tensor_real_tukey_v17(cfg,X);
    thr=ref.severityThreshold;
end

function out = ternary_real_tukey_v17(tf,a,b)
    if tf, out=a; else, out=b; end
end

%% =========================================================================
% V1.7 CLEAN DEVELOPMENT CALIBRATION: SAMPLE-LEVEL RESIDUAL NULL
% ==========================================================================
function [cfg,Traw,Tref] = calibrate_clean_sample_real_tukey_v17(allData,cfg)
    % V1.7 CLEAN-ONLY pooled sample-score calibration.
    %
    % The calibration unit is the INDIVIDUAL clean sample residual z-score,
    % pooled across many clean development splits.  This avoids estimating a
    % 95th percentile from only a handful of split-level shift statistics.
    % The resulting neutral/full-downweight thresholds are frozen before
    % R1--R8 and are never tuned on probe/test outcomes.

    rows={}; rid=0; refRows={};

    if ~cfg.sampleCalib.enabled
        for id=1:numel(cfg.datasets)
            key=safe_field_name_real_tukey_v1(cfg.datasets{id});
            ref=struct('enabled',false,'neutralThreshold',Inf, ...
                'fullDownweightThreshold',Inf,'nRep',0,'nPooled',0, ...
                'neutralQuantile',cfg.sampleCalib.neutralQuantile, ...
                'fullDownweightQuantile',cfg.sampleCalib.fullDownweightQuantile, ...
                'source','disabled');
            cfg.sampleReference.(key)=ref;
        end
        Traw=table(); Tref=table(); return;
    end

    q0=cfg.sampleCalib.neutralQuantile;
    q1=cfg.sampleCalib.fullDownweightQuantile;
    if ~(q0>0 && q0<q1 && q1<100)
        error('V1.7 requires 0 < neutralQuantile < fullDownweightQuantile < 100.');
    end

    for id=1:numel(cfg.datasets)
        dname=cfg.datasets{id}; key=safe_field_name_real_tukey_v1(dname);
        ds=allData.(key); [r,c]=get_rank_real_tukey_v1(cfg,dname,size(ds.X));
        large=any(strcmpi(dname,{'PIE','XM2VTS'}));
        if large, nRep=cfg.sampleCalib.repeats.large; else, nRep=cfg.sampleCalib.repeats.small; end

        zCell=cell(nRep,1);
        qMat=nan(nRep,5);
        nMat=zeros(nRep,1);

        for rep=1:nRep
            % Development-only seed family.  It is deliberately separate
            % from the fresh R1--R8 evaluation seed family.
            seed=1720000+10000*id+rep;
            [idxSub,~,~]=split_threeway_by_identity_real_tukey_v1(ds.labels,cfg.splitRatios,seed);
            Xsub=ds.X(:,:,idxSub);

            dummy=method_struct_real_tukey_v1( ...
                'CALIB','bpca','tukey','ess','auto',NaN,true,true);
            [Ui,Vi]=initialize_bpca_v6(Xsub,r,c,dummy,cfg.alg);
            Ei=residual_tensor(Xsub,Ui,Vi);
            zInit=sample_residual_z_v17(Ei,cfg.alg.eps0);
            clear Ei Ui Vi

            [Ul,Vl,~]=train_l2_bpca_v6(Xsub,r,c,12,1e-6);
            El=residual_tensor(Xsub,Ul,Vl);
            zL2=sample_residual_z_v17(El,cfg.alg.eps0);
            clear El Ul Vl

            nz=min(numel(zInit),numel(zL2));
            zNull=max(zInit(1:nz),zL2(1:nz));
            zNull=zNull(isfinite(zNull));
            zCell{rep}=zNull(:);
            nMat(rep)=numel(zNull);
            if ~isempty(zNull)
                qMat(rep,:)=[local_percentile(zNull,50),local_percentile(zNull,90), ...
                    local_percentile(zNull,95),local_percentile(zNull,99),max(zNull)];
            end

            rid=rid+1;
            rows(rid,:)={dname,rep,seed,r,c,nMat(rep), ...
                qMat(rep,1),qMat(rep,2),qMat(rep,3),qMat(rep,4),qMat(rep,5)}; %#ok<AGROW>
        end

        zPool=vertcat(zCell{:});
        zPool=zPool(isfinite(zPool));
        if isempty(zPool)
            c0=cfg.alg.sampleTauC;
            c1=max(c0+cfg.sampleCalib.minTransitionGap,c0*1.25);
        else
            c0=local_percentile(zPool,q0);
            c1=local_percentile(zPool,q1);
            c1=max(c1,c0+cfg.sampleCalib.minTransitionGap);
        end

        cleanEntryRate=mean(zPool>c0);
        cleanFullRate=mean(zPool>=c1);
        pooledQ90=local_percentile(zPool,90);
        pooledQ95=local_percentile(zPool,95);
        pooledQ99=local_percentile(zPool,99);
        pooledQ995=local_percentile(zPool,99.5);

        ref=struct('enabled',true,'neutralThreshold',c0, ...
            'fullDownweightThreshold',c1,'nRep',nRep,'nPooled',numel(zPool), ...
            'neutralQuantile',q0,'fullDownweightQuantile',q1, ...
            'cleanEntryRate',cleanEntryRate,'cleanFullRate',cleanFullRate, ...
            'source','clean_development_pooled_neutral_zone');
        cfg.sampleReference.(key)=ref;

        refRows(end+1,:)={dname,c0,c1,q0,q1,cleanEntryRate,cleanFullRate, ...
            pooledQ90,pooledQ95,pooledQ99,pooledQ995,nRep,numel(zPool)}; %#ok<AGROW>

        fprintf(['  [R0C][%s] pooled clean sample-z | c0(Q%.1f)=%.3f | ' ...
            'c1(Q%.1f)=%.3f | entry=%.4f | full=%.4f | nRep=%d | Npool=%d\n'], ...
            dname,q0,c0,q1,c1,cleanEntryRate,cleanFullRate,nRep,numel(zPool));
    end

    Traw=cell2table(rows,'VariableNames',{ ...
        'Dataset','Repeat','Seed','RankR','RankC','NSamples', ...
        'Q50Z','Q90Z','Q95Z','Q99Z','MaxZ'});
    Tref=cell2table(refRows,'VariableNames',{ ...
        'Dataset','NeutralThreshold','FullDownweightThreshold', ...
        'NeutralQuantile','FullDownweightQuantile','CleanEntryRate','CleanFullRate', ...
        'PooledQ90','PooledQ95','PooledQ99','PooledQ995','NRep','NPooledScores'});
end

function z = sample_residual_z_v17(E,eps0)
    n=size(E,3); score=zeros(n,1);
    for i=1:n
        Ei=E(:,:,i);
        score(i)=norm(Ei,'fro')/sqrt(numel(Ei));
    end
    medv=median(score);
    sc=robust_mad_scale(score,eps0);
    if sc<=eps0
        z=zeros(n,1); return;
    end
    % Structural sample outliers are expected to have unusually LARGE
    % reconstruction residuals.  Use one-sided positive robust z-scores.
    z=max(0,(score-medv)./sc);
end

function ref = sample_reference_for_tensor_real_tukey_v17(cfg,X)
    ref=struct('enabled',false,'neutralThreshold',Inf, ...
        'fullDownweightThreshold',Inf,'nRep',0,'nPooled',0, ...
        'neutralQuantile',95,'fullDownweightQuantile',99.5, ...
        'cleanEntryRate',0,'cleanFullRate',0,'source','fallback');
    if ~isfield(cfg,'sampleReference') || isempty(cfg.sampleReference), return; end
    sz=size(X); p=sz(1); q=sz(2);
    names=fieldnames(cfg.default_size);
    for i=1:numel(names)
        nm=names{i}; dsiz=cfg.default_size.(nm);
        if numel(dsiz)>=2 && dsiz(1)==p && dsiz(2)==q && ...
                isfield(cfg.sampleReference,nm)
            ref=cfg.sampleReference.(nm); return;
        end
    end
end

%% =========================================================================
% METHOD LISTS / METHOD WRAPPER
% ==========================================================================
function methods = make_main_methods_real_tukey_v1()
    methods(1) = method_struct_real_tukey_v1('L2-BPCA','bpca','l2','none','none',NaN,false,true);
    methods(2) = method_struct_real_tukey_v1('Huber-BPCA','bpca','huber','fixed','none',NaN,false,true);
    methods(3) = method_struct_real_tukey_v1('Welsch-BPCA','bpca','welsch','fixed','none',NaN,false,true);
    methods(4) = method_struct_real_tukey_v1('Fixed-Tukey-BPCA','bpca','tukey','fixed','none',NaN,false,true);
    methods(5) = method_struct_real_tukey_v1('ESS-Tukey-BPCA-eta85','bpca','tukey','ess','fixed',0.85,true,true);
    methods(6) = method_struct_real_tukey_v1('ESS-Tukey-BPCA-auto','bpca','tukey','ess','auto',NaN,true,true);
    methods(7) = method_struct_real_tukey_v1('L1RBPCA','l1','l1','none','none',NaN,false,true);
end

function methods = make_samplewise_main_methods_real_tukey_v17()
    % R3 matched-SW main comparison: all robust M-estimator baselines receive
    % the same sample-weight layer. Names are kept identical to R1/R2 so
    % paired publication code remains simple; the R3 protocol is documented
    % explicitly as MATCHED_SAMPLE_WEIGHT.
    methods(1) = method_struct_real_tukey_v1('L2-BPCA','bpca','l2','none','none',NaN,false,true);
    methods(2) = method_struct_real_tukey_v1('Huber-BPCA','bpca','huber','fixed','none',NaN,true,true);
    methods(3) = method_struct_real_tukey_v1('Welsch-BPCA','bpca','welsch','fixed','none',NaN,true,true);
    methods(4) = method_struct_real_tukey_v1('Fixed-Tukey-BPCA','bpca','tukey','fixed','none',NaN,true,true);
    methods(5) = method_struct_real_tukey_v1('ESS-Tukey-BPCA-eta85','bpca','tukey','ess','fixed',0.85,true,true);
    methods(6) = method_struct_real_tukey_v1('ESS-Tukey-BPCA-auto','bpca','tukey','ess','auto',NaN,true,true);
    methods(7) = method_struct_real_tukey_v1('L1RBPCA','l1','l1','none','none',NaN,false,true);
end

function methods = make_ablation_methods_real_tukey_v1()
    % Targeted V1.7 ablations.  Different components are tested in the
    % scenario where they are scientifically intended to operate.
    methods(1) = method_struct_real_tukey_v1('Fixed-Tukey-noSW','bpca','tukey','fixed','none',NaN,false,true);
    methods(2) = method_struct_real_tukey_v1('ESS-eta85-noSW','bpca','tukey','ess','fixed',0.85,false,true);
    methods(3) = method_struct_real_tukey_v1('ESS-auto-noSW','bpca','tukey','ess','auto',NaN,false,true);
    methods(4) = method_struct_real_tukey_v1('ESS-auto-noSW-noElemGuard','bpca','tukey','ess','auto',NaN,false,false);
    methods(5) = method_struct_real_tukey_v1('ESS-auto-noSW-noZeroCal','bpca','tukey','ess','auto',NaN,false,true);
    methods(6) = method_struct_real_tukey_v1('ESS-auto-SW','bpca','tukey','ess','auto',NaN,true,true);
    methods(7) = method_struct_real_tukey_v1('ESS-auto-SW-noSampleGuard','bpca','tukey','ess','auto',NaN,true,true);
    methods(5).useZeroCalibrationOverride = false;
    methods(7).sampleGuard = false;
end

function methods = make_matched_sw_methods_real_tukey_v1()
    methods(1) = method_struct_real_tukey_v1('Huber-SW','bpca','huber','fixed','none',NaN,true,true);
    methods(2) = method_struct_real_tukey_v1('Welsch-SW','bpca','welsch','fixed','none',NaN,true,true);
    methods(3) = method_struct_real_tukey_v1('Fixed-Tukey-SW','bpca','tukey','fixed','none',NaN,true,true);
    methods(4) = method_struct_real_tukey_v1('ESS-eta85-SW','bpca','tukey','ess','fixed',0.85,true,true);
    methods(5) = method_struct_real_tukey_v1('ESS-auto-SW','bpca','tukey','ess','auto',NaN,true,true);
end

function m = method_struct_real_tukey_v1(name,engine,loss,cutoff,etaMode,etaValue,sampleMode,cleanGuard)
    m = struct('name',name,'engine',engine,'loss',loss,'cutoff',cutoff, ...
        'etaMode',etaMode,'etaValue',etaValue,'sampleMode',sampleMode, ...
        'cleanGuard',cleanGuard,'sampleGuard',true);
end

function model = fit_method_real_tukey_v1_core(X,r,c,method,cfg)
    if strcmpi(method.engine,'l1')
        t0 = tic;
        fit = L1RBPCA_fit_real_tukey_v1(X,r,c,cfg.l1_tol);
        model = struct();
        model.U = fit.U; model.V = fit.V;
        % L1RBPCA has no explicit element/sample anomaly score.
        model.W = NaN;
        model.finalTau = NaN; model.finalEta = NaN;
        model.finalTailSeverity = NaN; model.finalCurrentTailSeverity = NaN;
        model.finalESSElement = NaN; model.finalESSCombined = NaN;
        model.finalMeanW = NaN; model.finalZeroW = NaN; model.finalObj = NaN;
        model.finalSampleOutlierRate = NaN;
        model.finalSampleMeanWeight = NaN;
        model.finalSampleSeverity = NaN;
        model.finalSampleActivationStrength = NaN;
        model.finalSampleDownweightStrength = NaN;
        model.finalSampleNeutralThreshold = NaN;
        model.finalSampleFullDownweightThreshold = NaN;
        model.finalSampleAnyDownweight = NaN;
        model.finalSampleActivated = NaN;
        % Unified sample-weight interface:
        % L1RBPCA does not perform sample reweighting, therefore all
        % samples keep unit weight for sample-wise audit.
        model.finalSampleWeights = ones(size(X,3),1);
        model.outerIters = NaN; model.mmRejectCount = 0; model.status = 'ok';
        model.TimeInternal = toc(t0);
    else
        m = rmfield(method,'engine');
        algLocal = cfg.alg;

        % V1.7: inject the dataset-specific EMPIRICAL clean-tail reference.
        % This reference was calibrated only from clean development splits.
        if isfield(cfg.alg,'realTailReferenceEnabled') && ...
                cfg.alg.realTailReferenceEnabled
            algLocal.realTail = tail_reference_for_tensor_real_tukey_v17(cfg,X);
        end
        if isfield(cfg,'sampleReference') && ~isempty(cfg.sampleReference)
            algLocal.realSample = sample_reference_for_tensor_real_tukey_v17(cfg,X);
        end

        % Ablation-only override: switch zero-weight calibration on/off while
        % keeping every other component identical.
        if isfield(m,'useZeroCalibrationOverride') && ...
                ~isempty(m.useZeroCalibrationOverride)
            algLocal.useZeroCalibration = logical(m.useZeroCalibrationOverride);
            m = rmfield(m,'useZeroCalibrationOverride');
        end

        model = train_method_bpca_v6(X,r,c,m,algLocal);

        % ================================================================
        % V1.7 unified model-output interface
        %
        % Some baseline BPCA engines do not contain sample-level weights.
        % For these methods, unit weights mean that no explicit sample
        % downweighting is performed. This keeps R3/R6/R8 sample audits
        % comparable across all methods.
        % ================================================================
        if ~isfield(model,'finalSampleWeights') || isempty(model.finalSampleWeights)
            model.finalSampleWeights = ones(size(X,3),1);
        end

        if ~isfield(model,'finalSampleMeanWeight') || isempty(model.finalSampleMeanWeight)
            model.finalSampleMeanWeight = mean(model.finalSampleWeights);
        end

        if ~isfield(model,'finalSampleOutlierRate') || isempty(model.finalSampleOutlierRate)
            model.finalSampleOutlierRate = mean(model.finalSampleWeights < 0.999);
        end

        if ~isfield(model,'finalSampleAnyDownweight') || isempty(model.finalSampleAnyDownweight)
            model.finalSampleAnyDownweight = any(model.finalSampleWeights < 0.999);
        end
    end
end

%% =========================================================================
% SHARED CLEAN REFERENCE / EVALUATION
% ==========================================================================
function ref = fit_clean_references_real_tukey_v1(Xsub,Xgal,ygal,Xprobe,yprobe,r,c,methods,cfg)
    % MEMORY-SAFE V1.1:
    % Clean references are used only for U/V drift, baseline ACC and NRE.
    % Do NOT retain the dense p-by-q-by-n weight tensor for every method.
    ref = repmat(struct('model',[],'ACC',NaN,'NRE',NaN),numel(methods),1);
    for mm = 1:numel(methods)
        model = fit_method_real_tukey_v1(Xsub,r,c,methods(mm),cfg);
        compact = struct('U',model.U,'V',model.V,'status',model.status);
        ref(mm).model = compact;
        ref(mm).ACC = recognition_accuracy_real_tukey_v1( ...
            Xgal,ygal,Xprobe,yprobe,model.U,model.V,cfg);
        ref(mm).NRE = projection_nre_real_tukey_v1(Xprobe,model.U,model.V);
        clear model compact
    end
end

function acc = recognition_accuracy_real_tukey_v1(Xgal,ygal,Xprobe,yprobe,U,V,cfg)
    G = extract_features_real_tukey_v1(Xgal,U,V);
    P = extract_features_real_tukey_v1(Xprobe,U,V);
    if cfg.classifier.zscoreFeatures
        mu = mean(G,2); sd = std(G,0,2); sd(sd<1e-10)=1;
        G = (G-mu)./sd; P = (P-mu)./sd;
    end
    pred = nn1_predict_real_tukey_v1(G,ygal,P);
    acc = mean(pred(:)==yprobe(:));
end

function Z = extract_features_real_tukey_v1(X,U,V)
    U = orth(U); V = orth(V);
    T = size(X,3); d = size(U,2)*size(V,2);
    Z = zeros(d,T);
    for t=1:T
        F = U'*X(:,:,t)*V;
        Z(:,t) = F(:);
    end
end

function pred = nn1_predict_real_tukey_v1(G,yG,P)
    ng = sum(G.^2,1)'; np = sum(P.^2,1);
    D = max(0,ng + np - 2*(G'*P));
    [~,ix] = min(D,[],1);
    pred = yG(ix);
end

function nre = projection_nre_real_tukey_v1(X,U,V)
    Xhat = reconstruct_tensor(X,U,V);
    nre = norm(X(:)-Xhat(:))/max(norm(X(:)),eps);
end

function [dr,dc,db] = bilateral_drift_real_tukey_v1(U0,V0,U1,V1)
    dr = projection_distance_normalized_real_tukey_v1(U0,U1);
    dc = projection_distance_normalized_real_tukey_v1(V0,V1);
    db = 0.5*(dr+dc);
end

function d = projection_distance_normalized_real_tukey_v1(A,B)
    A = orth(A); B = orth(B);
    k = min(size(A,2),size(B,2));
    A = A(:,1:k); B = B(:,1:k);
    d = norm(A*A'-B*B','fro')/sqrt(2*k);
end

function z = safe_ratio_real_tukey_v1(a,b)
    if ~isfinite(a) || ~isfinite(b) || abs(b)<1e-12, z=NaN; else, z=a/b; end
end

function v = model_field_or_nan_v17(model,fieldName)
    if isstruct(model) && isfield(model,fieldName)
        v=model.(fieldName);
        if isempty(v), v=NaN; end
    else
        v=NaN;
    end
end

function [roc,pr] = conditional_element_metrics_v17(W,mask)
    % Pixel/cell localization restricted to samples that are actually
    % contaminated.  Global metrics are still reported separately.
    roc=NaN; pr=NaN;
    if isempty(mask) || ~any(mask(:)), return; end
    if isempty(W) || (isscalar(W) && ~isfinite(W)), return; end

    samp=squeeze(any(any(mask,1),2));
    idx=find(samp);
    if isempty(idx), return; end

    M=mask(:,:,idx);
    if isscalar(W)
        score=zeros(size(M));
    else
        score=1-W(:,:,idx);
    end

    if any(M(:)) && any(~M(:))
        roc=binary_auc_tied(score(:),M(:));
        pr=binary_pr_auc_v6(score(:),M(:));
    end
end

%% =========================================================================
% R2: NESTED CELLWISE CONTAMINATION
% ==========================================================================
function plan = make_element_contamination_plan_real_tukey_v1(X,type,maxRate,seed,cfg)
    rng(seed,'twister');
    [p,q,T] = size(X);
    plan = struct(); plan.type = type; plan.seed = seed;
    plan.scale = robust_mad_scale(X(:),1e-12);
    if plan.scale < 1e-8, plan.scale = std(X(:))+1e-8; end

    switch lower(type)
        case 'impulse'
            totalN = numel(X);
            mmax = min(totalN,max(1,ceil(maxRate*totalN)));
            plan.order = randperm(totalN,mmax);
            plan.signs = 2*(rand(mmax,1)>0.5)-1;
            plan.mult = 0.75 + 0.50*rand(mmax,1);
        case 'block'
            bh = max(2,round(cfg.blockRatio*p));
            bw = max(2,round(cfg.blockRatio*q));
            maxBlocks = ceil(maxRate*p*q*T/max(1,bh*bw))*3 + 20;
            plan.bh = bh; plan.bw = bw;
            plan.sample = randi(T,maxBlocks,1);
            plan.r0 = randi(max(1,p-bh+1),maxBlocks,1);
            plan.c0 = randi(max(1,q-bw+1),maxBlocks,1);
            plan.signs = 2*(rand(maxBlocks,1)>0.5)-1;
            plan.mult = 0.80 + 0.40*rand(maxBlocks,1);
        otherwise
            error('Unknown cellwise contamination type: %s',type);
    end
end

function [Xout,mask,actualRate] = apply_element_contamination_plan_real_tukey_v1(X,plan,rate,strength,cfg) %#ok<INUSD>
    Xout = X; mask = false(size(X));
    if rate<=0, actualRate=0; return; end

    switch lower(plan.type)
        case 'impulse'
            m = min(numel(plan.order),round(rate*numel(X)));
            idx = plan.order(1:m);
            delta = strength*plan.scale .* plan.signs(1:m).*plan.mult(1:m);
            tmp = Xout(:); tmp(idx) = tmp(idx)+delta; Xout = reshape(tmp,size(X));
            mask(idx) = true;
        case 'block'
            b = 0;
            while mean(mask(:)) < rate && b < numel(plan.sample)
                b = b+1;
                i = plan.sample(b);
                rr = plan.r0(b):(plan.r0(b)+plan.bh-1);
                cc = plan.c0(b):(plan.c0(b)+plan.bw-1);
                delta = strength*plan.scale*plan.signs(b)*plan.mult(b);
                Xout(rr,cc,i) = Xout(rr,cc,i)+delta;
                mask(rr,cc,i) = true;
            end
    end
    actualRate = mean(mask(:));
end

%% =========================================================================
% R3: SAMPLEWISE OUTLIERS
% ==========================================================================
function plan = make_sample_contamination_plan_real_tukey_v1(X,FP,maxRate,seed,cfg) %#ok<INUSD>
    rng(seed,'twister');
    T = size(X,3); nmax = max(1,ceil(maxRate*T));
    plan.targetOrder = randperm(T,min(T,nmax));
    if ~isempty(FP.X)
        NF = size(FP.X,3);
        if NF <= nmax
            plan.foreignOrder = repmat(randperm(NF),1,ceil(nmax/NF));
        else
            plan.foreignOrder = randperm(NF,nmax);
        end
    else
        plan.foreignOrder = [];
    end
end

function [Xout,mask,actualRate] = apply_sample_contamination_plan_real_tukey_v1(X,FP,plan,rate,cfg)
    [p,q,T] = size(X); Xout = X; mask = false(size(X));
    n = min(T,max(0,round(rate*T)));
    if n==0, actualRate=0; return; end
    if isempty(FP.X)
        error('RealTukey:MissingForeignPool','Real samplewise contamination requires a real foreign pool.');
    end

    for ii=1:n
        t = plan.targetOrder(ii);
        fidx = plan.foreignOrder(ii);
        A = FP.X(:,:,fidx);
        if size(A,1)~=p || size(A,2)~=q
            A = resize_matrix_bilinear_real_tukey_v1(A,p,q);
        end
        % Match preprocessing scale to prevent trivial database-amplitude cues.
        A = A-mean(A(:));
        A = A/max(norm(A,'fro'),eps)*sqrt(p*q);
        Xout(:,:,t) = A;
        mask(:,:,t) = true;
    end
    actualRate = mean(squeeze(any(any(mask,1),2)));
end

function [idxSub,idxGal,idxProbe,FP] = prepare_heldout_identity_protocol_real_tukey_v1(ds,cfg,seed)
    labels = ds.labels(:); cls = unique(labels); nCls = numel(cls);
    if nCls < 4, error('HeldoutIdentity:TooFewClasses','Need at least 4 identities.'); end
    rng(seed+31337,'twister');
    nHold = max(cfg.heldoutIdentityMinClasses,round(cfg.heldoutIdentityFraction*nCls));
    nHold = min(nCls-2,nHold);
    ord = randperm(nCls); held = cls(ord(1:nHold)); main = cls(ord(nHold+1:end));

    idxMain = find(ismember(labels,main));
    [a,b,c] = split_threeway_by_identity_real_tukey_v1(labels(idxMain),cfg.splitRatios,seed+17);
    idxSub = idxMain(a); idxGal = idxMain(b); idxProbe = idxMain(c);
    idxForeign = find(ismember(labels,held));
    FP = struct('X',ds.X(:,:,idxForeign),'source_name','same_dataset_heldout_identities', ...
        'mode','heldout_identity','is_real',true);
end

%% =========================================================================
% R4: NESTED LOCAL OCCLUSION
% ==========================================================================
function plan = make_local_occlusion_plan_real_tukey_v1(X,sampleRatio,scenario,seed,cfg)
    rng(seed,'twister');
    [p,q,T] = size(X); n = max(1,min(T,round(sampleRatio*T)));
    plan.idx = randperm(T,n);
    plan.scenario = scenario;
    maxArea = max(cfg.localAreaList);
    if strcmpi(scenario,'random_block')
        target = max(1,round(maxArea*p*q));
        hmax = max(1,min(p,round(sqrt(target*p/q))));
        wmax = max(1,min(q,round(target/hmax)));
        rmin=1+floor((hmax-1)/2); rmax=p-ceil((hmax-1)/2);
        cmin=1+floor((wmax-1)/2); cmax=q-ceil((wmax-1)/2);
        if rmax<rmin, rmin=ceil(p/2); rmax=rmin; end
        if cmax<cmin, cmin=ceil(q/2); cmax=cmin; end
        plan.cr = randi([rmin rmax],n,1);
        plan.cc = randi([cmin cmax],n,1);
    else
        plan.cr=[]; plan.cc=[];
    end
end

function [Xout,mask,actualRate] = apply_local_occlusion_plan_real_tukey_v1(X,plan,area,scenario,cfg)
    [p,q,~] = size(X); Xout=X; mask=false(size(X));
    for ii=1:numel(plan.idx)
        t=plan.idx(ii); A=Xout(:,:,t); fill=local_fill_real_tukey_v1(A,cfg.localFillMode);
        switch lower(scenario)
            case 'random_block'
                target=max(1,round(area*p*q));
                h=max(1,min(p,round(sqrt(target*p/q))));
                w=max(1,min(q,round(target/h)));
                cr=plan.cr(ii); cc=plan.cc(ii);
                r0=max(1,min(p-h+1,cr-floor((h-1)/2)));
                c0=max(1,min(q-w+1,cc-floor((w-1)/2)));
                rr=r0:r0+h-1; cc2=c0:c0+w-1;
            case 'eyes_band'
                h=max(1,min(p,round(area*p)));
                center=round(0.38*p); r0=max(1,min(p-h+1,center-floor((h-1)/2)));
                rr=r0:r0+h-1; cc2=1:q;
            case 'lower_face'
                h=max(1,min(p,round(area*p))); rr=(p-h+1):p; cc2=1:q;
            otherwise
                error('Unknown local scenario: %s',scenario);
        end
        A(rr,cc2)=fill; Xout(:,:,t)=A; mask(rr,cc2,t)=true;
    end
    actualRate=mean(mask(:));
end

function fill = local_fill_real_tukey_v1(A,mode)
    switch lower(mode)
        case 'low_quantile', fill=local_percentile(A(:),10);
        case 'median', fill=median(A(:));
        otherwise, fill=0;
    end
end

%% =========================================================================
% R5 MECHANISM TABLE
% ==========================================================================
function T = build_mechanism_table_real_tukey_v1(Tcell,Tsamp,Tlocal,cfg) %#ok<INUSD>
    % V1.7 TARGETED mechanism audit:
    %   element pathway -> IMPULSE only;
    %   sample pathway  -> CROSS-DATASET only.
    % Block/local occlusion remain robustness stress tests and are not mixed
    % into the mechanism curve, preventing successful impulse behavior from
    % hiding a different structured-corruption response.
    rows={}; id=0; auto='ESS-Tukey-BPCA-auto';

    idx=strcmp(Tcell.Method,auto) & strcmp(Tcell.ContamType,'impulse');
    A=Tcell(idx,:);
    for i=1:height(A)
        id=id+1; rows(id,:)={'R2_impulse_element',A.Dataset{i},A.ContamType{i}, ...
            A.NominalRate(i),A.ActualRate(i),A.Repeat(i), ...
            A.FinalTailSeverity(i),A.FinalCurrentTailSeverity(i),A.FinalEta(i),A.FinalESSElement(i), ...
            A.FinalESSCombined(i),A.FinalZeroW(i), ...
            NaN,NaN,NaN,NaN,NaN,NaN,NaN, ...
            A.ACCRetention(i),A.BiDrift(i),A.ElemROCAUC(i),A.ElemPRAUC(i), ...
            NaN,NaN}; %#ok<AGROW>
    end

    idx=strcmp(Tsamp.Method,auto) & strcmp(Tsamp.Scenario,'cross_dataset');
    A=Tsamp(idx,:);
    for i=1:height(A)
        id=id+1; rows(id,:)={'R3_cross_dataset_sample',A.Dataset{i},A.Scenario{i}, ...
            A.NominalRate(i),A.ActualRate(i),A.Repeat(i), ...
            A.FinalTailSeverity(i),A.FinalCurrentTailSeverity(i),A.FinalEta(i),A.FinalESSElement(i), ...
            A.FinalESSCombined(i),A.FinalZeroW(i), ...
            A.FinalSampleOutlierRate(i),A.FinalSampleMeanWeight(i), ...
            A.FinalSampleCleanMeanWeight(i),A.FinalSampleForeignMeanWeight(i),A.FinalSampleWeightGap(i), ...
            A.FinalSampleSeverity(i),A.FinalSampleDownweightStrength(i),A.ACCRetention(i),A.BiDrift(i),A.ElemROCAUC(i),A.ElemPRAUC(i), ...
            A.SampleROCAUC(i),A.SamplePRAUC(i)}; %#ok<AGROW>
    end

    T=cell2table(rows,'VariableNames',{ ...
        'Experiment','Dataset','Scenario','NominalSeverity','ActualRate','Repeat', ...
        'ElementTailSeverityUsed','ElementTailSeverityCurrent','Eta','ESSElement','ESSCombined','ElementZeroW', ...
        'SampleOutlierRate','SampleMeanWeight','SampleCleanMeanWeight','SampleForeignMeanWeight','SampleWeightGap', ...
        'SampleSeverity','SampleDownweightStrength', ...
        'ACCRetention','BiDrift','ElemROCAUC','ElemPRAUC', ...
        'SampleROCAUC','SamplePRAUC'});
end

function T = run_eta_validation_real_tukey_v17(allData,cfg)
    rows={}; rid=0;
    % R7 isolates the element-level eta mechanism: sample weighting OFF.
    autoM = method_struct_real_tukey_v1( ...
        'ESS-Tukey-BPCA-auto','bpca','tukey','ess','auto',NaN,false,true);
    eta85M = method_struct_real_tukey_v1( ...
        'ESS-Tukey-BPCA-eta85','bpca','tukey','ess','fixed',0.85,false,true);

    for id=1:numel(cfg.datasets)
        dname=cfg.datasets{id}; ds=allData.(safe_field_name_real_tukey_v1(dname));
        [r,c]=get_rank_real_tukey_v1(cfg,dname,size(ds.X));
        large=any(strcmpi(dname,{'PIE','XM2VTS'}));
        if large, nRep=cfg.etaValidation.repeats.large; else, nRep=cfg.etaValidation.repeats.small; end

        for isc=1:numel(cfg.etaValidation.scenarios)
            scenario=cfg.etaValidation.scenarios{isc};
            for rep=1:nRep
                seed=cfg.evalSeedOffset+1800000+100000*id+10000*isc+rep;
                [idxSub,idxGal,idxProbe]=split_threeway_by_identity_real_tukey_v1( ...
                    ds.labels,cfg.splitRatios,seed);
                Xsub0=ds.X(:,:,idxSub); Xgal=ds.X(:,:,idxGal); ygal=ds.labels(idxGal);
                Xprobe=ds.X(:,:,idxProbe); yprobe=ds.labels(idxProbe);

                if ~strcmpi(scenario,'impulse')
                    error('V1.7 R7 supports the targeted impulse eta-validation scenario only.');
                end
                plan=make_element_contamination_plan_real_tukey_v1( ...
                    Xsub0,cfg.etaValidation.elementType,cfg.etaValidation.elementRate,seed+333,cfg);
                [Xsub,mask,actualRate]=apply_element_contamination_plan_real_tukey_v1( ...
                    Xsub0,plan,cfg.etaValidation.elementRate,cfg.etaValidation.elementStrength,cfg);
                nominalRate=cfg.etaValidation.elementRate;
                contamType=cfg.etaValidation.elementType;

                % Eta selected only by clean-gallery projection NRE.
                valNRE=nan(numel(cfg.etaValidation.grid),1);
                for ie=1:numel(cfg.etaValidation.grid)
                    eta=cfg.etaValidation.grid(ie);
                    m=method_struct_real_tukey_v1( ...
                        'ETA-CANDIDATE','bpca','tukey','ess','fixed',eta,false,true);
                    mod=fit_method_real_tukey_v1(Xsub,r,c,m,cfg);
                    valNRE(ie)=projection_nre_real_tukey_v1(Xgal,mod.U,mod.V);
                    clear mod
                end
                [bestValNRE,ib]=min(valNRE); bestEta=cfg.etaValidation.grid(ib);
                valBestM=method_struct_real_tukey_v1( ...
                    'ESS-Tukey-BPCA-valbest','bpca','tukey','ess','fixed',bestEta,false,true);

                trio={autoM,eta85M,valBestM};
                for im=1:numel(trio)
                    m=trio{im}; mod=fit_method_real_tukey_v1(Xsub,r,c,m,cfg);
                    testACC=recognition_accuracy_real_tukey_v1( ...
                        Xgal,ygal,Xprobe,yprobe,mod.U,mod.V,cfg);
                    testNRE=projection_nre_real_tukey_v1(Xprobe,mod.U,mod.V);
                    thisValNRE=projection_nre_real_tukey_v1(Xgal,mod.U,mod.V);
                    [eroc,epr,sroc,spr]=outlier_metrics_v6(mod.W,mask,contamType);
                    if strcmp(m.name,'ESS-Tukey-BPCA-valbest')
                        selectedEta=bestEta; thisValNRE=bestValNRE;
                    elseif strcmp(m.name,'ESS-Tukey-BPCA-eta85')
                        selectedEta=0.85;
                    else
                        selectedEta=mod.finalEta;
                    end
                    rid=rid+1;
                    rows(rid,:)={dname,scenario,nominalRate,actualRate,rep,seed,m.name, ...
                        selectedEta,thisValNRE,testACC,testNRE,eroc,epr,sroc,spr, ...
                        mod.finalEta,model_field_or_nan_v17(mod,'finalTailSeverity'), ...
                        model_field_or_nan_v17(mod,'finalCurrentTailSeverity'), ...
                        mod.finalESSElement,mod.finalESSCombined,mod.finalZeroW,mod.status}; %#ok<AGROW>
                    clear mod
                end
            end
        end
    end

    T=cell2table(rows,'VariableNames',{ ...
        'Dataset','Scenario','NominalRate','ActualRate','Repeat','Seed','Method', ...
        'SelectedEta','ValidationNRE','TestACC','TestNRE','ElemROCAUC','ElemPRAUC', ...
        'SampleROCAUC','SamplePRAUC','FinalEta','FinalTailSeverity', ...
        'FinalCurrentTailSeverity','FinalESSElement','FinalESSCombined','FinalZeroW','Status'});
end

function R = build_eta_regret_real_tukey_v17(T)
    rows={}; rid=0;
    if isempty(T), R=table(); return; end
    ib=find(strcmp(T.Method,'ESS-Tukey-BPCA-valbest'));
    compareNames={'ESS-Tukey-BPCA-auto','ESS-Tukey-BPCA-eta85'};
    for k=1:numel(ib)
        j=ib(k); d=T.Dataset{j}; sc=T.Scenario{j}; rep=T.Repeat(j);
        bestACC=T.TestACC(j); bestNRE=T.TestNRE(j); bestVal=T.ValidationNRE(j); bestEta=T.SelectedEta(j);
        for m=1:numel(compareNames)
            idx=strcmp(T.Dataset,d) & strcmp(T.Scenario,sc) & T.Repeat==rep & strcmp(T.Method,compareNames{m});
            ii=find(idx,1);
            if isempty(ii), continue; end
            rid=rid+1;
            rows(rid,:)={d,sc,rep,compareNames{m},T.SelectedEta(ii),bestEta, ...
                bestACC-T.TestACC(ii),T.TestNRE(ii)-bestNRE, ...
                T.ValidationNRE(ii)-bestVal,abs(T.SelectedEta(ii)-bestEta)}; %#ok<AGROW>
        end
    end
    R=cell2table(rows,'VariableNames',{ ...
        'Dataset','Scenario','Repeat','Method','SelectedEta','ValidationBestEta', ...
        'ACCRegretToValBest','NRERegretToValBest','ValidationNREGap','EtaAbsoluteGap'});
end

%% =========================================================================
% R8 SAMPLE-WEIGHT ALPHA SENSITIVITY
% ==========================================================================
function T = run_alpha_sensitivity_real_tukey_v17(allData,foreignPools,cfg)
    % V1.7: alpha sensitivity is evaluated on CROSS-DATASET structural
    % sample contamination, not held-out identities.  This directly tests
    % the sample-weight layer in a setting where whole-sample residual
    % outliers are expected to be meaningful.

    rows={}; rid=0;
    autoM=method_struct_real_tukey_v1( ...
        'ESS-Tukey-BPCA-auto','bpca','tukey','ess','auto',NaN,true,true);

    scenario=cfg.alphaSensitivity.scenario;

    for id=1:numel(cfg.datasets)
        dname=cfg.datasets{id};
        ds=allData.(safe_field_name_real_tukey_v1(dname));
        [r,c]=get_rank_real_tukey_v1(cfg,dname,size(ds.X));

        large=any(strcmpi(dname,{'PIE','XM2VTS'}));
        if large
            nRep=cfg.alphaSensitivity.repeats.large;
        else
            nRep=cfg.alphaSensitivity.repeats.small;
        end

        FP=get_foreign_pool_real_tukey_v1(foreignPools,dname);
        if isempty(FP.X)
            fprintf(2,'[R8][%s] foreign pool unavailable; skipping.\n',dname);
            continue;
        end

        for rep=1:nRep
            seed=cfg.evalSeedOffset+1900000+10000*id+rep;

            [idxSub,idxGal,idxProbe]=split_threeway_by_identity_real_tukey_v1( ...
                ds.labels,cfg.splitRatios,seed);
            Xsub0=ds.X(:,:,idxSub);
            Xgal=ds.X(:,:,idxGal); ygal=ds.labels(idxGal);
            Xprobe=ds.X(:,:,idxProbe); yprobe=ds.labels(idxProbe);

            plan=make_sample_contamination_plan_real_tukey_v1( ...
                Xsub0,FP,cfg.alphaSensitivity.sampleRate,seed+444,cfg);
            [Xsub,mask,actualRate]=apply_sample_contamination_plan_real_tukey_v1( ...
                Xsub0,FP,plan,cfg.alphaSensitivity.sampleRate,cfg);

            for ia=1:numel(cfg.alphaSensitivity.list)
                alpha=cfg.alphaSensitivity.list(ia);
                cfgA=cfg;
                cfgA.alg.sampleWeightAlpha=alpha;

                ref=fit_method_real_tukey_v1(Xsub0,r,c,autoM,cfgA);
                baseACC=recognition_accuracy_real_tukey_v1( ...
                    Xgal,ygal,Xprobe,yprobe,ref.U,ref.V,cfgA);
                baseNRE=projection_nre_real_tukey_v1(Xprobe,ref.U,ref.V);

                mod=fit_method_real_tukey_v1(Xsub,r,c,autoM,cfgA);
                acc=recognition_accuracy_real_tukey_v1( ...
                    Xgal,ygal,Xprobe,yprobe,mod.U,mod.V,cfgA);
                nre=projection_nre_real_tukey_v1(Xprobe,mod.U,mod.V);
                [~,~,db]=bilateral_drift_real_tukey_v1(ref.U,ref.V,mod.U,mod.V);
                [~,~,sroc,spr]=outlier_metrics_v6(mod.W,mask,'sample');
                [sampleCleanW,sampleForeignW,sampleWeightGap]= ...
                    sample_weight_group_means_v17(mod.finalSampleWeights,mask);

                rid=rid+1;
                rows(rid,:)={dname,scenario,FP.source_name,'ESS-Tukey-BPCA-auto', ...
                    alpha,cfg.alphaSensitivity.sampleRate,actualRate,rep,seed, ...
                    baseACC,acc,safe_ratio_real_tukey_v1(acc,baseACC), ...
                    baseNRE,nre,safe_ratio_real_tukey_v1(nre,baseNRE),db,sroc,spr, ...
                    mod.finalEta,mod.finalESSElement,mod.finalESSCombined,mod.finalZeroW, ...
                    model_field_or_nan_v17(mod,'finalSampleOutlierRate'), ...
                    model_field_or_nan_v17(mod,'finalSampleMeanWeight'), ...
                    sampleCleanW,sampleForeignW,sampleWeightGap, ...
                    model_field_or_nan_v17(mod,'finalSampleSeverity'), ...
                    model_field_or_nan_v17(mod,'finalSampleDownweightStrength'), ...
                    model_field_or_nan_v17(mod,'finalSampleNeutralThreshold'), ...
                    model_field_or_nan_v17(mod,'finalSampleFullDownweightThreshold'), ...
                    model_field_or_nan_v17(mod,'finalSampleAnyDownweight'),mod.status}; %#ok<AGROW>

                clear ref mod cfgA
            end
        end
    end

    T=cell2table(rows,'VariableNames',{ ...
        'Dataset','Scenario','ForeignSource','Method','Alpha','NominalRate','ActualRate', ...
        'Repeat','Seed','BaselineACC','ACC','ACCRetention','BaselineNRE','NRE', ...
        'NREInflation','BiDrift','SampleROCAUC','SamplePRAUC','FinalEta', ...
        'FinalESSElement','FinalESSCombined','FinalZeroW','FinalSampleOutlierRate', ...
        'FinalSampleMeanWeight','FinalSampleCleanMeanWeight','FinalSampleForeignMeanWeight','FinalSampleWeightGap', ...
        'FinalSampleSeverity','FinalSampleDownweightStrength','FinalSampleNeutralThreshold', ...
        'FinalSampleFullDownweightThreshold','FinalSampleAnyDownweight','Status'});
end

%% =========================================================================
% R6 ABLATION / MATCHED SW
% ==========================================================================
function [Tabl,Tmatch] = run_ablation_real_tukey_v1(allData,foreignPools,cfg,methodsAbl,methodsMatched)
    rowsA={}; ia=0; rowsM={}; im=0;
    useDs=intersect(cfg.ablationDatasets,cfg.datasets,'stable');

    for id=1:numel(useDs)
        dname=useDs{id}; ds=allData.(safe_field_name_real_tukey_v1(dname));
        [r,c]=get_rank_real_tukey_v1(cfg,dname,size(ds.X));
        FP=get_foreign_pool_real_tukey_v1(foreignPools,dname);

        for rep=1:cfg.nRep.ablation
            seed=cfg.evalSeedOffset+1600000+10000*id+rep;
            [idxSub,idxGal,idxProbe]=split_threeway_by_identity_real_tukey_v1(ds.labels,cfg.splitRatios,seed);
            Xsub0=ds.X(:,:,idxSub); Xgal=ds.X(:,:,idxGal); ygal=ds.labels(idxGal);
            Xprobe=ds.X(:,:,idxProbe); yprobe=ds.labels(idxProbe);

            % ============================================================
            % A. CLEAN GUARD: element pathway only (sample weighting off).
            % ============================================================
            l2m=method_struct_real_tukey_v1('L2-CLEAN-REF','bpca','l2','none','none',NaN,false,true);
            l2mod=fit_method_real_tukey_v1(Xsub0,r,c,l2m,cfg);
            l2acc=recognition_accuracy_real_tukey_v1(Xgal,ygal,Xprobe,yprobe,l2mod.U,l2mod.V,cfg);
            l2nre=projection_nre_real_tukey_v1(Xprobe,l2mod.U,l2mod.V);

            cleanNames={'ESS-auto-noSW','ESS-auto-noSW-noElemGuard'};
            for gg=1:numel(cleanNames)
                mm=find(strcmp({methodsAbl.name},cleanNames{gg}),1); if isempty(mm),continue;end
                mod=fit_method_real_tukey_v1(Xsub0,r,c,methodsAbl(mm),cfg);
                acc=recognition_accuracy_real_tukey_v1(Xgal,ygal,Xprobe,yprobe,mod.U,mod.V,cfg);
                nre=projection_nre_real_tukey_v1(Xprobe,mod.U,mod.V);
                [~,~,db]=bilateral_drift_real_tukey_v1(l2mod.U,l2mod.V,mod.U,mod.V);
                ia=ia+1; rowsA(ia,:)={dname,'clean_guard',rep,methodsAbl(mm).name, ...
                    acc,safe_ratio_real_tukey_v1(acc,l2acc),nre,safe_ratio_real_tukey_v1(nre,l2nre), ...
                    db,NaN,NaN,NaN,NaN,mod.finalEta,mod.finalESSElement, ...
                    mod.finalESSCombined,mod.finalZeroW,mod.status}; %#ok<AGROW>
                clear mod
            end
            clear l2mod

            % ============================================================
            % B. ELEMENT PATHWAY: impulse contamination.
            %    Tests fixed-vs-auto ESS and zero calibration in the regime
            %    where elementwise Tukey rejection is intended to operate.
            % ============================================================
            planE=make_element_contamination_plan_real_tukey_v1( ...
                Xsub0,cfg.ablationElementType,cfg.ablationCellRate,seed+10,cfg);
            [Xe,maskE,~]=apply_element_contamination_plan_real_tukey_v1( ...
                Xsub0,planE,cfg.ablationCellRate,cfg.ablationCellStrength,cfg);
            elemNames={'Fixed-Tukey-noSW','ESS-eta85-noSW','ESS-auto-noSW','ESS-auto-noSW-noZeroCal'};
            elemMethods=methodsAbl(ismember({methodsAbl.name},elemNames));
            refE=fit_clean_references_real_tukey_v1(Xsub0,Xgal,ygal,Xprobe,yprobe,r,c,elemMethods,cfg);
            for mm=1:numel(elemMethods)
                mod=fit_method_real_tukey_v1(Xe,r,c,elemMethods(mm),cfg);
                acc=recognition_accuracy_real_tukey_v1(Xgal,ygal,Xprobe,yprobe,mod.U,mod.V,cfg);
                nre=projection_nre_real_tukey_v1(Xprobe,mod.U,mod.V);
                [~,~,db]=bilateral_drift_real_tukey_v1(refE(mm).model.U,refE(mm).model.V,mod.U,mod.V);
                [roc,pr,~,~]=outlier_metrics_v6(mod.W,maskE,cfg.ablationElementType);
                ia=ia+1; rowsA(ia,:)={dname,'impulse_10pct',rep,elemMethods(mm).name, ...
                    acc,safe_ratio_real_tukey_v1(acc,refE(mm).ACC),nre,safe_ratio_real_tukey_v1(nre,refE(mm).NRE), ...
                    db,roc,pr,NaN,NaN,mod.finalEta,mod.finalESSElement,mod.finalESSCombined,mod.finalZeroW,mod.status}; %#ok<AGROW>
                clear mod
            end

            % ============================================================
            % C. SAMPLE PATHWAY: cross-dataset whole-sample contamination.
            %    Tests SW on/off and the independent sample guard.
            % ============================================================
            planS=make_sample_contamination_plan_real_tukey_v1(Xsub0,FP,cfg.ablationSampleRate,seed+20,cfg);
            [Xs,maskS,~]=apply_sample_contamination_plan_real_tukey_v1(Xsub0,FP,planS,cfg.ablationSampleRate,cfg);
            sampNames={'ESS-auto-noSW','ESS-auto-SW','ESS-auto-SW-noSampleGuard'};
            sampMethods=methodsAbl(ismember({methodsAbl.name},sampNames));
            refS=fit_clean_references_real_tukey_v1(Xsub0,Xgal,ygal,Xprobe,yprobe,r,c,sampMethods,cfg);
            for mm=1:numel(sampMethods)
                mod=fit_method_real_tukey_v1(Xs,r,c,sampMethods(mm),cfg);
                acc=recognition_accuracy_real_tukey_v1(Xgal,ygal,Xprobe,yprobe,mod.U,mod.V,cfg);
                nre=projection_nre_real_tukey_v1(Xprobe,mod.U,mod.V);
                [~,~,db]=bilateral_drift_real_tukey_v1(refS(mm).model.U,refS(mm).model.V,mod.U,mod.V);
                [roc,pr,sroc,spr]=outlier_metrics_v6(mod.W,maskS,'sample');
                ia=ia+1; rowsA(ia,:)={dname,'cross_dataset_20pct',rep,sampMethods(mm).name, ...
                    acc,safe_ratio_real_tukey_v1(acc,refS(mm).ACC),nre,safe_ratio_real_tukey_v1(nre,refS(mm).NRE), ...
                    db,roc,pr,sroc,spr,mod.finalEta,mod.finalESSElement,mod.finalESSCombined,mod.finalZeroW,mod.status}; %#ok<AGROW>
                clear mod
            end

            % Matched-SW fairness for robust M-estimator baselines.
            refM=fit_clean_references_real_tukey_v1(Xsub0,Xgal,ygal,Xprobe,yprobe,r,c,methodsMatched,cfg);
            for mm=1:numel(methodsMatched)
                mod=fit_method_real_tukey_v1(Xs,r,c,methodsMatched(mm),cfg);
                acc=recognition_accuracy_real_tukey_v1(Xgal,ygal,Xprobe,yprobe,mod.U,mod.V,cfg);
                nre=projection_nre_real_tukey_v1(Xprobe,mod.U,mod.V);
                [~,~,db]=bilateral_drift_real_tukey_v1(refM(mm).model.U,refM(mm).model.V,mod.U,mod.V);
                [~,~,sroc,spr]=outlier_metrics_v6(mod.W,maskS,'sample');
                im=im+1; rowsM(im,:)={dname,'cross_dataset_20pct',rep,methodsMatched(mm).name, ...
                    acc,safe_ratio_real_tukey_v1(acc,refM(mm).ACC),nre,safe_ratio_real_tukey_v1(nre,refM(mm).NRE), ...
                    db,sroc,spr,mod.finalEta,mod.finalESSElement,mod.finalESSCombined,mod.finalZeroW,mod.status}; %#ok<AGROW>
                clear mod
            end
        end
    end

    Tabl=cell2table(rowsA,'VariableNames',{'Dataset','Scenario','Repeat','Method','ACC','ACCRetention', ...
        'NRE','NREInflation','BiDrift','ElemROCAUC','ElemPRAUC','SampleROCAUC','SamplePRAUC', ...
        'FinalEta','FinalESSElement','FinalESSCombined','FinalZeroW','Status'});
    Tmatch=cell2table(rowsM,'VariableNames',{'Dataset','Scenario','Repeat','Method','ACC','ACCRetention', ...
        'NRE','NREInflation','BiDrift','SampleROCAUC','SamplePRAUC','FinalEta','FinalESSElement', ...
        'FinalESSCombined','FinalZeroW','Status'});
end

function T = run_zero_calibration_grid_real_tukey_v17(allData,cfg)
    % Pre-registered stress grid for the auxiliary zero-weight calibration.
    % The purpose is diagnostic: determine whether adding the R0 penalty
    % actually changes tau under stronger impulse contamination.  If it never
    % changes tau, the paper should treat zero calibration as a safeguard
    % rather than as an independently validated performance contribution.

    rows={}; rid=0;
    useDs=intersect(cfg.ablationDatasets,cfg.datasets,'stable');

    onM=method_struct_real_tukey_v1( ...
        'ESS-auto-ZeroCalON','bpca','tukey','ess','auto',NaN,false,true);
    offM=method_struct_real_tukey_v1( ...
        'ESS-auto-ZeroCalOFF','bpca','tukey','ess','auto',NaN,false,true);
    offM.useZeroCalibrationOverride=false;

    for id=1:numel(useDs)
        dname=useDs{id}; ds=allData.(safe_field_name_real_tukey_v1(dname));
        [r,c]=get_rank_real_tukey_v1(cfg,dname,size(ds.X));

        for rep=1:cfg.zeroCalGrid.repeats
            seed=cfg.evalSeedOffset+1650000+10000*id+rep;
            [idxSub,idxGal,idxProbe]=split_threeway_by_identity_real_tukey_v1( ...
                ds.labels,cfg.splitRatios,seed);
            Xsub0=ds.X(:,:,idxSub); Xgal=ds.X(:,:,idxGal); ygal=ds.labels(idxGal);
            Xprobe=ds.X(:,:,idxProbe); yprobe=ds.labels(idxProbe);

            cleanRef=fit_method_real_tukey_v1(Xsub0,r,c,onM,cfg);
            cleanACC=recognition_accuracy_real_tukey_v1( ...
                Xgal,ygal,Xprobe,yprobe,cleanRef.U,cleanRef.V,cfg);
            cleanNRE=projection_nre_real_tukey_v1(Xprobe,cleanRef.U,cleanRef.V);

            for is=1:numel(cfg.zeroCalGrid.strengths)
                strength=cfg.zeroCalGrid.strengths(is);
                for ir=1:numel(cfg.zeroCalGrid.rates)
                    rate=cfg.zeroCalGrid.rates(ir);
                    plan=make_element_contamination_plan_real_tukey_v1( ...
                        Xsub0,'impulse',rate,seed+1000*is+100*ir,cfg);
                    [Xc,mask,actualRate]=apply_element_contamination_plan_real_tukey_v1( ...
                        Xsub0,plan,rate,strength,cfg);

                    mon=fit_method_real_tukey_v1(Xc,r,c,onM,cfg);
                    moff=fit_method_real_tukey_v1(Xc,r,c,offM,cfg);

                    accOn=recognition_accuracy_real_tukey_v1( ...
                        Xgal,ygal,Xprobe,yprobe,mon.U,mon.V,cfg);
                    accOff=recognition_accuracy_real_tukey_v1( ...
                        Xgal,ygal,Xprobe,yprobe,moff.U,moff.V,cfg);
                    nreOn=projection_nre_real_tukey_v1(Xprobe,mon.U,mon.V);
                    nreOff=projection_nre_real_tukey_v1(Xprobe,moff.U,moff.V);
                    [~,~,driftOn]=bilateral_drift_real_tukey_v1( ...
                        cleanRef.U,cleanRef.V,mon.U,mon.V);
                    [~,~,driftOff]=bilateral_drift_real_tukey_v1( ...
                        cleanRef.U,cleanRef.V,moff.U,moff.V);
                    [rocOn,prOn,~,~]=outlier_metrics_v6(mon.W,mask,'impulse');
                    [rocOff,prOff,~,~]=outlier_metrics_v6(moff.W,mask,'impulse');

                    tauChanged=double(abs(log((mon.finalTau+cfg.alg.eps0)/(moff.finalTau+cfg.alg.eps0)))>1e-6);
                    rid=rid+1;
                    rows(rid,:)={dname,rate,actualRate,strength,rep,seed, ...
                        cleanACC,cleanNRE, ...
                        mon.finalTau,moff.finalTau,tauChanged, ...
                        mon.finalEta,moff.finalEta, ...
                        mon.finalESSElement,moff.finalESSElement, ...
                        mon.finalZeroW,moff.finalZeroW, ...
                        accOn,accOff,nreOn,nreOff,driftOn,driftOff, ...
                        rocOn,rocOff,prOn,prOff,mon.status,moff.status}; %#ok<AGROW>
                    clear mon moff Xc mask
                end
            end
            clear cleanRef
        end
    end

    T=cell2table(rows,'VariableNames',{ ...
        'Dataset','NominalRate','ActualRate','Strength','Repeat','Seed', ...
        'CleanACC','CleanNRE','TauOn','TauOff','ZeroCalChangedTau', ...
        'EtaOn','EtaOff','ESSElementOn','ESSElementOff','ZeroWOn','ZeroWOff', ...
        'ACCOn','ACCOff','NREOn','NREOff','BiDriftOn','BiDriftOff', ...
        'ElemROCOn','ElemROCOff','ElemPROn','ElemPROff','StatusOn','StatusOff'});
end

function Tout = paired_compare_real_tukey_v1(T,condVars,autoName,baselines,metric,direction)
    rows={}; id=0;
    % Build condition key excluding Method.
    keys=strings(height(T),1);
    for i=1:height(T)
        parts=strings(1,numel(condVars));
        for j=1:numel(condVars)
            parts(j)=string(table_value_as_text_real_tukey_v1(T,condVars{j},i));
        end
        keys(i)=strjoin(parts,'||');
    end
    u=unique(keys,'stable');
    for b=1:numel(baselines)
        diffs=[];
        for k=1:numel(u)
            ia=find(keys==u(k) & strcmp(T.Method,autoName),1);
            ib=find(keys==u(k) & strcmp(T.Method,baselines{b}),1);
            if isempty(ia)||isempty(ib), continue; end
            a=T.(metric)(ia); bb=T.(metric)(ib);
            if ~isfinite(a)||~isfinite(bb), continue; end
            if strcmpi(direction,'higher'), d=a-bb; else, d=bb-a; end
            diffs(end+1,1)=d; %#ok<AGROW>
        end
        N=numel(diffs);
        if N==0, mu=NaN;sd=NaN;se=NaN;lo=NaN;hi=NaN;win=NaN;
        else
            mu=mean(diffs); sd=std(diffs); se=sd/sqrt(N); lo=mu-1.96*se; hi=mu+1.96*se; win=mean(diffs>0);
        end
        id=id+1; rows(id,:)={metric,autoName,baselines{b},direction,N,mu,sd,se,lo,hi,win}; %#ok<AGROW>
    end
    Tout=cell2table(rows,'VariableNames',{'Metric','AutoMethod','Baseline','Direction','N', ...
        'MeanImprovement','Std','SE','CI95Low','CI95High','WinRate'});
end

function s = table_value_as_text_real_tukey_v1(T,var,i)
    v=T.(var)(i);
    if iscell(v), s=string(v{1}); elseif isnumeric(v), s=string(num2str(v,'%.12g')); else, s=string(v); end
end

function Tstatus = status_audit_real_tukey_v1(varargin)
    rows={}; id=0;
    for a=1:nargin
        T=varargin{a};
        if isempty(T) || ~istable(T) || ~ismember('Status',T.Properties.VariableNames), continue; end
        methods=unique(T.Method,'stable');
        for m=1:numel(methods)
            idx=strcmp(T.Method,methods{m}); st=T.Status(idx);
            if iscell(st), ss=string(st); else, ss=string(st); end
            id=id+1; rows(id,:)={a,methods{m},sum(idx),mean(ss=="converged"),mean(ss=="stationary"), ...
                mean(ss=="ok"),mean(ss=="timecap"),mean(ss=="mm_stalled")}; %#ok<AGROW>
        end
    end
    Tstatus=cell2table(rows,'VariableNames',{'TableIndex','Method','N','ConvergedRate','StationaryRate','OkRate','TimecapRate','MMStalledRate'});
end

%% =========================================================================
% PLOTTING
% ==========================================================================
function plot_clean_summary_real_tukey_v1(T,cfg)
    ds=unique(T.Dataset,'stable');
    for i=1:numel(ds)
        idx=strcmp(T.Dataset,ds{i});
        methods=T.Method(idx); acc=T.ACC_Mean(idx); lo=T.ACC_CI95Low(idx); hi=T.ACC_CI95High(idx);
        fig=figure('Color','w','Position',[100 100 1000 520]);
        x=1:numel(methods); bar(x,acc); hold on; errorbar(x,acc,acc-lo,hi-acc,'.','LineWidth',1.2);
        set(gca,'XTick',x,'XTickLabel',methods); xtickangle(25); ylabel('Clean probe ACC'); grid on;
        title([ds{i} ': clean efficiency']); save_figure_real_tukey_v1(fig,cfg,['R1_ACC_' ds{i}]);
    end
end

function plot_cellwise_summary_real_tukey_v1(T,cfg)
    ds=unique(T.Dataset,'stable'); types=unique(T.ContamType,'stable'); strengths=unique(T.Strength,'stable');
    for i=1:numel(ds)
        for j=1:numel(types)
            for s=1:numel(strengths)
                idx=strcmp(T.Dataset,ds{i}) & strcmp(T.ContamType,types{j}) & T.Strength==strengths(s);
                if ~any(idx),continue;end
                methods=unique(T.Method(idx),'stable');
                fig=figure('Color','w','Position',[100 100 860 540]); hold on; grid on; box on;
                for m=1:numel(methods)
                    z=idx & strcmp(T.Method,methods{m}); x=T.NominalRate(z); y=T.ACCRetention_Mean(z); [x,o]=sort(x); y=y(o);
                    plot(x,y,'-o','LineWidth',1.4,'DisplayName',methods{m});
                end
                yline(1,'--'); xlabel('Training contamination rate'); ylabel('ACC retention');
                title(sprintf('%s | %s | strength %.1f',ds{i},types{j},strengths(s)),'Interpreter','none');
                legend('Location','best','Interpreter','none');
                save_figure_real_tukey_v1(fig,cfg,sprintf('R2_ACCret_%s_%s_s%.1f',ds{i},types{j},strengths(s)));
            end
        end
    end
end

function plot_samplewise_summary_real_tukey_v1(T,cfg)
    ds=unique(T.Dataset,'stable'); sc=unique(T.Scenario,'stable');
    for i=1:numel(ds)
        for j=1:numel(sc)
            idx=strcmp(T.Dataset,ds{i}) & strcmp(T.Scenario,sc{j}); if ~any(idx),continue;end
            methods=unique(T.Method(idx),'stable');
            fig=figure('Color','w','Position',[100 100 860 540]); hold on; grid on; box on;
            for m=1:numel(methods)
                z=idx & strcmp(T.Method,methods{m}); x=T.NominalRate(z); y=T.ACCRetention_Mean(z); [x,o]=sort(x); y=y(o);
                plot(x,y,'-o','LineWidth',1.4,'DisplayName',methods{m});
            end
            yline(1,'--'); xlabel('Sample contamination rate'); ylabel('ACC retention');
            title([ds{i} ' | ' sc{j}],'Interpreter','none'); legend('Location','best','Interpreter','none');
            save_figure_real_tukey_v1(fig,cfg,['R3_ACCret_' ds{i} '_' sc{j}]);

            fig=figure('Color','w','Position',[100 100 860 540]); hold on; grid on; box on;
            for m=1:numel(methods)
                z=idx & strcmp(T.Method,methods{m}); x=T.NominalRate(z); y=T.BiDrift_Mean(z); [x,o]=sort(x); y=y(o);
                plot(x,y,'-o','LineWidth',1.4,'DisplayName',methods{m});
            end
            xlabel('Sample contamination rate'); ylabel('Bilateral subspace drift');
            title([ds{i} ' | ' sc{j} ' | structural stability'],'Interpreter','none'); legend('Location','best','Interpreter','none');
            save_figure_real_tukey_v1(fig,cfg,['R3_Drift_' ds{i} '_' sc{j}]);
        end
    end
end

function plot_local_summary_real_tukey_v1(T,cfg)
    ds=unique(T.Dataset,'stable'); sc=unique(T.Scenario,'stable');
    for i=1:numel(ds)
        for j=1:numel(sc)
            idx=strcmp(T.Dataset,ds{i}) & strcmp(T.Scenario,sc{j}); if ~any(idx),continue;end
            methods=unique(T.Method(idx),'stable');
            fig=figure('Color','w','Position',[100 100 860 540]); hold on; grid on; box on;
            for m=1:numel(methods)
                z=idx & strcmp(T.Method,methods{m}); x=T.AreaRatio(z); y=T.ACCRetention_Mean(z); [x,o]=sort(x); y=y(o);
                plot(x,y,'-o','LineWidth',1.4,'DisplayName',methods{m});
            end
            yline(1,'--'); xlabel('Occluded area ratio'); ylabel('ACC retention');
            title([ds{i} ' | ' sc{j}],'Interpreter','none'); legend('Location','best','Interpreter','none');
            save_figure_real_tukey_v1(fig,cfg,['R4_ACCret_' ds{i} '_' sc{j}]);
        end
    end
end

function plot_mechanism_real_tukey_v1(T,cfg)
    if isempty(T),return;end
    exps=unique(T.Experiment,'stable');

    for e=1:numel(exps)
        idx=strcmp(T.Experiment,exps{e});
        A=T(idx,:);

        levels=unique(A.NominalSeverity);
        eta=nan(size(levels));
        ess=eta; zw=eta; tail=eta; tailCurrent=eta;
        sampRate=eta; sampMeanW=eta; sampSev=eta; sampAct=eta;

        for k=1:numel(levels)
            z=A.NominalSeverity==levels(k);
            eta(k)=mean(A.Eta(z),'omitnan');
            ess(k)=mean(A.ESSElement(z),'omitnan');
            zw(k)=mean(A.ElementZeroW(z),'omitnan');
            tail(k)=mean(A.ElementTailSeverityUsed(z),'omitnan');
            tailCurrent(k)=mean(A.ElementTailSeverityCurrent(z),'omitnan');
            sampRate(k)=mean(A.SampleOutlierRate(z),'omitnan');
            sampMeanW(k)=mean(A.SampleMeanWeight(z),'omitnan');
            sampSev(k)=mean(A.SampleSeverity(z),'omitnan');
            if ismember('SampleDownweightStrength',A.Properties.VariableNames)
                sampAct(k)=mean(A.SampleDownweightStrength(z),'omitnan');
            end
        end

        [levels,o]=sort(levels);
        eta=eta(o); ess=ess(o); zw=zw(o); tail=tail(o); tailCurrent=tailCurrent(o);
        sampRate=sampRate(o); sampMeanW=sampMeanW(o); sampSev=sampSev(o); sampAct=sampAct(o);

        % Element-level mechanism
        fig=figure('Color','w','Position',[100 100 900 540]); hold on; grid on; box on;
        plot(levels,eta,'-o','LineWidth',1.5,'DisplayName','Final eta');
        plot(levels,ess,'-s','LineWidth',1.5,'DisplayName','Element ESS');
        plot(levels,zw,'-^','LineWidth',1.5,'DisplayName','Element zero-weight ratio');
        plot(levels,tail,'-d','LineWidth',1.5,'DisplayName','Severity used (memory)');
        plot(levels,tailCurrent,'--d','LineWidth',1.2,'DisplayName','Current residual severity');
        xlabel('Nominal contamination severity');
        ylabel('Element mechanism statistic');
        ylim([0 1]);
        title([exps{e} ': element-level adaptive mechanism'],'Interpreter','none');
        legend('Location','best');
        save_figure_real_tukey_v1(fig,cfg,['R5_element_mechanism_' exps{e}]);

        % Sample-level mechanism only when defined.
        if any(isfinite(sampRate)) || any(isfinite(sampMeanW)) || any(isfinite(sampSev))
            fig=figure('Color','w','Position',[100 100 900 540]); hold on; grid on; box on;
            plot(levels,sampRate,'-o','LineWidth',1.5,'DisplayName','Sample outlier-rate diagnostic');
            plot(levels,sampMeanW,'-s','LineWidth',1.5,'DisplayName','Mean sample weight');
            plot(levels,sampSev,'-d','LineWidth',1.5,'DisplayName','Sample severity');
            plot(levels,sampAct,'-^','LineWidth',1.5,'DisplayName','Soft activation strength');
            xlabel('Nominal contamination severity');
            ylabel('Sample mechanism statistic');
            title([exps{e} ': sample-level adaptive mechanism'],'Interpreter','none');
            legend('Location','best');
            save_figure_real_tukey_v1(fig,cfg,['R5_sample_mechanism_' exps{e}]);
        end
    end
end

function plot_ablation_summary_real_tukey_v1(T,cfg)
    sc=unique(T.Scenario,'stable');
    for j=1:numel(sc)
        idx=strcmp(T.Scenario,sc{j}); methods=T.Method(idx); y=T.ACCRetention_Mean(idx);
        fig=figure('Color','w','Position',[100 100 1000 520]); x=1:numel(methods); bar(x,y); yline(1,'--'); grid on;
        set(gca,'XTick',x,'XTickLabel',methods); xtickangle(25); ylabel('ACC retention');
        title(['Ablation | ' sc{j}],'Interpreter','none'); save_figure_real_tukey_v1(fig,cfg,['R6_ablation_' sc{j}]);
    end
end

function plot_eta_validation_real_tukey_v17(T,cfg)
    ds=unique(T.Dataset,'stable'); sc=unique(T.Scenario,'stable');
    for i=1:numel(ds)
        for j=1:numel(sc)
            idx=strcmp(T.Dataset,ds{i}) & strcmp(T.Scenario,sc{j});
            if ~any(idx), continue; end
            methods=T.Method(idx); y=T.TestACC_Mean(idx); lo=T.TestACC_CI95Low(idx); hi=T.TestACC_CI95High(idx);
            fig=figure('Color','w','Position',[100 100 820 500]);
            x=1:numel(methods); bar(x,y); hold on; errorbar(x,y,y-lo,hi-y,'.','LineWidth',1.1);
            set(gca,'XTick',x,'XTickLabel',methods); xtickangle(20); ylabel('Clean-probe ACC'); grid on;
            title([ds{i} ' | ' sc{j} ' | auto vs validation-best eta'],'Interpreter','none');
            save_figure_real_tukey_v1(fig,cfg,['R7_eta_' ds{i} '_' sc{j}]);
        end
    end
end

function plot_alpha_sensitivity_real_tukey_v17(T,cfg)
    ds=unique(T.Dataset,'stable');
    for i=1:numel(ds)
        idx=strcmp(T.Dataset,ds{i}); if ~any(idx),continue;end
        x=T.Alpha(idx); y=T.ACCRetention_Mean(idx); d=T.BiDrift_Mean(idx);
        [x,o]=sort(x); y=y(o); d=d(o);
        fig=figure('Color','w','Position',[100 100 820 500]);
        yyaxis left; plot(x,y,'-o','LineWidth',1.5); ylabel('ACC retention');
        yyaxis right; plot(x,d,'-s','LineWidth',1.5); ylabel('Bilateral drift');
        xlabel('Sample-weight exponent \\alpha'); grid on;
        title([ds{i} ': sample-weight alpha sensitivity'],'Interpreter','none');
        save_figure_real_tukey_v1(fig,cfg,['R8_alpha_' ds{i}]);
    end
end

function save_figure_real_tukey_v1(fig,cfg,name)
    try, exportgraphics(fig,fullfile(cfg.out_dir,[name '.png']),'Resolution',250); catch, saveas(fig,fullfile(cfg.out_dir,[name '.png'])); end
    close(fig);
end

%% =========================================================================
% DATASET LOADING / DIRECTORY INFRASTRUCTURE
% ==========================================================================
function ds = load_face_dataset_real_tukey_v1(data_root,dname,default_size)
    dirs=find_dataset_dirs_real_tukey_v1(data_root,dname);
    if isempty(dirs), error('DatasetLoader:MissingPixels','Dataset directory for %s not found.',dname); end
    expectedN = expected_sample_count_real_tukey_v12(dname);
    labels_global=collect_dataset_labels_real_tukey_v1(dirs,dname,expectedN);
    best=[]; best_score=-inf;

    for id=1:numel(dirs)
        mats=recursive_files_real_tukey_v1(dirs{id},'*.mat');
        for im=1:numel(mats)
            f=mats{im};
            try, S=load(f); catch, continue; end
            labels_local=find_label_vector_real_tukey_v1(S);
            if isempty(labels_local), labels=labels_global; else, labels=labels_local; end
            vars=fieldnames(S);
            for iv=1:numel(vars)
                v=S.(vars{iv});
                if ~isnumeric(v)||isempty(v)||isvector(v)||numel(v)<500, continue; end
                [X,ok,score]=numeric_candidate_to_tensor_real_tukey_v1(v,labels,default_size,expectedN);
                if ok
                    if ~isempty(labels)&&size(X,3)==numel(labels), score=score+1000; end
                    score=score+preferred_pixel_file_bonus_real_tukey_v1(f,dname);
                    if score>best_score
                        best_score=score; best=struct('X',double(X),'labels',labels,'source',f);
                    end
                end
            end
        end
    end

    if ~isempty(best)
        X=best.X; labels=best.labels; N=size(X,3);
        if isempty(labels)||numel(labels)~=N, labels=(1:N)'; else, labels=labels(:); end
        ds=struct('X',X,'labels',labels,'source',best.source); return;
    end

    exts={'*.pgm','*.png','*.jpg','*.jpeg','*.bmp','*.tif','*.tiff'}; files={};
    for id=1:numel(dirs), for ie=1:numel(exts), files=[files;recursive_files_real_tukey_v1(dirs{id},exts{ie})]; end, end %#ok<AGROW>
    if isempty(files), error('DatasetLoader:MissingPixels','No valid MAT pixel tensor or image files for %s.',dname); end
    base=default_size; X=[]; labels=zeros(numel(files),1); kept=0;
    for i=1:numel(files)
        try, A=imread(files{i}); catch, continue; end
        if ndims(A)==3, A=mean(double(A),3); else, A=double(A); end
        if isempty(base), base=size(A); end
        if any(size(A)~=base), A=resize_matrix_bilinear_real_tukey_v1(A,base(1),base(2)); end
        kept=kept+1; if isempty(X), X=zeros(base(1),base(2),numel(files)); end
        X(:,:,kept)=A;
        parent=fileparts(files{i}); [~,pn]=fileparts(parent); tok=regexp(pn,'\d+','match','once');
        if isempty(tok), labels(kept)=kept; else, labels(kept)=str2double(tok); end
    end
    X=X(:,:,1:kept); labels=labels(1:kept); ds=struct('X',X,'labels',labels,'source',dirs{1});
end

function dirs=find_dataset_dirs_real_tukey_v1(root,dname)
    aliases={dname,lower(dname),upper(dname)};
    if strcmpi(dname,'YALE'), aliases=[aliases {'Yale','yale'}]; end
    if strcmpi(dname,'ORL'), aliases=[aliases {'Orl','orl','att_faces','ATT'}]; end
    if strcmpi(dname,'PIE'), aliases=[aliases {'Pie','pie'}]; end
    if strcmpi(dname,'XM2VTS'), aliases=[aliases {'xm2vts','Xm2vts','XM2Vts'}]; end
    dirs={}; for i=1:numel(aliases), p=fullfile(root,aliases{i}); if exist(p,'dir'), dirs{end+1}=p; end, end %#ok<AGROW>
    dirs=unique(dirs,'stable');
end

function files=recursive_files_real_tukey_v1(root,pattern)
    files={}; if ~exist(root,'dir'),return;end
    try, D=dir(fullfile(root,'**',pattern)); catch, D=dir(fullfile(root,pattern)); end
    files=arrayfun(@(x)fullfile(x.folder,x.name),D,'UniformOutput',false)';
end

function labels=collect_dataset_labels_real_tukey_v1(dirs,dname,expectedN)
    labels=[];
    if strcmpi(dname,'YALE'), preferred={'yalelabel.mat','label.mat','yale_label.mat'};
    elseif strcmpi(dname,'ORL'), preferred={'label.mat','ORLlabel.mat','orllabel.mat','orl_label.mat'};
    elseif strcmpi(dname,'PIE'), preferred={'pielabel.mat','pie_label.mat','label.mat'};
    elseif strcmpi(dname,'XM2VTS'), preferred={'xm2label.mat','xm2vtslabel.mat','xm2_label.mat','label.mat'};
    else, preferred={}; end
    for id=1:numel(dirs)
        mats=recursive_files_real_tukey_v1(dirs{id},'*.mat');
        for ip=1:numel(preferred)
            for im=1:numel(mats)
                [~,nm,ext]=fileparts(mats{im});
                if strcmpi([nm ext],preferred{ip})
                    try, S=load(mats{im}); labels=find_label_vector_real_tukey_v1(S); catch, labels=[]; end
                    if ~isempty(labels), labels=double(labels(:)); return; end
                end
            end
        end
    end
    % Exact expected-length fallback is important for datasets such as PIE,
    % whose pixel matrix may be readable even when the label variable/file
    % name differs from the preferred list.
    if nargin>=3 && ~isempty(expectedN) && isfinite(expectedN)
        for id=1:numel(dirs)
            mats=recursive_files_real_tukey_v1(dirs{id},'*.mat');
            for im=1:numel(mats)
                [~,nm]=fileparts(mats{im}); nml=lower(nm);
                if contains(nml,'index')||contains(nml,'split')||contains(nml,'ind'), continue; end
                try, S=load(mats{im}); catch, continue; end
                ff=fieldnames(S);
                for jj=1:numel(ff)
                    vv=S.(ff{jj});
                    if isnumeric(vv) && isvector(vv) && numel(vv)==expectedN
                        vv=double(vv(:));
                        if all(isfinite(vv)) && numel(unique(vv)) < max(500,0.75*expectedN)
                            labels=vv; return;
                        end
                    end
                end
            end
        end
    end

    for id=1:numel(dirs)
        mats=recursive_files_real_tukey_v1(dirs{id},'*.mat');
        for im=1:numel(mats)
            [~,nm]=fileparts(mats{im}); nml=lower(nm);
            if contains(nml,'index')||contains(nml,'split')||contains(nml,'ind'), continue; end
            try, S=load(mats{im}); catch, continue; end
            lab=find_label_vector_real_tukey_v1(S); if ~isempty(lab), labels=double(lab(:)); return; end
        end
    end
end

function labels=find_label_vector_real_tukey_v1(S)
    labels=[]; preferred={'label','labels','gnd','class','classes','y','Y','target','targets'}; f=fieldnames(S);
    for i=1:numel(preferred)
        idx=find(strcmpi(f,preferred{i}),1); if ~isempty(idx), v=S.(f{idx}); if isnumeric(v)&&isvector(v)&&numel(v)>=5, labels=double(v(:)); return; end, end
    end
    for i=1:numel(f)
        v=S.(f{i}); if isnumeric(v)&&isvector(v)&&numel(v)>=10&&numel(v)<=10000
            vv=double(v(:)); if all(isfinite(vv))&&numel(unique(vv))<max(400,0.5*numel(vv)), labels=vv; return; end
        end
    end
end

function [X,ok,score]=numeric_candidate_to_tensor_real_tukey_v1(v,labels,default_size,expectedN)
    ok=false;score=-inf;X=[]; sz=size(v);
    if ndims(v)>=3
        dims=sz; idx=[];
        if nargin>=4 && ~isempty(expectedN) && isfinite(expectedN)
            idx=find(dims==expectedN,1,'last');
        end
        if isempty(idx) && ~isempty(labels), idx=find(dims==numel(labels),1,'last'); end
        if isempty(idx), [~,idx]=min(dims); end
        perm=[setdiff(1:numel(dims),idx,'stable') idx]; A=permute(v,perm); spatial=size(A);
        if numel(spatial)>3, A=reshape(A,spatial(1),prod(spatial(2:end-1)),spatial(end)); end
        if size(A,1)>=8&&size(A,2)>=8&&size(A,3)>=5, X=double(A);ok=true;score=size(X,1)*size(X,2)+size(X,3); end
        return;
    end
    if ismatrix(v)
        [a,b]=size(v); orient=0; feat=0; N=[];
        % Prefer the configured sample count before heuristics.  This fixes
        % ambiguous large matrices such as PIE 4096 x 2924, where both
        % dimensions are large and the previous heuristic could swap samples
        % and features when the label file was not found first.
        if nargin>=4 && ~isempty(expectedN) && isfinite(expectedN)
            if b==expectedN, N=b; feat=a; orient=1;
            elseif a==expectedN, N=a; feat=b; orient=2; end
        end
        if orient==0 && ~isempty(labels)
            if b==numel(labels),N=b;feat=a;orient=1; elseif a==numel(labels),N=a;feat=b;orient=2; end
        end
        if orient==0
            if a>=20&&b>=500&&a<b,N=a;feat=b;orient=2;
            elseif b>=20&&a>=500&&b<a,N=b;feat=a;orient=1;
            elseif a>=20&&b>=500,N=b;feat=a;orient=1;
            elseif b>=20&&a>=500,N=a;feat=b;orient=2;
            else,return;end
        end
        if ~isempty(default_size)&&prod(default_size)==feat, h=default_size(1);w=default_size(2); else,[h,w]=infer_factor_pair_real_tukey_v1(feat);end
        if h<8||w<8||h*w~=feat,return;end
        if orient==1, X=reshape(double(v),h,w,N); else, X=reshape(double(v'),h,w,N); end
        ok=true;score=h*w+N;
    end
end

function [h,w]=infer_factor_pair_real_tukey_v1(n)
    h=1;w=n;for d=floor(sqrt(n)):-1:1,if mod(n,d)==0,h=d;w=n/d;break;end,end
end

function b=preferred_pixel_file_bonus_real_tukey_v1(f,dname)
    b=0;[~,nm,ext]=fileparts(f);fname=lower([nm ext]);
    if strcmpi(dname,'YALE')&&strcmp(fname,'yaledata_norm.mat'),b=5000;
    elseif strcmpi(dname,'ORL')&&strcmp(fname,'data_norm.mat'),b=5000;
    elseif strcmpi(dname,'PIE')&&strcmp(fname,'piedata_norm.mat'),b=5000;
    elseif strcmpi(dname,'XM2VTS')&&strcmp(fname,'xm2data_norm.mat'),b=5000;end
end

function N = expected_sample_count_real_tukey_v12(dname)
    switch upper(char(dname))
        case 'YALE',   N = 165;
        case 'ORL',    N = 400;
        case 'PIE',    N = 2924;
        case 'XM2VTS', N = 2360;
        otherwise,     N = [];
    end
end

function validate_loaded_dataset_real_tukey_v1(ds,dname,cfg)
    if ~isfield(ds,'X')||ndims(ds.X)~=3,error('DatasetLoader:MissingPixels','%s has no valid 3-D tensor.',dname);end
    [p,q,N]=size(ds.X); if p<8||q<8||N<5,error('DatasetLoader:MissingPixels','%s has invalid size.',dname);end
    K=numel(unique(ds.labels));
    key=safe_field_name_real_tukey_v1(dname);
    if isfield(cfg.expected_samples,key)&&N~=cfg.expected_samples.(key)
        msg=sprintf('%s N=%d, expected %d',dname,N,cfg.expected_samples.(key));
        if strcmpi(cfg.mode,'paper'), error('DatasetLoader:UnexpectedSampleCount','%s',msg);
        else, fprintf(2,'[DATA AUDIT] %s\n',msg); end
    end
    if isfield(cfg.expected_classes,key)&&K~=cfg.expected_classes.(key)
        msg=sprintf('%s K=%d, expected %d',dname,K,cfg.expected_classes.(key));
        if strcmpi(cfg.mode,'paper'), error('DatasetLoader:UnexpectedClassCount','%s',msg);
        else, fprintf(2,'[DATA AUDIT] %s\n',msg); end
    end
end

function X=standardize_tensor_samples_real_tukey_v1(X,mode)
    [p,q,T]=size(X); X=double(X);
    for t=1:T
        A=X(:,:,t);A=A-mean(A(:));s=norm(A,'fro');if s<=eps,s=1;end
        if strcmpi(mode,'sqrtmn'),A=A/s*sqrt(p*q);else,A=A/s;end
        X(:,:,t)=A;
    end
end

function [idxSub,idxGal,idxProbe]=split_threeway_by_identity_real_tukey_v1(labels,ratios,seed)
    rng(seed,'twister'); labels=labels(:); cls=unique(labels);
    idxSub=[];idxGal=[];idxProbe=[];
    for i=1:numel(cls)
        idx=find(labels==cls(i)); idx=idx(randperm(numel(idx))); n=numel(idx);
        if n<3, idxSub=[idxSub;idx(:)]; continue; end %#ok<AGROW>
        nSub=max(1,round(ratios(1)*n)); nGal=max(1,round(ratios(2)*n));
        if nSub+nGal>=n, nGal=max(1,n-nSub-1); end
        if nSub+nGal>=n, nSub=max(1,n-nGal-1); end
        nProbe=n-nSub-nGal;
        idxSub=[idxSub;idx(1:nSub)]; %#ok<AGROW>
        idxGal=[idxGal;idx(nSub+1:nSub+nGal)]; %#ok<AGROW>
        idxProbe=[idxProbe;idx(nSub+nGal+1:nSub+nGal+nProbe)]; %#ok<AGROW>
    end
    idxSub=idxSub(:);idxGal=idxGal(:);idxProbe=idxProbe(:);
    if isempty(idxGal)||isempty(idxProbe),error('Split:InsufficientSamples','Three-way identity split failed.');end
end

function [pools,audit]=build_cross_dataset_pools_real_tukey_v1(allData,cfg)
    pools=struct();audit=struct();audit.mapping=struct();audit.missing={};
    for i=1:numel(cfg.datasets)
        target=cfg.datasets{i}; key=safe_field_name_real_tukey_v1(target);
        source=''; if isfield(cfg.foreign_pair_source,key),source=cfg.foreign_pair_source.(key);end
        skey=safe_field_name_real_tukey_v1(source);
        if ~isempty(source)&&isfield(allData,skey)
            pools.(key)=struct('X',allData.(skey).X,'source_name',source,'mode','paired_cross_dataset','is_real',true);
            audit.mapping.(key)=source;
        else
            pools.(key)=struct('X',[],'source_name','UNAVAILABLE','mode','unavailable','is_real',false);
            audit.missing{end+1}=target; %#ok<AGROW>
        end
    end
end

function FP=get_foreign_pool_real_tukey_v1(pools,dname)
    key=safe_field_name_real_tukey_v1(dname); FP=pools.(key);
end

function A2=resize_matrix_bilinear_real_tukey_v1(A,h2,w2)
    A=double(A);[h,w]=size(A);if h==h2&&w==w2,A2=A;return;end
    x=linspace(1,w,w2);y=linspace(1,h,h2);[Xq,Yq]=meshgrid(x,y);[X,Y]=meshgrid(1:w,1:h);
    A2=interp2(X,Y,A,Xq,Yq,'linear');A2(~isfinite(A2))=0;
end

function root=resolve_existing_dir_real_tukey_v1(cands)
    root='';for i=1:numel(cands),if exist(cands{i},'dir'),root=cands{i};return;end,end
end

function root=auto_find_face_data_root_real_tukey_v1(parent)
    root='';if ~exist(parent,'dir'),return;end;D=dir(parent);best=-inf;
    for i=1:numel(D)
        if ~D(i).isdir||ismember(D(i).name,{'.','..'}),continue;end
        nm=lower(D(i).name);if ~(contains(nm,'b2dlda')||contains(nm,'rb2dlda')),continue;end
        cand=fullfile(parent,D(i).name);score=0;
        for d={'yale','orl','pie','xm2vts'}, if exist(fullfile(cand,d{1}),'dir')||exist(fullfile(cand,upper(d{1})),'dir'),score=score+10;end,end
        if strcmpi(D(i).name,'B2DLDA1111'),score=score+120;elseif strcmpi(D(i).name,'B2DLDA111'),score=score+100;end
        if score>best,best=score;root=cand;end
    end
end

function s=safe_field_name_real_tukey_v1(x),s=matlab.lang.makeValidName(char(x));end
function s=first_line_real_tukey_v1(msg),c=regexp(msg,'\r\n|\n|\r','split');s=c{1};end
function sz=get_default_size_real_tukey_v1(cfg,dname),key=safe_field_name_real_tukey_v1(dname);if isfield(cfg.default_size,key),sz=cfg.default_size.(key);else,sz=[];end,end
function [r,c]=get_rank_real_tukey_v1(cfg,dname,sz),key=safe_field_name_real_tukey_v1(dname);if isfield(cfg.rank,key),v=cfg.rank.(key);else,v=cfg.rank.default;end;r=min(v(1),sz(1)-1);c=min(v(2),sz(2)-1);end
function n=get_nrep_real_tukey_v1(cfg,dname,kind),large=any(strcmpi(dname,{'PIE','XM2VTS'}));s=cfg.nRep.(kind);if large,n=s.large;else,n=s.small;end,end

%% =========================================================================
% L1RBPCA EXTERNAL ROBUST BASELINE
% ==========================================================================
function out=L1RBPCA_fit_real_tukey_v1(X,k1,k2,tol)
    if nargin<4||isempty(tol),tol=1e-5;end
    [p,q,~]=size(X); q0=min(max(k1,k2),min(p,q));
    mo=init_tpca_model_real_tukey_v1(X,q0); mo1=TPCA_RBPCA_local_real_tukey_v1(mo,X,[q0 q0],tol);
    U=orth(mo1.V(:,1:k1)); V=orth(mo1.U(:,1:k2));
    out.U=U;out.V=V;
end

function mo=init_tpca_model_real_tukey_v1(X,q)
    [p1,p2,T]=size(X);Sr=zeros(p1);Sc=zeros(p2);
    for t=1:T,A=X(:,:,t);Sr=Sr+A*A';Sc=Sc+A'*A;end
    mo.V=top_eigvecs_sym(Sr,q);mo.U=top_eigvecs_sym(Sc,q);
end

function mo1=TPCA_RBPCA_local_real_tukey_v1(mo,data,q,tol)
    [r,d,N]=size(data);qr=q(1);qc=q(2);maxIter=100;mo1=mo;
    for j=1:qr
        if j==1,Ccell=arrayfun(@(i)data(:,:,i)*mo.U(:,j),1:N,'UniformOutput',false);Cu=cat(3,Ccell{:});Xu=reshape(Cu,[r,N]);end
        V0=mo.V(:,j);eold=sum(abs(V0'*Xu));
        for it=1:maxIter
            p=sign(V0'*Xu);p(p==0)=-1;Mu=Xu*p';[L,~,Rsvd]=svd(Mu,'econ');v=L(:,1)*Rsvd(:,1)';v=v/max(norm(v),eps);
            enew=sum(abs(v'*Xu));if it>1&&abs(enew-eold)/max(abs(enew),eps)<tol,break;end;V0=v;eold=enew;
        end
        mo1.V(:,j)=v;Xu=Xu-v*(v'*Xu);
    end
    for m=1:qc
        if m==1,Ccell=arrayfun(@(i)(mo1.V(:,m)'*data(:,:,i))',1:N,'UniformOutput',false);Cv=cat(3,Ccell{:});Xv=reshape(Cv,[d,N]);end
        U0=mo.U(:,m);eold=sum(abs(U0'*Xv));
        for it=1:maxIter
            p=sign(Xv'*U0);p(p==0)=-1;Mv=Xv*p;[L,~,Rsvd]=svd(Mv,'econ');u=L(:,1)*Rsvd(:,1)';u=u/max(norm(u),eps);
            enew=sum(abs(u'*Xv));if it>1&&abs(enew-eold)/max(abs(enew),eps)<tol,break;end;U0=u;eold=enew;
        end
        mo1.U(:,m)=u;Xv=(Xv'-Xv'*u*u')';
    end
end

function model = train_method_bpca_v6(X, r, c, method, alg)

    tStart = tic;

    switch lower(method.loss)
        case 'l2'
            [U, V, objHist] = train_l2_bpca_v6(X, r, c, alg.maxOuter, alg.tolOuter);
            E = residual_tensor(X, U, V);
            W = 1; % memory-safe constant-weight representation for L2

            model = make_model_struct_v6(U, V, W, NaN, NaN, NaN, ...
                NaN, 1, 1, 0, sum(E(:).^2), numel(objHist), 0, 'ok');
            model.objHist = objHist;
            return;

        otherwise
            model = train_robust_bpca_irls_v6(X, r, c, method, alg, tStart);
    end
end

function model = train_robust_bpca_irls_v6(X, r, c, method, alg, tStart)

    [U, V] = initialize_bpca_v6(X, r, c, method, alg);

    objHist = nan(alg.maxOuter, 1);
    objBeforeHist = nan(alg.maxOuter,1);
    tauHist = nan(alg.maxOuter, 1);
    etaHist = nan(alg.maxOuter, 1);
    tailHist = nan(alg.maxOuter, 1);          % severity actually used
    currentTailHist = nan(alg.maxOuter,1);    % current residual severity
    essElemHist = nan(alg.maxOuter, 1);
    essCombHist = nan(alg.maxOuter, 1);
    meanWHist = nan(alg.maxOuter, 1);
    zeroWHist = nan(alg.maxOuter, 1);
    scaleHist = nan(alg.maxOuter, 1);
    sampleOutlierHist = nan(alg.maxOuter,1);
    sampleMeanWHist = nan(alg.maxOuter,1);
    sampleSeverityHist = nan(alg.maxOuter,1);

    status = 'ok';
    mmRejectCount = 0;
    last = 0;

    % V1.7 severity memory.  A contaminated initialization may later be
    % partially absorbed by the current subspace, making the residual look
    % deceptively clean.  Max-so-far evidence prevents that false reversion.
    severityMemory = 0;

    for outer = 1:alg.maxOuter

        if toc(tStart) > alg.maxTimePerMethod
            status = 'timecap';
            break;
        end

        E = residual_tensor(X, U, V);
        evec = E(:);
        scale = robust_mad_scale(evec, alg.eps0);
        sampleDiag = default_sample_diag_v17();

        switch lower(method.loss)
            case 'tukey'
                if strcmpi(method.cutoff, 'ess')
                    if isfield(method,'etaMode') && strcmpi(method.etaMode,'fixed')
                        eta = method.etaValue;
                        currentSeverity = NaN;
                        tailSeverity = NaN;
                    else
                        currentSeverity = estimate_tail_severity_v6(E, alg);
                        tailSeverity = currentSeverity;

                        if isfield(alg,'useSeverityMemory') && alg.useSeverityMemory
                            switch lower(alg.severityMemoryMode)
                                case 'max'
                                    severityMemory = max(severityMemory,currentSeverity);
                                otherwise
                                    severityMemory = max(severityMemory,currentSeverity);
                            end
                            tailSeverity = severityMemory;
                        end
                        eta = eta_from_tail_severity_v17(tailSeverity,alg);
                    end

                    guardOn = method_clean_guard_v6(method);
                    if guardOn && ~isnan(tailSeverity) && tailSeverity == 0
                        tau = max(abs(evec)) * 10 + alg.eps0;
                        Welem = ones(size(E));
                    else
                        [tau, ~, ~] = select_tukey_tau_by_ess_v6( ...
                            evec, eta, tailSeverity, alg);
                        Welem = tukey_weights(E, tau);
                    end
                else
                    eta = NaN;
                    currentSeverity = NaN;
                    tailSeverity = NaN;
                    tau = alg.fixedTukeyC * scale;
                    Welem = tukey_weights(E, tau);
                end

                W = Welem;
                applySW = isfield(method,'sampleMode') && method.sampleMode && alg.useSampleWeight;
                if applySW
                    [Ws,sampleDiag] = sample_level_weights_v17( ...
                        E, alg, method_sample_guard_v17(method));
                    W = apply_sample_weights_v6(W, Ws, alg.sampleWeightAlpha);
                end
                objBefore = tukey_objective(E, tau);

            case 'huber'
                eta = NaN; currentSeverity = NaN; tailSeverity = NaN;
                tau = alg.huberC * scale;
                Welem = huber_weights(E, tau, alg.eps0);
                W = Welem;
                if isfield(method,'sampleMode') && method.sampleMode && alg.useSampleWeight
                    [Ws,sampleDiag] = sample_level_weights_v17(E, alg, method_sample_guard_v17(method));
                    W = apply_sample_weights_v6(W, Ws, alg.sampleWeightAlpha);
                end
                objBefore = huber_objective(E, tau);

            case 'welsch'
                eta = NaN; currentSeverity = NaN; tailSeverity = NaN;
                tau = alg.welschC * scale;
                Welem = welsch_weights(E, tau);
                W = Welem;
                if isfield(method,'sampleMode') && method.sampleMode && alg.useSampleWeight
                    [Ws,sampleDiag] = sample_level_weights_v17(E, alg, method_sample_guard_v17(method));
                    W = apply_sample_weights_v6(W, Ws, alg.sampleWeightAlpha);
                end
                objBefore = welsch_objective(E, tau);

            otherwise
                error('Unknown loss: %s', method.loss);
        end

        essElem = compute_weight_ess_ratio_v6(Welem, alg.eps0);
        essComb = compute_weight_ess_ratio_v6(W, alg.eps0);

        clear E evec Welem;
        [Unew, Vnew, subStatus, rejects] = solve_weighted_bpca_mm_v6( ...
            X, W, U, V, method.loss, tau, alg, tStart);
        mmRejectCount = mmRejectCount + rejects;

        Enew = residual_tensor(X, Unew, Vnew);
        objAfter = robust_objective_by_loss_v6(Enew, method.loss, tau);
        clear Enew;

        U = Unew; V = Vnew;
        last = outer;
        objBeforeHist(outer) = objBefore;
        objHist(outer) = objAfter;
        tauHist(outer) = tau;
        etaHist(outer) = eta;
        tailHist(outer) = tailSeverity;
        currentTailHist(outer) = currentSeverity;
        essElemHist(outer) = essElem;
        essCombHist(outer) = essComb;
        meanWHist(outer) = mean(W(:));
        zeroWHist(outer) = mean(W(:) <= alg.zeroTol);
        scaleHist(outer) = scale;
        sampleOutlierHist(outer) = sampleDiag.outlierRate;
        sampleMeanWHist(outer) = sampleDiag.meanWeight;
        sampleSeverityHist(outer) = sampleDiag.severity;
        clear W;

        if strcmp(subStatus, 'timecap')
            status = 'timecap';
            break;
        elseif strcmp(subStatus, 'stationary')
            status = 'stationary';
            break;
        elseif strcmp(subStatus, 'mm_stalled')
            status = 'mm_stalled';
        end

        relchg = abs(objBefore - objAfter) / (abs(objBefore) + alg.eps0);
        if relchg < alg.tolOuter
            if strcmp(subStatus, 'mm_stalled')
                status = 'mm_stalled';
            else
                status = 'converged';
            end
            break;
        end
    end

    if last == 0, last = 1; end

    objHist = objHist(1:last);
    objBeforeHist = objBeforeHist(1:last);
    tauHist = tauHist(1:last);
    etaHist = etaHist(1:last);
    tailHist = tailHist(1:last);
    currentTailHist = currentTailHist(1:last);
    essElemHist = essElemHist(1:last);
    essCombHist = essCombHist(1:last);
    meanWHist = meanWHist(1:last);
    zeroWHist = zeroWHist(1:last);
    scaleHist = scaleHist(1:last);
    sampleOutlierHist = sampleOutlierHist(1:last);
    sampleMeanWHist = sampleMeanWHist(1:last);
    sampleSeverityHist = sampleSeverityHist(1:last);

    clear E evec Enew W Welem;
    Efinal = residual_tensor(X, U, V);
    finalScale = robust_mad_scale(Efinal(:), alg.eps0);
    finalSampleDiag = default_sample_diag_v17();
    finalSampleWeights = ones(size(Efinal,3),1);
    finalCurrentTailSeverity = NaN;

    switch lower(method.loss)
        case 'tukey'
            if strcmpi(method.cutoff, 'ess')
                if isfield(method,'etaMode') && strcmpi(method.etaMode,'fixed')
                    finalEta = method.etaValue;
                    finalTailSeverity = NaN;
                    finalCurrentTailSeverity = NaN;
                else
                    finalCurrentTailSeverity = estimate_tail_severity_v6(Efinal,alg);
                    if isfield(alg,'useSeverityMemory') && alg.useSeverityMemory
                        severityMemory = max(severityMemory,finalCurrentTailSeverity);
                        finalTailSeverity = severityMemory;
                    else
                        finalTailSeverity = finalCurrentTailSeverity;
                    end
                    finalEta = eta_from_tail_severity_v17(finalTailSeverity,alg);
                end

                guardOn = method_clean_guard_v6(method);
                if guardOn && ~isnan(finalTailSeverity) && finalTailSeverity == 0
                    finalTau = max(abs(Efinal(:))) * 10 + alg.eps0;
                    WelemFinal = ones(size(Efinal));
                else
                    [finalTau, ~, ~] = select_tukey_tau_by_ess_v6( ...
                        Efinal(:), finalEta, finalTailSeverity, alg);
                    WelemFinal = tukey_weights(Efinal, finalTau);
                end
            else
                finalEta = NaN; finalTailSeverity = NaN;
                finalCurrentTailSeverity = NaN;
                finalTau = alg.fixedTukeyC * finalScale;
                WelemFinal = tukey_weights(Efinal, finalTau);
            end

            Wfinal = WelemFinal;
            if isfield(method,'sampleMode') && method.sampleMode && alg.useSampleWeight
                [Ws,finalSampleDiag] = sample_level_weights_v17( ...
                    Efinal, alg, method_sample_guard_v17(method));
                Wfinal = apply_sample_weights_v6(Wfinal, Ws, alg.sampleWeightAlpha);
                finalSampleWeights = Ws(:);
            end
            finalObj = tukey_objective(Efinal, finalTau);

        case 'huber'
            finalEta = NaN; finalTailSeverity = NaN;
            finalCurrentTailSeverity = NaN;
            finalTau = alg.huberC * finalScale;
            WelemFinal = huber_weights(Efinal, finalTau, alg.eps0);
            Wfinal = WelemFinal;
            if isfield(method,'sampleMode') && method.sampleMode && alg.useSampleWeight
                [Ws,finalSampleDiag] = sample_level_weights_v17(Efinal, alg, method_sample_guard_v17(method));
                Wfinal = apply_sample_weights_v6(Wfinal, Ws, alg.sampleWeightAlpha);
                finalSampleWeights = Ws(:);
            end
            finalObj = huber_objective(Efinal, finalTau);

        case 'welsch'
            finalEta = NaN; finalTailSeverity = NaN;
            finalCurrentTailSeverity = NaN;
            finalTau = alg.welschC * finalScale;
            WelemFinal = welsch_weights(Efinal, finalTau);
            Wfinal = WelemFinal;
            if isfield(method,'sampleMode') && method.sampleMode && alg.useSampleWeight
                [Ws,finalSampleDiag] = sample_level_weights_v17(Efinal, alg, method_sample_guard_v17(method));
                Wfinal = apply_sample_weights_v6(Wfinal, Ws, alg.sampleWeightAlpha);
                finalSampleWeights = Ws(:);
            end
            finalObj = welsch_objective(Efinal, finalTau);
    end

    finalESSElement = compute_weight_ess_ratio_v6(WelemFinal, alg.eps0);
    finalESSCombined = compute_weight_ess_ratio_v6(Wfinal, alg.eps0);

    model = make_model_struct_v6(U, V, Wfinal, finalTau, finalEta, finalTailSeverity, ...
        finalESSElement, finalESSCombined, mean(Wfinal(:)), ...
        mean(Wfinal(:) <= alg.zeroTol), finalObj, last, mmRejectCount, status);

    model.finalScale = finalScale;
    model.finalCurrentTailSeverity = finalCurrentTailSeverity;
    model.finalSampleOutlierRate = finalSampleDiag.outlierRate;
    model.finalSampleMeanWeight = finalSampleDiag.meanWeight;
    model.finalSampleSeverity = finalSampleDiag.severity;
    model.finalSampleActivationStrength = finalSampleDiag.activationStrength; % backward-compatible alias
    model.finalSampleDownweightStrength = finalSampleDiag.downweightStrength;
    model.finalSampleNeutralThreshold = finalSampleDiag.neutralThreshold;
    model.finalSampleFullDownweightThreshold = finalSampleDiag.fullDownweightThreshold;
    model.finalSampleAnyDownweight = finalSampleDiag.anyDownweight;
    model.finalSampleActivated = finalSampleDiag.activated; % audit only; no global gate
    model.finalSampleWeights = finalSampleWeights;

    model.objHist = objHist;
    model.objBeforeHist = objBeforeHist;
    model.tauHist = tauHist;
    model.etaHist = etaHist;
    model.tailSeverityHist = tailHist;
    model.currentTailSeverityHist = currentTailHist;
    model.essElementHist = essElemHist;
    model.essCombinedHist = essCombHist;
    model.meanWHist = meanWHist;
    model.zeroWHist = zeroWHist;
    model.scaleHist = scaleHist;
    model.sampleOutlierHist = sampleOutlierHist;
    model.sampleMeanWHist = sampleMeanWHist;
    model.sampleSeverityHist = sampleSeverityHist;
    model.finalPiHat = model.finalTailSeverity;
    model.finalESSRatio = model.finalESSElement;
end

function tf = method_clean_guard_v6(method)
    if isfield(method,'cleanGuard')
        tf = logical(method.cleanGuard);
    else
        tf = true;
    end
end

function tf = method_sample_guard_v17(method)
    if isfield(method,'sampleGuard') && ~isempty(method.sampleGuard)
        tf=logical(method.sampleGuard);
    else
        tf=true;
    end
end

function model = make_model_struct_v6(U, V, W, tau, eta, tailSeverity, ...
        essElement, essCombined, meanW, zeroW, obj, outerIters, mmRejectCount, status)
    model = struct();
    model.U = U;
    model.V = V;
    model.W = W;
    model.finalTau = tau;
    model.finalEta = eta;
    model.finalTailSeverity = tailSeverity;
    model.finalCurrentTailSeverity = tailSeverity;
    model.finalSampleOutlierRate = NaN;
    model.finalSampleMeanWeight = NaN;
    model.finalSampleSeverity = NaN;
    model.finalESSElement = essElement;
    model.finalESSCombined = essCombined;
    model.finalMeanW = meanW;
    model.finalZeroW = zeroW;
    model.finalObj = obj;
    model.outerIters = outerIters;
    model.mmRejectCount = mmRejectCount;
    model.status = status;
end

function [eta, tailSeverity] = choose_eta_v6(evec, method, alg)

    if isfield(method, 'etaMode') && strcmpi(method.etaMode, 'fixed')
        eta = method.etaValue;
        tailSeverity = NaN;
        return;
    end

    tailSeverity = estimate_tail_severity_v6(evec, alg);
    eta = eta_from_tail_severity_v17(tailSeverity,alg);
end

function eta = eta_from_tail_severity_v17(tailSeverity,alg)
    if ~isfinite(tailSeverity) || tailSeverity <= 0
        eta = alg.essEtaDefaultClean;
        return;
    end

    etaRaw = 1 - alg.etaGuard - alg.essTailGamma * tailSeverity;
    eta = min(etaRaw, alg.essEtaMaxContam);
    eta = max(eta, alg.essEtaMin);
end

function tailSeverity = estimate_tail_severity_v6(E, alg)
    % V1.7 real-data rule:
    %   * empirical clean-referenced features when available;
    %   * Gaussian/global-tail fallback for compatibility.
    %
    % The returned value is excess severity ABOVE calibrated clean
    % split-to-split variability.  Clean data can therefore map exactly to 0.

    feat = tail_features_real_tukey_v17(E,alg);

    useEmpirical = isfield(alg,'realTail') && isstruct(alg.realTail) && ...
        isfield(alg.realTail,'enabled') && alg.realTail.enabled && ...
        isfield(alg.realTail,'baselineFeatures') && ...
        numel(alg.realTail.baselineFeatures)>=4;

    if useEmpirical
        rawSeverity = empirical_tail_severity_from_features_v17( ...
            feat,alg.realTail.baselineFeatures,alg);

        if isfield(alg.realTail,'severityThreshold') && ...
                isfinite(alg.realTail.severityThreshold)
            cleanThr = alg.realTail.severityThreshold;
        else
            cleanThr = 0;
        end
        tailSeverity = max(0,rawSeverity-cleanThr);
    else
        ks=[alg.essTailK1 alg.essTailK2 alg.essTailK3];
        gp=[erfc(ks(1)/sqrt(2)) erfc(ks(2)/sqrt(2)) erfc(ks(3)/sqrt(2))];
        baseF=[gp gp(1)];
        rawSeverity=empirical_tail_severity_from_features_v17(feat,baseF,alg);
        tailSeverity=max(0,rawSeverity-alg.tailSeverityCleanThreshold);
    end

    tailSeverity=min(max(tailSeverity,0),alg.tailSeverityCap);
end

function [tau, bestESSRatio, bestZeroW] = select_tukey_tau_by_ess_v6(evec, eta, tailSeverity, alg)
    % MEMORY-SAFE V1.1:
    % Evaluate the exact same ESS criterion in chunks.  The previous
    % implementation formed a full w vector and then another full w.^2
    % vector for every candidate tau, which caused peak-memory failures on
    % real face tensors.  Chunking changes no statistics or thresholds.

    a = abs(evec(:));
    finiteMask = isfinite(a);
    if ~all(finiteMask)
        a = a(finiteMask);
    end

    if isempty(a) || max(a) < alg.eps0
        tau = 1;
        bestESSRatio = 1;
        bestZeroW = 0;
        return;
    end

    amin = max(local_percentile(a, 0.2), alg.eps0);
    amax = max(a);

    linGrid = linspace(amin, amax * 1.05 + alg.eps0, alg.essGridSize);
    logGrid = logspace(log10(amin + alg.eps0), ...
        log10(amax * 5 + alg.eps0), alg.essGridSize);
    grid = unique([linGrid(:); logGrid(:); amax * 10 + alg.eps0]);
    grid = grid(isfinite(grid) & grid > alg.eps0);

    if isnan(tailSeverity)
        zeroTarget = max(0, 1 - eta);
    else
        zeroTarget = tailSeverity;
    end
    zeroTarget = min(max(zeroTarget, 0), 0.40);
    zeroLower = alg.zeroLowerFactor * zeroTarget;
    zeroUpper = alg.zeroUpperFactor * zeroTarget;

    if isfield(alg,'memoryBlockSize') && ~isempty(alg.memoryBlockSize)
        blockSize = max(1000,round(alg.memoryBlockSize));
    else
        blockSize = 200000;
    end

    bestScore = Inf;
    tau = grid(end);
    bestESSRatio = 1;
    bestZeroW = 0;

    for k = 1:numel(grid)
        tk = grid(k);
        [essRatio, zeroW] = tukey_ess_zero_from_abs_chunked_v11( ...
            a, tk, alg.eps0, blockSize);

        essLoss = abs(essRatio - eta);
        if ~alg.useZeroCalibration || (~isnan(tailSeverity) && tailSeverity <= 0)
            zeroLoss = 0;
        else
            underLoss = max(0, zeroLower - zeroW);
            overLoss  = max(0, zeroW - zeroUpper);
            zeroLoss = alg.zeroUnderPenalty * underLoss + ...
                alg.zeroOverPenalty * overLoss;
        end
        score = essLoss + zeroLoss;

        if score < bestScore
            bestScore = score;
            tau = tk;
            bestESSRatio = essRatio;
            bestZeroW = zeroW;
        end
    end
end

function [essRatio, zeroW] = tukey_ess_zero_from_abs_chunked_v11(a, tau, eps0, blockSize)
    % Exact ESS/zero-weight computation without allocating full w and w.^2.
    N = numel(a);
    if N == 0 || tau <= 0 || ~isfinite(tau)
        essRatio = NaN; zeroW = NaN; return;
    end
    sw = 0; sw2 = 0; nZero = 0;
    for s = 1:blockSize:N
        e = min(N,s+blockSize-1);
        ab = a(s:e);
        rb = ab ./ tau;
        wb = (1 - rb.^2).^2;
        out = ab > tau;
        wb(out) = 0;
        wb(wb < 0) = 0;
        wb(wb > 1) = 1;
        sw = sw + sum(wb);
        sw2 = sw2 + dot(wb,wb);
        nZero = nZero + sum(out);
    end
    if sw2 <= eps0
        essRatio = 0;
    else
        essRatio = (sw^2/sw2)/N;
    end
    zeroW = nZero/N;
end

function [Ws,diag] = sample_level_weights_v17(E, alg, guardOn)
    % V1.7 CLEAN-NEUTRAL per-sample weighting.
    %
    % Primary path (guardOn=true):
    %   z <= c0 : weight exactly 1;
    %   c0 < z < c1 : smooth Tukey-type transition;
    %   z >= c1 : minimum pre-specified sample weight.
    % There is NO dataset-level activation gate.
    %
    % Diagnostic ablation (guardOn=false): apply full Tukey-type sample
    % weighting from z=0 to c1, reproducing the intentionally stronger
    % no-neutral-zone comparator without changing the ranking statistic.
    if nargin<3 || isempty(guardOn), guardOn=true; end

    z=sample_residual_z_v17(E,alg.eps0);
    n=numel(z);
    diag=default_sample_diag_v17();
    if n==0
        Ws=ones(size(z)); return;
    end

    if isfield(alg,'realSample') && isstruct(alg.realSample) && ...
            isfield(alg.realSample,'enabled') && alg.realSample.enabled
        ref=alg.realSample;
        c0=max(0,ref.neutralThreshold);
        c1=max(ref.fullDownweightThreshold,c0+alg.eps0);
        hasRef=true;
    else
        % Fallback is not used for the paper real-data suite.  It keeps the
        % function safe for isolated calls.
        c0=local_percentile(z,95);
        c1=max(local_percentile(z,99.5),c0+0.50);
        hasRef=false;
    end

    if guardOn && hasRef
        u=(z-c0)./max(c1-c0,alg.eps0);
        u=max(0,min(1,u));
        Ws=ones(n,1);
        mid=(z>c0 & z<c1);
        Ws(mid)=(1-u(mid).^2).^2;
        Ws(z>=c1)=alg.sampleWeightMin;
        Ws=max(Ws,alg.sampleWeightMin);
    else
        % Stronger diagnostic comparator: no clean-neutral region.
        u=z./max(c1,alg.eps0);
        Ws=(1-u.^2).^2;
        Ws(z>=c1)=0;
        Ws=max(min(Ws,1),alg.sampleWeightMin);
    end

    entry=(z>c0);
    full=(z>=c1);
    severity=mean(max(0,(z-c0)./max(c1-c0,alg.eps0)));
    downStrength=mean(1-Ws);

    diag.threshold=c1;                  % backward-compatible audit field
    diag.neutralThreshold=c0;
    diag.fullDownweightThreshold=c1;
    diag.outlierRate=mean(entry);       % fraction entering the neutral-zone tail
    diag.fullDownweightRate=mean(full);
    diag.severity=severity;
    diag.rawShift=severity;             % compatibility only; no batch shift gate in V1.7
    diag.baselineRate=NaN;
    diag.guardRate=c0;                  % compatibility only; stores c0
    diag.activationStrength=downStrength; % compatibility: now mean downweight strength
    diag.downweightStrength=downStrength;
    diag.meanWeight=mean(Ws);
    diag.activated=double(any(entry));  % audit only; not a global gate
    diag.anyDownweight=double(any(Ws<1-1e-12));
    if isfield(alg,'sampleStrongDownweightThreshold')
        diag.strongDownweightRate=mean(Ws<=alg.sampleStrongDownweightThreshold);
    else
        diag.strongDownweightRate=mean(Ws<=0.5);
    end
end

function diag = default_sample_diag_v17()
    diag = struct('threshold',NaN,'neutralThreshold',NaN, ...
        'fullDownweightThreshold',NaN,'outlierRate',0,'fullDownweightRate',0, ...
        'meanWeight',1,'severity',0,'rawShift',0,'activationStrength',0, ...
        'downweightStrength',0,'strongDownweightRate',0,'baselineRate',NaN, ...
        'guardRate',NaN,'activated',0,'anyDownweight',0);
end

function [meanClean,meanForeign,gap] = sample_weight_group_means_v17(Ws,mask)
    meanClean=NaN; meanForeign=NaN; gap=NaN;
    if isempty(Ws) || all(~isfinite(Ws(:))) || isempty(mask), return; end
    truth=squeeze(any(any(mask,1),2));
    truth=logical(truth(:));
    Ws=Ws(:);
    n=min(numel(Ws),numel(truth));
    Ws=Ws(1:n); truth=truth(1:n);
    if any(~truth), meanClean=mean(Ws(~truth),'omitnan'); end
    if any(truth),  meanForeign=mean(Ws(truth),'omitnan'); end
    if isfinite(meanClean) && isfinite(meanForeign)
        gap=meanClean-meanForeign;
    end
end

function W2 = apply_sample_weights_v6(W, Ws, alpha)

    [~, ~, n] = size(W);
    W2 = W;

    for i = 1:n
        W2(:,:,i) = W(:,:,i) * (Ws(i)^alpha);
    end
end

function [essRatio, zeroW] = compute_tukey_ess_zero_v6(evec, tau, eps0)

    a = abs(evec(:));
    a = a(isfinite(a));

    if isempty(a) || tau <= 0 || ~isfinite(tau)
        essRatio = NaN;
        zeroW = NaN;
        return;
    end

    w = (1 - (a ./ tau).^2).^2;
    w(a > tau) = 0;
    w(w < 0) = 0;
    w(w > 1) = 1;

    sw = sum(w);
    sw2 = sum(w.^2);

    if sw2 <= eps0
        essRatio = 0;
    else
        essRatio = (sw^2 / sw2) / numel(a);
    end

    zeroW = mean(a > tau);
end

function [U, V] = initialize_bpca_v6(X, r, c, method, alg)

    switch lower(alg.initMode)
        case 'l2'
            [U, V, ~] = train_l2_bpca_v6(X, r, c, 10, 1e-5);

        case 'robust_l2'
            Xclip = winsorize_tensor_by_mad(X, alg.clipC, alg.eps0);
            [U, V, ~] = train_l2_bpca_v6(Xclip, r, c, 10, 1e-5);

        otherwise
            error('Unknown initMode: %s', alg.initMode);
    end
end

function Xclip = winsorize_tensor_by_mad(X, clipC, eps0)
    x = X(:);
    medv = memfix_median(x,[],100000);
    s = robust_mad_scale(x, eps0);

    lo = medv - clipC * s;
    hi = medv + clipC * s;

    Xclip = min(max(X, lo), hi);
end

function [U, V, objHist] = train_l2_bpca_v6(X, r, c, maxIter, tol)

    [p, q, n] = size(X);

    Cr = zeros(p, p);
    Cc = zeros(q, q);

    for i = 1:n
        Xi = X(:,:,i);
        Cr = Cr + Xi * Xi';
        Cc = Cc + Xi' * Xi;
    end

    U = top_eigvecs_sym(Cr, r);
    V = top_eigvecs_sym(Cc, c);

    objHist = zeros(maxIter, 1);

    for it = 1:maxIter

        PV = V * V';
        SU = zeros(p, p);

        for i = 1:n
            Xi = X(:,:,i);
            SU = SU + Xi * PV * Xi';
        end

        U = top_eigvecs_sym(SU, r);

        PU = U * U';
        SV = zeros(q, q);

        for i = 1:n
            Xi = X(:,:,i);
            SV = SV + Xi' * PU * Xi;
        end

        V = top_eigvecs_sym(SV, c);

        objHist(it) = l2_bpca_objective(X, U, V);

        if it > 1
            relchg = abs(objHist(it) - objHist(it-1)) / (abs(objHist(it-1)) + 1e-12);
            if relchg < tol
                objHist = objHist(1:it);
                return;
            end
        end
    end
end

function [U, V, status, rejectCount] = solve_weighted_bpca_mm_v6(X, W, U, V, lossName, tau, alg, tStart)
    status = 'ok'; rejectCount = 0;
    for it = 1:alg.maxInner
        if toc(tStart) > alg.maxTimePerMethod
            status = 'timecap'; return;
        end

        E0 = residual_tensor(X,U,V);
        q0 = weighted_ls_objective_v6(E0,W);
        r0 = robust_objective_by_loss_v6(E0,lossName,tau);
        clear E0

        % MEMORY-SAFE weighted imputation: avoid keeping a full Xhat tensor
        % and avoid the large W.*X + (1-W).*Xhat temporaries.
        [p,q,n] = size(X);
        Ximp = zeros(p,q,n,'like',X);
        for ii = 1:n
            Xi = X(:,:,ii);
            Xhi = U*(U'*Xi*V)*V';
            Wi = W(:,:,ii);
            Ximp(:,:,ii) = Wi.*Xi + (1-Wi).*Xhi;
        end
        [Ucand,Vcand] = bpca_warm_alt_update_v6(Ximp,U,V,alg.fastBpcaSteps);
        clear Ximp

        % A rejected MM candidate can simply mean the subspace has stopped
        % moving.  Detect that case explicitly instead of labeling it a
        % numerical failure.
        candMove = projection_distance_normalized_real_tukey_v1(U,Ucand) + ...
                   projection_distance_normalized_real_tukey_v1(V,Vcand);
        if candMove < alg.stationarityTol
            status = 'stationary';
            return;
        end

        accepted = false; alpha = 1;
        for ls = 1:(alg.mmLineSearchMax+1)
            if alpha == 1
                Utry = Ucand; Vtry = Vcand;
            else
                Utry = qf_retraction((1-alpha)*U + alpha*Ucand);
                Vtry = qf_retraction((1-alpha)*V + alpha*Vcand);
            end
            Etry = residual_tensor(X,Utry,Vtry);
            qtry = weighted_ls_objective_v6(Etry,W);
            rtry = robust_objective_by_loss_v6(Etry,lossName,tau);
            clear Etry
            qOK = qtry <= q0 + alg.mmAcceptTol*(1+abs(q0));
            rOK = rtry <= r0 + alg.mmAcceptTol*(1+abs(r0));
            if qOK && rOK
                U = Utry; V = Vtry; accepted = true; break;
            end
            alpha = alpha*alg.mmShrink;
        end
        if ~accepted
            rejectCount = rejectCount+1;
            if alpha*candMove < alg.stationarityTol
                status='stationary';
            else
                status='mm_stalled';
            end
            return;
        end
        if toc(tStart) > alg.maxTimePerMethod
            status='timecap'; return;
        end
    end
end

function f = weighted_ls_objective_v6(E, W)
    % MEMORY-SAFE: accumulate by sample instead of E(:).^2 full temporary.
    f = 0;
    n = size(E,3);
    for i = 1:n
        Ei = E(:,:,i);
        Wi = W(:,:,i);
        f = f + sum(Wi(:) .* (Ei(:).^2));
    end
end

function f = robust_objective_by_loss_v6(E, lossName, tau)
    switch lower(lossName)
        case 'tukey'
            f = tukey_objective(E, tau);
        case 'huber'
            f = huber_objective(E, tau);
        case 'welsch'
            f = welsch_objective(E, tau);
        case 'l2'
            f = sum(E(:).^2);
        otherwise
            error('Unknown loss for objective: %s', lossName);
    end
end

function essRatio = compute_weight_ess_ratio_v6(W, eps0)
    % MEMORY-SAFE: no full W(:).^2 temporary.
    if isempty(W)
        essRatio = NaN;
        return;
    end
    sw = 0; sw2 = 0; N = 0;
    n3 = max(1,size(W,3));
    for i = 1:n3
        Wi = W(:,:,i);
        wi = Wi(:);
        good = isfinite(wi);
        if ~all(good), wi = wi(good); end
        sw = sw + sum(wi);
        sw2 = sw2 + dot(wi,wi);
        N = N + numel(wi);
    end
    if N == 0
        essRatio = NaN;
    elseif sw2 <= eps0
        essRatio = 0;
    else
        essRatio = (sw^2 / sw2) / N;
    end
end

function [U, V] = bpca_warm_alt_update_v6(X, U, V, numSteps)

    [p, q, n] = size(X);

    r = size(U, 2);
    c = size(V, 2);

    for step = 1:numSteps

        PV = V * V';
        SU = zeros(p, p);

        for i = 1:n
            Xi = X(:,:,i);
            SU = SU + Xi * PV * Xi';
        end

        U = top_eigvecs_sym(SU, r);

        PU = U * U';
        SV = zeros(q, q);

        for i = 1:n
            Xi = X(:,:,i);
            SV = SV + Xi' * PU * Xi;
        end

        V = top_eigvecs_sym(SV, c);
    end
end

function E = residual_tensor(X, U, V)

    [p, q, n] = size(X);
    E = zeros(p, q, n);

    for i = 1:n
        Xi = X(:,:,i);
        Xhat = U * (U' * Xi * V) * V';
        E(:,:,i) = Xi - Xhat;
    end
end

function Xhat = reconstruct_tensor(X, U, V)

    [p, q, n] = size(X);
    Xhat = zeros(p, q, n);

    for i = 1:n
        Xi = X(:,:,i);
        Xhat(:,:,i) = U * (U' * Xi * V) * V';
    end
end

function f = l2_bpca_objective(X, U, V)
    E = residual_tensor(X, U, V);
    f = sum(E(:).^2);
end

function W = tukey_weights(E, tau)
    if isempty(tau) || ~isscalar(tau) || tau <= 0 || ~isfinite(tau)
        tau = robust_mad_scale(E(:), 1e-12);
        tau = max(tau, 1e-12);
    end
    % MEMORY-SAFE: only one image-sized temporary at a time.
    W = zeros(size(E));
    n = size(E,3);
    for i = 1:n
        Ei = E(:,:,i);
        R = Ei ./ tau;
        Wi = (1 - R.^2).^2;
        Wi(abs(Ei) > tau) = 0;
        Wi(Wi < 0) = 0;
        Wi(Wi > 1) = 1;
        W(:,:,i) = Wi;
    end
end

function W = huber_weights(E, delta, eps0)
    if nargin < 3, eps0 = 1e-12; end
    if isempty(delta) || ~isscalar(delta) || ~isfinite(delta) || delta <= 0
        delta = robust_mad_scale(E(:), eps0);
        delta = max(delta, eps0);
    end
    W = ones(size(E));
    n = size(E,3);
    for i = 1:n
        Ei = E(:,:,i);
        A = abs(Ei);
        Wi = ones(size(Ei));
        idx = A > delta;
        Wi(idx) = delta ./ (A(idx) + eps0);
        W(:,:,i) = Wi;
    end
end

function W = welsch_weights(E, sigma)
    if isempty(sigma) || ~isscalar(sigma) || ~isfinite(sigma) || sigma <= 0
        sigma = robust_mad_scale(E(:), 1e-12);
        sigma = max(sigma, 1e-12);
    end
    W = zeros(size(E));
    n = size(E,3);
    for i = 1:n
        Ei = E(:,:,i);
        W(:,:,i) = exp(-(Ei ./ sigma).^2);
    end
end

function f = tukey_objective(E, tau)
    if isempty(tau) || ~isscalar(tau) || tau <= 0 || ~isfinite(tau)
        tau = robust_mad_scale(E(:), 1e-12);
        tau = max(tau, 1e-12);
    end
    f = 0; c = tau^2/6;
    n = size(E,3);
    for i = 1:n
        Ei = E(:,:,i);
        A = abs(Ei); inside = A <= tau;
        if any(inside(:))
            R = Ei(inside)./tau;
            f = f + sum(c*(1-(1-R.^2).^3));
        end
        f = f + sum(~inside(:))*c;
    end
end

function f = huber_objective(E, delta)
    if isempty(delta) || ~isscalar(delta) || ~isfinite(delta) || delta <= 0
        delta = robust_mad_scale(E(:), 1e-12);
        delta = max(delta, 1e-12);
    end
    f = 0; n = size(E,3);
    for i = 1:n
        Ei = E(:,:,i); A = abs(Ei); inside = A <= delta;
        if any(inside(:)), f = f + 0.5*sum(Ei(inside).^2); end
        if any(~inside(:)), f = f + sum(delta*A(~inside)-0.5*delta^2); end
    end
end

function f = welsch_objective(E, sigma)
    if isempty(sigma) || ~isscalar(sigma) || ~isfinite(sigma) || sigma <= 0
        sigma = robust_mad_scale(E(:), 1e-12);
        sigma = max(sigma, 1e-12);
    end
    f = 0; c = sigma^2/2; n = size(E,3);
    for i = 1:n
        Ei = E(:,:,i);
        f = f + sum(c*(1-exp(-(Ei(:)./sigma).^2)));
    end
end


function err = subspace_error(A, U)
    A = orth(A); U = orth(U);
    err = norm(A*A' - U*U', 'fro') / sqrt(2);
end

function err = subspace_error_normalized_v6(A, U)
    A = orth(A); U = orth(U);
    k = min(size(A,2), size(U,2));
    if k <= 0
        err = NaN;
        return;
    end
    err = norm(A*A' - U*U', 'fro') / sqrt(2*k);
end

function re = clean_reconstruction_error(Xclean, Xhat)
    % Compatibility: this is NMSE (squared normalized Frobenius error).
    [~, re] = clean_projection_metrics_v6(Xclean, Xhat);
end

function [nre, nmse] = clean_projection_metrics_v6(Xclean, Xhat)
    den = norm(Xclean(:)) + 1e-12;
    nre = norm(Xclean(:) - Xhat(:)) / den;
    nmse = nre^2;
end

function [elemROC, elemPR, sampROC, sampPR] = outlier_metrics_v6(W, mask, contamType)
    % L1-type baselines may not provide explicit weights.
    if isempty(W) || (isscalar(W) && ~isfinite(W))
        elemROC=NaN; elemPR=NaN; sampROC=NaN; sampPR=NaN; return;
    end
    if isscalar(W)
        % Constant score baseline (e.g. L2 W=1) without allocating a full tensor.
        if any(mask(:))
            elemROC = 0.5;
            elemPR = mean(mask(:));
        else
            elemROC = NaN; elemPR = NaN;
        end
        sampROC=NaN; sampPR=NaN;
        if strcmpi(contamType,'sample') && any(mask(:))
            sampLabel = squeeze(any(any(mask,1),2));
            if any(sampLabel) && any(~sampLabel)
                sampROC=0.5; sampPR=mean(sampLabel(:));
            end
        end
        return;
    end

    score = 1-W;
    if any(mask(:))
        elemROC = binary_auc_tied(score(:),mask(:));
        elemPR = binary_pr_auc_v6(score(:),mask(:));
    else
        elemROC=NaN; elemPR=NaN;
    end
    sampROC=NaN; sampPR=NaN;
    if strcmpi(contamType,'sample') && any(mask(:))
        sampScore=squeeze(mean(mean(score,1),2));
        sampLabel=squeeze(any(any(mask,1),2));
        sampROC=binary_auc_tied(sampScore(:),sampLabel(:));
        sampPR=binary_pr_auc_v6(sampScore(:),sampLabel(:));
    end
end

function prauc = binary_pr_auc_v6(score, label)
    score = score(:);
    label = label(:) > 0;
    valid = isfinite(score);
    score = score(valid); label = label(valid);
    nPos = sum(label);
    if nPos == 0 || nPos == numel(label)
        prauc = NaN;
        return;
    end
    if max(score) == min(score)
        prauc = nPos / numel(label);
        return;
    end

    [s, ord] = sort(score, 'descend');
    y = label(ord);
    tp = cumsum(y);
    fp = cumsum(~y);
    % Collapse tied thresholds at the last occurrence of each score.
    lastTie = [s(1:end-1) ~= s(2:end); true];
    tp = tp(lastTie); fp = fp(lastTie);
    recall = tp / nPos;
    precision = tp ./ max(tp + fp, 1);
    recall = [0; recall];
    precision = [1; precision];
    prauc = trapz(recall, precision);
end

function auc = binary_auc_tied(score, label)

    score = score(:);
    label = label(:) > 0;

    valid = isfinite(score);
    score = score(valid);
    label = label(valid);

    nPos = sum(label);
    nNeg = sum(~label);

    if nPos == 0 || nNeg == 0
        auc = NaN;
        return;
    end

    if max(score) == min(score)
        auc = 0.5;
        return;
    end

    ranks = tied_ranks_local(score);
    rankSumPos = sum(ranks(label));

    auc = (rankSumPos - nPos*(nPos+1)/2) / (nPos*nNeg);
end

function ranks = tied_ranks_local(x)

    [xs, order] = sort(x(:), 'ascend');
    n = numel(xs);
    ranksSorted = zeros(n,1);

    i = 1;
    while i <= n
        j = i;
        while j < n && xs(j+1) == xs(i)
            j = j + 1;
        end
        avgRank = (i + j) / 2;
        ranksSorted(i:j) = avgRank;
        i = j + 1;
    end

    ranks = zeros(n,1);
    ranks(order) = ranksSorted;
end

function val = local_percentile(x, pct)

    x = sort(x(:));
    n = numel(x);

    if n == 0
        val = NaN;
        return;
    end

    pos = 1 + (pct/100) * (n-1);
    lo = floor(pos);
    hi = ceil(pos);

    if lo == hi
        val = x(lo);
    else
        val = x(lo) + (pos-lo) * (x(hi) - x(lo));
    end
end

function U = top_eigvecs_sym(A, k)

    A = 0.5 * (A + A');
    [V, D] = eig(A);
    [~, idx] = sort(diag(D), 'descend');
    U = V(:, idx(1:k));
    U = qf_retraction(U);
end

function Q = qf_retraction(Y)

    [Q, R] = qr(Y, 0);
    d = sign(diag(R));
    d(d == 0) = 1;
    Q = Q * diag(d);
end

function Tsum = summarize_table_by_group_v6(T, groupVars, metricVars)

    n = height(T);
    key = strings(n,1);

    for i = 1:n
        parts = strings(1, numel(groupVars));
        for g = 1:numel(groupVars)
            v = T.(groupVars{g})(i);
            if iscell(v)
                parts(g) = string(v{1});
            elseif isstring(v)
                parts(g) = v;
            elseif ischar(v)
                parts(g) = string(v);
            elseif isnumeric(v)
                parts(g) = string(num2str(v, '%.12g'));
            else
                parts(g) = string(v);
            end
        end
        key(i) = strjoin(parts, "||");
    end

    [ukey, ~, gid] = unique(key, 'stable');
    statsPerMetric = 7; % N, mean, std, SE, CI95 low/high, median
    rows = cell(numel(ukey), numel(groupVars) + statsPerMetric*numel(metricVars));

    for k = 1:numel(ukey)
        idx = gid == k;
        firstIdx = find(idx, 1, 'first');
        col = 0;

        for g = 1:numel(groupVars)
            col = col + 1;
            val = T.(groupVars{g})(firstIdx);
            if iscell(val)
                rows{k,col} = val{1};
            else
                rows{k,col} = val;
            end
        end

        for m = 1:numel(metricVars)
            vals = T.(metricVars{m})(idx);
            vals = vals(isfinite(vals));

            N = numel(vals);
            if N == 0
                mu = NaN; sd = NaN; se = NaN; lo = NaN; hi = NaN; md = NaN;
            else
                mu = mean(vals);
                sd = std(vals);
                se = sd / sqrt(N);
                lo = mu - 1.96*se;
                hi = mu + 1.96*se;
                md = median(vals);
            end

            valsOut = {N, mu, sd, se, lo, hi, md};
            for j = 1:numel(valsOut)
                col = col + 1;
                rows{k,col} = valsOut{j};
            end
        end
    end

    varNames = groupVars;
    suffix = {'_N','_Mean','_Std','_SE','_CI95Low','_CI95High','_Median'};
    for m = 1:numel(metricVars)
        for j = 1:numel(suffix)
            varNames{end+1} = [metricVars{m}, suffix{j}];
        end
    end

    Tsum = cell2table(rows, 'VariableNames', varNames);
end


function oldDir=memfix_find_old(taskRoot)
    remembered=fullfile(taskRoot,'results_Tukey_v17_memoryfix','selected_old_directory.mat');
    if exist(remembered,'file')
        a=load(remembered,'payload');
        if isfield(a,'payload') && (ischar(a.payload) || isstring(a.payload)) && ...
                exist(fullfile(char(a.payload),'R1_clean_raw_v17.csv'),'file')
            oldDir=char(a.payload);
            return;
        end
    end
    base='results_real_ESS_Tukey_BRPCA_faces_v1_7_paperfinal';
    candidates={fullfile(taskRoot,base,'quick',base,'paper'),fullfile(taskRoot,base,'paper')};
    valid={};
    for k=1:numel(candidates)
        if exist(fullfile(candidates{k},'R1_clean_raw_v17.csv'),'file')
            valid{end+1}=candidates{k}; %#ok<AGROW>
        end
    end
    if numel(valid)==1
        oldDir=valid{1};
    else
        fprintf('Select the OLD PAPER folder containing R1_clean_raw_v17.csv.\n');
        oldDir=uigetdir(taskRoot,'Select OLD paper results (R0 and R1 CSV files)');
        if isequal(oldDir,0)
            error('TukeyMemfix:Folder','No folder selected. Pass the old PAPER directory as argument 2.');
        end
    end
end

function [cfg,res,Tclean,TcleanSum]=memfix_restore_csv(cfg,oldDir)
    fileNames={'R0A_rank_calibration_raw_v17.csv','R0A_rank_selected_v17.csv', ...
        'R0B_clean_tail_raw_v17.csv','R0B_clean_tail_threshold_v17.csv', ...
        'R0C_clean_sample_raw_v17.csv','R0C_clean_sample_reference_v17.csv', ...
        'R1_clean_raw_v17.csv','R1_clean_summary_v17.csv'};
    tables=cell(size(fileNames));
    for k=1:numel(fileNames)
        f=fullfile(oldDir,fileNames{k});
        if ~exist(f,'file')
            error('TukeyMemfix:MissingCSV','Missing old result: %s\nSelect the PAPER folder for the failed run.',f);
        end
        tables{k}=readtable(f,'TextType','char');
        if isempty(tables{k})
            error('TukeyMemfix:EmptyCSV','Empty result: %s',f);
        end
        fprintf('[FOUND] %s | %d rows\n',fileNames{k},height(tables{k}));
    end
    A=tables{2}; B=tables{4}; C=tables{6}; Tclean=tables{7}; TcleanSum=tables{8};
    memfix_require_columns(A,{'Dataset','SelectedK','NRep','ACCTolerance'});
    memfix_require_columns(B,{'Dataset','BaselineP1','BaselineP2','BaselineP3','BaselineConcentration', ...
        'CleanSeverityThreshold','QuantilePct','SampleTailQuantile','NRep'});
    memfix_require_columns(C,{'Dataset','NeutralThreshold','FullDownweightThreshold','NeutralQuantile', ...
        'FullDownweightQuantile','CleanEntryRate','CleanFullRate','NRep','NPooledScores'});
    memfix_require_columns(Tclean,{'Dataset','Repeat','Seed','Method','RankR','RankC','ACC','NRE','Time','Status', ...
        'FinalTau','FinalEta','FinalTailSeverity','FinalCurrentTailSeverity','FinalESSElement', ...
        'FinalESSCombined','FinalZeroW','OuterIters','MMRejectCount'});
    if height(A)~=4 || height(B)~=4 || height(C)~=4 || height(Tclean)~=560
        error('TukeyMemfix:Protocol','Expected the original complete PAPER R0 references and 560 R1 rows. QUICK/incomplete CSVs cannot be imported.');
    end
    methods=make_main_methods_real_tukey_v1(); methodNames={methods.name};
    memfix_require_columns(tables{1},{'Dataset','Repeat','Seed','CandidateK','ValidationACC','ValidationNRE'});
    memfix_require_columns(tables{3},{'Dataset','Repeat','Seed','RankR','RankC'});
    memfix_require_columns(tables{5},{'Dataset','Repeat','Seed','RankR','RankC','NSamples'});
    for id=1:numel(cfg.datasets)
        nm=cfg.datasets{id}; key=safe_field_name_real_tukey_v1(nm);
        ia=find(strcmp(A.Dataset,nm)); ib=find(strcmp(B.Dataset,nm)); ic=find(strcmp(C.Dataset,nm));
        assert(numel(ia)==1 && numel(ib)==1 && numel(ic)==1,'TukeyMemfix:Protocol','Missing/duplicate dataset references: %s',nm);
        large=any(strcmp(nm,{'PIE','XM2VTS'}));
        if large, group='large'; else, group='small'; end
        kval=A.SelectedK(ia);
        assert(ismember(kval,cfg.rankCalib.candidates),'TukeyMemfix:Rank','Unexpected rank in %s.',nm);
        assert(A.NRep(ia)==cfg.rankCalib.repeats.(group) && abs(A.ACCTolerance(ia)-cfg.rankCalib.accTolerance)<1e-12, ...
            'TukeyMemfix:Protocol','Rank calibration settings differ for %s.',nm);
        cfg.rank.(key)=[kval kval];
        ra=tables{1}(strcmp(tables{1}.Dataset,nm),:);
        rb=tables{3}(strcmp(tables{3}.Dataset,nm),:);
        rc=tables{5}(strcmp(tables{5}.Dataset,nm),:);
        na=cfg.rankCalib.repeats.(group); nb=cfg.tailCalib.repeats.(group); nc=cfg.sampleCalib.repeats.(group);
        assert(height(ra)==na*numel(cfg.rankCalib.candidates) && height(rb)==nb && height(rc)==nc, ...
            'TukeyMemfix:CalibrationRaw','Incomplete calibration raw rows for %s.',nm);
        for kk=cfg.rankCalib.candidates
            rr=ra(ra.CandidateK==kk,:);
            assert(isequal(sort(rr.Repeat(:)),(1:na)') && all(rr.Seed==1700000+10000*id+rr.Repeat), ...
                'TukeyMemfix:CalibrationRaw','Rank raw seeds/repeats differ for %s.',nm);
        end
        assert(isequal(sort(rb.Repeat(:)),(1:nb)') && all(rb.Seed==1710000+10000*id+rb.Repeat) && ...
            all(rb.RankR==kval & rb.RankC==kval),'TukeyMemfix:CalibrationRaw','Tail raw protocol differs for %s.',nm);
        assert(isequal(sort(rc.Repeat(:)),(1:nc)') && all(rc.Seed==1720000+10000*id+rc.Repeat) && ...
            all(rc.RankR==kval & rc.RankC==kval),'TukeyMemfix:CalibrationRaw','Sample raw protocol differs for %s.',nm);
        f=[B.BaselineP1(ib),B.BaselineP2(ib),B.BaselineP3(ib),B.BaselineConcentration(ib)];
        thr=B.CleanSeverityThreshold(ib);
        assert(all(isfinite(f)) && all(f>=0 & f<=1) && isfinite(thr) && thr>=0, ...
            'TukeyMemfix:Reference','Invalid tail reference for %s.',nm);
        assert(B.NRep(ib)==cfg.tailCalib.repeats.(group) && B.QuantilePct(ib)==cfg.tailCalib.quantile && ...
            B.SampleTailQuantile(ib)==cfg.alg.sampleTailQuantile,'TukeyMemfix:Protocol','Tail settings differ for %s.',nm);
        cfg.tailReference.(key)=struct('enabled',true,'baselineFeatures',f,'baselineP',f(1:3), ...
            'severityThreshold',thr,'k',[cfg.alg.essTailK1 cfg.alg.essTailK2 cfg.alg.essTailK3], ...
            'sampleTailQuantile',cfg.alg.sampleTailQuantile,'nRep',B.NRep(ib),'source','clean_development_empirical');
        cfg.tailThreshold.(key)=thr;
        c0=C.NeutralThreshold(ic); c1=C.FullDownweightThreshold(ic);
        assert(isfinite(c0) && isfinite(c1) && c1>c0 && c1-c0>=cfg.sampleCalib.minTransitionGap-1e-10, ...
            'TukeyMemfix:Reference','Invalid sample reference for %s.',nm);
        assert(C.NRep(ic)==cfg.sampleCalib.repeats.(group) && C.NeutralQuantile(ic)==cfg.sampleCalib.neutralQuantile && ...
            C.FullDownweightQuantile(ic)==cfg.sampleCalib.fullDownweightQuantile, ...
            'TukeyMemfix:Protocol','Sample calibration settings differ for %s.',nm);
        cfg.sampleReference.(key)=struct('enabled',true,'neutralThreshold',c0,'fullDownweightThreshold',c1, ...
            'nRep',C.NRep(ic),'nPooled',C.NPooledScores(ic),'neutralQuantile',C.NeutralQuantile(ic), ...
            'fullDownweightQuantile',C.FullDownweightQuantile(ic),'cleanEntryRate',C.CleanEntryRate(ic), ...
            'cleanFullRate',C.CleanFullRate(ic),'source','clean_development_pooled_neutral_zone');
        R=Tclean(strcmp(Tclean.Dataset,nm),:);
        expectedRep=cfg.nRep.clean.(group);
        assert(height(R)==expectedRep*numel(methodNames),'TukeyMemfix:R1','Unexpected R1 row count for %s.',nm);
        for rep=1:expectedRep
            rr=R(R.Repeat==rep,:);
            assert(height(rr)==numel(methodNames) && isequal(sort(string(rr.Method(:))),sort(string(methodNames(:)))), ...
                'TukeyMemfix:R1','R1 methods missing/duplicated: %s repeat %d.',nm,rep);
            assert(all(rr.Seed==cfg.evalSeedOffset+1100000+1000*id+rep) && all(rr.RankR==kval & rr.RankC==kval), ...
                'TukeyMemfix:R1','R1 seeds/ranks do not match %s repeat %d.',nm,rep);
        end
        assert(all(isfinite(R.ACC) & R.ACC>=0 & R.ACC<=1) && all(isfinite(R.NRE) & R.NRE>=0), ...
            'TukeyMemfix:R1','Invalid R1 ACC/NRE for %s.',nm);
        fprintf('[RESTORED] %s | k=%d | guard=%.15g | c0=%.15g c1=%.15g\n',nm,kval,thr,c0,c1);
    end
    % Recompute the summary from checked raw rows to avoid importing a stale
    % summary file from a different run. This performs no model fitting.
    TcleanSum=summarize_table_by_group_v6(Tclean,{'Dataset','Method'}, ...
        {'ACC','NRE','Time','FinalTau','FinalEta','FinalTailSeverity','FinalCurrentTailSeverity', ...
         'FinalESSElement','FinalESSCombined','FinalZeroW','OuterIters','MMRejectCount'});
    res=struct('cfg',cfg,'R0A_rank_raw',tables{1},'R0A_rank_selected',A, ...
        'R0B_clean_tail_raw',tables{3},'R0B_clean_tail_threshold',B, ...
        'R0C_clean_sample_raw',tables{5},'R0C_clean_sample_reference',C, ...
        'R1_clean',Tclean,'R1_clean_summary',TcleanSum);
    s=string(Tclean.Status);
    fprintf('R1 statuses: ok=%d converged=%d stationary=%d mm_stalled=%d timecap=%d\n', ...
        sum(s=="ok"),sum(s=="converged"),sum(s=="stationary"),sum(s=="mm_stalled"),sum(s=="timecap"));
    if any(s=="mm_stalled" | s=="timecap")
        warning('TukeyMemfix:R1Status','R1 contains stalled/time-limited fits; retain and review these statuses.');
    end
end

function memfix_require_columns(T,names)
    if ~all(ismember(names,T.Properties.VariableNames))
        error('TukeyMemfix:Schema','CSV columns do not match original V1.7. Missing: %s', ...
            strjoin(setdiff(names,T.Properties.VariableNames),', '));
    end
end

function signature=memfix_signature(cfg,allData,oldDir)
    config=rmfield(cfg,'out_dir');
    signature=struct('version','v17-memoryfix-20260911','cfg',config, ...
        'code',fileread([mfilename('fullpath') '.m']),'data',struct(),'oldCSV',struct());
    for k=1:numel(cfg.datasets)
        nm=cfg.datasets{k}; key=safe_field_name_real_tukey_v1(nm); ds=allData.(key);
        info=dir(ds.source);
        signature.data.(key)=struct('source',ds.source,'fileBytes',info.bytes,'fileDate',info.datenum, ...
            'size',size(ds.X),'labels',ds.labels,'sum',sum(ds.X(:)),'norm',norm(ds.X(:)));
    end
    ff=dir(fullfile(oldDir,'R0*.csv'));
    ff=[ff;dir(fullfile(oldDir,'R1*.csv'))];
    for k=1:numel(ff)
        key=matlab.lang.makeValidName(ff(k).name);
        signature.oldCSV.(key)=fileread(fullfile(oldDir,ff(k).name));
    end
end

function memfix_check_manifest(outDir,signature)
    f=fullfile(outDir,'run_manifest.mat');
    if exist(f,'file')
        a=load(f,'payload');
        if ~isequaln(a.payload,signature)
            error('TukeyMemfix:ChangedRun', ...
                'Code, settings, data, or old results changed. Keep the existing output folder as a backup and rename it before starting a new run: %s',outDir);
        end
    else
        memfix_atomic_save(f,signature);
    end
end

function T=memfix_diagnose(allData,cfg,methods)
    memfix_selftest();
    id=find(strcmp(cfg.datasets,'PIE'),1); nm='PIE';
    ds=allData.(safe_field_name_real_tukey_v1(nm));
    [r,c]=get_rank_real_tukey_v1(cfg,nm,size(ds.X));
    seed=cfg.evalSeedOffset+1200000+10000*id+1;
    [ii,ig,ip]=split_threeway_by_identity_real_tukey_v1(ds.labels,cfg.splitRatios,seed);
    Xclean=ds.X(:,:,ii); Xgal=ds.X(:,:,ig); Xprobe=ds.X(:,:,ip);
    plan=make_element_contamination_plan_real_tukey_v1(Xclean,'impulse',max(cfg.cellwiseRates),seed+1000,cfg);
    [X,mask,rate]=apply_element_contamination_plan_real_tukey_v1(Xclean,plan,0.30,4.5,cfg);
    clear Xclean;
    rows=cell(numel(methods),10);
    fprintf('[DIAGNOSIS] PIE, repeat 1, impulse rate 0.30, strength 4.5; 7 fits only.\n');
    for mm=1:numel(methods)
        cfg.memfix.stage=sprintf('DIAGNOSE PIE method %d/7',mm);
        fprintf('[DIAGNOSIS %d/7] %s\n',mm,methods(mm).name);
        t=tic; model=fit_method_real_tukey_v1(X,r,c,methods(mm),cfg); elapsed=toc(t);
        acc=recognition_accuracy_real_tukey_v1(Xgal,ds.labels(ig),Xprobe,ds.labels(ip),model.U,model.V,cfg);
        nre=projection_nre_real_tukey_v1(Xprobe,model.U,model.V);
        [auc,pr,~,~]=outlier_metrics_v6(model.W,mask,'impulse');
        assert(isfinite(acc) && isfinite(nre),'TukeyMemfix:DiagnosticMetric','Nonfinite diagnostic ACC/NRE.');
        rows(mm,:)={nm,methods(mm).name,rate,acc,nre,elapsed,auc,pr,model.status,mean(model.finalSampleWeights)};
        T=cell2table(rows(1:mm,:),'VariableNames',{'Dataset','Method','ActualRate','ACC','NRE','Time','ElemROCAUC','ElemPRAUC','Status','SampleMeanWeight'});
        writetable(T,fullfile(cfg.out_dir,'diagnosis_results.csv'));
        clear model;
        memfix_print_memory(sprintf('AFTER DIAGNOSIS %d/7',mm));
    end
end

function model=fit_method_real_tukey_v1(X,r,c,method,cfg)
    if isfield(cfg,'memfix')
        ctx=struct('stage',cfg.memfix.stage,'method',method.name,'sizeX',size(X), ...
            'classX',class(X),'elements',numel(X),'rank',[r c],'time',datestr(now,31));
        wx=whos('X'); ctx.bytesX=wx.bytes;
        try
            [ctx.memoryUser,ctx.memorySystem]=memory;
        catch
        end
        memfix_atomic_save(fullfile(cfg.memfix.logDir,'last_fit_context.mat'),ctx);
        fprintf('[FIT] %s | %s | X %.2f MiB\n',ctx.stage,method.name,wx.bytes/1024^2);
        memfix_print_memory('BEFORE FIT');
    end
    model=fit_method_real_tukey_v1_core(X,r,c,method,cfg);
end

function memfix_print_memory(label)
    try
        [u,s]=memory;
        fprintf('[MEM] %s | MATLAB %.3f GiB | free RAM %.3f GiB | max array %.3f GiB\n', ...
            label,u.MemUsedMATLAB/1024^3,s.PhysicalMemory.Available/1024^3,u.MaxPossibleArrayBytes/1024^3);
    catch
        fprintf('[MEM] %s | memory() unavailable on this platform\n',label);
    end
end

function memfix_failure(ME,outDir)
    try
        f=fullfile(outDir,'failure_report.txt'); fid=fopen(f,'a');
        if fid>=0
            fprintf(fid,'\n%s\n%s\n',datestr(now,31),getReport(ME,'extended','hyperlinks','off'));
            try
                [u,s]=memory;
                fprintf(fid,'MATLAB used bytes: %.0f\nAvailable RAM bytes: %.0f\nMax array bytes: %.0f\n', ...
                    u.MemUsedMATLAB,s.PhysicalMemory.Available,u.MaxPossibleArrayBytes);
            catch
            end
            fclose(fid);
        end
        fprintf(2,'Stopped. Completed checkpoints are retained. See %s\n',f);
        fprintf(2,'Also retain run_log.txt and last_fit_context.mat.\n');
    catch
        fprintf(2,'Stopped; could not write all diagnostics. Retain the command-window error.\n');
    end
end

function memfix_atomic_save(file,payload)
    % Save a small checkpoint to a temporary file, then replace its target.
    folder=fileparts(file);
    tmp=[tempname(folder) '.mat'];
    cleaner=onCleanup(@() memfix_remove_tmp(tmp)); %#ok<NASGU>
    save(tmp,'payload','-v7');
    [ok,msg]=movefile(tmp,file,'f');
    if ~ok, error('TukeyMemfix:Checkpoint','Checkpoint could not be committed: %s',msg); end
end

function memfix_remove_tmp(file)
    if exist(file,'file'), delete(file); end
end

function s=robust_mad_scale(evec,eps0)
    % Both medians are GLOBAL and exact order statistics, with bounded
    % working arrays. The input/residual tensor itself still occupies RAM.
    evec=evec(:);
    medv=memfix_median(evec,[],100000);
    madv=memfix_median(evec,medv,100000);
    s=1.4826*madv+eps0;
end

function value=memfix_median(x,center,bs)
    n=numel(x);
    if n<=bs
        v=x(:);
        if ~isempty(center), v=abs(v-center); end
        value=median(v);
        return;
    end
    k1=floor((n+1)/2); k2=ceil((n+1)/2);
    a=memfix_kth(x,center,k1,bs);
    if k1==k2, value=a; return; end
    b=memfix_kth(x,center,k2,bs);
    value=median([a;b]);
end

function value=memfix_kth(x,center,k,bs)
    % Select an actual observed order statistic by repeated bounded scans.
    % The interval always shrinks to observed values; no numeric tolerance,
    % histogram approximation, random subsampling, or block-median averaging.
    n=numel(x); lo=Inf; hi=-Inf; negInf=0; posInf=0;
    for st=1:bs:n
        v=x(st:min(n,st+bs-1)); v=v(:);
        if ~isempty(center), v=abs(v-center); end
        if any(isnan(v)), value=NaN; return; end
        negInf=negInf+sum(v==-Inf); posInf=posInf+sum(v==Inf);
        v=v(isfinite(v));
        if ~isempty(v), lo=min(lo,min(v)); hi=max(hi,max(v)); end
    end
    if k<=negInf, value=-Inf; return; end
    if k>n-posInf, value=Inf; return; end
    k=k-negInf; active=n-negInf-posInf;
    while true
        if lo==hi, value=lo; return; end
        if active<=bs
            buffer=zeros(active,1,'like',x); at=0;
            for st=1:bs:n
                v=x(st:min(n,st+bs-1)); v=v(:);
                if ~isempty(center), v=abs(v-center); end
                v=v(v>=lo & v<=hi);
                buffer(at+(1:numel(v)))=v; at=at+numel(v);
            end
            assert(at==active,'TukeyMemfix:Selection','Exact median interval count mismatch.');
            buffer=sort(buffer); value=buffer(k); return;
        end
        pivot=lo/2+hi/2;
        if pivot<lo || pivot>=hi, pivot=lo; end
        left=0; maxLeft=-Inf; minRight=Inf;
        for st=1:bs:n
            v=x(st:min(n,st+bs-1)); v=v(:);
            if ~isempty(center), v=abs(v-center); end
            v=v(v>=lo & v<=hi);
            q=v<=pivot; left=left+sum(q);
            if any(q), maxLeft=max(maxLeft,max(v(q))); end
            if any(~q), minRight=min(minRight,min(v(~q))); end
        end
        assert(left>0 && left<active,'TukeyMemfix:Selection','Exact median interval failed to shrink.');
        if k<=left
            hi=maxLeft; active=left;
        else
            lo=minRight; active=active-left; k=k-left;
        end
    end
end

function result=memfix_selftest()
    state=rng; guard=onCleanup(@() rng(state)); %#ok<NASGU>
    rng(71831,'twister');
    cases={[],0,[1;2],[3;1;2],ones(97,1),[-Inf;-3;2;Inf],[NaN;1;2], ...
        [Inf;Inf],[-realmax;realmax],[-1e-300;0;1e-300],randi(7,513,1)-4,randn(1001,1)};
    count=0;
    for j=1:numel(cases)
        x=cases{j};
        for bs=[3 17 100000]
            a=memfix_median(x,[],bs); b=median(x(:));
            assert(isequaln(a,b),'TukeyMemfix:Selftest','Global median mismatch.');
            a=memfix_median(x,b,bs); ref=median(abs(x(:)-b));
            assert(isequaln(a,ref),'TukeyMemfix:Selftest','Global absolute-deviation median mismatch.');
            count=count+2;
        end
    end
    x=randn(200001,1);
    ref=1.4826*median(abs(x-median(x)))+1e-12;
    assert(isequaln(robust_mad_scale(x,1e-12),ref),'TukeyMemfix:Selftest','Large-array MAD mismatch.');
    fprintf('[SELFTEST PASSED] %d exact median checks and one large MAD check.\n',count);
    result=struct('checks',count+1,'passed',true);
end
