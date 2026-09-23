% Test inverting T from theta_il assuming ice-liquid coexisting
IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

%% Coexisting
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = T0;
qs = eval_qs(T,p);
qt = (1+rand(N,1)).*qs;
qs = eval_qs(T,p,qt);
ql = (qt-qs).*rand(N,1);
qi = qt-qs-ql;
theta_il = eval_theta_il(T,qs,ql,qi,p);
Ttrue = T;
qstrue = qs;
qltrue = ql;
qitrue = qi;

CPL = CPD + (CPV-CPD)*qt;
RL = RD*(1-qt) + RV*qt;
% R = RD*(1-qt) + RV*qs;
chi = RL./CPL;

PI = (p./P0).^chi;
gamma = qt.*RV./CPL;

G0 = theta_il .* PI .* RL.^chi ./ qt.^gamma; % G0=theta_il/c1

T = T0;
q = eval_qs(T0,p,qt);
R = RD*(1-qt) + RV*q;
% Just find out the partition (ql,qi) s.t. ql+qi=qt-qs
qc = qt-q;
ql = ( LS*qc - CPL.*T.*log((T0./G0) ./ q.^gamma .* R.^chi) )./(LS-lv(T0));
qi = qc-ql;

disp([num2str(sum(ql>=0 & qi>=0)) '/' num2str(N)])

figure
subplot(1,2,1)
plot(qltrue,qltrue-ql,'.')
grid on
box on
axis square
xlabel('q_l (kg/kg)')
ylabel('q_l-q_{l,sol} (kg/kg)')
subplot(1,2,2)
plot(qitrue,qitrue-qi,'.')
grid on
box on
axis square
xlabel('q_i (kg/kg)')
ylabel('q_i-q_{i,sol} (kg/kg)')

%% Ice-free at T=T0
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = T0;
qs = eval_qs(T,p);
qt = (1+rand(N,1)).*qs;
qs = eval_qs(T,p,qt);
ql = qt-qs;
qi = 0;
theta_il = eval_theta_il(T,qs,ql,qi,p);
Ttrue = T;
qstrue = qs;
qltrue = ql;
qitrue = qi;

CPL = CPD + (CPV-CPD)*qt;
RL = RD*(1-qt) + RV*qt;
% R = RD*(1-qt) + RV*qs;
chi = RL./CPL;

PI = (p./P0).^chi;
gamma = qt.*RV./CPL;

G0 = theta_il .* PI .* RL.^chi ./ qt.^gamma; % G0=theta_il/c1

T = T0;
q = eval_qs(T0,p,qt);
R = RD*(1-qt) + RV*q;
% Just find out the partition (ql,qi) s.t. ql+qi=qt-qs
qc = qt-q;
ql = ( LS*qc - CPL.*T.*log((T0./G0) ./ q.^gamma .* R.^chi) )./(LS-lv(T0));
qi = qc-ql;

disp([num2str(sum(ql>=0)) '/' num2str(N)])
disp([num2str(sum(qi>=0)) '/' num2str(N)])

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
plot(qi(qi<0),'.')
grid on
box on
axis square
ylabel('q_i (kg/kg)')

%% Liquid-free at T=T0
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = T0;
qs = eval_qs(T,p);
qt = (1+rand(N,1)).*qs;
qs = eval_qs(T,p,qt);
qi = qt-qs;
ql = 0;
theta_il = eval_theta_il(T,qs,ql,qi,p);
Ttrue = T;
qstrue = qs;
qltrue = ql;
qitrue = qi;

CPL = CPD + (CPV-CPD)*qt;
RL = RD*(1-qt) + RV*qt;
% R = RD*(1-qt) + RV*qs;
chi = RL./CPL;

PI = (p./P0).^chi;
gamma = qt.*RV./CPL;

G0 = theta_il .* PI .* RL.^chi ./ qt.^gamma; % G0=theta_il/c1

T = T0;
q = eval_qs(T0,p,qt);
R = RD*(1-qt) + RV*q;
% Just find out the partition (ql,qi) s.t. ql+qi=qt-qs
qc = qt-q;
ql = ( LS*qc - CPL.*T.*log((T0./G0) ./ q.^gamma .* R.^chi) )./(LS-lv(T0));
qi = qc-ql;

disp([num2str(sum(ql>=0)) '/' num2str(N)])
disp([num2str(sum(qi>=0)) '/' num2str(N)])

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
plot(ql(ql<0),'.')
grid on
box on
axis square
ylabel('q_l (kg/kg)')