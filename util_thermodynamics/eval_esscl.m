function esscl = eval_esscl(T)
%{
  Calculate saturation vapor pressure while allowing super-cooled liquid (scl).

  Units: Pa.

  Args:
    T (double): air temperature in K.

  Returns:
    double: saturation vapor pressure of water as a linear combination of 
            liquid and ice using Eqs. (4.4.13) & (4.4.15) in Emanual (1994)
            for -40-deg-C<=T<=0-deg-C; using pure liquid/ice formulae
            otherwise.
%}
% % % esscl = zeros(size(T));
% % % % Above freezing
% % % esscl(T>=273.15) = eval_es(T(T>=273.15));
% % % % With super-cooled liquid
% % % I = (T<273.15)&(T>233.15);
% % % esscl(I) = ( (T(I)-233.15).*eval_es(T(I))+(273.15-T(I)).*eval_esi(T(I)) )/40;
% % % % All ice
% % % esscl(T<=233.15) = eval_esi(T(T<=233.15));
esscl = ( (T-233.15).*eval_es(T)+(273.15-T).*eval_esi(T) )/40;