#!/usr/bin/env python3
"""Render integrated manuscript figures from exact revised CORE CSVs.

No fits are run. Synthetic intervals are pointwise percentile-bootstrap
intervals of ten repeat values, using the original common indices
(10,000 draws; seed 20261025). Real whiskers describe sample SD over ten
matched outer splits. The weight-vector illustration is not empirical data.
"""
from pathlib import Path
import hashlib
import json

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import PercentFormatter, MaxNLocator
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'figures'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE_S = ROOT / 'evidence/core_synthetic/fit_records.csv'
SOURCE_R = ROOT / 'evidence/core_real/fit_records.csv'
S = pd.read_csv(SOURCE_S)
R = pd.read_csv(SOURCE_R)
for d in (S, R):
    assert not d.duplicated(['Dataset', 'Condition', 'Repeat', 'MethodID']).any()
    for _, g in d.groupby(['Dataset', 'Condition', 'Repeat']):
        assert g.CaseHash.nunique() == 1
        assert g.InitHash.nunique() == 1
    assert set(d.MethodID) == {'C1', 'C2', 'C3', 'C4'}
    assert set(d.SolverVersion) == {'v2'}
    assert d.Guard.eq(0).all()

plt.rcParams.update({
    'font.family': 'DejaVu Sans', 'font.size': 9.0,
    'axes.labelsize': 9.0, 'axes.titlesize': 10.0,
    'xtick.labelsize': 8.7, 'ytick.labelsize': 8.7,
    'legend.fontsize': 8.5, 'axes.spines.top': False,
    'axes.spines.right': False, 'axes.linewidth': .7,
    'pdf.fonttype': 42, 'ps.fonttype': 42,
    'savefig.facecolor': 'white', 'figure.facecolor': 'white',
})
COLORS = {'C1': '#555555', 'C2': '#0072B2',
          'C3': '#D55E00', 'C4': '#009E73'}
MARKERS = {'C1': 's', 'C2': '^', 'C3': 'o', 'C4': 'D'}
LABELS = {'C1': 'C1: fixed Tukey', 'C2': 'C2: fixed target',
          'C3': 'C3: adaptive target', 'C4': 'C4: no zero-weight term'}
METHODS = ['C1', 'C2', 'C3', 'C4']
BOOT_SEED = 20261025
BOOT_N = 10000
REPEATS = list(range(1, 11))
IDX = np.random.default_rng(BOOT_SEED).integers(0, 10, (BOOT_N, 10))
rows = []

def save(fig, stem):
    fig.savefig(OUT / (stem + '.pdf'), bbox_inches='tight', pad_inches=.05)
    fig.savefig(OUT / (stem + '.png'), dpi=220, bbox_inches='tight', pad_inches=.05)
    plt.close(fig)

def boot(g, metric):
    a = g.set_index('Repeat').loc[REPEATS, metric].to_numpy(float)
    assert np.isfinite(a).all()
    lo, hi = np.quantile(a[IDX].mean(axis=1), [.025, .975])
    return a.mean(), lo, hi

# Figure 1: the reconstruction metric is visible for every contamination type.
fig, axes = plt.subplots(2, 2, figsize=(6.6, 4.9))
types = [('sample', 'Samplewise'), ('impulse', 'Impulse'),
         ('block_random', 'Random block'), ('block_coherent', 'Coherent block')]
for panel, (ax, (typ, title)) in enumerate(zip(axes.flat, types)):
    for m in ['C1', 'C2', 'C4', 'C3']:
        part = S[(S.Strength == 4) & (S.Type == typ) & (S.MethodID == m)]
        pts = []
        for condition, g in part.groupby('Condition'):
            mean, lo, hi = boot(g, 'NRE')
            pts.append((g.NominalRate.iloc[0], g.ActualRate.mean(), mean, lo, hi))
            rows.append(dict(Figure='Synthetic_NRE_strength4', Panel=chr(97+panel),
                Dataset='SYN', Condition=condition, MethodOrContrast=m,
                Metric='NRE', Mean=mean, SD=g.NRE.std(ddof=1),
                CI95Low=lo, CI95High=hi, N=10,
                MeanRealizedContamination=g.ActualRate.mean()))
        a = np.array(sorted(pts))
        kwargs = dict(color=COLORS[m], marker=MARKERS[m],
                      ms=4.1, lw=1.1, capsize=2.0, elinewidth=.7)
        if m == 'C2':
            kwargs['ls'] = '--'
        elif m == 'C4':
            kwargs.update(ls=':', mfc='none', ms=5.2, markeredgewidth=1.0)
        ax.errorbar(a[:, 1], a[:, 2],
            yerr=[np.maximum(0, a[:, 2]-a[:, 3]), np.maximum(0, a[:, 4]-a[:, 2])],
            label=LABELS[m], **kwargs)
    ax.set_title(f'({chr(97+panel)}) {title}', loc='left', pad=7)
    ax.set_xlabel('Mean realized contamination fraction')
    ax.set_ylabel('Clean-reference NRE')
    ax.set_ylim(bottom=0)
    ax.grid(True, alpha=.2, lw=.5)
    ax.xaxis.set_major_locator(MaxNLocator(5))
    ax.yaxis.set_major_locator(MaxNLocator(5))
