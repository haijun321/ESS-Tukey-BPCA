# External methods and their execution status

The supplementary runner distinguishes an available interface from a completed
scientific comparison. Its external-method interfaces are included so that
additional comparisons can be executed on the frozen real-image inputs. Their
presence does not establish that the corresponding results appear in the
current manuscript.

## Status of each method

| Method label | Implementation in this repository | Current execution requirements |
| --- | --- | --- |
| `L2` | Squared-loss objective using the retained P0 numerical solver and the common robust-BPCA initialization | MATLAB and the required frozen real-image archive |
| `BA2DPCA` | Adapter contract and readiness checks; no verified original implementation is bundled | A verified implementation and an adapter with source provenance; otherwise `BLOCKED` |
| `L2pSB2DPCA` | Adapter contract; not a bundled implementation or a default completed baseline | A verified implementation and its adapter |
| `ROMPCA` | MATLAB/R I/O bridge and an explicit downloader for a pinned original-author R source | R, its listed packages, the original source, and a successful local pilot |
| `RA2DPCA_dev` | Optional independent MATLAB port retained under `legacy_nb/external/` | Explicit method selection and the documented representation-dimension checks |

The `L2` result is a shared-initialization squared-loss reference. It is not an
independently obtained official GLRAM implementation, and the common `INIT`
readout is not a converged L2/GLRAM solution.

## Selecting supplementary tasks

Use the repository entry point with an explicit frozen archive and a separate
output directory. The default supplementary task is initialization evaluation;
external comparisons are requested explicitly:

```matlab
opts = struct();
opts.archiveRoot = 'D:\research\results_Tukey_CONFIRM_v1';
opts.outputRoot = 'D:\research\results_external_pilot';
opts.modules = {'03_external'};
opts.moduleOptions = struct('externalMethods', {{'L2','ROMPCA'}});
RUN_EXPERIMENTS('supp_plan', opts);
RUN_EXPERIMENTS('supp_pilot', opts);
```

Replace both paths with real local directories. The archive must contain the
original `cache/`, `splits/`, `calibration/`, and `jobs/` objects. A directory of
raw images or exported CSV summaries does not replace that archive. Run a
scientific `supp_paper` job with the intended frozen options and an appropriate
output directory after the pilot. Pilot results remain engineering checks and
are not included in paper summaries.

`opts.moduleOptions` passes supplementary-module configuration fields through
to the retained runner. For example, it can specify `rscriptPath`,
`rompcaSource`, `rLibraryPath`, or verified `externalAdapters`. Keep the same
scientific configuration when resuming a stage; the runner rejects incompatible
saved protocols rather than mixing their outputs.

## Original-author ROMPCA setup

ROMPCA is the method of Hirari, Centofanti, Hubert, and Van Aelst,
*Casewise and Cellwise Robust Multilinear Principal Component Analysis*,
DOI: <https://doi.org/10.1080/10618600.2026.2637632>.

The original-author source and example data are not bundled. The retained
downloader uses:

- Author source: <https://fabiocentofanti.github.io/files/Code_ROMPCA.zip>
- ZIP SHA256: `4b28e46b76257bbc6e71da9319b4014f05c41d69a049eaab1a146d14111f177b`
- R-source SHA256: `e0817d038ce9da2754228e7a875b2b5004fb103295675650f45c72527883e171`

Download, dependency installation, and readiness checking are explicit separate
operations. Scientific runs do not automatically download source or install R
packages:

```matlab
suppDir = fullfile(pwd, 'modules', 'supplement');
addpath(suppDir, '-begin');
setupOptions = struct();
setupOptions.archiveRoot = 'D:\research\results_Tukey_CONFIRM_v1';
setupOptions.outputRoot = 'D:\research\results_external_setup';
C = CSSP_SETUP('paper', setupOptions);
% If necessary, set C.rscriptPath to the actual Rscript executable.
CSSP_SETUP_ROMPCA('download', C);
CSSP_SETUP_ROMPCA('install', C);
CSSP_SETUP_ROMPCA('check', C);
```

Run this example from the repository root. The setup configuration and the
subsequent experiment must refer to the same source and R-library locations.
The downloader stops if the original source no longer matches the recorded pin;
it does not silently accept a different author release.

The bridge checks the following R packages: `argparse`, `rTensor`, `Rcpp`,
`cellWise`, `ggplot2`, `RcppArmadillo`, `devtools`, `OmicsPLS`, `combinat`,
`fastmatrix`, `Matrix`, `abind`, `rrcov`, `robustbase`, `scales`, `reshape2`, and
`RSpectra`. Installation availability depends on the local R environment. A
dependency-ready receipt is not evidence of a successful model fit.

The bridge passes training observations, ranks, seed, and iteration settings to
the original numerical functions. It does not supply contamination masks,
probe images, or probe labels. It retains native initialization and mean-aware
out-of-sample reconstruction. Its setup, source pins, adapter contract, and
budget differences are documented in
[`EXTERNAL_SETUP_CN.txt`](../modules/supplement/EXTERNAL_SETUP_CN.txt).

## BA2DPCA and L2pSB2DPCA adapters

These names are not aliases for a generic angular or IRLS routine. Configure an
adapter only after identifying its actual source, version, and numerical
conventions. The expected interface is:

```matlab
function model = MY_VERIFIED_ADAPTER(X, info)
```

`info` supplies ranks, seed, budget, optional common initial bases, and clean
gallery development information. It does not contain the injected mask, probe,
or probe labels. The adapter returns `U`, `V`, optional `mean`, source
`provenance`, and the actual `initializationHash`. The runner checks dimensions,
finite outputs, and orthogonality rather than silently repairing a baseline.

Without such an implementation, readiness checks and task reports retain
`BLOCKED`. A missing adapter is not a zero score and is not a successfully
completed comparison.

## Optional RA-2DPCA development port

`RA2DPCA_dev` refers to the independent MATLAB implementation of the recurrence
documented in Tan and Yang, *Reweighted angle two-dimensional principal
component analysis for feature extraction*, Pattern Recognition 168 (2025),
111817, DOI: <https://doi.org/10.1016/j.patcog.2025.111817>.

The original author repository is <https://github.com/cqtzx/RA2DPCA>; the retained
reference commit is `84d54472cc5b615611b605f330df2501d00401d0`. This repository
does not identify the MATLAB port as official author software or bitwise
equivalent R code. Keep
[`RA_PROVENANCE.txt`](../modules/supplement/legacy_nb/external/RA_PROVENANCE.txt)
with the implementation.

The method is one-sided and has `p*k` feature entries. This differs from the
bilateral representation size `r*c`. Report the actual feature dimension and
native mean handling. Degenerate weights or unusable outputs remain explicitly
labelled; the runner does not silently change parameters to rescue a baseline.

## Reading results

Read `task_status.csv`, `run_status.json`, and external readiness information
together. `BLOCKED`, `FAILED`, and unusable-baseline records are retained
separately from usable numerical results. Completion of a job does not establish
convergence or superiority. The supplied repository has not executed these
additional real-image/R fits in this preparation environment.
