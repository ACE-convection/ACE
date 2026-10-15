"""Background native 10-minute and one-hour cases; no eight-hour execution path."""
import concurrent.futures
import importlib.util
import json
import pathlib
import shutil
import subprocess
import sys
import traceback


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def run(work):
    config = json.loads((work / 'configuration.json').read_text())
    spec = importlib.util.spec_from_file_location('frozen_slab', config['frozen_runner'])
    slab = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(slab)
    def case(name, duration):
        child = work / name
        slab.verify(child)
        result = slab.pair(child, name, duration, short=duration == 600)
        subprocess.run([sys.executable, str(work / 'audit.py'), str(child)], check=True,
                       stdout=(child / 'audit.log').open('w'), stderr=subprocess.STDOUT)
        audit = json.loads((child / 'audit_results.json').read_text())
        assert audit['jobs'][name]['passed']
        slab.status(child, 'completed_pending_scientific_review')
        return {'result': result, 'audit_passed': True}
    slab.status(work, 'parallel_native_10min_1h', eight_hour_authorized=False)
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        jobs = {pool.submit(case, name, duration): name
                for name, duration in [('native_10min', 600), ('native_1h', 3600)]}
        for future in concurrent.futures.as_completed(jobs):
            name = jobs[future]
            try:
                results[name] = future.result()
            except Exception:
                results[name] = {'error': traceback.format_exc()}
            write(work / 'results.json', results)
            print(name, 'completed' if 'error' not in results[name] else 'failed', flush=True)
    phase = 'completed_awaiting_8h_decision' if all('error' not in r for r in results.values()) else 'failed'
    slab.status(work, phase, eight_hour_authorized=False)


def main():
    if sys.argv[1] == '--run':
        run(pathlib.Path(sys.argv[2]).resolve())
        return
    prepared, work = [pathlib.Path(p).resolve() for p in sys.argv[1:3]]
    work.mkdir(exist_ok=False)
    shutil.copyfile(__file__, work / 'executed_runner.py')
    shutil.copyfile(pathlib.Path(__file__).with_name('audit.py'), work / 'audit.py')
    original = json.loads((prepared / 'configuration.json').read_text())
    assert original['threads'] == original['matlab_threads'] == 32
    write(work / 'configuration.json', {'frozen_runner': str(prepared / 'executed_runner.py'),
          'prepared_workspace': str(prepared), 'durations_seconds': [600, 3600],
          'matlab_threads': 32, 'fortran_threads': 32, 'eight_hour_authorized': False})
    for name in ('native_10min', 'native_1h'):
        child = work / name
        child.mkdir()
        shutil.copyfile(prepared / 'configuration.json', child / 'configuration.json')
        for directory in ('source', 'budget'):
            (child / directory).symlink_to(prepared / directory, target_is_directory=True)
    with (work / 'supervisor.log').open('x') as log:
        command = [sys.executable, str(work / 'executed_runner.py'), '--run', str(work)]
        process = subprocess.Popen(command, cwd=work, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
    write(work / 'launch.json', {'pid': process.pid, 'command': command})
    print(json.dumps({'pid': process.pid, 'workspace': str(work)}))


if __name__ == '__main__':
    main()
