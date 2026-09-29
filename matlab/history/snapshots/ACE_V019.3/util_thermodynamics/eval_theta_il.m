function theta_il = eval_theta_il(T, q, ql, qi, p)
%{ 
  Units: K.

  This is the CONSERVED variable in the entraining plume calculation.

  Following Eq. (2.44) in Stevens & Siebesma (2020)
    which, with ice correction, is equivalent to Eq. (4.5.15) in Emanuel (1994)

  Args:
    T (double): air temperature in K.
    q (double): specific humidity of water vapor in kg/kg.
    ql (double): specific liquid water content in kg/kg.
    qi (double): specific ice content in kg/kg.
    p (double): air pressure in Pa.
    RD (constant): gas constant of dry air in J/Kg/K.
    RV (constant): gas constant of water vapor in J/Kg/K.
    CPD (constant): heat capacity at constant pressure for dry air in J/Kg/K.
    CPV (constant): heat capacity at constant pressure for water vapor in J/Kg/K.
    LS (constant): latent heat of sublimation in J/Kg/K (-100<=T<= 0-deg-C)
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.
    P0 (constant): reference pressure (1,000 hPa) in Pa.

  Returns:
    double: ice-liquid water equivalent potential temperature.
%}
  LV = lv(T);
  
  qt = q + ql + qi;
  
  RL = 287.04*( 1 + (1-0.621971830985916)/0.621971830985916*qt );
  R = (1-qt)*287.04 + q*461.5;
  
  CPL = 1005.7 + qt*3184.3;
  
  chi = RL./CPL;
  gamma = 461.5*qt ./ CPL;
  
  theta_il = T .* (1e5*R./p./RL).^chi ...
               .* (qt./q).^gamma ...
               .* exp( -( LV.*ql + 2.834e6*qi  )./CPL./T );