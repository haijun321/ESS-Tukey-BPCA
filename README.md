# ESS-Tukey-BPCA research code

[中文说明](README_CN.md) · [Experiment map](docs/EXPERIMENT_MAP.md) ·
[Real-data setup](docs/DATA_SETUP.md) · [External methods](docs/EXTERNAL_METHODS.md)

Code associated with the manuscript **Weight-Based Cutoff Calibration for Tukey
Bilateral PCA: Properties and Empirical Limits**. This is a research-code
collection prepared on 16 November 2026; it does not represent the manuscript
as accepted or published.

Authors: Haijun Jiang, Ganggang Xu, Fen Jiang, Yue Wang, and Xinyu Li.
Corresponding author: xinyuli1322@163.com.

## What is included

| Directory | Contents | Input and evidence scope |
|---|---|---|
| `modules/core/` | Frozen P0 runner, revised solver, legacy solver and helpers | Synthetic generation is self-contained; real runs require the frozen archive |
| `modules/sample_extension/` | Standalone E versus E+S experiment | Generates its own data; 8 computational prechecks and 80 formal fits |
| `modules/supplement/` | Five follow-up experiment runners and retained NB code | Runners are supplied; pending outputs are not represented as completed results |
| `tools/historical_replay/` | Native endpoint/initialization replay tool | Requires original saved historical models and matching source signatures |
| `evidence/` | Retained CSV exports used for paper analyses | Summary exports, not raw image data or a complete fitted-model archive |
| `analysis/`, `reproducibility/` | Python metric reanalysis and figure code | Uses included CSVs; does not fit new models |
| `reference_figures/` | Retained manuscript/SI figure PDFs | Reference artwork, including historical figures needing saved traces to regenerate |
| `provenance/` | File hashes, packaging changes and validation scope | Numerical MATLAB source files have not been modified for this collection |

The sample-layer source files match all 47 hashes in the supplied formal-run
review export. Wrapper files live outside the frozen modules. Do not combine
all folders with `addpath(genpath(...))`: several retained modules contain
different copies of the same function names.

## Requirements

- Native MATLAB with JVM enabled. The authors' reported working environment is
  MATLAB R2025a on Windows; this packaging task did not execute MATLAB.
- The active core synthetic and sample paths do not require a GPU, R, or
  Statistics/Parallel Toolbox. MATLAB-specific table, JSON, hashing and MAT-file
  operations are used; GNU Octave compatibility is not claimed.
- Python 3.11 or newer is optional for CSV verification and figures. The plotting dependencies
  are pinned in `requirements.txt`; the recorded analysis environment used
  NumPy 2.3.5, pandas 2.2.3 and Matplotlib 3.10.8.
- ROMPCA requires additional explicit setup; BA2DPCA is not bundled as a verified
  implementation. See `docs/EXTERNAL_METHODS.md`.

## Start without fitting models

Set MATLAB's current folder to this repository root:

```matlab
RUN_EXPERIMENTS('check');
RUN_EXPERIMENTS('selftest');
RUN_EXPERIMENTS('sample_selftest');
```

`check` only inspects source files, JVM and directory presence. `selftest` and
`sample_selftest` call the respective original engineering checks. A successful
check is not evidence of optimization convergence or a new scientific result.

For a small original P0 engineering run, use `RUN_EXPERIMENTS('quick')`. Its
40 small fits are not part of the paper's formal statistics.

## Recreate the separate sample-layer experiment

```matlab
RUN_EXPERIMENTS('sample_all');
```

This invokes the original frozen protocol: four conditions, ten new seed
blocks and E/E+S, after eight computational prechecks. The default output is
`results/sample_extension/`. Existing completed fits are reused only when the
original source/configuration/data signatures match. `sample_formal` requires
successful prechecks in the same output root; a fresh run should use
`sample_all`. Use `sample_summary` to summarize existing outputs.

To choose an output directory:

```matlab
opts = struct('outputRoot','D:\TukeyResults\sample_extension');
RUN_EXPERIMENTS('sample_all', opts);
```

Changing scientific settings requires a new output directory. Soft time limits
can cause machine-dependent stopping; matching source and seeds is not a promise
of bit-for-bit endpoint reproduction on another machine.

## Main synthetic and real-image experiments

```matlab
RUN_EXPERIMENTS('core_synthetic');       % 1,760 fit records
RUN_EXPERIMENTS('budget_synthetic');     % 320 budget records
RUN_EXPERIMENTS('solver_synthetic');     % 240 solver-comparison records
```

Formal fitting can take substantial time. Uploading or checking this repository
does not require rerunning these experiments. Explicit module actions avoid
starting extra historical/main configuration sweeps not needed for the current
paper tables.

Exact real-image reruns require more than the original ORL/YALE images:

```matlab
opts = struct('archiveRoot','D:\TukeyData\frozen_archive');
RUN_EXPERIMENTS('real_preflight', opts);
RUN_EXPERIMENTS('core_real', opts);
% Other original actions: extension_real, tune_real, budget_real, solver_real.
```

The archive must contain the matching `cache/`, `splits/`, `calibration/` and
`jobs/` objects. They are not contained in this public-code preparation.
There is no supplied fresh-image importer that reconstructs all these frozen
objects exactly. See `docs/DATA_SETUP.md` before claiming full real-data
reproducibility. `TUKEY_ARCHIVE_ROOT` is an alternative to `opts.archiveRoot`.

## Follow-up experiment runners

```matlab
opts = struct();
opts.archiveRoot = 'D:\TukeyData\frozen_archive';
opts.modules = {'01_initialization'};
RUN_EXPERIMENTS('supp_plan', opts);
% Then, after input checks: supp_pilot, supp_paper, supp_summary.
```

Other module IDs are `02_factorial`, `03_external`, `04_yale_selection` and
`05_b10_budget`. The wrapper defaults to initialization only. Use a distinct
output root when the selected plan or scientific settings change. Publishing
the runners does not establish that their pending scientific comparisons have
already been completed.

## Recalculate included CSV analyses and figures

From a terminal in the repository root:

```bash
python tools/verify_release.py
python -m pip install -r requirements.txt
python analysis/reproduce.py --mode all
```

The first command uses only Python's standard library. The final command
rebuilds the archived synthetic error-component tables and selected main/SI
figures, including all four main figure sources and the sample-weight figure.
Outputs go to `generated/` and `figures/`; historical checkpoint trajectories
still require their saved historical archives. No MATLAB model fitting occurs.

## Stop, resume and source integrity

```matlab
REQUEST_EXPERIMENT_STOP('sample');
% For a custom directory:
REQUEST_EXPERIMENT_STOP('core','D:\TukeyResults\p0_core');
```

The flag requests a stop at the runner's next safe boundary. Remove it before
resuming the same command. Do not delete a running lock while another MATLAB
process is active. The `.gitattributes` file preserves source line endings:
automatic newline conversion would change the hashes checked on resume.

## License, citation and funding

No repository-wide open-source license has been assigned in this preparation.
Retained code and third-party material keep their original provenance; see
`THIRD_PARTY_NOTICES.md`. Authors can add a license after settling the release
scope. `CITATION.cff` supplies author metadata without inventing a paper DOI or
an as-yet-uncreated GitHub URL.

This work was supported by the Scientific Research Fund of the Yunnan
Provincial Department of Education (Grant No. 2026Y0763).

See `docs/REPRODUCIBILITY.md` for validation limits and
`docs/GITHUB_UPLOAD_CN.md` for upload instructions.
