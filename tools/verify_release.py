#!/usr/bin/env python3
"""Verify retained source bytes and exported records, without running MATLAB."""
from __future__ import annotations
import argparse
import collections
import csv
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read_csv(path):
    with path.open(encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream))

def verify():
    retained = read_csv(ROOT / 'provenance/retained_files.csv')
    failures = []
    for row in retained:
        path = ROOT / row['path']
        if not path.is_file() or sha(path) != row['sha256']:
            failures.append(row['path'])
    assert not failures, f'Retained files differ: {failures}'
    sample = ROOT / 'modules/sample_extension'
    recorded = read_csv(ROOT / 'evidence/sample_extension_20261116/review_bundle/source_hashes.csv')
    assert len(recorded) == 47
    for row in recorded:
        assert sha(sample / row['File'].replace('\\','/')) == row['SHA256'], row['File']
    fits = read_csv(ROOT / 'evidence/sample_extension_20261116/review_bundle/formal/fit_records.csv')
    assert len(fits) == 80
    conditions = ['Clean','CellOnly','CaseOnly','Mixed']
    keys = {(r['Condition'],int(r['Repeat']),r['Method']) for r in fits}
    assert len(keys) == 80
    assert keys == {(c,r,m) for c in conditions for r in range(1,11) for m in ['E','ES']}
    assert all(not r['FailureMessage'] for r in fits)
    assert all(math.isfinite(float(r[field])) for r in fits
               for field in ['ErrSubNorm','ProbeCleanNRE','SampleESS'])
    for condition in conditions:
        for repeat in range(1,11):
            pair = [r for r in fits if r['Condition'] == condition and int(r['Repeat']) == repeat]
            assert len({r['CaseHash'] for r in pair}) == 1
            assert len({r['InitHash'] for r in pair}) == 1
    counts = collections.Counter(r['Status'] for r in fits)
    assert counts == {'timecap':79,'budget_exhausted':1}, counts
    primary = {}
    for condition in ['CaseOnly','Mixed']:
        group = [r for r in fits if r['Condition'] == condition]
        means = {m:sum(float(r['ErrSubNorm']) for r in group if r['Method']==m)/10 for m in ['E','ES']}
        primary[condition] = 100 * (means['E']-means['ES'])/means['E']
    assert abs(primary['CaseOnly']-5.3089403)<1e-6
    assert abs(primary['Mixed']-4.0387748)<1e-6
    for folder, expected in [('core_synthetic',1760),('core_real',400)]:
        rows = read_csv(ROOT / 'evidence' / folder / 'fit_records.csv')
        assert len(rows)==expected, folder
        groups = collections.defaultdict(list)
        for row in rows:
            groups[(row['Dataset'],row['Condition'],row['Repeat'])].append(row)
        for pair in groups.values():
            assert {row['MethodID'] for row in pair} == {'C1','C2','C3','C4'}
            assert len({row['CaseHash'] for row in pair}) == 1
            assert len({row['InitHash'] for row in pair}) == 1
    return {'pass':True,'scope':'Source-byte integrity and exported-record consistency only',
            'retained_files_checked':len(retained),'sample_source_hashes_checked':47,
            'sample_formal_records':80,'sample_statuses':dict(counts),
            'sample_subspace_reduction_percent':primary,
            'matlab_executed':False,'scientific_fits_executed':0,
            'notice':'This check does not replay raw arrays, model bases or optimization traces.'}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    args = parser.parse_args()
    report = verify()
    text = json.dumps(report,indent=2)+'\n'
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(text)
    print(text,end='')

if __name__=='__main__':
    main()
