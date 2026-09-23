function qsscl = eval_qsscl(T, p, qt)
%{
  Calculate saturation specific humidity while allowing super-cooled liquid (scl).

  Units: kg/kg (unitless).

  Args:
    T (double): air temperature in K.
    p (double): air pressure in Pa.
    qt (double): total water mixing ratio in kg/kg.
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.

  Returns:
    double: saturation specific humidity using vapor pressure as a linear 
            combination of liquid and ice using Eqs. (4.4.13) & (4.4.15) in 
            Emanual (1994) for -40-deg-C<=T<=0-deg-C; using pure liquid/ice 
            formulae otherwise.
%}
  esscl = eval_esscl(T);
  
  if nargin==2 %assuming condensate-free
    qsscl = eval_q(esscl,p);
  else %given qt (suitable for plume computations)
    qsscl = eval_q(esscl,p,qt);
  end