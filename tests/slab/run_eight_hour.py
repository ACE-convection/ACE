"""Launch the explicitly authorized eight-hour case with frozen 32/32 sources."""
import importlib.util
import json
import pathlib
import shutil
import subprocess
import sys
import traceback


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def run(work):
    settings = json.loads((work / 'launch_configuration.json').read_text())
    spec = importlib.util.spec_from_file_location('frozen_slab', settings['frozen_runner'])
    slab = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(slab)
    try:
        slab.verify(work)
        result = slab.pair(work, 'native_8h', 28800, short=False)
        subprocess.run([sys.executable, str(work / 'audit.py'), str(work)], check=True,
                       stdout=(work / 'audit.log').open('w'), stderr=subprocess.STDOUT)
        audit = json.loads((work / 'audit_results.json').read_text())
        assert audit['jobs']['native_8h']['passed']
        write(work / 'summary.json', {'result': result, 'audit_passed': True,
              'scientific_acceptance': 'pending review', 'precomputed_enabled': False})
        slab.status(work, 'completed_pending_scientific_review')
    except BaseException:
        slab.status(work, 'failed', error=traceback.format_exc())
        raise


def main():
    if sys.argv[1] == '--run':
        run(pathlib.Path(sys.argv[2]).resolve())
        return
    prepared, work = [pathlib.Path(p).resolve() for p in sys.argv[1:3]]
    gate = prepared.parent / 'parallel32_10min_1h'
    assert json.loads((gate / 'status.json').read_text())['phase'] == 'completed_awaiting_8h_decision'
    for name in ('native_10min', 'native_1h'):
        audit = json.loads((gate / name / 'audit_results.json').read_text())
        assert audit['jobs'][name]['passed']
    cfg = json.loads((prepared / 'configuration.json').read_text())
    assert cfg['threads'] == cfg['matlab_threads'] == 32
    work.mkdir(exist_ok=False)
    shutil.copyfile(__file__, work / 'executed_runner.py')
    shutil.copyfile(pathlib.Path(__file__).with_name('audit.py'), work / 'audit.py')
    shutil.copyfile(prepared / 'configuration.json', work / 'configuration.json')
    for name in ('source', 'budget'):
        (work / name).symlink_to(prepared / name, target_is_directory=True)
    write(work / 'launch_configuration.json', {
        'frozen_runner': str(prepared / 'executed_runner.py'),
        'prepared_workspace': str(prepared), 'gate_workspace': str(gate),
        'duration_seconds': 28800, 'matlab_threads': 32, 'fortran_threads': 32,
        'developer_authorization': 'Start background eight-hour simulation now',
        'precomputed_enabled': False})
    with (work / 'supervisor.log').open('x') as log:
        command = [sys.executable, str(work / 'executed_runner.py'), '--run', str(work)]
        process = subprocess.Popen(command, cwd=work, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
    write(work / 'launch.json', {'pid': process.pid, 'command': command})
    print(json.dumps({'pid': process.pid, 'workspace': str(work)}))


if __name__ == '__main__':
    main()
