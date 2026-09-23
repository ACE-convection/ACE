function dTes = eval_dTes(T)
%{
  Calculate partial derivative of (liquid) saturation vapor pressure with respect to temperature.

  Units: kg/kg/T.

  Args:
    T (double): air temperature in K.
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.

  Returns:
    double: derivative of saturation vapor pressure w.r.t. T.
%}
  es = eval_es(T);
  % With es from Eq. (4.4.13) in Emanual (1994)
  %   accurate within <1e-3 rel. error for 0<=T<=20-deg-C
  %   <1.4e-3 up to T<=40-deg-C
  % Rel. error increases exponentially with T
  dTes = (6743.769./T-4.8451).*es./T;