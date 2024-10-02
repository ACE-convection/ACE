function Tv = eval_Tv(T, q, qc)
%{
  Calculate virtual temperature (actually, density temperature).

  Units: K.

  Vapor and condensed phase of water are included in the calculation.

  Args:
    T (double): air temperature in K.
    q (double): specific humidity of water vapor in kg/kg.
    qc (double): specific liquid and ice water content in kg/kg.
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.

  Returns:
    double: density temperature following Eq. (4.3.6) in Emanuel (1994).
%}
  if nargin==2
    qc = 0;
  end
  
  Tv = T .* (1 + 0.607789855072462*q - qc);
