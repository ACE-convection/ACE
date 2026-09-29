% Test inverting T from theta_il assuming ice-free but with liquid
IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

ABS_TOL = 1e-3;
%% With-liquid-but-no-ice (ql>0,qi=0) examples
% N = 10000;
% p = 100e2 + 900e2*rand(N,1);
% T = T0 + 30*rand(N,1);
% qs = eval_qs(T,p);
% qt = (1+rand(N,1)).*qs;
% q = eval_qs(T,p,qt); %<--update qs given qt
% ql = qt-q;
% theta_e = eval_theta_e(T,q,ql,0,p);
% Ttrue = T;
% qtrue = q;
% qltrue = ql;

%% Liquid-only solutions for ice-only cases
%% ==> T<T0; theta_e values inconsistent (but could be reasonably consistent).
N = 1000000;
p = 100e2 + 900e2*rand(N,1);
T = T0 - 80*rand(N,1);
qsi = eval_qsi(T,p);
qt = (1+rand(N,1)).*qsi;
q = eval_qsi(T,p,qt); %<--update qs given qt
ql = (qt-q).*(T>=T0);
qi = (qt-q).*(T<T0);
theta_e = eval_theta_e(T,q,ql,qi,p);
Ttrue = T;
qtrue = q;
qltrue = ql;
qitrue = qi;

%%
CPL = CPD + (CL-CPD)*qt;
RE = RD*(1-qt);
chi = RE./CPL;

% Solve G(T)-G0=0; G'(T)>0 & G"(T)>0.
G0 = theta_e .* (p.*RE/P0).^chi;
% Set inital T
LOG = log(p.*qt) - log(610.78*EPS);
T = 237.3*LOG./(17.27-LOG) + 273.15;

dT = 9999;
while max(abs(dT))>ABS_TOL
  disp('iteration')
  qs = eval_qs(T,p,qt);
  R = RE + RV*qs;
  G = T .* R.^chi .* exp(qs.*lv(T)./CPL./T);
  dGdT = 1./T + ( (RV*RE./R+lv(T)./T).*eval_dTqs(T,p,qt) - (LV0-CPVMCL*273.15).*qs./T.^2 )./CPL;
  dGdT = dGdT.*G;
  dT = -(G-G0)./dGdT;
  T = T + dT;
end%convergence
disp(['dT~' num2str(max(abs(dT)))])
q = eval_qs(T,p,qt);
ql = (qt-q).*(T>=T0);
qi = (qt-q).*(T<T0);

disp([num2str(sum(T<T0)) '/' num2str(N)])
disp([num2str(sum(q<=qt)) '/' num2str(N)])
disp([num2str(sum(ql>=0)) '/' num2str(N)])
disp([num2str(sum(qi>=0)) '/' num2str(N)])

I = (T>=T0);
% I = [1:N];

figure;
subplot(2,2,1)
plot(Ttrue(I),Ttrue(I)-T(I),'.')
grid on
box on
axis square
xlabel('T (K)')
ylabel('T-T_{sol} (K)')
subplot(2,2,2)
plot(qtrue(I),qtrue(I)-q(I),'.')
grid on
box on
axis square
xlabel('q_s (kg/kg)')
ylabel('q_s-q_{s,sol} (kg/kg)')
subplot(2,2,3)
plot(qltrue(I),qltrue(I)-ql(I),'.')
grid on
box on
axis square
xlabel('q_l (kg/kg)')
ylabel('q_l-q_{l,sol} (kg/kg)')
subplot(2,2,4)
plot(theta_e(I),theta_e(I)-eval_theta_e(T(I),q(I),ql(I),qi(I),p(I)),'.')
grid on
box on
axis square
xlabel('\theta_{e} (K)')
ylabel('\theta_{e}-\theta_{e,sol} (K)')
% ylim([-1e-3 1e-3])