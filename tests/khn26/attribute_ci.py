#!/usr/bin/env python3
"""Attribute common-state theta_e differences to the existing Ci reference offset.

Postprocess saved outputs only. Does not alter any model source or integrate time.
"""
import argparse
import json
from pathlib import Path

import numpy as np

from run import digest


def run(work):
    report=json.loads((work/'results.json').read_text());n=report['samples']
    m=np.fromfile(work/'matlab_outputs.bin','<f8').reshape((n,9),order='F')
    f=np.fromfile(work/'fortran_fixed_thermo.bin','<f8').reshape((n,9),order='F')
    T,q,ql,qi=m[:,:4].T
    if not np.array_equal(m[:,:4],f[:,:4]):raise ValueError('Thermodynamic inputs differ')
    triple_point=273.1636783445389
    delta=7.3*(triple_point-273.15)
    qt=q+ql+qi;qc=ql+qi;wet=qc>0
    cpl=1005.7+3184.3*qt
    predicted=m[:,4]*np.exp(delta*qi/cpl*np.log(triple_point/T))
    dql=np.divide(1e-8*ql,qc,out=np.zeros(n),where=wet)
    dqi=np.divide(1e-8*qi,qc,out=np.zeros(n),where=wet)
    cpl_perturbed=1005.7+3184.3*(q+(ql+dql)+(qi+dqi))
    corrected_base=f[:,4]*np.exp(-delta*qi/cpl*np.log(triple_point/T))
    corrected_perturbed=f[:,5]*np.exp(-delta*(qi+dqi)/cpl_perturbed*np.log(triple_point/T))
    derivative=np.where(wet,(corrected_perturbed-corrected_base)/1e-8,0)
    sink=derivative*f[:,8]
    result={
        'scope':'Postprocessing saved forward theta_e values; no model changes or integration. The factor follows solely from the Ci reference-temperature difference; corrected finite differences still have rounding error.',
        'Ci_matlab_at_triple_point':2106+delta,'Ci_fortran_at_triple_point':2106.,
        'Ci_difference_J_kg_K':delta,
        'original_forward_theta_e_max_error_K':float(np.max(np.abs(f[:,4]-m[:,4]))),
        'predicted_fortran_theta_e_max_residual_K':float(np.max(np.abs(f[:,4]-predicted))),
        'corrected_forward_theta_e_max_error_K':float(np.max(np.abs(corrected_base-m[:,4]))),
        'original_theta_e_sink_max_error_K_s':float(np.max(np.abs(f[:,7]-m[:,7]))),
        'corrected_theta_e_sink_max_error_K_s':float(np.max(np.abs(sink-m[:,7]))),
        'original_derivative_max_error':float(np.max(np.abs(f[:,6]-m[:,6]))),
        'corrected_derivative_max_error':float(np.max(np.abs(derivative-m[:,6]))),
        'sha256':{str(p):digest(p) for p in (Path(__file__).resolve(),work/'results.json',work/'matlab_outputs.bin',work/'fortran_fixed_thermo.bin')}}
    (work/'ci_attribution.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('work',type=Path)
    run(parser.parse_args().work.resolve())
