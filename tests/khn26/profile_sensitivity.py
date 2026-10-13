#!/usr/bin/env python3
"""Bracket MATLAB timer/source-expression experiments with unchanged controls."""
import argparse
import json
from pathlib import Path

from profile_matlab import prepare, run, digest


def experiment(work):
    work.mkdir(parents=True,exist_ok=False)
    sequence = [('control_before',True,'helper'),('split_only',False,'split_only'),
                ('unsplit_timers',False,'unsplit'),('split_timers',False,'helper'),
                ('control_after',True,'helper')]
    results = []
    for name, control, mode in sequence:
        directory = work/name
        print('Preparing and running '+name,flush=True)
        prepare(directory,control,mode)
        run(directory)
        path = directory/('control_results.json' if control or mode == 'split_only' else 'profile_results.json')
        report = json.loads(path.read_text())
        if not report['binary_identical_to_three_hour_prefix'] or not report['provenance_rechecked']:
            raise ValueError('Validation failed: '+name)
        average = report.get('wall_seconds_per_step',report.get('matlab_ms_per_step',0)/1000)
        results.append({'variant':name,'wall_seconds_per_step':average,
                        'binary_identical':True,'report':str(path),'report_sha256':digest(path),
                        'comparison':report.get('comparison'),'sections':report.get('sections')})
        (work/'sensitivity_results.json').write_text(json.dumps({'sequence':results},indent=2)+'\n')
    summary = {'sequence':results,'duration_seconds_each':60,'steps_each':15,
               'settings':'Fresh MATLAB batch/default process for each run, no thread setter/CPU pin.',
               'limits':'Single sample per variant with before/after unchanged controls on shared hardware. Differences identify source-transformation sensitivity; exact JIT/allocation attribution is not directly measured.'}
    (work/'sensitivity_results.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps([{k:r[k] for k in ('variant','wall_seconds_per_step','binary_identical')} for r in results],indent=2),flush=True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    experiment(parser.parse_args().work.resolve())
