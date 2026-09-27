function qsi = eval_qsi2(T, p)
%{
  Calculate ice saturation specific humidity.

  Units: kg/kg (unitless).

  Args:
    T (double): air temperature in K.
    p (double): air pressure in Pa.
    qt (double): total water mixing ratio in kg/kg.
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.

  Returns:
    double: ice saturation specific humidity.
%}
%   global EPS
  esi = eval_esi(T);
  qsi = eval_q2(esi,p);