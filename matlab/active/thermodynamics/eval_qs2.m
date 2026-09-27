function qs = eval_qs2(T, p)
%{
  Calculate saturation specific humidity with respect to liquid water.

  Units: kg/kg (unitless).

  Args:
    T (double): air temperature in K.
    p (double): air pressure in Pa.
    qt (double): total water mixing ratio in kg/kg.
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.

  Returns:
    double: saturation specific humidity.
%}
%   global EPS
  es = eval_es(T);
  qs = eval_q2(es,p);