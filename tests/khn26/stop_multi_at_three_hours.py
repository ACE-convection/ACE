#!/usr/bin/env python3
"""Preserve live output and stop an authorized multiACE run at 180 saved minutes."""
import argparse
import json
import os
from pathlib import Path
import signal
import time
from datetime import datetime, timezone


def write(path, data):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(data, indent=2) + '\n')
    tmp.replace(path)


def stop(pid, expected, group=False):
    proc = Path('/proc') / str(pid) / 'cmdline'
    if not proc.exists():
        return
    cmd = proc.read_bytes()
    if not cmd:
        return
    if expected.encode() not in cmd:
        raise RuntimeError(f'Unexpected process at PID {pid}')
    if group:
        if os.getpgid(pid) != pid:
            raise RuntimeError(f'Expected independent process group: {pid}')
        os.killpg(pid, signal.SIGTERM)
    else:
        os.kill(pid, signal.SIGTERM)


def minutes(work, name):
    width = 101 if name == 'matlab' else 102
    header = 0 if name == 'matlab' else 12 + 401 * 8
    return max(0, ((work / 'full' / (name + '_states.bin')).stat().st_size - header)
               // (width * 401 * 3 * 8) - 1)


def run(work):
    status = json.loads((work / 'status.json').read_text())
    pids = status['driver_pids']
    # Stop the old 12-hour monitor first so it cannot reject an intentional stop.
    stop(status['supervisor_pid'], 'unrestricted_multi.py')
    if minutes(work, 'fortran') < 180:
        raise RuntimeError('Fortran has not yet saved the requested three hours')
    stop(pids['fortran'], 'ace_model.exe', group=True)
    status.update(state='running_to_revised_three_hour_target',
                  target_model_seconds=10800, original_target_model_seconds=43200,
                  stop_reason='User shortened gravity-wave comparison to three hours',
                  controller_pid=os.getpid())
    write(work / 'three_hour_stop_policy.json', {
        'requested_duration_seconds': 10800,
        'original_duration_seconds': 43200,
        'output_policy': 'Preserve all raw records; compare only minutes 0–180. No claim of natural solver exit.',
        'driver_pids': pids})
    while True:
        saved = {name: minutes(work, name) for name in pids}
        status.update(model_seconds={name: value * 60 for name, value in saved.items()},
                      progress_updated_utc=datetime.now(timezone.utc).isoformat())
        if saved['matlab'] >= 180:
            stop(pids['matlab'], 'MATLAB', group=True)
            status.update(state='stopped_at_revised_target_pending_comparison',
                          comparison_duration_seconds=10800,
                          intentionally_stopped_languages=['matlab', 'fortran'])
            write(work / 'status.json', status)
            break
        if not (Path('/proc') / str(pids['matlab'])).exists():
            status.update(state='failed_before_revised_target')
            write(work / 'status.json', status)
            raise RuntimeError('MATLAB exited before saving 180 minutes')
        write(work / 'status.json', status)
        time.sleep(5)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    run(parser.parse_args().work.resolve())
