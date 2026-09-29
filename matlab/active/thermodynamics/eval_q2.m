function q = eval_q2(e, p)
%{
  Calculate specific humidity.

  Units: kg/kg (unitless).

  Args:
    e (double): vapor pressure in Pa.
    p (double): air pressure in Pa.
    qt (double): total water mixing ratio in kg/kg.
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.

  Returns:
    double: specific humidity.
%}  
  q = 0.621971830985916 * e ./ ( p-e*0.378028169014084 );