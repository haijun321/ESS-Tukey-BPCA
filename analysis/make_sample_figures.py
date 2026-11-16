"""Rebuild the sample-layer publication figures from the saved 80 fit records.

All plotted points are seed-level records.  The main figure shows each of the
ten paired E+S-minus-E differences in each condition; no fit is dropped.  The
supplementary figure uses actual last-accepted-update sample coefficients.
This script only reads exported results and does not fit scientific models.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "evidence/sample_extension_20261116/review_bundle/formal/fit_records.csv"
CONDITIONS = ["Clean", "CellOnly", "CaseOnly", "Mixed"]
LABELS = ["Clean", "Cell-\nonly", "Case-\nonly", "Mixed"]
BLUE = "#245b85"
ORANGE = "#b85b2b"


def settings():
    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 8,
            "axes.labelsize": 8,
            "axes.titlesize": 8,
            "xtick.labelsize": 7.5,
            "ytick.labelsize": 7.5,
            "legend.fontsize": 7,
            "axes.linewidth": 0.65,
            "lines.linewidth": 0.8,
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
            "mathtext.fontset": "dejavusans",
            "savefig.facecolor": "white",
        }
    )


def read_records():
    records = pd.read_csv(SOURCE)
    keys = ["Condition", "Repeat", "Method"]
    assert len(records) == 80 and not records.duplicated(keys).any()
    assert set(records.Condition) == set(CONDITIONS)
    assert set(records.Method) == {"E", "ES"}
    assert records.FailureMessage.isna().all()
    assert records.groupby(["Condition", "Method"]).size().eq(10).all()
    assert np.isfinite(records[["ErrSubNorm", "ProbeCleanNRE", "SampleESS"]]).all().all()
    for condition in CONDITIONS:
        e = records[(records.Condition == condition) & (records.Method == "E")].set_index("Repeat").sort_index()
        es = records[(records.Condition == condition) & (records.Method == "ES")].set_index("Repeat").sort_index()
        assert e.index.tolist() == list(range(1, 11))
        assert es.index.equals(e.index)
        assert e.CaseHash.equals(es.CaseHash)
        assert e.InitHash.equals(es.InitHash)
    return records


def clean_axes(axis):
    axis.set_xlim(0.55, 4.45)
    axis.set_xticks(range(1, 5), LABELS)
    axis.tick_params(direction="out", length=2.5, width=0.6)
    axis.spines[["top", "right"]].set_visible(False)
    axis.set_axisbelow(True)
    axis.grid(axis="y", color="0.88", linewidth=0.45)


def points_and_mean(axis, center, values, color, marker="o", spread=0.115):
    values = np.asarray(values, dtype=float)
    assert len(values) == 10 and np.isfinite(values).all()
    offset = np.linspace(-spread, spread, len(values))
    axis.scatter(
        center + offset,
        values,
        s=14,
        facecolors="white",
        edgecolors=color,
        linewidths=0.65,
        marker=marker,
        zorder=3,
    )
    axis.plot(
        [center - spread - 0.025, center + spread + 0.025],
        [values.mean(), values.mean()],
        color="black",
        linewidth=1.25,
        solid_capstyle="butt",
        zorder=4,
    )


def export(figure, path, title):
    path.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(
        path,
        metadata={"Title": title, "CreationDate": None, "ModDate": None},
    )
    figure.savefig(path.with_suffix(".png"), dpi=300)
    plt.close(figure)
    print(path)


def main_figure(records):
    fig, axes = plt.subplots(1, 2, figsize=(4.7, 2.45))
    for axis, metric, title in zip(
        axes,
        ["ErrSubNorm", "ProbeCleanNRE"],
        ["(a) Subspace error", "(b) Clean-probe error"],
    ):
        axis.axhline(0, color="0.3", linestyle=(0, (2, 2)), linewidth=0.65, zorder=2)
        for position, condition in enumerate(CONDITIONS, 1):
            subset = records[records.Condition == condition].pivot(index="Repeat", columns="Method", values=metric).sort_index()
            difference = subset.ES.to_numpy() - subset.E.to_numpy()
            points_and_mean(axis, position, 1000 * difference, BLUE)
        axis.set_title(title, loc="left", pad=5)
        axis.set_ylabel(r"E+S minus E ($\times10^{-3}$)")
        clean_axes(axis)
    fig.tight_layout(pad=0.65, w_pad=0.7)
    export(
        fig,
        ROOT / "figures/Fig3_sample_increment.pdf",
        "Paired sample-layer task effects over ten seed blocks",
    )


def supplementary_figure(records):
    fig, axes = plt.subplots(1, 2, figsize=(6.5, 2.7))
    axis = axes[0]
    for method, offset, color, marker in [
        ("E", -0.17, BLUE, "o"),
        ("ES", 0.17, ORANGE, "s"),
    ]:
        for position, condition in enumerate(CONDITIONS, 1):
            values = records[(records.Condition == condition) & (records.Method == method)].sort_values("Repeat").SampleESS
            points_and_mean(axis, position + offset, values, color, marker, spread=0.085)
        axis.scatter([], [], s=14, facecolors="white", edgecolors=color, marker=marker, linewidths=0.65, label="E" if method == "E" else "E+S")
    axis.set_title("(a) Sample-coefficient concentration", loc="left", pad=5)
    axis.set_ylabel("Normalized sample ESS")
    axis.set_ylim(0.970, 1.0015)
    axis.set_yticks([0.97, 0.98, 0.99, 1.00])
    axis.legend(loc="lower left", frameon=False, handletextpad=0.4)
    clean_axes(axis)

    axis = axes[1]
    for field, offset, color, marker, label in [
        ("CaseMeanA", -0.17, BLUE, "o", "Case-contaminated"),
        ("NonCaseMeanA", 0.17, ORANGE, "s", "Non-case"),
    ]:
        for position, condition in enumerate(CONDITIONS, 1):
            values = records[(records.Condition == condition) & (records.Method == "ES")].sort_values("Repeat")[field].to_numpy()
            if np.isnan(values).all():
                # No case positives occur in Clean and Cell-only.
                assert field == "CaseMeanA" and condition in {"Clean", "CellOnly"}
                continue
            points_and_mean(axis, position + offset, values, color, marker, spread=0.085)
        axis.scatter([], [], s=14, facecolors="white", edgecolors=color, marker=marker, linewidths=0.65, label=label)
    axis.set_title("(b) E+S coefficient allocation", loc="left", pad=5)
    axis.set_ylabel("Mean accepted-update coefficient")
    axis.set_ylim(0.54, 0.98)
    axis.set_yticks([0.55, 0.65, 0.75, 0.85, 0.95])
    axis.legend(loc="center left", frameon=False, handletextpad=0.4)
    clean_axes(axis)
    fig.tight_layout(pad=0.7, w_pad=1.0)
    export(
        fig,
        ROOT / "figures/FigS7_sample_weights.pdf",
        "Accepted-update sample-weight diagnostics over ten seed blocks",
    )


if __name__ == "__main__":
    settings()
    data = read_records()
    main_figure(data)
    supplementary_figure(data)
