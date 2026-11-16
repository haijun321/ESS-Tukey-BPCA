#!/usr/bin/env python3
"""Rebuild selected manuscript figures and archived-metric tables; no fitting."""
from __future__ import annotations
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def run(script,*arguments):
    subprocess.run([sys.executable,str(ROOT/script),*map(str,arguments)],cwd=ROOT,check=True)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode',choices=['verify','tables','figures','all'],default='verify')
    args=parser.parse_args()
    run('tools/verify_release.py')
    if args.mode in ['tables','all']:
        out=ROOT/'generated/tables'
        out.mkdir(parents=True,exist_ok=True)
        run('analysis/compute_synthetic_error_decomposition.py',
            '--output-dir',out,'--tex-output',out/'Table_S8_Error_Decomposition.tex',
            '--main-tex-output',out/'synthetic_decomposition_main_table.tex')
    if args.mode in ['figures','all']:
        run('reproducibility/render_integrated_figures.py')
        run('reproducibility/render_v2_figures.py')
        run('analysis/make_sample_figures.py')
        folder=ROOT/'generated/manuscript_figures'
        folder.mkdir(parents=True,exist_ok=True)
        names={'ESS_weight_example.pdf':'Fig1.pdf',
               'Synthetic_NRE_strength4.pdf':'Fig2.pdf',
               'Fig3_sample_increment.pdf':'Fig3_sample_increment.pdf',
               'Real_calibration_task_evidence.pdf':'Fig4_real_calibration.pdf',
               'FigS7_sample_weights.pdf':'FigS7_sample_weights.pdf'}
        for source,target in names.items():
            shutil.copy2(ROOT/'figures'/source,folder/target)
        print('Selected publication figures:',folder)
        print('Historical trajectory figures need their full saved checkpoint archives.')

if __name__=='__main__':
    main()
