#!/usr/bin/env python3
"""Substitute exact-input MATLAB pressure powers in temporary forward probes.

Requires a successful isolate_forward_evaluation.py run. No production source
is modified, no inversion is performed, and no acceptance tolerance is imposed.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

import numpy as np
from compare import metrics


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    values = np.fromfile(path, dtype='<f8').reshape((1200, 54), order='F')
    assert np.isfinite(values).all(), str(path)
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--forward', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    work = args.work.resolve(); forward = args.forward.resolve()
    if work.exists() and any(work.iterdir()):
        raise SystemExit('Use a fresh directory; existing evidence is preserved')
    retained = json.loads((forward/'results.json').read_text())
    for name, value in retained['production_sources_sha256'].items():
        assert digest(root/name) == value, f'Stale production source: {name}'
    for name, value in retained['artifact_sha256'].items():
        assert digest(forward/name) == value, f'Stale forward artifact: {name}'
    for name, value in retained['probe_sources_sha256'].items():
        assert digest(root/name) == value, f'Stale forward probe source: {name}'
    assert digest(root/'data/input/manus208.nc') == retained['input_sha256']
    compiler = subprocess.check_output(['gfortran', '--version'], text=True).splitlines()[0]
    assert compiler == retained['tool_versions']['gfortran'], 'Compiler differs from parent probe'
    work.mkdir(parents=True, exist_ok=True)
    matlab = read(forward/'matlab.bin')
    pairs = np.concatenate([matlab[:, [11, 7, 15]], matlab[:, [37, 33, 41]]])
    for base, exponent in np.unique(pairs[:, :2], axis=0):
        selected = pairs[(pairs[:, 0] == base) & (pairs[:, 1] == exponent), 2]
        assert np.unique(selected).size == 1, 'Ambiguous pressure power lookup'
    pairs.flatten(order='F').astype('<f8').tofile(work/'matlab_pressure.bin')
    helper = '''
subroutine set_forward_power_override(file)
character(*), intent(in) :: file
integer :: u
allocate(diagnostic_power_pairs(2400,3))
open(newunit=u,file=file,access='stream',form='unformatted',status='old')
read(u) diagnostic_power_pairs
close(u)
end subroutine
function diagnostic_pressure_power(base,exponent) result(value)
use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
real, intent(in) :: base,exponent
real :: value
integer :: j
if (.not.ieee_is_finite(base).or..not.ieee_is_finite(exponent)) then
 value=base**exponent
 return
endif
do j=1,size(diagnostic_power_pairs,1)
 if (base==diagnostic_power_pairs(j,1).and.exponent==diagnostic_power_pairs(j,2)) then
  value=diagnostic_power_pairs(j,3)
  return
 endif
enddo
error stop 'Pressure power inputs absent from identical MATLAB probe'
end function
'''
    driver = (root/'tests/alignment/fortran_forward_probe.f90').read_text()
    driver = driver.replace('set_forward_exp_override\n',
                            'set_forward_exp_override, set_forward_power_override\n', 1)
    driver = driver.replace("open(newunit=u,file=trim(input_file)",
        "if (command_argument_count()>=4) then\n"
        " call get_command_argument(4,exp_file)\n"
        " call set_forward_power_override(trim(exp_file))\nendif\n"
        "open(newunit=u,file=trim(input_file)", 1)
    (work/'driver.f90').write_text(driver)
    flags = ['-O2', '-ffree-form', '-fdefault-real-8', '-fdefault-double-8',
             '-ffree-line-length-none']
    include = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
    libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
    rpath = '-Wl,-rpath,' + subprocess.check_output(['nf-config', '--prefix'], text=True).strip() + '/lib'
    commands = []; outputs = {}

    def run(command, label, directory):
        command = list(map(str, command))
        commands.append({'argv': command, 'cwd': str(directory)})
        with (directory/(label+'.log')).open('w') as log:
            subprocess.run(command, cwd=directory, stdout=log,
                           stderr=subprocess.STDOUT, check=True, timeout=600)

    variants = [('control', 'control', False),
                ('pressure_override', 'control', True),
                ('eps_literal_exp_control', 'eps_literal_exp_override', False),
                ('eps_literal_exp_pressure_override', 'eps_literal_exp_override', True)]
    for name, parent, override in variants:
        directory = work/name; directory.mkdir()
        original = (forward/parent/'ace_module.F').read_text()
        module = original.replace('contains\n', 'contains\n'+helper, 1)
        module = module.replace('real, save :: forward_trace(26)',
            'public :: set_forward_power_override\n'
            'real, allocatable, save :: diagnostic_power_pairs(:,:)\n'
            'real, save :: forward_trace(26)', 1)
        start = module.index('function theta_e(T,q,ql,qi,p)')
        end = module.index('end function theta_e', start)
        kernel = module[start:end]
        if override:
            assert kernel.count('(P0*R/p/Re)**chi') == 1
            assert kernel.count('forward_trace(12)**chi') == 1
            kernel = kernel.replace('(P0*R/p/Re)**chi', 'diagnostic_pressure_power(P0*R/p/Re,chi)')
            kernel = kernel.replace('forward_trace(12)**chi', 'diagnostic_pressure_power(forward_trace(12),chi)')
        module = module[:start]+kernel+module[end:]
        inverse = original.index('subroutine inv_theta_e')
        assert module[module.index('subroutine inv_theta_e'):] == original[inverse:]
        (directory/'ace_module.F').write_text(module)
        (directory/'pressure.patch').write_text(''.join(difflib.unified_diff(
            original.splitlines(True), module.splitlines(True),
            fromfile=parent+'/ace_module.F', tofile=name+'/ace_module.F')))
        for suffix in ['.mod', '.o']:
            shutil.copyfile(forward/('ace_input'+suffix), directory/('ace_input'+suffix))
        run(['gfortran', *flags, *include, '-c', 'ace_module.F'], 'module_build', directory)
        run(['gfortran', *flags, *include, work/'driver.f90', 'ace_module.o',
             'ace_input.o', *libs, rpath, '-o', 'probe.exe'], 'driver_build', directory)
        command = [directory/'probe.exe', forward/'input.bin', directory/'output.bin']
        if override or parent == 'eps_literal_exp_override':
            command.append(forward/'matlab_exp.bin')
        if override:
            command.append(work/'matlab_pressure.bin')
        run(command, 'probe', directory)
        outputs[name] = read(directory/'output.bin')
        if not override:
            assert np.array_equal(outputs[name], read(forward/parent/'output.bin')), 'Control changed'
    report = {'parent_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'production_sources_sha256': retained['production_sources_sha256'],
              'input_sha256': retained['input_sha256'],
              'forward_result_sha256': digest(forward/'results.json'),
              'fields': retained['fields'],
              'matlab_reference': 'Reused verified native forward artifact; no new MATLAB invocation',
              'scope': '1200 matched-state forward/sink probes; exact-input pressure-power substitution only; no integration',
              'controls_match_retained_exactly': True,
              'tolerance_status': 'No acceptance tolerance', 'commands': commands, 'variants': {}}
    for name, values in outputs.items():
        numerator_m = matlab[:, 49]-matlab[:, 23]
        numerator_f = values[:, 49]-values[:, 23]
        worst = int(np.argmax(abs(matlab[:, 52]-values[:, 52])))
        report['variants'][name] = {
            'base': metrics(matlab[:, 23], values[:, 23]),
            'perturbed': metrics(matlab[:, 49], values[:, 49]),
            'numerator': metrics(numerator_m, numerator_f),
            'theta_e_sink': metrics(matlab[:, 52], values[:, 52]),
            'qt_sink': metrics(matlab[:, 53], values[:, 53]),
            'numerator_exact_count': int(np.count_nonzero(numerator_m == numerator_f)),
            'theta_e_sink_exact_count': int(np.count_nonzero(matlab[:, 52] == values[:, 52])),
            'unequal_sink_with_equal_numerator_count': int(np.count_nonzero(
                (matlab[:, 52] != values[:, 52]) & (numerator_m == numerator_f))),
            'component_difference_counts': {
                phase: {field: int(np.count_nonzero(matlab[:, offset+j] != values[:, offset+j]))
                        for j, field in enumerate(retained['fields'])}
                for phase, offset in [('base', 0), ('perturbed', 26)]},
            'record_500_sink_difference': float(matlab[499, 52]-values[499, 52]),
            'record_500_trace_exact': bool(np.array_equal(matlab[499, :52], values[499, :52])),
            'worst_record': {'index_one_based': worst+1, 'matlab': matlab[worst].tolist(),
                             'fortran': values[worst].tolist()}}
        print(name, report['variants'][name]['theta_e_sink'])
    report['probe_sha256'] = digest(Path(__file__))
    report['tool_versions'] = {'gfortran': compiler,
                              'matlab': retained['tool_versions']['matlab']}
    report['artifact_sha256'] = {str(p.relative_to(work)): digest(p) for p in sorted(work.rglob('*'))
                                if p.is_file() and p.suffix in ['.F', '.f90', '.patch', '.bin', '.exe']}
    for name, value in retained['production_sources_sha256'].items():
        assert digest(root/name) == value, 'Production source changed during probe'
    (work/'results.json').write_text(json.dumps(report, indent=2, allow_nan=False)+'\n')


if __name__ == '__main__':
    main()
