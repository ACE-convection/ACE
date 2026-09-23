% Test inverting T from theta_e assuming qc-free
IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

ABS_TOL = 1e-1;
%% Qc-free
%% ==> Unsaturated: qt<=qs
%% ==> Saturated but qc-free: qt<=qs+1e-9 (qt<=qs for ~36%); set qc=qt-qs (if qt>qs) would be fine.
% N = 1000000;
% p = 100e2 + 900e2*rand(N,1);
% T = 200 + 100*rand(N,1);
% qs = eval_qs(T,p);
% qsi = eval_qsi(T,p);
% qs(T<T0) = qsi(T<T0);
% qt = qs;%.*rand(N,1);
% ql = 0;
% qi = 0;
% q = qt;
% theta_e = eval_theta_e(T,q,ql,qi,p);
% Ttrue = T;
% qtrue = qt;
% qltrue = ql;
% qitrue = qi;

%% Condensate-free solutions in the presence of condensate
%% ==> Almost all with F0<F(T0) s.t. inital T=T0.
%% ==> Converges but theta_e value inconsistent; ~3% with Im(dT)=nan.
% N = 10000;
% p = 100e2 + 900e2*rand(N,1);
% T = 200 + 100*rand(N,1);%T0 - 100*rand(N,1);
% qs = eval_qs(T,p);
% qsi = eval_qsi(T,p);
% qs(T<T0) = qsi(T<T0);
% qt = (1+rand(N,1)).*qs;
% qs = eval_qs(T,p,qt);
% qsi = eval_qsi(T,p,qt);
% qs(T<T0) = qsi(T<T0); clear qsi
% ql = (qt-qs).*(T>=T0);
% qi = (qt-qs).*(T<T0);
% q = qs;
% theta_e = eval_theta_il(T,q,ql,qi,p);
% Ttrue = T;
% qtrue = qs;
% qltrue = ql;
% qitrue = qi;

%% Condensate-free solutions in the presence of liquid
N = 1000;
p = 100e2 + 900e2*rand(N,1);
T = 200 + 100*rand(N,1);
qs = eval_qs(T,p);
qsi = eval_qsi(T,p);
qs(T<T0) = qsi(T<T0);
qt = (1+rand(N,1)).*qs;
qs = eval_qs(T,p,qt);
qsi = eval_qsi(T,p,qt);
qs(T<T0) = qsi(T<T0); clear qsi
ql = (qt-qs).*(T>=T0);
qi = (qt-qs).*(T<T0);
q = qs;
theta_e = eval_theta_il(T,q,ql,qi,p);
Ttrue = T;
qtrue = qs;
qltrue = ql;
qitrue = qi;

%%
CPL = CPD + (CL-CPD)*qt;
RE = RD*(1-qt);
chi = RE./CPL;

% Assuming q=qt (unsaturated)
R = RE + RV*q; %RE+RV*q
gamma = RV*q./CPL; %RV*q/CPL
e = p.*q./(EPS+(1-EPS)*qt); %e<=es(esi) if condensate-free

% Solve F(T)-F0=0; F'(T)>0 & F"(T)>0.
F0 = theta_e .* (p.*RE./R/P0).^chi .* e.^gamma;
% F0>=F(T0): T>=T0; F0<F(T0): T<T0.
FT0 = T0 * eval_es(T0).^gamma .* exp(qt./CPL*lv(T0)/T0); %F(T0)
% Set inital T
T = 400*ones(N,1);
T(F0<FT0) = T0;

dT = 9999;
while max(abs(dT))>ABS_TOL
  disp('iteration')
  F = T .* eval_es(T).^gamma .* exp(qt./CPL.*lv(T)./T);
  F(F0<FT0) = T(F0<FT0) .* eval_esi(T(F0<FT0)).^gamma(F0<FT0) ... 
                        .* exp(qt(F0<FT0)./CPL(F0<FT0).*lv(T(F0<FT0))./T(F0<FT0));
  dFdT = (1-CPVMCL*qt./CPL)./T;
  dFdT(F0<FT0) = ( 1+(LS-LV0-CPVMCL*273.15)*qt(F0<FT0)./CPL(F0<FT0)./T(F0<FT0) )./T(F0<FT0);
  dFdT = dFdT.*F;
  dT = -(F-F0)./dFdT;
  T = T + dT;
end%convergence

dtheta_e = theta_e - eval_theta_e(T,qt,0,0,p);
disp(['MAX ERROR: ' num2str(max(abs(dtheta_e))) ' K'])

% es = eval_es(T);
% es(T<T0) = eval_esi(T(T<T0));
qs = eval_qs(T,p);
qs(T<T0) = eval_qsi(T(T<T0),p(T<T0));
% disp(['Consistency: ' num2str(sum(qt<=(qs+1e-9))) '/' num2str(N)])
disp(['Consistency: ' num2str(sum(qt<=(qs))) '/' num2str(N)])
dtheta_e_c = theta_e - eval_theta_e(T,qs,(qt-qs).*(qt>qs).*(T>=T0),(qt-qs).*(qt>qs).*(T<T0),p);
disp(['MAX ERROR: ' num2str(max(abs(dtheta_e))) ' K'])

% figure
% subplot(1,3,1)
% plot(theta_e,dtheta_e,'.')
% xlabel('\theta_e (K)')
% ylabel('\Delta\theta_e (K)')
% grid on
% box on
% subplot(1,3,2)
% plot(Ttrue(Ttrue>=T0),T(Ttrue>=T0)-Ttrue(Ttrue>=T0),'.',...
%      Ttrue(Ttrue<T0),T(Ttrue<T0)-Ttrue(Ttrue<T0),'r.')
% xlabel('T (K)')
% ylabel('\Delta T (K)')
% grid on
% box on
% subplot(1,3,3)
% plot(Ttrue(qs>=qt),1e3*(qs(qs>=qt)-qt(qs>=qt)),'.',...
%      Ttrue(qs<qt),1e3*(qs(qs<qt)-qt(qs<qt)),'r.')
% xlabel('T (K)')
% ylabel('Subsaturation (g/kg)')
% grid on
% box on