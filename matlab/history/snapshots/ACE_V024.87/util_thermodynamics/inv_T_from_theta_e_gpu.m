% inv_T_from_theta_e_gpu -- GPU-SAFE COPY of inv_T_from_theta_e.m, used by ACE_V024GF87 when GPU = 1.
% IDENTICAL arithmetic; the ONLY changes are (a) the three fail-fast fprintf reports removed
% (fprintf is not callable inside a gpuArray arrayfun kernel) and (b) the NaN-out made scalar.
% Use:  [T,q,ql,qi] = arrayfun(@inv_T_from_theta_e_gpu, theta_e, qt, p)  on gpuArrays (util_thermodynamics/gputest_invTq.m
% is a small driver for this call). inv_T_from_theta_e.m serves the host path, so the two must be kept in step if the inversion is ever changed.
% NON-CONVERGENCE IS SILENT HERE: the host copy names the failing branch and the input range before it
% NaN-s out; on the device the NaN simply propagates and the march's nonfinite guard stops the run
% (blew_up). Re-run the failing case with GPU = 0 to get the diagnostic.
function [T, q, ql, qi] = inv_T_from_theta_e_gpu(theta_e, qt, p)%, ABS_TOL)
% function [T, q, ql, qi, bsmeter, step] = inv_T_from_theta_e(theta_e, qt, p, ABS_TOL, P0)
%{
  Invert air temperature and specific humidities, 
  given equivalent potential temperature, total specific water
  content, pressure.

  Units: K.

  Args:
    theta_e (double): equivalent potential temperature in K.
    qt (double): specific total water content in kg/kg.
    p (double): air pressure in Pa.
    RD (constant): gas constant of dry air in J/Kg/K.
    RV (constant): gas constant of water vapor in J/Kg/K.
    CPD (constant): heat capacity at constant pressure for dry air in J/Kg/K.
    CL (constant): heat capacity for liquid water in J/Kg/K.
    CPVMCL (constant): heat capacity of liquid water minus CPV.
    LS (constant): latent heat of sublimation in J/Kg/K (-100<=T<= 0-deg-C)
    LF (constant): latent heat of fusion in J/Kg/K
    LV0 (constant): latent heat of vaporization at 0-deg-C in J/Kg/K
    EPS (constant): ratio of gas constant of dry air to gas constant of water vapor.
    P0 (constant): reference pressure (1,000 hPa) in Pa.
    ABS_TOL (constant): absolute tolerance (units: K) for stopping iteration.

  Returns:
    double: air temperature.
    double: specific humidities.
    bsmeter: presence of condensate
    step: for debugging
%}
%% Goal: solve (T,q,ql,qi) given (theta_e,p,qt)
ABS_TOL = 1e-3; %<--Apply only for Newton iteration: NOT for ice-liquid coexisting

% FAIL-FAST ITERATION CAP: each Newton loop below is capped at
% INVT_MAX_ITER iterations. Legitimate convergence takes O(5-20); inputs outside the
% design envelope historically NEVER converge (the march freezes silently -- elev6K
% froze at output 20/<10/~3 across machinery generations, CPU pinned, no evidence).
% On cap exceedance: report the offending inputs once, return all-NaN outputs, and let
% the march's existing nonfinite detection declare blew_up and STOP THE INTEGRATION
% cleanly (trajectory preserved). Behavior below the cap is bit-identical to the
% certified original.
INVT_MAX_ITER = 200;

T0 = complex(273.1636783445389); % Triple-point temperature; for water-ice saturation consistency

CPL = complex(1005.7 + 3184.3*qt);
RE = complex(287.04*(1-qt));
chi = RE./CPL;

qt = complex(qt); % complex declared for GPU

%% Step 1: solve assuming no condensate & check consistency
% Solve F(T)=F0 with F',F">0: F0<F(T0) for T<T0 (same for >)
% If qc>0, theta_e would be inconsistent
R = RE + 461.5*qt; % RE+RV*q assuming q=qt (unsaturated)
gamma = 461.5*qt./CPL; % RV*q/CPL
e = p.*qt./(0.621971830985916+0.378028169014084*qt);

F0 = theta_e .* (p.*RE./R/1e5).^chi .* e.^gamma;
FT0 = T0 * 611.3902114165171.^gamma .* exp(qt./CPL*9155.566660243245); % F(T0)

% Initalize T (starting at 400K/T0 for above/belew freezing)
if F0>=FT0
  T = complex(400);
else
  T = T0;
end

dT = complex(9999); it1_ = 0;
while abs(dT)>ABS_TOL && imag(dT)==0 && ~isnan(T)
  if F0>=FT0
    F = T .* eval_es(T).^gamma .* exp(qt./CPL.*lv(T)./T);
    dFdT = (1-2320*qt./CPL)./T;
  else
    F = T .* eval_esi(T).^gamma .* exp(qt./CPL.*lv(T)./T);
    dFdT = ( 1-300708*qt./CPL./T )./T;
  end
  dFdT = dFdT.*F;
  dT = -(F-F0)./dFdT;
  T = T + dT;
  it1_ = it1_ + 1;
  if it1_ > INVT_MAX_ITER
    % fail-fast -> NaN out (silent: see the header; fprintf is illegal in an arrayfun kernel)
    T = complex(nan); q = T; ql = T; qi = T; return
  end
