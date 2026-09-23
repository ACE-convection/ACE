% Test inverting T from theta_e assuming ice-liquid coexisting
IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

%% Coexisting
% N = 10000;
% p = 100e2 + 900e2*rand(N,1);
% T = T0;
% qs = eval_qs(T,p);
% qsi = eval_qsi(T,p);
% RN = rand(N,1);
% qs = qs + RN.*(qsi-qs);
% qt = (1+rand(N,1)).*qs;
% qs = (1-RN).*eval_qs(T,p,qt)+RN.*eval_qsi(T,p,qt); %<--Evaluate q given qt
% ql = (qt-qs).*rand(N,1);
% qi = qt-qs-ql;
% theta_e = eval_theta_e(T,qs,ql,qi,p);
% Ttrue = T;
% qstrue = qs;
% qltrue = ql;
% qitrue = qi;

%% Ice-free at T0
% N = 10000;
% p = 100e2 + 900e2*rand(N,1);
% T = T0;
% qs = eval_qs(T,p);
% qsi = eval_qsi(T,p);
% RN = rand(N,1);
% qs = qs + RN.*(qsi-qs);
% qt = (1+rand(N,1)).*qs;
% qs = (1-RN).*eval_qs(T,p,qt)+RN.*eval_qsi(T,p,qt); %<--Evaluate q given qt
% ql = qt-qs;
% qi = 0;
% theta_e = eval_theta_e(T,qs,ql,qi,p);
% Ttrue = T;
% qstrue = qs;
% qltrue = ql;
% qitrue = qi;

%% Liquid-free at T0
% N = 10000;
% p = 100e2 + 900e2*rand(N,1);
% T = T0;
% qs = eval_qs(T,p);
% qsi = eval_qsi(T,p);
% RN = rand(N,1);
% qs = qs + RN.*(qsi-qs);
% qt = (1+rand(N,1)).*qs;
% qs = (1-RN).*eval_qs(T,p,qt)+RN.*eval_qsi(T,p,qt); %<--Evaluate q given qt
% ql = 0;
% qi = qt-qs;
% theta_e = eval_theta_e(T,qs,ql,qi,p);
% Ttrue = T;
% qstrue = qs;
% qltrue = ql;
% qitrue = qi;

%% Co-existing solutions for qc-free cases
%% ==> qi=0; ql>=0; theta_e values inconsistent (error>5e-3)
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = 200 + 100*rand(N,1);
qs = eval_qs(T,p);
qsi = eval_qsi(T,p);
qs(T<T0) = qsi(T<T0);
qt = qs.*rand(N,1);
ql = 0;
qi = 0;
q = qt;
theta_e = eval_theta_e(T,q,ql,qi,p);
Ttrue = T;
qtrue = qt;
qltrue = ql;
qitrue = qi;

CPL = CPD + (CL-CPD)*qt;
RE = RD*(1-qt);
chi = RE./CPL;

T = T0;
q = 0.5*( eval_qs(T,p,qt)+eval_qsi(T,p,qt) ); %<--Mid-value for T=T0
R = RE + RV*q;
PI = (p.*RE./R/P0).^chi;
% Just find out the partition (ql,qi) s.t. ql+qi=qt-qs
qc = qt-q;
qi = ( lv(T0)*q - T0*CPL.*log(theta_e.*PI/T0) )/LF;
ql = qc-qi;
% In case qc<0 (~0.0005%; magnitude<1e-6)
q(qc<0) = qt(qc<0);
ql(qc<0) = 0;
qi(qc<0) = 0;
qc(qc<0) = 0;
% Make sure ql & qi non-negative
qi(ql<0) = qc(ql<0);
ql(ql<0) = 0;
ql(qi<0) = qc(qi<0);
qi(qi<0) = 0;

disp([num2str(sum(qc>=0)) '/' num2str(N)])
disp([num2str(sum(q<=qt)) '/' num2str(N)])
disp([num2str(sum(qi>=0)) '/' num2str(N)])
disp([num2str(sum(ql>=0)) '/' num2str(N)])

figure
subplot(1,3,1)
plot(qltrue,qltrue-ql,'.')
grid on
box on
axis square
xlabel('q_l (kg/kg)')
ylabel('q_l-q_{l,sol} (kg/kg)')
subplot(1,3,2)
plot(qitrue,qitrue-qi,'.')
grid on
box on
axis square
xlabel('q_i (kg/kg)')
ylabel('q_i-q_{i,sol} (kg/kg)')
subplot(1,3,3)
plot(theta_e,theta_e-eval_theta_e(T0,q,ql,qi,p),'.')
grid on
box on
axis square
xlabel('\theta_e (K)')
ylabel('\Delta\theta_e (K)')