#!/usr/bin/env python3
"""Rebuild the v2 CORE figures from the accompanying exact CSV records.

The original manuscript image paths are retained; all plotted values are v2.
Synthetic bands are pointwise percentile bootstrap intervals using common
resampling indices for the ten repeat IDs (10,000 resamples, seed 20261025).
Real-image whiskers are sample SDs over ten matched outer splits, not CIs.
"""
from pathlib import Path
import json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / 'figures'
(OUT / 'original_budget').mkdir(parents=True, exist_ok=True)
plt.rcParams.update({
    'font.family': 'DejaVu Sans', 'font.size': 8.5,
    'axes.labelsize': 8.5, 'xtick.labelsize': 8.5, 'ytick.labelsize': 8.5,
    'legend.fontsize': 8.0, 'axes.spines.top': False,
    'axes.spines.right': False, 'axes.linewidth': .7,
    'pdf.fonttype': 42, 'ps.fonttype': 42,
    'savefig.facecolor': 'white', 'figure.facecolor': 'white',
})

S = pd.read_csv(HERE / 'source_synthetic_core_v2.csv')
R = pd.read_csv(HERE / 'source_real_core_v2.csv')
T = pd.read_csv(HERE / 'source_tune_real_v2.csv')
for d in (S, R, T):
    assert not d.duplicated(['Dataset', 'Condition', 'Repeat', 'MethodID']).any()
    for _, g in d.groupby(['Dataset', 'Condition', 'Repeat']):
        assert g.CaseHash.nunique() == 1 and g.InitHash.nunique() == 1

REPEATS = sorted(S.Repeat.unique())
assert REPEATS == list(range(1, 11))
BOOT_SEED = 20261025
BOOT_N = 10000
IDX = np.random.default_rng(BOOT_SEED).integers(0, len(REPEATS), (BOOT_N, len(REPEATS)))
def interval(g, metric):
    a = g.set_index('Repeat').loc[REPEATS, metric].to_numpy(float)
    assert np.isfinite(a).all()
    means = a[IDX].mean(axis=1)
    lo, hi = np.quantile(means, [.025, .975])
    return a.mean(), lo, hi

STYLES = {
    'C1': dict(color='#444444', marker='s', ms=4, ls='-'),
    'C2': dict(color='#0072B2', marker='^', ms=4.4, ls='--'),
    'C3': dict(color='#D55E00', marker='o', ms=3.6, ls='-'),
    'C4': dict(color='#009E73', marker='D', ms=5.4, ls=':', mfc='none'),
}
LABELS = {'C1':'C1: fixed Tukey', 'C2':'C2: fixed target',
          'C3':'C3: adaptive', 'C4':'C4: no zero term'}
sumrows = []
for typ in ['sample', 'impulse', 'block_random', 'block_coherent']:
    fig, ax = plt.subplots(figsize=(2.5, 2.35))
    for method in ['C1','C2','C4','C3']:
        sub = S[(S.Strength == 4) & (S.Type == typ) & (S.MethodID == method)]
        points = []
        for condition, g in sub.groupby('Condition'):
            m, lo, hi = interval(g, 'ErrSubNorm')
            points.append((g.NominalRate.iloc[0], g.ActualRate.mean(), m, lo, hi))
            sumrows.append(dict(Type=typ, MethodID=method, Condition=condition,
                NominalRate=g.NominalRate.iloc[0], MeanActualRate=g.ActualRate.mean(),
                Metric='ErrSubNorm', Mean=m, CI95Low=lo, CI95High=hi))
        a = np.array(sorted(points))
        ax.errorbar(a[:,1],a[:,2],yerr=[np.maximum(0,a[:,2]-a[:,3]),np.maximum(0,a[:,4]-a[:,2])],
                    label=LABELS[method],capsize=2.1,lw=1.1,elinewidth=.7,**STYLES[method])
    ax.set_xlabel('Mean realized\ncontamination fraction')
    ax.set_ylabel('Normalized\nsubspace error')
    ax.set_ylim(bottom=0)
    ax.grid(True, alpha=.22, lw=.5)
    handles, labels = ax.get_legend_handles_labels()
    order = [labels.index(LABELS[m]) for m in ['C1','C2','C3','C4']]
    fig.legend([handles[i] for i in order], [labels[i] for i in order],
               loc='lower center', ncol=2, frameon=False, bbox_to_anchor=(.50,-.015),
               columnspacing=.65, handlelength=1.5)
    fig.subplots_adjust(left=.23,right=.985,top=.97,bottom=.40)
    fig.savefig(OUT / 'original_budget' / f'P0_s4_{typ}_ErrSubNorm.pdf', bbox_inches='tight',pad_inches=.025)
    plt.close(fig)

