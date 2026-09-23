function h = eval_h(T,qt,qv,qi)
%{
  Calculate moist enthalpy.

  Units: K.

  Following Eq. (2.61) in Stevens & Siebesma (2020)
   but without phi (i.e., h + geopotential = moist static energy)

  Args:
    T (double): air temperature in K.
    qt (double): specific total water content in kg/kg.
    qv (double): specific humidity of water vapor in kg/kg.
    qi (double): specific liquid water content in kg/kg.
    CPD (constant): heat capacity at constant pressure for dry air in J/Kg/K.
    CL (constant): heat capacity of liquid water (above freezing) in J/Kg/K.
    LF (constant): latent heat of fusion at 0-deg-C in J/Kg/K

  Returns:
    double: moist enthalpy.
	%}
global CPD CL LF

T0 = 273.15; % Units: K

CPL = (1-qt)*CPD + qt*CL;
h = CPL.*(T-T0) + qv.*lv(T) - qi*LF;