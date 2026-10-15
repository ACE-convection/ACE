"""Sequential isolated MATLAB thread benchmarks; never launches integrations beyond one step."""
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import time
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = ROOT / 'migration_work/v02187_validation'


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def main():
    work = pathlib.Path(sys.argv[1]).resolve()
    work.mkdir(exist_ok=False)
    source = ROOT / 'tests/slab/benchmark_basis.m'
    source_bytes = source.read_bytes()
    (work / 'benchmark_basis_source.txt').write_bytes(source_bytes)
    order = ['default', 64, 32, 80, 80, 32, 64, 'default']
    write(work / 'configuration.json', {
        'order': order, 'trials_per_process': 3,
        'source_sha256': hashlib.sha256(source_bytes).hexdigest(),
        'environment': 'inherited unchanged by Python; no concurrent test Fortran',
        'scope': 'two reversed process blocks; fresh MATLAB per group; then default and fastest full single steps',
    })
    samples = {}
    reference = None
    for index, setting in enumerate(order):
        assert source.read_bytes() == source_bytes
        name = f'{index:02d}_{setting}'
        job = work / name
        extra = '' if setting == 'default' else f',{setting}'
        command = ['matlab', '-batch',
                   f"addpath('{ROOT}/tests/slab');benchmark_basis('{ROOT}/data/input/goamazon314_88aces.nc','{job}'{extra});"]
        write(work / 'status.json', {'phase': name, 'started_unix': time.time(), 'command': command})
        with (work / (name + '.log')).open('x') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
        report = json.loads((job / 'results.json').read_text())
        outputs = [(job / f'result_{t}.bin').read_bytes() for t in range(1, 4)]
        if reference is None:
            reference = outputs
        assert outputs == reference, 'Cross-thread output mismatch'
        samples.setdefault(str(setting), []).extend(np.array(report['seconds'])[:, 0].tolist())
        print(name, report['reported_threads'], samples[str(setting)], flush=True)
    medians = {k: float(np.median(v)) for k, v in samples.items()}
    fastest = min(medians, key=medians.get)
    summary = {'samples_seconds': samples, 'median_seconds': medians,
               'all_kernel_outputs_bitwise_equal': True, 'fastest_tested_setting': fastest,
               'limitation': 'Two process blocks only; system load and memory placement not controlled.'}
    write(work / 'results.json', summary)
    # Validate whole-step behavior with default and the measured fastest setting.
    original = BASE / 'matlab_inherited_environment_smoke'
    reference_state = (original / 'matlab_states.bin').read_bytes()
    full_steps = {}
    for setting in dict.fromkeys(['default', fastest]):
        job = work / ('full_step_' + setting)
        job.mkdir()
        script = (original / 'matlab_main.m').read_text().replace(str(original), str(job))
        (job / 'matlab_main.m').write_text(script)
        prefix = '' if setting == 'default' else f'maxNumCompThreads({setting});'
        command = ['matlab', '-batch', prefix + f"run('{job}/matlab_main.m');"]
        write(work / 'status.json', {'phase': job.name, 'command': command})
        with (job / 'matlab.log').open('x') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
        text = (job / 'matlab.log').read_text()
        assert 'SLAB_INTEGRATION_COMPLETED' in text
        elapsed = float(re.search(r'ODE solver time = ([\d.]+) sec', text)[1])
        assert (job / 'matlab_states.bin').read_bytes() == reference_state
        full_steps[setting] = {'ode_seconds': elapsed, 'bitwise_equal_to_reference': True,
                               'simulated_seconds': 6}
        print(job.name, elapsed, flush=True)
    summary['full_steps'] = full_steps
    write(work / 'results.json', summary)
    write(work / 'status.json', {'phase': 'completed', 'long_validation': 'stopped'})


if __name__ == '__main__':
    main()