TYPE_LABELS = {'sample':'Samplewise', 'impulse':'Impulse',
               'block_random':'Random block', 'block_coherent':'Coherent block'}
TYPE_COLORS = ['#444444','#0072B2','#D55E00','#009E73']
for metric, stem, ylabel in [('Eta','eta','Final target $\\eta$'), ('ESS','ess','Final element-weight\nESS ratio')]:
    fig, ax = plt.subplots(figsize=(2.5,2.35))
    for (typ,label), color, marker in zip(TYPE_LABELS.items(),TYPE_COLORS,['s','^','o','D']):
        sub=S[(S.Strength==4)&(S.MethodID=='C3')&(S.Type==typ)]
        points=[]
        for condition,g in sub.groupby('Condition'):
            m,lo,hi=interval(g,metric)
            points.append((g.NominalRate.iloc[0],g.ActualRate.mean(),m,lo,hi))
            sumrows.append(dict(Type=typ,MethodID='C3',Condition=condition,
                NominalRate=g.NominalRate.iloc[0],MeanActualRate=g.ActualRate.mean(),
                Metric=metric,Mean=m,CI95Low=lo,CI95High=hi))
        a=np.array(sorted(points))
        ax.errorbar(a[:,1],a[:,2],yerr=[np.maximum(0,a[:,2]-a[:,3]),np.maximum(0,a[:,4]-a[:,2])],
                    label=label,color=color,marker=marker,ms=4,lw=1.1,capsize=2.1,elinewidth=.7)
    ax.set_xlabel('Mean realized\ncontamination fraction'); ax.set_ylabel(ylabel)
    ax.grid(True,alpha=.22,lw=.5)
    if metric=='Eta':ax.set_ylim(.805,1.005)
    else:ax.set_ylim(0,1.025)
    fig.legend(loc='lower center',ncol=2,frameon=False,bbox_to_anchor=(.5,-.015),
               columnspacing=.65,handlelength=1.5)
    fig.subplots_adjust(left=.23,right=.985,top=.97,bottom=.40)
    fig.savefig(OUT/'original_budget'/f'P0_s4_auto_{stem}.pdf',bbox_inches='tight',pad_inches=.025)
    plt.close(fig)
pd.DataFrame(sumrows).to_csv(HERE/'synthetic_figure_summary_v2.csv',index=False,float_format='%.17g')

fig, axes=plt.subplots(3,1,figsize=(5.1,5.6))
realrows=[]
ax=axes[0]
xs=np.array([0,1]); width=.30
for j,m in enumerate(['C3','C4']):
    means=[];sds=[]
    for ds in ['ORL','YALE']:
        g=R[(R.Dataset==ds)&(R.Condition=='I30')&(R.MethodID==m)]
        a=g.ZeroExact.to_numpy(float)
        means.append(a.mean());sds.append(a.std(ddof=1))
        realrows.append(dict(Panel='a',Dataset=ds,Condition='I30',Contrast=m,Metric='ZeroExact',
                             Mean=a.mean(),SD=a.std(ddof=1),N=len(a)))
    ax.bar(xs+(j-.5)*width,means,width,yerr=sds,capsize=2,
           color=STYLES[m]['color'],alpha=.85,label=m,error_kw={'elinewidth':.8})
ax.set_xticks(xs,['ORL','YALE']);ax.set_ylabel('Exact zero-weight\nfraction')
ax.set_title('(a) I30 rejection response',fontsize=9,pad=6)
ax.legend(frameon=False,loc='upper right',fontsize=8.3,ncol=2)
ax.set_ylim(0,.24);ax.grid(axis='y',alpha=.20,lw=.5);ax.set_axisbelow(True)