handles, labels = axes[0, 0].get_legend_handles_labels()
order = [labels.index(LABELS[m]) for m in METHODS]
fig.legend([handles[i] for i in order], [labels[i] for i in order],
           loc='lower center', ncol=2, frameon=False,
           bbox_to_anchor=(.52, .005), columnspacing=1.1, handlelength=2.3)
fig.subplots_adjust(left=.105, right=.985, top=.95, bottom=.19,
                    hspace=.59, wspace=.37)
save(fig, 'Synthetic_NRE_strength4')

# Figure 2: target response, correct/false rejection, and recognition tradeoff.
fig, axes = plt.subplots(2, 2, figsize=(6.6, 5.35))
conditions = ['Clean', 'I10', 'I30', 'B10', 'B30']
xs = np.arange(len(conditions))
for panel, (ax, ds, color) in enumerate(zip(axes[0], ['YALE', 'ORL'], ['#D55E00', '#0072B2'])):
    means, sds = [], []
    for j, con in enumerate(conditions):
        p = R[(R.Dataset == ds) & (R.Condition == con)].pivot(
            index='Repeat', columns='MethodID', values='NRE').loc[REPEATS]
        a = (p.C3-p.C2).to_numpy(float)
        means.append(a.mean()); sds.append(a.std(ddof=1))
        offsets = np.linspace(-.115, .115, len(a))
        ax.scatter(j+offsets, a, s=10, color=color, alpha=.25,
                   edgecolors='none', zorder=2)
        rows.append(dict(Figure='Real_calibration_task_evidence', Panel=chr(97+panel),
            Dataset=ds, Condition=con, MethodOrContrast='C3-C2',
            Metric='NRE', Mean=a.mean(), SD=a.std(ddof=1), N=10))
    ax.errorbar(xs, means, yerr=sds, color=color, marker='o', lw=1.0,
                ms=4, capsize=2.5, elinewidth=.85, zorder=3)
    ax.axhline(0, color='.4', lw=.7, zorder=1)
    ax.set_xticks(xs, conditions)
    ax.set_ylabel(r'$\Delta$NRE (C3 $-$ C2)')
    ax.set_title(f'({chr(97+panel)}) {ds}: adaptive target', loc='left', pad=8)
    ax.grid(axis='y', alpha=.2, lw=.5)
    ax.yaxis.set_major_locator(MaxNLocator(5))

ax = axes[1, 0]
barxs = np.array([0., .75, 2., 2.75])
for x, ds, m in zip(barxs, ['ORL', 'ORL', 'YALE', 'YALE'], ['C3', 'C4', 'C3', 'C4']):
    g = R[(R.Dataset == ds) & (R.Condition == 'I30') & (R.MethodID == m)].sort_values('Repeat')
    a = 100*g.TPR0.to_numpy(float)
    fpr = 100*g.FPR0.to_numpy(float)
    ax.bar(x, a.mean(), width=.53, color=COLORS[m], alpha=.8, zorder=2)
    ax.scatter(x+np.linspace(-.14, .14, 10), a, s=9, color='black',
               alpha=.35, edgecolors='none', zorder=3)
    ax.text(x, max(a.max()+2.2, a.mean()+2.2), f'{a.mean():.1f}',
            ha='center', va='bottom', fontsize=8.7)
    for metric in ['TPR0', 'FPR0', 'ZeroExact', 'NRE', 'ACC']:
        b = g[metric].to_numpy(float)
        rows.append(dict(Figure='Real_calibration_task_evidence', Panel='c',
            Dataset=ds, Condition='I30', MethodOrContrast=m, Metric=metric,
            Mean=b.mean(), SD=b.std(ddof=1), N=10))
ax.set_xticks(barxs, ['ORL\nC3', 'ORL\nC4', 'YALE\nC3', 'YALE\nC4'])
ax.set_ylabel('Corrupted entries rejected (%)')
ax.set_title('(c) I30: correct rejection', loc='left', pad=8)
ax.set_ylim(0, 86)
ax.grid(axis='y', alpha=.2, lw=.5); ax.set_axisbelow(True)
fpr_orl3 = R[(R.Dataset=='ORL') & (R.Condition=='I30') & (R.MethodID=='C3')].FPR0.mean()*100
fpr_orl4 = R[(R.Dataset=='ORL') & (R.Condition=='I30') & (R.MethodID=='C4')].FPR0.mean()*100
fpr_yale3 = R[(R.Dataset=='YALE') & (R.Condition=='I30') & (R.MethodID=='C3')].FPR0.mean()*100
fpr_yale4 = R[(R.Dataset=='YALE') & (R.Condition=='I30') & (R.MethodID=='C4')].FPR0.mean()*100
assert fpr_orl3 == fpr_orl4 == fpr_yale4 == 0
ax.text(.5, .97, f'Mean FPR: 0 except YALE C3\n({fpr_yale3:.5f}%)',
        transform=ax.transAxes, ha='center', va='top', fontsize=8.5,
        bbox=dict(facecolor='white', edgecolor='none', alpha=.95, pad=1))

