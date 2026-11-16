# Data and frozen-input setup

The repository separates generated synthetic data, archived real-image inputs,
and retained summary evidence. These have different reproducibility requirements.

## What can be generated without image data

The core synthetic generator and separate sample-layer generator are included.
They generate arrays from their frozen seeds and protocol settings.
No ORL/YALE images or real-data archive is needed for `selftest`, `quick`,
`core_synthetic`, `solver_synthetic` or `budget_synthetic`.
The sample experiment also generates its own cases; follow the root README.

Core synthetic settings include 240 matrices of size 40 x 30 with rank 5 x 4.
Its full grid and the new four-condition sample experiment are separate protocols.
Changing dimensions, seeds, algorithm settings or budgets creates a new experiment.

## What is not distributed here

- Raw third-party ORL and YALE images.
- The complete normalized-image cache used by the real fits.
- Complete fixed split, calibration and real-case archives.
- All fitted model matrices and full optimization traces from the original runs.

The retained result CSVs are sufficient for the documented summary/figure analyses,
but they are not a replacement for those input and model archives.
Consult the original dataset providers for access and reuse terms; no unverified
download URL or dataset redistribution permission is asserted here.

## Exact real-image rerun requirements

The P0 real-data interface expects a completed frozen archive, not a raw-image folder:

```text
frozen_archive/
  cache/
    ORL_normalized.mat
    YALE_normalized.mat
  splits/
    ORL_r001.mat ... ORL_r010.mat
    YALE_r001.mat ... YALE_r010.mat
  calibration/
    ORL_r001/fold.mat ... ORL_r010/fold.mat
    YALE_r001/fold.mat ... YALE_r010/fold.mat
  jobs/
    <original task directory>/case.mat
```

Keep original variable schemas, names, numerical arrays, IDs and hashes intact.
Creating empty files or renaming unrelated MAT files will not satisfy the checks.

The cache contains normalized observations, labels and data/protocol hashes.
Split files contain learning, development, gallery and probe memberships.
Fold files contain the selected rank, development-reference objects and exclusion
receipts, including the calibration IDs and `probeExcluded` flag.
Case files contain the fixed contamination plan and matching data/split/protocol
signatures. Case replay verifies the resulting corruption hash and realized coverage.

The interface checks that the probe does not enter development or calibration.
It also verifies that a case's learning/gallery/probe IDs match its split.
For exact schema requirements, inspect `modules/core/frozen/SU_DATA.m` and
`modules/core/frozen/SU_CASE.m`.

## Configure paths through options

Run MATLAB from the repository root. Use your actual absolute archive path:

```matlab
repoRoot = pwd;
opts = struct();
opts.archiveRoot = 'D:\TukeyData\frozen_archive';
opts.outputRoot = fullfile(repoRoot,'results','p0_core');
RUN_EXPERIMENTS('real_preflight',opts);
RUN_EXPERIMENTS('core_real',opts);
```

`real_preflight` checks both the core and extended-main case lists.
Individual real actions also preflight their own required datasets and conditions.
For a partial archive, invoke only a matching module after checking its input scope.
Other real actions include `solver_real`, `extension_real`, `tune_real` and `budget_real`.

The core entry accepts only option fields defined in `P0_CONFIG.m`.
Set `archiveRoot` and `outputRoot` through `opts`; do not edit frozen scientific files.
Do not override `packageRoot`, which is derived from the installed code location.
An output directory created with changed sources or protocol settings cannot be
reused as if it belonged to the original experiment.

## If the frozen archive is unavailable

You can run generated-data experiments and inspect retained summary evidence.
You cannot claim an exact rerun of the manuscript's real-image fits.
The public P0 entry does not automatically rebuild the original archive from images.
Rebuilding inputs with new splits or recalibration would define a new evaluation,
which must be labeled and assessed separately rather than substituted into old tables.
The author's release/access arrangement for these frozen inputs must be stated
explicitly before claiming complete real-data reproducibility.

The later supplement runner has its own input/setup protocol. Its presence does
not supply the missing P0 archive or retroactively complete planned comparisons.
A saved initialization evaluation does not itself constitute a fitted GLRAM baseline.

## Environment and storage

The authors' working environment is MATLAB R2025a. Original core notes recommend
R2018b or newer; this packaging task did not independently execute MATLAB or
certify compatibility across releases. Core hashes use Java, so a MATLAB session
with JVM support is required. Do not start these runs with `-nojvm`.
Core synthetic code does not require the Statistics or Parallel Computing Toolbox.
Full numerical compatibility should be checked with `selftest` and `quick` locally.

Keep images, caches, local output models and large traces outside Git source history.
Use the repository's ignored data/results locations or a separate local disk.
Retain full local archives even when sharing compact review CSVs.