ax=axes[1]; conditions=['Clean','I10','I30','B10','B30']; xs=np.arange(5)
for j,(ds,color,marker) in enumerate([('ORL','#0072B2','o'),('YALE','#D55E00','^')]):
    means=[];sds=[]
    for con in conditions:
        p=R[(R.Dataset==ds)&(R.Condition==con)].pivot(index='Repeat',columns='MethodID',values='NRE')
        a=(p.C3-p.C2).to_numpy(float)
        means.append(a.mean());sds.append(a.std(ddof=1))
        realrows.append(dict(Panel='b',Dataset=ds,Condition=con,Contrast='C3-C2',Metric='NRE',
                             Mean=a.mean(),SD=a.std(ddof=1),N=len(a)))
    ax.errorbar(xs+(j-.5)*.12,means,yerr=sds,color=color,marker=marker,lw=.9,ms=3.6,
                capsize=2,label=ds,elinewidth=.7)
ax.axhline(0,color='.45',lw=.7);ax.set_xticks(xs,conditions)
ax.set_ylabel('$\\Delta$NRE\n(C3 $-$ C2)');ax.set_title('(b) Adaptive target',fontsize=9,pad=6)
ax.legend(frameon=False,loc='upper left',fontsize=8.3,ncol=2);ax.grid(axis='y',alpha=.20,lw=.5)

ax=axes[2];conditions=['Clean','I10','B10'];xs=np.arange(3)
for j,(right,color,marker,label) in enumerate([('SelectedEta','#0072B2','o','Selected $\\eta$'),
                                            ('SelectedC','#D55E00','^','Selected $c$')]):
    means=[];sds=[]
    for con in conditions:
        p=T[T.Condition==con].pivot(index='Repeat',columns='MethodID',values='NRE')
        a=(p.Auto-p[right]).to_numpy(float)
        means.append(a.mean());sds.append(a.std(ddof=1))
        realrows.append(dict(Panel='c',Dataset='ORL',Condition=con,Contrast='Auto-'+right,
                             Metric='NRE',Mean=a.mean(),SD=a.std(ddof=1),N=len(a)))
    ax.errorbar(xs+(j-.5)*.13,means,yerr=sds,color=color,marker=marker,lw=.9,ms=3.6,
                capsize=2,label=label,elinewidth=.7)
ax.axhline(0,color='.45',lw=.7);ax.set_xticks(xs,conditions)
ax.set_ylabel('$\\Delta$NRE\n(Auto $-$ selected)')
ax.set_title('(c) ORL validation selection',fontsize=9,pad=6)
ax.legend(frameon=False,loc='upper left',fontsize=8.3,ncol=2);ax.grid(axis='y',alpha=.20,lw=.5)
fig.subplots_adjust(left=.16,right=.98,bottom=.06,top=.96,hspace=.72)
fig.savefig(OUT/'real_matched_evidence_20261003.pdf',bbox_inches='tight',pad_inches=.025)
fig.savefig(OUT/'real_matched_evidence_20261003.png',dpi=200,bbox_inches='tight',pad_inches=.025)
plt.close(fig)
pd.DataFrame(realrows).to_csv(HERE/'real_figure_summary_v2.csv',index=False,float_format='%.17g')
(HERE/'figure_metadata_v2.json').write_text(json.dumps({
    'solver_version':'v2','synthetic_configuration':'CORE C1-C4; guard and sample weights disabled',
    'synthetic_bootstrap':{'seed':BOOT_SEED,'resamples':BOOT_N,'method':'pointwise percentile; common resampled repeat indices', 'unit':'ten repeat IDs'},
    'real_error_bars':'sample standard deviation of ten matched outer-split values or differences',
    'source_files':['source_synthetic_core_v2.csv','source_real_core_v2.csv','source_tune_real_v2.csv'],
    'warning':'Pointwise intervals are not simultaneous; plot filenames preserve legacy paths but contain only v2 data.'
},indent=2)+'\n')
print('Generated seven PDF figures, one PNG preview, and exact figure-summary CSVs.')
