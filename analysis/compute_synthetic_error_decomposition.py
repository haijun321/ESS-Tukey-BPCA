#!/usr/bin/env python3
"""Reprocess saved synthetic metrics; no raw model fit or projection is run.

Example:
  python compute_synthetic_error_decomposition.py

The default input is this deliverable's evidence/core_synthetic/fit_records.csv;
the copied, unchanged CSV beside this script is a self-contained fallback.
OracleCleanProjectionNRE is renamed descriptively: it
uses the estimated projection, not the true generating bases.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path


METHODS = ('C1', 'C2', 'C3', 'C4')
FAMILIES = ('sample', 'impulse', 'block_random', 'block_coherent')
FAMILY_LABELS = {'sample': 'Samplewise', 'impulse': 'Impulse',
                 'block_random': 'Random block', 'block_coherent': 'Coherent block'}
METRICS = ('NRE', 'CleanProjectionNRE', 'TotalSquaredError',
           'SignalLoss', 'RetainedDisturbance')


def mean(values):
    return statistics.fmean(values)


def write_csv(path, rows):
    with path.open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def summarize(rows, scope):
    """Equal condition weights within each repetition, then mean and sample SD."""
    blocks = defaultdict(list)
    for row in rows:
        blocks[row['Repeat']].append(row)
    if sorted(blocks) != list(range(1, 11)):
        raise ValueError(f'{scope}: expected ten repetition blocks')
    condition_sets = [{r['Condition'] for r in block} for block in blocks.values()]
    if any(x != condition_sets[0] for x in condition_sets):
        raise ValueError(f'{scope}: unequal condition grids across repetitions')
    out = {'Scope': scope, 'MethodID': rows[0]['MethodID'],
           'ConditionsPerRepeat': len(condition_sets[0]), 'RepeatBlocks': len(blocks),
           'FitRecords': len(rows)}
    for metric in METRICS:
        values = [mean(r[metric] for r in blocks[rep]) for rep in range(1, 11)]
        out[metric+'Mean'] = mean(values)
        out[metric+'SDRepeatBlocks'] = statistics.stdev(values)
    out['SignalLossShareOfMeanTotal'] = out['SignalLossMean']/out['TotalSquaredErrorMean']
    out['RetainedDisturbanceShareOfMeanTotal'] = out['RetainedDisturbanceMean']/out['TotalSquaredErrorMean']
    return out


def plusminus(row, metric):
    return f"${row[metric+'Mean']:.6f}\\pm{row[metric+'SDRepeatBlocks']:.6f}$"


def write_tex(path, grid, families, failure):
    lines = [r'% Generated from retained synthetic CORE metrics; no new fits.',
             r'\begin{table}[htbp]\centering\small',
             r'\caption{Synthetic CORE error decomposition over the complete 44-condition grid. Each repetition first averages conditions equally; entries are means $\pm$ sample SDs of ten repetition averages. The total column is the mean of squared NRE, not the square of mean NRE. Signal loss uses the estimated subspaces. Displayed sums can differ by rounding.}\label{tab:si_error_decomposition_grid}',
             r'\setlength{\tabcolsep}{4pt}',
             r'\begin{tabular}{lccc}\toprule',
             r'Configuration & $\mathrm{NRE}^2$ & $\mathcal{E}_{\mathrm{sig}}$ & $\mathcal{E}_{\mathrm{dist}}$\\\midrule']
    for row in grid:
        lines.append(row['MethodID']+' & '+' & '.join(plusminus(row,m) for m in METRICS[2:])+r'\\')
    lines += [r'\bottomrule\end{tabular}\end{table}', '',
              r'\begin{table}[htbp]\centering\small',
              r'\caption{Error decomposition by synthetic contamination family. Entries are means $\pm$ sample SDs over ten repetition blocks, averaging conditions equally within each family and repetition. Both strengths are included. Samplewise, impulse, and random-block families each contain 12 conditions; coherent blocks contain eight. All planned conditions and adverse outcomes are retained.}\label{tab:si_error_decomposition_family}',
              r'\setlength{\tabcolsep}{3pt}',
              r'\begin{tabular}{llccc}\toprule',
              r'Family & Configuration & $\mathrm{NRE}^2$ & $\mathcal{E}_{\mathrm{sig}}$ & $\mathcal{E}_{\mathrm{dist}}$\\\midrule']
    for family in FAMILIES:
        selected=[r for r in families if r['Scope']==family]
        for i,row in enumerate(selected):
            label=FAMILY_LABELS[family] if i==0 else ''
            lines.append(label+' & '+row['MethodID']+' & '+' & '.join(plusminus(row,m) for m in METRICS[2:])+r'\\')
        lines.append(r'\addlinespace')
    lines += [r'\bottomrule\end{tabular}\end{table}', '',
              r'\begin{table}[htbp]\centering\small',
              r'\caption{Descriptive decomposition of the retained coherent-block failure: strength 4, nominal fraction 0.10, repetition 5, seed 152405. These are individual fitted outcomes, not means or additional independent observations.}\label{tab:si_error_decomposition_failure}',
              r'\setlength{\tabcolsep}{5pt}',
              r'\begin{tabular}{lccc}\toprule',
              r'Configuration & $\mathrm{NRE}^2$ & $\mathcal{E}_{\mathrm{sig}}$ & $\mathcal{E}_{\mathrm{dist}}$\\\midrule']
    for row in failure:
        lines.append(row['MethodID']+' & '+' & '.join(f'${row[m]:.6f}$' for m in METRICS[2:])+r'\\')
    lines += [r'\bottomrule\end{tabular}\end{table}', '']
    path.write_text('\n'.join(lines), encoding='utf-8')


def write_main_tex(path, grid):
    lines=[r'% Retrospective analysis of retained CORE records; no new scientific fits.',
           r'\begin{table}[tbp]\centering\small',
           r'\caption{Retrospective decomposition of the saved synthetic CORE errors. Entries are means $\pm$ sample SDs of ten repetition averages, each averaging all 44 conditions equally. The total is the mean of squared NRE, not the square of mean NRE; all components use the same archived numerical denominator. This reanalysis adds no independent trials. Displayed sums can differ by rounding.}\label{tab:synthetic_error_decomposition}',
           r'\setlength{\tabcolsep}{4pt}',
           r'\begin{tabular}{lccc}\toprule',
           r'Configuration & $\mathrm{NRE}^{2}$ & $\mathcal{E}_{\mathrm{sig}}$ & $\mathcal{E}_{\mathrm{dist}}$\\\midrule']
    for row in grid:
        lines.append(row['MethodID']+' & '+' & '.join(plusminus(row,m) for m in METRICS[2:])+r'\\')
    lines += [r'\bottomrule\end{tabular}\end{table}', '']
    path.write_text('\n'.join(lines),encoding='utf-8')


def main():
    here = Path(__file__).resolve().parent
    package_input=here.parent/'evidence/core_synthetic/fit_records.csv'
    default_input=package_input if package_input.is_file() else here/'source_core_synthetic_fit_records.csv'
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input-csv', type=Path, default=default_input)
    parser.add_argument('--output-dir', type=Path, default=here)
    parser.add_argument('--tex-output', type=Path,
                        default=here.parent/'Supplementary/Table_S8_Error_Decomposition.tex')
    parser.add_argument('--main-tex-output', type=Path,
                        default=here/'synthetic_decomposition_main_table.tex')
    args = parser.parse_args()
    raw = list(csv.DictReader(args.input_csv.open(encoding='utf-8')))
    if len(raw) != 1760:
        raise ValueError('This analysis expects exactly the retained 1,760 CORE records')
    rows = []
    keys = set()
    for record in raw:
        key=(record['Condition'],int(record['Repeat']),record['MethodID'])
        if key in keys: raise ValueError(f'Duplicate fit key: {key}')
        keys.add(key)
        if record['Dataset']!='SYN' or record['SolverVersion']!='v2' or record['BudgetMultiplier']!='1':
            raise ValueError('Unexpected protocol record')
        nre=float(record['NRE']); clean=float(record['OracleCleanProjectionNRE'])
        if not all(math.isfinite(v) and v>=0 for v in [nre,clean]):
            raise ValueError(f'Nonfinite or negative error: {key}')
        total=nre*nre; signal=clean*clean; retained=total-signal
        if retained < -1e-12:
            raise ValueError(f'Negative inferred retained disturbance: {key}: {retained}')
        # Do not silently truncate small values; retain exact CSV arithmetic.
        row={k:record[k] for k in ['Dataset','Condition','Type','NominalRate','Strength',
                                 'Seed','MethodID','CaseHash','InitHash','Absorption']}
        row.update(Repeat=int(record['Repeat']),NRE=nre,CleanProjectionNRE=clean,
                   TotalSquaredError=total,SignalLoss=signal,RetainedDisturbance=retained)
        rows.append(row)
    grouped=defaultdict(list)
    for row in rows: grouped[(row['Condition'],row['Repeat'])].append(row)
    for key, group in grouped.items():
        if set(r['MethodID'] for r in group)!=set(METHODS):
            raise ValueError(f'Incomplete matched configuration set: {key}')
        for field in ['CaseHash','InitHash']:
            if len({r[field] for r in group})!=1:
                raise ValueError(f'Mismatched {field}: {key}')
    conditions=sorted({r['Condition'] for r in rows})
    if len(conditions)!=44:raise ValueError('Expected all 44 planned conditions')
    grid=[summarize([r for r in rows if r['MethodID']==m],'All44') for m in METHODS]
    families=[summarize([r for r in rows if r['MethodID']==m and r['Type']==family],family)
              for family in FAMILIES for m in METHODS]
    cells=[summarize([r for r in rows if r['MethodID']==m and r['Condition']==condition],condition)
           for condition in conditions for m in METHODS]
    paired=[]
    for baseline in ['C1','C2','C4']:
        a={r['Repeat']:[] for r in rows if r['MethodID']=='C3'}
        for repeat in range(1,11):
            left={r['Condition']:r for r in rows if r['MethodID']=='C3' and r['Repeat']==repeat}
            right={r['Condition']:r for r in rows if r['MethodID']==baseline and r['Repeat']==repeat}
            a[repeat]={metric:mean(left[c][metric]-right[c][metric] for c in conditions)
                       for metric in METRICS}
        for metric in METRICS:
            values=[a[rep][metric] for rep in range(1,11)]
            paired.append({'Contrast':'C3-'+baseline,'Metric':metric,'ConditionsPerRepeat':44,
                           'RepeatBlocks':10,'MeanDifference':mean(values),
                           'SDRepeatBlocks':statistics.stdev(values),
                           'Interpretation':'descriptive retained-record comparison; no new hypothesis test'})
    failure=[r for r in rows if r['Condition']=='block_coherent_k4_p010' and r['Repeat']==5]
    args.output_dir.mkdir(parents=True,exist_ok=True)
    write_csv(args.output_dir/'Synthetic_Error_Decomposition_FitRecords.csv',rows)
    write_csv(args.output_dir/'Synthetic_Error_Decomposition_Grid.csv',grid)
    write_csv(args.output_dir/'Synthetic_Error_Decomposition_Families.csv',families)
    write_csv(args.output_dir/'Synthetic_Error_Decomposition_Conditions.csv',cells)
    write_csv(args.output_dir/'Synthetic_Error_Decomposition_Paired.csv',paired)
    write_csv(args.output_dir/'Synthetic_Error_Decomposition_Failure.csv',failure)
    args.tex_output.parent.mkdir(parents=True,exist_ok=True)
    write_tex(args.tex_output,grid,families,failure)
    args.main_tex_output.parent.mkdir(parents=True,exist_ok=True)
    write_main_tex(args.main_tex_output,grid)
    metadata={
      'InputSHA256':hashlib.sha256(args.input_csv.read_bytes()).hexdigest(),
      'SavedFitRecords':len(rows),'Conditions':44,'RepetitionBlocks':10,
      'Methods':list(METHODS),'ScientificFitsExecuted':0,
      'RawMatrixProjectionsReexecuted':False,
      'NegativeRetainedDisturbanceRows':sum(r['RetainedDisturbance']<0 for r in rows),
      'MinimumRetainedDisturbance':min(r['RetainedDisturbance'] for r in rows),
      'Interpretation':[
        'OracleCleanProjectionNRE uses estimated U,V; it is not a true-basis oracle.',
        'At each fit, TotalSquaredError=NRE^2 and SignalLoss=OracleCleanProjectionNRE^2.',
        'RetainedDisturbance is inferred as TotalSquaredError-SignalLoss under the orthogonal-projection identity.',
        'The common metric denominator is norm(Xclean(:))+1e-12 in the source implementation.',
        'The retained term includes projected Gaussian background noise, injected contamination, and their cross term.',
        'Absorption uses the contamination-energy denominator and is not additive with these normalized losses.',
        'Means of squared errors are not squares of means of NRE.',
        'All 44 conditions and the coherent failure are retained; grouped values are descriptive.',
        'No raw-matrix projection or independent saved-basis orthogonality verification was performed here.'
      ]}
    (args.output_dir/'Synthetic_Error_Decomposition_Metadata.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
    print(json.dumps({'grid':grid,'paired':paired,'tex_output':str(args.tex_output),
                      'main_tex_output':str(args.main_tex_output)},indent=2))


if __name__=='__main__':main()