ax = axes[1, 1]
for ds, shift, color, marker in [('YALE', -.06, '#D55E00', '^'), ('ORL', .06, '#0072B2', 'o')]:
    means, sds = [], []
    for con in conditions:
        p = R[(R.Dataset == ds) & (R.Condition == con)].pivot(
            index='Repeat', columns='MethodID', values='ACC').loc[REPEATS]
        a = 100*(p.C3-p.C4).to_numpy(float)
        means.append(a.mean()); sds.append(a.std(ddof=1))
        rows.append(dict(Figure='Real_calibration_task_evidence', Panel='d',
            Dataset=ds, Condition=con, MethodOrContrast='C3-C4',
            Metric='ACC_percentage_points', Mean=a.mean(), SD=a.std(ddof=1), N=10))
    ax.errorbar(xs+shift, means, yerr=sds, color=color, marker=marker,
                lw=.9, ms=4, capsize=2.2, elinewidth=.75, label=ds)
ax.axhline(0, color='.4', lw=.7)
ax.set_xticks(xs, conditions)
ax.set_ylabel(r'$\Delta$ACC (percentage points)')
ax.set_title('(d) Zero-weight term: recognition', loc='left', pad=8)
ax.grid(axis='y', alpha=.2, lw=.5)
ax.legend(frameon=False, loc='lower right', ncol=2, columnspacing=.7,
          handlelength=1.4, borderpad=.2)
fig.subplots_adjust(left=.105, right=.985, top=.95, bottom=.09,
                    hspace=.52, wspace=.41)
save(fig, 'Real_calibration_task_evidence')

# Figure 3: exact weight vectors illustrating the identifiability of ESS alone.
fig, axes = plt.subplots(1, 2, figsize=(6.6, 2.15), sharey=True)
weights = [np.r_[np.ones(8), np.zeros(2)], np.r_[np.ones(5), np.full(5, 1/3)]]
for ax, w, title, color in zip(axes, weights,
        ['(a) Eight unit weights, two zeros', '(b) Five unit weights, five one-thirds'],
        ['#4477AA', '#EE7733']):
    ess = w.sum()**2/(len(w)*(w*w).sum())
    zero = np.mean(w==0)
    assert np.isclose(ess, .8)
    ax.bar(np.arange(1, 11), w, width=.64, color=color, alpha=.9)
    ax.scatter(np.where(w==0)[0]+1, w[w==0], s=22, facecolors='white',
               edgecolors=color, linewidths=1.1, zorder=4, clip_on=False)
    ax.set_xlim(.3, 10.7); ax.set_ylim(0, 1.18)
    ax.set_xticks([1, 5, 10]); ax.set_yticks([0, 1/3, 1], ['0', '1/3', '1'])
    ax.set_title(title, loc='left', fontsize=9.1, pad=8)
    ax.text(.5, .94, f'Normalized ESS = {ess:.1f}; zero fraction = {zero:.1f}',
            transform=ax.transAxes, ha='center', va='top', fontsize=8.6)
    ax.set_xlabel('Entry index')
    ax.grid(axis='y', alpha=.18, lw=.5); ax.set_axisbelow(True)
axes[0].set_ylabel('Weight')
fig.text(.52, .015, 'Illustrative weight vectors; not experimental results.',
         ha='center', fontsize=8.5, color='.3')
fig.subplots_adjust(left=.08, right=.985, top=.82, bottom=.29, wspace=.18)
save(fig, 'ESS_weight_example')

summary = pd.DataFrame(rows)
summary.to_csv(ROOT / 'reproducibility/integrated_figure_summary.csv',
               index=False, float_format='%.17g')
metadata = {
    'sources': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (SOURCE_S, SOURCE_R)},
    'solver_version': 'v2',
    'configuration_scope': 'CORE C1-C4, guard and sample weighting disabled',
    'synthetic_bootstrap': {'resamples': BOOT_N, 'seed': BOOT_SEED,
        'method': 'pointwise percentile; common repeat-index resampling',
        'unit': 'ten repeat IDs', 'interval': [0.025, 0.975]},
    'real_error_bars': 'sample SD of ten matched outer-split values or paired differences',
    'real_panel_c': 'bars are means, small points individual splits; FPR annotation is a mean',
    'recognition_contrast': 'C3 minus C4 in percentage points',
    'weight_example': 'two exact illustrative vectors, neither an experiment nor a proposed fit',
    'no_scientific_fits_executed': True,
}
(ROOT / 'reproducibility/integrated_figure_metadata.json').write_text(
    json.dumps(metadata, indent=2)+'\n')
print('Created three PDF figures and three PNG previews from revised CORE records.')
