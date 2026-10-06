# Updated timestep timing table

Same v0.18 eight-ACE case. Times in ms; each step advances 4 simulated seconds.
Full-step column: median of five batch averages. 100-step column: median of
three evolving-run averages. Original four rows used CPU 0; MATLAB default
uses unrestricted affinity and no computational-thread setting.

| Version | Complete step ms | 100-step average ms/step |
|---|---:|---:|
| Original Fortran | 87.441 | 88.022 |
| + packed PMB | 37.894 | 37.864 |
| + packed PMB + binary PCHIP | 35.053 | 35.046 |
| MATLAB single | 65.353 | 62.595 |
| MATLAB default (thread cap 80) | **149.294** | **145.715** |

Default-mode ranges: frozen-step batch averages 96.174–158.305 ms; evolving-100 averages 53.346–148.476 ms/step.
The default-mode first step and 100-step trajectory match MATLAB single bitwise.

## Scope and adoption in the current Fortran branch

These are the measured v0.18 eight-ACE Manus 208 results from main d7d25b1,
not performance predictions for the 101-ACE KHN26/slab case. The default
MATLAB follow-up used a fresh process without a thread setter or CPU pin.
Its natural computational-thread cap was 80; time variation is recorded above.

The current migration/v020-preparation Fortran implementation already packs
PMB once at initialization and retains vertical-then-forcing reduction order.
PCHIP interval lookup is now binary search in src/ace_interpolation.F, with
all floating-point interpolation expressions retained. Annular dynamics call
PCHIP; slab dynamics keep their existing MAKIMA/direct interpolation path.
No interpolation-method switch, OpenMP enablement or scientific setting
change is part of this adoption.

Raw measured batches are retained in serial_timestep_results.json and
matlab_default_results.json beside this report. Interpolation equivalence
and the current production model smoke comparison are recorded in the
existing interpolation test reports.
