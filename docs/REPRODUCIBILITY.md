# Reproducibility and validation scope

This collection preserves the available fitting source and analysis exports.
Source completeness and availability of every required research input are
separate questions.

## Four distinct operations

1. **Verify exported records:** `python tools/verify_release.py` checks retained
   bytes, 47 sample source hashes, complete E/ES pairs and paired CORE identities.
2. **Recalculate tables/figures:** `python analysis/reproduce.py --mode all` uses
   included CSVs. It does not project raw arrays or run optimization.
3. **Generate synthetic experiments:** the original MATLAB runners generate
   new data and fitted-model archives using the frozen seeds and settings.
4. **Repeat exact real-image fits:** original image arrays, split IDs,
   calibration objects and corruption cases must be supplied in the frozen
   archive described in `DATA_SETUP.md`.

The retained sample review exports do not include all cases, bases and full
optimization traces. A successful CSV/hash check cannot certify those missing
objects, all orthogonality checks, or independent replay of projection errors.

## Scientific interpretation

- The 44-condition synthetic CORE uses ten repetition blocks. The 440 paired
  condition realizations are not 440 independent grid-level repetitions.
- The sample experiment uses ten seed blocks, 80 formal fits and eight separate
  computational prechecks. Prechecks are not included in its scientific table.
- The ten real-image splits reuse some images. Split variability is not an
  independent-subject confidence guarantee.
- Budget-B1 and locked-candidate modules can reuse existing model identities.
  Record counts are not all unique fits and numerical trial checks are not
  statistical observations.
- The new sample E/ES pair uses the unguarded synthetic sample rule. It is not
  the guarded real-image R5/R6 contrast and not a new sample-ESS target selector.
- Runtime/iteration-limit outcomes are retained. The reported sample experiment
  has 79 time-cap records and one outer-budget record; this does not establish
  convergence, acceleration, or a failed data export.

## Protocol and machine dependence

Numerical source files and their line endings are preserved. New repository
wrappers are outside frozen module roots so the wrappers do not enter the
historical numerical-source hashes. Both sources and scientific configurations
are checked by the original resume logic. Use a new output directory after
changing a plan or scientific setting.

Several experiments stop at soft time limits. Another machine or BLAS/MATLAB
environment can complete a different number of updates within the same limit.
The bundle therefore supports the documented procedure, not a promise of
identical endpoint bytes on all machines.

The author-reported MATLAB environment is R2025a on Windows. During repository
preparation, Python analysis and MATLAB static parsing were available; native
MATLAB and R were not executed. Validation records in `provenance/` state this
scope explicitly. Original module validation reports retain their historical
dates and must not be presented as new native executions.

## What remains to be supplied

The public code preparation does not include the full frozen real archive or
the original third-party face images. The authors should document an actual
access or reconstruction arrangement before claiming exact end-to-end real
reproduction in a paper data/code availability statement.

Follow-up INIT, external-method, factorial and selection runners are included
as executable research plans. Their presence does not fill the manuscript's
remaining evidence gaps. Missing external implementations are marked by the
original runners rather than substituted with another method under the same
name.

The repository-level license and final GitHub URL are not invented by this
bundle. `CITATION.cff` contains the confirmed author order; after publishing,
authors can add the actual repository URL and a persistent release identifier.
