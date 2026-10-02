function theta = eval_theta(T, p)
%{
  Calculate (dry) potential temperature.

  Units: K.

  Args:
    T (double): air temperature in K.
    p (double): air pressure in Pa.
    RD (constant): gas constant of dry air in J/Kg/K.
    CPD (constant): heat capacity at constant pressure for dry air in J/Kg/K.
    P0 (constant): reference pressure (1,000 hPa) in Pa.

  Returns:
    double: potential temperature.
	%}
  theta = T .* (1e5./p).^0.285413145073083;