end%convergence
q = qt;
ql = complex(0);
qi = complex(0);
% step = 1;

% Check no-condensate consistency: if condensate, T/dT=nan/imag or qt>qs 
if T>=T0
  qsat = eval_qs(T,p,qt);
else
  qsat = eval_qsi(T,p,qt);
end
bsmeter = imag(dT)~=0 || isnan(T) || (q>qsat);

if bsmeter
  %% Step 2: determine condensate type(s) by comparing G(T0) & H(T0) to G0
  G0 = theta_e .* (p.*RE/1e5).^chi;
  
  % H(T0); H(T)=H0 for liquid-free
  dC = complex(2083.900148084866);
  qsi = eval_qsi(T0,p,qt);
  HT0 = T0 .* (RE+461.5*qsi).^chi .* exp( (qsi*2.500968266240670e+06-0.3337e6*(qt-qsi))./CPL/T0 );
         
  % G(T0); G(T)=G0 for ice-free
  qs = eval_qs(T0,p,qt);
  GT0 = T0 .* (RE+461.5*qs).^chi .* exp(qs.*9155.566660243245./CPL);
    
  % 3 cases: liquid-only, ice-only, co-existing
  if G0>GT0 && G0>HT0 % Liquid-only
    % Set inital T for liquid with Tetens: es(T)~610.78*exp(17.27*(T-273.16)/(T-35.86))
    LOG = log(p.*qt) - complex(5.939876353793538);
    T = 237.3*LOG./(17.27-LOG) + 273.15;

    % Solve G(T)-G0=0; G'(T)>0 & G"(T)>0.
    dT = complex(9999); it2_ = 0;
    while max(abs(dT))>ABS_TOL
      qs = eval_qs(T,p,qt);
      R = RE + 461.5*qs;
      LVoT = lv(T)./T;
      G = T .* R.^chi .* exp(qs.*LVoT./CPL);
      dGdT = 1./T + ( (461.5*RE./R+LVoT).*eval_dTqs(T,p,qt) - 1867292.*qs./T.^2 )./CPL;
      dGdT = dGdT.*G;
      dT = -(G-G0)./dGdT;
      T = T + dT;
      it2_ = it2_ + 1;
      if it2_ > INVT_MAX_ITER
        % fail-fast -> NaN out (silent: see the header; fprintf is illegal in an arrayfun kernel)
        T = complex(nan); q = T; ql = T; qi = T; return
      end
    end%convergence
    q = eval_qs(T,p,qt);
    ql = qt-q;
    qi = complex(0);
    if ql<0
      q = qt;
      ql = complex(0);
    end
%     step = 2; 
  
  elseif G0<GT0 && G0<HT0 % Ice-only
    % Set initial T with Tetens for ice: esi(T)~610.78*exp(21.875*(T-273.16)/(T-7.66))
    LOG = log(p.*qt) - complex(5.939876353793538);
    T = 265.5*LOG./(21.875-LOG) + 273.16;
    
    % Solve H(T)-H0=0; H'(T)>0 & H"(T)>0. Note: H0=G0.
    dT = complex(9999); it3_ = 0;
    while max(abs(dT))>ABS_TOL
      qsi = eval_qsi(T,p,qt);
      qi = qt-qsi;
      dTqsi = eval_dTqsi(T,p,qt);
      LVoT = lv(T)./T;
      R = RE + 461.5*qsi;
      H = T .* R.^chi .* (T0./T).^(dC*qi./CPL) ...
            .* exp((qsi.*LVoT - 0.3337e6/T0*qi)./CPL);
      dHdT = 1./T + ( ( 461.5*RE./R + LVoT + dC*log(T/T0) + 1221.611899584641 ).*dTqsi ...
                     - ( (1867292./T-dC).*qsi + dC*qt )./T )./CPL;
      dHdT = dHdT.*H;
      dT = -(H-G0)./dHdT;
      T = T + dT;
      it3_ = it3_ + 1;
      if it3_ > INVT_MAX_ITER
        % fail-fast -> NaN out (silent: see the header; fprintf is illegal in an arrayfun kernel)
        T = complex(nan); q = T; ql = T; qi = T; return
      end
    end%convergence
    q = eval_qsi(T,p,qt);
    ql = complex(0);
    qi = qt-q;
    if qi<0
      q = qt;
      qi = complex(0);
    end
%     step = 3; 
    
  else % Liquid-ice co-existing

    T = T0;
    q = 0.5*( eval_qs(T,p,qt)+eval_qsi(T,p,qt) ); %<--Mid-value for T=T0
    R = RE + 461.5*q;
    PI = (p.*RE./R/1e5).^chi;
    % Just find out the partition (ql,qi) s.t. ql+qi=qt-qs
    qc = qt-q;
    qi = ( lv(T0)*q - T0*CPL.*log(theta_e.*PI/T0) )/0.3337e6;
    ql = qc-qi;
    if qc<0 %if discrepancy arises from qs(T0)>qsi(T0) [because of formulae for es(T) & esi(T)]
      q = qt;
      ql = complex(0);
      qi = complex(0);   
    elseif ql<0 %if liquid-free
      ql = complex(0);
      qi = qc;
    elseif qi<0 %if ice-free
      qi = complex(0);
      ql = qc;
    end
%     step = 4;
  end%3 condensate cases
end%if condensate