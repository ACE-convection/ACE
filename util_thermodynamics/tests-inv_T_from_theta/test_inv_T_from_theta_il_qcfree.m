% Test inverting T from theta_il assuming condensate-free
IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

%% Condensate-free examples
N = 1000;
p = 100e2 + 900e2*rand(N,1);
T = 200 + 100*rand(N,1);
qs = eval_qs(T,p);
qsi = eval_qsi(T,p);
qs(T<T0) = qsi(T<T0); clear qsi
q = rand(N,1).*qs;
ql = 0;
qi = 0;
qt = q + ql + qi;
theta_il = eval_theta_il(T,q,ql,qi,p);

CPL = CPD + (CPV-CPD)*qt;
RL = RD*(1-qt) + RV*qt;
% R = RD*(1-qt) + RV*q;
chi = RL./CPL;

PI = (p/P0).^chi; % RL=R for condensate-free
Tsol = theta_il.*PI;
qsol = qt;

figure;
semilogy(T,abs(T-Tsol),'x')
grid on
box on
title(['Condensate-free consistency: ' num2str(sum(qt<=qs)) '/' num2str(N)])
xlabel('T (T)')
ylabel('T-T_{sol} (K)')

%% Condensate-free solutions in the presence of condensate
N = 1000;
p = 100e2 + 900e2*rand(N,1);
T = 200 + 100*rand(N,1);
qs = eval_qs(T,p);
qsi = eval_qsi(T,p);
qs(T<T0) = qsi(T<T0); clear qsi
q = (1+rand(N,1)).*qs;
ql = (q-qs).*(T>=T0);
qi = (q-qs).*(T<T0);
qt = q + ql + qi;
theta_il = eval_theta_il(T,q,ql,qi,p);

CPL = CPD + (CPV-CPD)*qt;
RL = RD*(1-qt) + RV*qt;
% R = RD*(1-qt) + RV*q;
chi = RL./CPL;

PI = (p/P0).^chi;
Tsol = theta_il.*PI;
qsol = qt;

figure;
loglog(qt-q,T-Tsol,'x')
grid on
box on
title({'Consistency violated by supersaturation:';...
       ['q_t>q_s(T_{sol}): ' num2str(sum(qt>qs)) '/' num2str(N)]})
xlabel('q_c (kg/kg)')
ylabel('T-T_{sol} (K)')