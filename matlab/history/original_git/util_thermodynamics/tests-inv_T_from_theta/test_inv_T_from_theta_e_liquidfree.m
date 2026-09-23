% Test inverting T from theta_il assuming liquid-free but with ice
IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

ABS_TOL = 1e-3;
%% With-ice-but-no-liquid (ql=0,qi>0) examples
% N = 10000;
% p = 100e2 + 900e2*rand(N,1);
% T = T0 - 70*rand(N,1);
% qsi = eval_qsi(T,p);
% qt = (1+rand(N,1)).*qsi;
% qsi = eval_qsi(T,p,qt);
% qi = qt-qsi;
% theta_e = eval_theta_e(T,qsi,0,qi,p);
% Ttrue = T;
% qtrue = qsi;
% qitrue = qi;
% qltrue = zeros(N,1);

%% Ice-only solutions for liquid-only cases
N = 1000000;
p = 100e2 + 900e2*rand(N,1);
T = T0 + 30*rand(N,1);
qs = eval_qs(T,p);
qt = (1+rand(N,1)).*qs;
q = eval_qs(T,p,qt); %<--update qs given qt
ql = qt-q;
theta_e = eval_theta_e(T,q,ql,0,p);
Ttrue = T;
qtrue = q;
qltrue = ql;
qitrue = zeros(N,1);

%%
CPL = CPD + (CL-CPD)*qt;
RE = RD*(1-qt);
chi = RE./CPL;

% Solve H(T)-H0=0; H'(T)>0 & H"(T)>0.
H0 = theta_e .* (p.*RE/P0).^chi; % H0=G0
% Set initial T for ice
LOG = log(p.*qt) - log(610.78*EPS);
T = 265.5*LOG./(21.875-LOG) + 273.16;
% dC = CL-ci(T0)
dC = CL-ci(T0);

dT = 9999;
while max(abs(dT))>ABS_TOL
  disp('iteration')
  qsi = eval_qsi(T,p,qt);
  qi = qt-qsi;
  dTqsi = eval_dTqsi(T,p,qt);
  LV = lv(T);
  R = RE + RV*qsi;
  H = T .* R.^chi .* (T0./T).^(dC*qi./CPL) ...
        .* exp((qsi.*LV./T - LF/T0*qi)./CPL);
  dHdT = 1./T + ( ( RV*RE./R + LV./T + dC*log(T/T0) + LF/T0 ).*dTqsi ...
                 - ( ((LV0-CPVMCL*273.15)./T-dC).*qsi + dC*qt )./T )./CPL;
  dHdT = dHdT.*H;
  dT = -(H-H0)./dHdT;
  T = T + dT;
end%convergence
disp(['dT~' num2str(max(abs(dT)))])
q = eval_qsi(T,p,qt);
ql = (qt-q).*(T>=T0);
qi = (qt-q).*(T<T0);

disp([num2str(sum(q<=qt)) '/' num2str(N)])
disp([num2str(sum(ql>=0)) '/' num2str(N)])
disp([num2str(sum(qi>=0)) '/' num2str(N)])

I = (T<T0);
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