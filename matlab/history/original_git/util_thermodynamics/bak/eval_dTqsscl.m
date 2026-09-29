function dTqsscl = eval_dTqsscl(T,p,qt)
%{
  Calculate partial derivative of saturation specific humidity while allowing super-cooled liquid (scl).

  Units: kg/kg/T.

  Args:
    T (double): air temperature in K.
    p (double): air pressure in Pa.
    qt (double): total water mixing ratio in kg/kg.
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.

  Returns:
    double: derivative of saturation specific humidity w.r.t. T.
%}
  global EPS %RV LS
  % Saturation vapor pressure as a linear combination of liquid and ice for
  %   -40-deg-C<T<0-deg-C
  % Rel. error increases exponentially with T
  % dTqs = EPS.*p./( p-es*(1-EPS) ).^2 .* d(es)/dT
  %      = EPS.*p.*(1-qt)./(p-es).^2 .* d(es)/dT
  % d(es)/dT = (6743.769./T-4.8451).*es./T
  % d(esi)/dT = (6111.72784./T+0.15215).*esi./T
  es = eval_es(T);
  esi = eval_esi(T);
  esscl = ( (T-233.15).*es+(273.15-T).*esi )/40;
  dTesscl = ( ( (T-233.15).*(6743.769./T-4.8451).*es ...
               + (273.15-T).*(6111.72784./T+0.15215).*esi )./T ...
            + es-esi )/40;
  if nargin==2
    dTqsscl = EPS.*p./( p-esscl*(1-EPS) ).^2 .* dTesscl;
  else
    dTqsscl = EPS.*p.*(1-qt)./(p-esscl).^2 .* dTesscl;
  end
% % %   if nargin==2 %assuming condensate-free
% % %     if T>=273.15 %liquid only
% % %       es = eval_es(T);
% % %       dTqsscl = EPS.*p./( p-es*(1-EPS) ).^2 .* (6743.769./T-4.8451).*es./T;
% % %     elseif T>233.15 %with super-cooled liquid
% % %       es = eval_es(T);
% % %       esi = eval_esi(T);
% % %       esscl = ( (T-233.15).*es+(273.15-T).*esi )/40;
% % %       dTesscl = ( ( (T-233.15).*(6743.769./T-4.8451).*es ...
% % %                    + (273.15-T).*(6111.72784./T+0.15215).*esi )./T ...
% % %                 + es-esi )/40;
% % %       dTqsscl = EPS.*p./( p-esscl*(1-EPS) ).^2 .* dTesscl;
% % %     else %ice only
% % %       esi = eval_esi(T);
% % %       dTqsscl = EPS.*p./( p-esi*(1-EPS) ).^2 .* (6111.72784./T+0.15215).*esi./T;
% % %     end
% % %  	else %given qt (suitable for plume computations)
% % %     if T>=273.15 %liquid only
% % %       es = eval_es(T);
% % %       dTqsscl = EPS.*p.*(1-qt)./(p-es).^2 .* (6743.769./T-4.8451).*es./T;
% % %     elseif T>233.15 %with super-cooled liquid
% % %       es = eval_es(T);
% % %       esi = eval_esi(T);
% % %       esscl = ( (T-233.15).*es+(273.15-T).*esi )/40;
% % %       dTesscl = ( ( (T-233.15).*(6743.769./T-4.8451).*es ...
% % %                    + (273.15-T).*(6111.72784./T+0.15215).*esi )./T ...
% % %                 + es-esi )/40;
% % %       dTqsscl = EPS.*p.*(1-qt)./(p-esscl).^2 .* dTesscl;
% % %     else %ice only
% % %       esi = eval_esi(T);
% % %       dTqsscl = EPS.*p.*(1-qt)./(p-esi).^2 .* (6111.72784./T+0.15215).*esi./T;
% % %     end
% % %   end