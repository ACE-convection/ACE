function [T, q, ql, qi, step] = inv_T_from_h(h, qt, p, ABS_TOL)
%{
  Invert air temperature and specific humidities, 
  given moist enthalpy, total specific water content, pressure.

  Args:
    h (double): moist enthalpy in J/kg.
    qt (double): specific total water content in kg/kg.
    p (double): air pressure in Pa.
    CPD (constant): heat capacity at constant pressure for dry air in J/Kg/K.
    CL (constant): heat capacity for liquid water in J/Kg/K.
    CPVMCL (constant): heat capacity of liquid water minus CPV.
    LF (constant): latent heat of fusion in J/Kg/K
    ABS_TOL (constant): absolute tolerance (units: K) for stopping iteration.

  Returns:
    double: air temperature.
    double: specific humidities.
    step: for debugging
%}
%% Solution steps
% 1. Try no condensate (if qs>qt or T<0 --> inconsistent --> condensate)
% 2. Preliminary determination of temperature range by comparing the given h 
%     with h at T=TI given (p,qt)
%     a) h >/< h(T=TI,qt,qsi(T=TI),qi=qt-qsi(T=TI)) implies T >/< TI
%     b) Solve assuming ice-only if T<=TI
% 3. If T>TI, try liquid-only first, then test if refined iteration is
%     required or move to super-cooled liquid case
%   3.5) If h value inconsistent or T>>T0 (e.g., T-T0>100K) --> true T may 
%        be large so that es(T)~p --> bisection approximation starting with
%        Ti satisfying es(Ti)<p
% 4. If T (from steps 3 or 3.5) < TI --> ice only
% 10. step+10 if correction for qc<0 (put in just in case; not encountered
%      during testing)

%% Goal: solve (T,q,ql,qi) given (h,p,qt)
global CPD CL LV0 CPVMCL LF

if nargin==3
  ABS_TOL = 1e-3; %<--Apply only for Newton iteration
end

T0 = 273.15; % Units: K; above which liquid only
TI = T0-40; % Units: K; below which ice only

%% Step 1: solve assuming no condensate & check consistency
% If qc>0, h would be inconsistent
CPL = (1-qt)*CPD + qt*CL;
T = T0 + (h-qt*LV0)/(CPL-qt*CPVMCL);
% % % T = T0 + h./CPL; <---WRONG BUT CAN DISTINGUISH CONDENSATE (BEFORE-3/7 VERSION)
q = qt;
ql = 0;
qi = 0;
step = 1;

% Check h consistency
% hval = eval_h(T,qt,q,qi);
if T>T0
  qs = eval_qs(T,p,qt);
elseif T>=TI
  qs = eval_qsscl(T,p,qt);
else
  qs = eval_qsi(T,p,qt);
end

if qs<q || T<=0 % Condensate exists
  %% Step 1.5: determine T>TI or T<=TI
  % Compute h at TI given (qt,p); sign(h-hTI)=sign(T-TI)
  hTI = eval_h(TI,qt,eval_qsscl(TI,p,qt),qt-eval_qsscl(TI,p,qt));
  
  if h<=hTI % T<=TI 
    %% Step 4: solve for ice only
    T = TI;
    dT = 999; 
    while abs(dT)>ABS_TOL
      qsi = eval_qsi(T,p,qt);
      dTqsi = eval_dTqsi(T,p,qt);
      qi = qt-qsi;
      hval = eval_h(T,qt,qsi,qi);
      dTh = CPL - CPVMCL*qsi + dTqsi.*( lv(T) + LF );
      dT = -(hval-h)./dTh;
      T = T+dT;
    end
    q = eval_qsi(T,p,qt); 
    ql = 0;
    qi = qt-q;
    step = 2;

  else % T>TI
    %% Step 2: solve assuming liquid only & check consistency
    T = 300;%T0;
    dT = 999;
    while abs(dT)>ABS_TOL
      qs = eval_qs(T,p,qt);
      dTqs = eval_dTqs(T,p,qt);
      hval = eval_h(T,qt,qs,0);
      dTh = CPL - CPVMCL*qs + dTqs.*lv(T);
      dT = -(hval-h)./dTh;
      T = T+dT;
    end
    q = eval_qs(T,p,qt);
    ql = qt-q;
    qi = 0;
    step = 3;

    %% Check for large-T cases (e.g., T>310K usually leads to solution T>600K)
    % Working assumption: T<T0+100K
    hval = eval_h(T,qt,q,0);
    if abs(h-hval)/CPL>ABS_TOL || T>T0+100
      % Use bisection if previous steps failed; starting with [TL,TR]
      % Find TR via es(TR)==p
      TR = T0+100;
      dTR = 999;
      while abs(dTR)>ABS_TOL
        dTR = -(eval_es(TR)-p)/eval_dTes(TR);
        TR = TR+dTR;
      end
      TR = TR-ABS_TOL;
      TL = T0;
      TLMR = [TL,(TL+TR)/2,TR]; % Left, mid, and right points for bisection
      while TLMR(3)-TLMR(1)>2 % So outcome accurate within 1K
        QSLMR = eval_qs(TLMR,p,qt);
        hLMR = eval_h(TLMR,qt,QSLMR,0);
        if (hLMR(1)-h)*(hLMR(2)-h)>=0
          TLMR(1:2) = [TLMR(2),(TLMR(2)+TLMR(3))/2];
        elseif (hLMR(2)-h)*(hLMR(3)-h)>=0
          TLMR(2:3) = [(TLMR(1)+TLMR(2))/2,TLMR(2)];
        end
      end
      % T accurate within 1K
      T = TLMR(2);
      % Now repeat Step 2 with the better initial guess
      dT = 999;
      while abs(dT)>ABS_TOL
        qs = eval_qs(T,p,qt);
        dTqs = eval_dTqs(T,p,qt);
        hval = eval_h(T,qt,qs,0);
        dTh = CPL - CPVMCL*qs + dTqs.*lv(T);
        dT = -(hval-h)./dTh;
        T = T+dT;
      end
      q = eval_qs(T,p,qt);
      ql = qt-q;
      qi = 0;
      step = 3.5;
    end%large-T

    % Check T consistency (T close to true T up to ~0.5K anyway)
    if T<T0 
      %% Step 3: solve assuming super-cooled liquid 
      dT = 999; 
      while abs(dT)>ABS_TOL
        qsscl = eval_qsscl(T,p,qt); % scl=super-cooled liquid
        dTqsscl = eval_dTqsscl(T,p,qt);
        qc = qt-qsscl;
        qi = qc*(T0-T)/(T0-TI);
        hval = eval_h(T,qt,qsscl,qi);
        dTqsi = -( (T0-T).*dTqsscl + (qt-qs) )/(T0-TI);
        dTh = CPL - CPVMCL*qsscl + dTqsscl.*lv(T) - LF*dTqsi;
        dT = -(hval-h)./dTh;
        T = T+dT;
      end
      q = eval_qsscl(T,p,qt);
      ql = (qt-q)/(T0-TI)*(T-TI);
      qi = (qt-q)/(T0-TI)*(T0-T);
      step = 4;
    end%super-cooled liquid
    
  end%sign(h-hTI)

  %% Check condensate consistency before output
  if q>qt
    q = qt;
    ql = 0;
    qi = 0;
    step = 10+step;
  end%Condenstate consistency
end%if condensate