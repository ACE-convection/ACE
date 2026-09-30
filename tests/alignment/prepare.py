#!/usr/bin/env python3
"""Build isolated comparison access to preserved numerical routines.

Production numerical code is unchanged. The generated Fortran module adds
public diagnostics and a runtime flag at its existing single-ACE mask.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('work', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
work = args.work.resolve()
work.mkdir(parents=True, exist_ok=True)
source = (root / 'matlab/active/ace.m').read_text()
local = source[source.index('function X = timeint('):]
header = (root / 'tests/alignment/matlab_case.txt').read_text()
(work / 'run_alignment_case.m').write_text(header + '\n' + local)
original = (root / 'fortran/active/src/ace_module.F').read_text()
modified = original.replace('! defien operator', '''public :: ace_tendency, weno_up3, set_alignment_single, precip_sinks, set_alignment_thermo
logical, save :: alignment_single=.false.

! defien operator''', 1)
modified = modified.replace('contains\n', '''contains
subroutine set_alignment_single(enabled)
logical, intent(in) :: enabled
alignment_single=enabled
end subroutine
subroutine set_alignment_thermo(temperature,vapor,liquid,ice)
real, intent(in) :: temperature(:,:),vapor(:,:),liquid(:,:),ice(:,:)
allocate(T(size(temperature,1),size(temperature,2)),q(size(temperature,1),size(temperature,2)))
allocate(ql(size(temperature,1),size(temperature,2)),qi(size(temperature,1),size(temperature,2)))
T=temperature; q=vapor; ql=liquid; qi=ice
end subroutine
''', 1)
assert modified.count('!dXdt(2:ncols,:,:)=0.') == 1
modified = modified.replace('!dXdt(2:ncols,:,:)=0.', 'if (alignment_single) dXdt(2:ncols,:,:)=0.')
(work / 'ace_module.F').write_text(modified)
(work / 'fortran_access.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True), modified.splitlines(True), fromfile='active/ace_module.F', tofile='alignment/ace_module.F')))
flags = ['-O2', '-ffree-form', '-fdefault-real-8', '-fdefault-double-8', '-ffree-line-length-none']
include = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
commands = [
    ['gfortran', *flags, *include, '-c', str(root / 'fortran/active/src/ace_input.F')],
    ['gfortran', *flags, *include, '-c', 'ace_module.F'],
    ['gfortran', *flags, *include, str(root / 'tests/alignment/fortran_case.f90'), 'ace_module.o', 'ace_input.o', *libs, '-Wl,-rpath,' + str(Path(subprocess.check_output(['nf-config', '--prefix'], text=True).strip()) / 'lib'), '-o', 'fortran_case.exe'],
    ['gfortran', *flags, *include, str(root / 'tests/alignment/fortran_thermo.f90'), 'ace_module.o', 'ace_input.o', *libs, '-Wl,-rpath,' + str(Path(subprocess.check_output(['nf-config', '--prefix'], text=True).strip()) / 'lib'), '-o', 'fortran_thermo.exe'],
    ['gfortran', *flags, *include, str(root / 'tests/alignment/fortran_diagnostics.f90'), 'ace_module.o', 'ace_input.o', *libs, '-Wl,-rpath,' + str(Path(subprocess.check_output(['nf-config', '--prefix'], text=True).strip()) / 'lib'), '-o', 'fortran_diagnostics.exe'],
]
for command in commands:
    subprocess.run(command, cwd=work, check=True)
sources = ['matlab/active/ace.m','fortran/active/src/ace_module.F','fortran/active/src/ace_input.F','tests/alignment/matlab_case.txt','tests/alignment/fortran_case.f90','tests/alignment/fortran_thermo.f90','tests/alignment/fortran_diagnostics.f90','tests/alignment/prepare.py','tests/alignment/matlab_thermo.txt']
sources += [str(p.relative_to(root)) for directory in ['util_weno','util_plume','util_thermodynamics']
            for p in sorted((root/'matlab/active'/directory).glob('*.m'))]
manifest = {'baseline_commit': subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
            'sources_sha256': {f: hashlib.sha256((root/f).read_bytes()).hexdigest() for f in sources},
            'commands': commands, 'scope': 'test-only access and existing single tendency mask; no numerical correction',
            'input_file_sha256': hashlib.sha256((root/'data/input/manus208.nc').read_bytes()).hexdigest()}
(work / 'configuration.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(work)
header=(root / 'tests/alignment/matlab_thermo.txt').read_text()
(work / 'run_thermo.m').write_text(header+'\n'+local)
