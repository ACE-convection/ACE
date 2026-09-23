function theta_l = eval_theta_l(T, q, ql, p)
%{
  Calculate liquid water potential temperature.

  Units: K.

  Args:
    T (double): air temperature in K.
    q (double): specific humidity of water vapor in kg/kg.
    ql (double): specific liquid water content in kg/kg.
    p (double): air pressure in Pa.
    RD (constant): gas constant of dry air in J/Kg/K.
    RV (constant): gas constant of water vapor in J/Kg/K.
    CPD (constant): heat capacity at constant pressure for dry air in J/Kg/K.
    CPV (constant): heat capacity at constant pressure for water vapor in J/Kg/K.
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.
    P0 (constant): reference pressure (1,000 hPa) in Pa.

  Returns:
    double: liquid water potential temperature following Eq. (2.44) in Stevens & Siebesma (2020)
              which is equivalent to Eq. (4.5.15) in Emanuel (1994)
%}
  LV = lv(T);
  
  qt = q + ql;
  
  RL = 287.04*( 1 + 0.607789855072462*qt );
  R = (1-qt)*287.04 + q*461.5;
  
  CPL = 1005.7 + qt*3184.3;
  
  chi = RL./CPL;
  gamma = 461.5*qt ./ CPL;
  
  theta_l = T .* (1e5*R./p./RL).^chi ...
              .* (qt./q).^gamma ...
              .* exp( -LV.*ql./CPL./T );
