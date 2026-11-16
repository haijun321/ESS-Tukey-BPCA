# Experiment map and evidence scope

This map describes the manuscript version integrated on 16 November 2026:
*Weight-Based Cutoff Calibration for Tukey Bilateral PCA: Properties and Empirical Limits*.
Section numbers refer to that version. Repository packaging does not add model fits.

## Code families

| Directory | Role | Scientific status |
|---|---|---|
| `modules/core/` | P0 revised solver, matched controls, statistics and archived legacy implementations | Source for the completed CORE, solver, extension, selection and budget evidence |
| `modules/sample_extension/` | Separate frozen E/E+S synthetic experiment | Source for the completed 80-fit sample-layer experiment |
| `modules/supplement/` | Follow-up experiment runner and external-method adapters | Execution infrastructure; presence of code does not establish completed results |
| `modules/supplement/legacy_nb/` | Historical NB code and post-processing | Historical protocol, including the separately reported S7 diagnostics |
| `evidence/` | Retained result CSVs and provenance | Endpoint/summary evidence; not complete fitted-model or raw-data archives |

The core `frozen/` directory is required. It supplies generators, initialization,
data/archive interfaces and legacy comparisons used by the revised solver.
Do not remove it or edit frozen sources merely to replace local path defaults.
Do not add all module subdirectories to MATLAB's path at once.

## Completed experiments and their entry actions

Use the repository entry `RUN_EXPERIMENTS(action,opts)` for the core actions below.
They map to `START_TUKEY_CSSP_P0_V2(action,opts)` without changing scientific settings.
Counts describe the default protocol, not a recommendation to rerun every module.

| Manuscript location | Core action or code family | Default records/fits | Retained evidence |
|---|---|---:|---|
| S3 solver comparison, synthetic | `solver_synthetic` | 240 fits | `evidence/solver_synthetic/` |
| S3 solver comparison, real images | `solver_real` | 120 fits | `evidence/solver_real/` |
| 5.2.1-5.2.3, S1/S4 | `core_synthetic` | 1,760 fits | `evidence/core_synthetic/` |
| 5.2.4, S8 error decomposition | Analysis of retained CORE metrics | 0 additional fits | CORE CSVs and `analysis/` |
| 5.2.5, S6 | `budget_synthetic` | 320 records | `evidence/budget_synthetic/` |
| 5.2.6, S9 | Sample-extension family; see root README | 80 formal fits | `evidence/sample_extension_20261116/` |
| 5.3.1-5.3.2, S4 | `core_real` | 400 fits | `evidence/core_real/` |
| 5.3.3, S5 | `extension_real` | 400 fits | `evidence/extension_real/` |
| 5.3.4, S5 | `tune_real` | 360 candidate fits; 150 later evaluations | `evidence/tune_candidates/`, `evidence/tune_real/` |
| 5.3.5, S6 | `budget_real` | 480 records | `evidence/budget_real/` |
| S7 historical diagnostics | Legacy NB scripts and retained endpoint replay | Separate five-repetition protocol | `evidence/old_A/` |

`core_synthetic` is 44 condition tuples x 10 repetitions x 4 controls.
`budget_synthetic` is 4 selected conditions x 10 repetitions x 4 controls x 2 budgets.
`core_real` and `extension_real` each use 2 datasets x 5 conditions x 10 splits x 4 settings.
`budget_real` uses 2 datasets x 3 conditions x 10 splits x 4 controls x 2 budgets.

## Counts that must not be added as independent experiments

- Real budget B1 outcomes reproduce the corresponding CORE records.
- TUNE's 150 locked-procedure evaluations reuse candidate models; they are not 150 new fits.
- The `extension_real` module reruns its C3 reference under that module's protocol.
- Error decomposition uses existing metrics and introduces no new fitted models.
- Sample-extension prechecks contain eight computational fits, excluded from formal statistics.
- Each E/E+S condition has ten paired seed blocks. The 80 fits are not 80 independent pairs.
- Whole-grid CORE inference uses ten repetition-level blocks, not 440 independent condition pairs.
- Real split summaries describe repeated image splits that can share images.
- Numerical trial-check counts are engineering checks, not statistical sample sizes.

## Controlled component definitions

| Setting | Cutoff control | Rejection preference | Element guard | Sample layer |
|---|---|---|---|---|
| C1 | Fixed Tukey multiplier | Not used | Off | Off |
| C2 | Fixed ESS target | On | Off | Off |
| C3 | Adaptive ESS target | On | Off | Off |
| C4 | Adaptive ESS target | Off | Off | Off |
| R5 | As C3 | On | On | Off |
| R6 | As C3 | On | On | On |
| R7 | As C3 | Off | On | Off |
| E | C3 rule on new synthetic cases | On | Off | Off |
| E+S | As E | On | Off | Existing synthetic sample rule |

E+S is not the guarded real-image R6 configuration. Its sample ESS is diagnostic,
not an additional sample-ESS target selection method. The current CORE does not
contain the complete target-by-rejection-preference factorial design.

## Execution scope

Synthetic CORE and the separate sample experiment generate their own arrays.
Exact real-image reruns require the author's frozen archive; see [DATA_SETUP.md](DATA_SETUP.md).
Original images alone do not supply the archived splits, development calibration
and corruption plans. This repository does not silently rebuild substitute inputs.

The supplemental runner includes proposed INIT, external-method, mechanism and
selection work. Its job plan is not proof that those outputs were obtained or
included in this manuscript. Current same-protocol real INIT and verified external
method comparisons remain distinct from the completed evidence listed above.
An initialization readout is not automatically an optimized L2/GLRAM baseline.

## Engineering actions and extra configurations

- `selftest` checks implementation properties without loading real images.
- `quick` performs 40 reduced-geometry engineering fits; these are not paper results.
- `real_preflight` checks frozen inputs before fitting.
- `summary` and `export_review` process an existing core output directory.
- `paper_synthetic` also launches `main_synthetic` (2,640 additional complete-configuration fits).
- `paper_real` includes `main_real` (420 fits) and other modules beyond the current main comparisons.
- Optional C5 and new seed offsets define additional protocols and require new output directories.

The original source snapshots contain historical delivery-validation notes.
Their inclusion does not mean MATLAB was executed during this repository-packaging task.
No convergence, universal recovery advantage or external-method superiority is
established by a source file, successful export, or complete record count alone.
