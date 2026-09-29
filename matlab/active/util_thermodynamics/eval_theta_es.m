function theta_es = eval_theta_es(T, p)
%{
  Calculate saturation equivalent potential temperature.

  Units: K.

  Following Eq. (2.67) in Stevens & Siebesma (2020)
   which, with ice correction, is equivalent to Eq. (4.5.11) in Emanuel (1994).

  Args:
    T (double): air temperature in K.
    p (double): air pressure in Pa.
    RD (constant): gas constant of dry air in J/Kg/K.
    RV (constant): gas constant of water vapor in J/Kg/K.
    CPD (constant): heat capacity at constant pressure for dry air in J/Kg/K.
    CL (constant): heat capacity of liquid water (above freezing) in J/Kg/K.
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.
    P0 (constant): reference pressure (1,000 hPa) in Pa.

  Returns:
    double: equivalent potential temperature.
	%}

    T0 = 273.1636783445389; % Triple point = freezing point; for water-ice saturation consistency
    LV = lv(T);
    
    q = eval_qsat(T,p);
    qt = q;
    e = p.*q./( q+0.621971830985916*(1-qt) );
    es = eval_es(T).*(T>=T0)+eval_esi(T).*(T<T0);
    
    RE = (1-qt)*287.04;
    R = RE + q*461.5;
    
    CPL = 1005.7 + qt*3184.3;
    
    chi = RE./CPL;
    gamma = 461.5*q ./ CPL;
    
    theta_es = T .* (1e5*R./p./RE).^chi ...
                .* (es./e).^gamma ...
                .* exp( (q.*LV./T)./CPL );  