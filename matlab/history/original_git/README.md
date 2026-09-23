# ACE_MATLAB_v0.18
Anelastic Convective Entity (ACE) Model - MATLAB Implementation version 0.18

This ACE_MATLAB_v0.18 code package is prepared for and released with the publication of Kuo & Neelin (2025a, 2025b) in the Journal of Atmospheric Sciences. Detailed model description can be found in the references list below.

The pre-computed nonlocal bases under `ACE_MATLAB/data/basis/` are provided as is.

Running the ACE model requires ARM site sounding data (ARMBEATM) available at http://dx.doi.org/10.5439/1333748. 

A copy of a few samples—not part of this code package, provided only for user’s convenience—can be found here: [soundings.zip](https://drive.google.com/file/d/1XQ6rVE7Izc_5xipvHFaswgSCNdquk61T/view?usp=drive_link)


## To run the package
(1) Place sounding data under `ACE_MATLAB/data/soundings/` and

(2) Execute the driver script `ace_v018_dev_8aces.m` in MATLAB.


## Experimenting with the ACE model
In the `Set up parameters` section of `ace_v018_dev_8aces.m` there are a few parameters users can vary, including: `arm`, `pidx`, `qc_ramp`, `conti`, `tspan`, as well as variables for `Initial mass flux`, `Initial thermal bubble`, and `External buoyancy forcing` \[most variables are documented with in-line comments in the driver script; initiation and forcing options documented in Kuo & Neelin (2025a, 2025b)].

Changing other variables is not recommended unless you are certain what you are doing.


## References:
- Kuo, Y.-H., and J. D. Neelin, 2022: Conditions for convective deep inflow. _Geophys. Res. Lett._, 49, e2022GL100 552, doi:10.1029/2022GL100552.

- Kuo, Y.-H., and J. D. Neelin, 2025a: Anelastic Convective Entities. Part 1: Formulation and implication for nighttime convection. _J. Atmos. Sci._, 82, 599-623, doi:10.1175/JAS-D-23-0214.1.

- Kuo, Y.-H., and J. D. Neelin, 2025b: Anelastic Convective Entities. Part 2: Adjustment processes and convective cold top. _J. Atmos. Sci._, 82, 625-640, doi:10.1175/JAS-D-24-0130.1.
