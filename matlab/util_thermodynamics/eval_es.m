function es = eval_es(T)
%{
  Calculate saturation vapor pressure with respect to liquid water.

  Units: Pa.

  Args:
    T (double): air temperature in K.

  Returns:
    double: saturation vapor pressure of water (liquid) using Eq. (4.4.13) in Emanual (1994) 
            Error within 0.006% in 0<=T<=40-deg-C; 
                           0.3% for -30-deg-C<=T;
                           0.7% for -40-deg-C<=T.
%}
es = 1e2 * exp( 53.67957 - 6743.769./T - 4.8451*log(T) );
% d(es)/dT = (6743.769./T-4.8451).*es./T
    
%% Below are using 2 formulae for different temperature ranges (separated by -80-deg-C).
%   For T>-80-deg-C, the difference between the 2 formulae is within 0.5%.
%   Tc = T-273.15;
% 
%   es = eval_es_bolton(T);
%   
%   es(Tc>=-80) = 0.6105851e+03 + Tc(Tc>=-80) .*( ...
%                 0.4440316e+02 + Tc(Tc>=-80) .*( ...
%                 0.1430341e+01 + Tc(Tc>=-80) .*( ... 
%                 0.2641412e-01 + Tc(Tc>=-80) .*( ... 
%                 0.2995057e-03 + Tc(Tc>=-80) .*( ... 
%                 0.2031998e-05 + Tc(Tc>=-80) .*( ...
%                 0.6936113e-08 + Tc(Tc>=-80) .*( ...
%                 0.2564861e-11 - Tc(Tc>=-80) .* 0.3704404e-13)))))));