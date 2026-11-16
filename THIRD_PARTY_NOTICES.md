# Source provenance and third-party notices

This release collects retained experimental implementations, supporting
drivers, and analysis tools for ESS-calibrated Tukey bilateral PCA. The source
snapshots and their provenance records identify the implementations used by the
experimental modules.

## Repository license status

No repository-wide open-source license has been selected for this release.
Packaging the files here does not assign MIT or another license to all retained
sources. Existing notices and source-provenance statements remain with their
respective files. The manuscript authors should select the intended license for
their original contributions and retain the applicable terms for any external
materials.

## Retained experimental code

The P0, NB, CSSP supplementary, and separate sample-layer source snapshots are
kept in their module directories. Their existing version identifiers, hashes,
source comments, and implementation-scope records are retained. In particular,
the `frozen/` directories contain historical numerical snapshots rather than a
new external library release.

Some historical source comments and fallback settings contain the original
Windows paths. The active repository wrappers accept explicit archive and output
locations; they do not require those historical paths. Preserving these
snapshots avoids silently changing the numerical source identity. Configure
current paths through the top-level entry point rather than rewriting the
frozen numerical files.

## ROMPCA

Reference: M. Hirari, F. Centofanti, M. Hubert, and S. Van Aelst,
*Casewise and Cellwise Robust Multilinear Principal Component Analysis*,
DOI: <https://doi.org/10.1080/10618600.2026.2637632>.

Author source location: <https://fabiocentofanti.github.io/files/Code_ROMPCA.zip>.

Only the repository's MATLAB/R I/O bridge, readiness checks, and explicit
downloader are included. The original-author numerical R source and datasets
are not redistributed in this release. The downloader verifies recorded source
hashes and installs no source automatically during a scientific fit. Downloaded
author software retains its own provenance and applicable terms; this release
does not grant additional rights to that software.

## RA-2DPCA

Reference: Z. Tan and H. Yang, *Reweighted angle two-dimensional principal
component analysis for feature extraction*, Pattern Recognition 168 (2025),
111817, DOI: <https://doi.org/10.1016/j.patcog.2025.111817>.

Original author repository: <https://github.com/cqtzx/RA2DPCA>.

The optional `NB_RA2DPCA.m` development port is an independent MATLAB
implementation of the documented recurrence, not official author MATLAB
software. The original author's R source and datasets are not bundled. The
retained `RA_PROVENANCE.txt` identifies the reference commit, preserved choices,
engineering differences, and comparison limitations. It must accompany the
port and its diagnostics.

## BA2DPCA and L2pSB2DPCA

The supplementary module contains adapter contracts and status checks for these
methods. No verified original-author implementation is bundled under either
name. Supplying an implementation later should also supply its actual source,
version, notices, and applicable terms; an adapter name alone does not establish
source identity.

## ORL, YALE, and other image data

Original third-party face images are not redistributed. Data remain subject to
their original access and reuse terms. Public result summaries do not replace
the image data or the fixed split, data-instance, and development-calibration
objects required for exact real-image replay. The data documentation states
which inputs must be obtained separately.

## MATLAB, R, and Python dependencies

MATLAB is required for the numerical experiment runners and is not distributed
with this repository. Optional ROMPCA execution additionally uses R and its
listed packages. Python analysis dependencies are installed separately. These
software systems and packages retain their respective licenses and notices.

For external-method setup, source pins, and execution status, see
[`docs/EXTERNAL_METHODS.md`](docs/EXTERNAL_METHODS.md).
