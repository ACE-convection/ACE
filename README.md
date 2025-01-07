Anelastic Convection Entity (ACE) Model - FORTRAN implementation 

This code package is prepared for and released with the submission of Kuo & Neelin (2024a, 2024b) to the Journal of Atmospheric Sciences. Detailed model description can be found in the references list below.

The pre-computed nonlocal bases under `ACE_MATLAB_v0.16/data/basis/` are provided as is.

Running the ACE model requires ARM site sounding data (ARMBEATM) available at http://dx.doi.org/10.5439/1333748.

A copy of a few samples—not part of this code package, provided only for user’s convenience—can be found here: [soundings.zip](https://drive.google.com/file/d/1XQ6rVE7Izc_5xipvHFaswgSCNdquk61T/view?usp=drive_link)

## References:
- Kuo, Y.-H., and J. D. Neelin, 2022: Conditions for convective deep inflow. _Geophys. Res. Lett._, 49, e2022GL100 552, doi:10.1029/2022GL100552.

- Kuo, Y.-H., and J. D. Neelin, 2024a: Anelastic Convective Entities. Part 1: Formulation and implication for nighttime convection. _J. Atmos. Sci._, under review. Preprint available via [ESS Open Archive](https://doi.org/10.22541/essoar.171805589.93950783/v1).

- Kuo, Y.-H., and J. D. Neelin, 2024b: Anelastic Convective Entities. Part 2: Adjustment processes and convective cold top. _J. Atmos. Sci._, under review. Preprint available via [ESS Open Archive](https://doi.org/10.22541/essoar.171805611.18082376/v1).


How to run?

some preparations for running ACE model.
1. prepare initial conditions placed under ./input_data (Double-precision binary file with the sequence: theta_mf, qt_mf, Tv_mf, p_mf, rho_mf, zm, theta_e_zc, qt_zc, Tv_zc, p_zc, rho_zc, and z).
2. place precomputed file under ./input_data (PMB.dat is used for 8-column ACE simulation).
3. modify the filename at line 162 and 213 in ./src/test.F if double-precision binary files of initial conditions and precomputed basis are prepared.
4. change some settings in line 138-159 ./src/test.F, and give initial massflux in line 199-209 in ./src/test.F.
5. set the output file name at line 227 in ./src/test.F

run ACE model
1. execute make under this ACE_FORTRAN directory. Then, source code under ./src/ will be compiled.
2. execute ace_model.exe to run the model.



