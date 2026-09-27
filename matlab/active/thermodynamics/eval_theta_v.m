function theta_v = eval_theta_v(T, q, ql, p)
%{                 
  Calculate virtual potential temperature.

  Units: K.

  Args:
    T (double): air temperature in K.
    q (double): specific humidity of water vapor in kg/kg.
    ql (double): specific liquid water content in kg/kg.
    p (double): air pressure in Pa.
    RD (constant): gas constant of dry air in J/Kg/K.
    CPD (constant): heat capacity at constant pressure for dry air in J/Kg/K.
    P0 (constant): reference pressure (1,000 hPa) in Pa.

  Returns:
    double: virtual potential temperature following Eq. (4.3.2) in Emanuel (1994).
%}
  theta_v = eval_Tv(T, q, ql) .* (1e5/p).^0.285413145073083;