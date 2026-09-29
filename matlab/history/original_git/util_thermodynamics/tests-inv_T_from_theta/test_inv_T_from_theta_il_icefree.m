% Test inverting T from theta_il assuming ice-free but with liquid
IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

%% With-liquid-but-no-ice (ql>0,qi=0) examples
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = 200 + 100*rand(N,1);
qs = eval_qs(T,p);
qt = (1+rand(N,1)).*qs;
qs = eval_qs(T,p,qt); %<--update qs given qt
ql = qt-qs;
theta_il = eval_theta_il(T,qs,ql,0,p);
Ttrue = T;
qstrue = qs;
qltrue = ql;

CPL = CPD + (CPV-CPD)*qt;
RL = RD*(1-qt) + RV*qt;
% R = RD*(1-qt) + RV*qs;
chi = RL./CPL;

PI = (p./P0).^chi;
gamma = qt.*RV./CPL;

% Try to solve G(T)-G0 = 0
G0 = theta_il .* PI .* RL.^chi ./ qt.^gamma; % G0=theta_il/c1

% Initial guess for T has to be from the right given G(T)~exponential
% T = 243.04*LOG./(17.625-LOG) + 273.15;
LOG = log(p.*qt) - log(610.78*EPS);
T = 237.3*LOG./(17.27-LOG) + 273.15;

dT = 9999;
while max(abs(dT))>1e-1
  disp(['iteration: dT~' num2str(max(abs(dT)))])
  qs = eval_qs(T,p,qt);
  dTqs = eval_dTqs(T,p,qt);
  ql = qt-qs;
  LV = lv(T);
  R = RD*(1-qt) + RV*qs;
  EXP = exp(-ql.*LV./CPL./T);
  dGdT = EXP .* R.^chi ./ CPL ./ qs.^gamma ...
             .*( dTqs.*( LV + RV*(RL./R - qt./qs).*T ) + CPL + ql.*(LV./T+CPVMCL) );
  G = T./qs.^gamma .* EXP .* R.^chi - G0;
  % Newton: T(n+1) = T(n) - G(Tn)/G'(Tn)
  dT = - G./dGdT;
  T = T + dT;
end%convergence
disp(['dT~' num2str(max(abs(dT)))])
q = eval_qs(T,p,qt);
ql = qt-q;

figure;
subplot(2,2,1)
plot(Ttrue,Ttrue-T,'.')
grid on
box on
axis square
xlabel('T (K)')
ylabel('T-T_{sol} (K)')
subplot(2,2,2)
plot(qstrue,qstrue-q,'.')
grid on
box on
axis square
xlabel('q_s (kg/kg)')
ylabel('q_s-q_{s,sol} (kg/kg)')
subplot(2,2,3)
plot(qltrue,qltrue-ql,'.')
grid on
box on
axis square
xlabel('q_l (kg/kg)')
ylabel('q_l-q_{l,sol} (kg/kg)')
subplot(2,2,4)
plot(theta_il,theta_il-eval_theta_il(T,q,ql,0,p),'.')
grid on
box on
axis square
xlabel('\theta_{il} (K)')
ylabel('\theta_{il}-\theta_{il,sol} (K)')

%% Ice-free solution in the presence of ice (liquid-free)
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = T0 - 70*rand(N,1);
qs = eval_qsi(T,p);
qt = (1+rand(N,1)).*qs;
qs = eval_qsi(T,p,qt);
qi = qt-qs;
theta_il = eval_theta_il(T,qs,0,qi,p);
Ttrue = T;
qstrue = qs;
qctrue = qi;

CPL = CPD + (CPV-CPD)*qt;
RL = RD*(1-qt) + RV*qt;
% R = RD*(1-qt) + RV*qs;
chi = RL./CPL;

PI = (p/P0).^chi;
gamma = qt.*RV./CPL;

% Try to solve G(T)-G0 = 0
G0 = theta_il .* PI .* RL.^chi ./ qt.^gamma; % G0=theta_il/c1

% Initial guess for T has to be from the right given G(T)~exponential
% T = 243.04*LOG./(17.625-LOG) + 273.15;
LOG = log(p.*qt) - log(610.78*EPS);
T = 237.3*LOG./(17.27-LOG) + 273.15;

dT = 9999;
while max(abs(dT))>1e-1
  disp(['iteration: dT~' num2str(max(abs(dT)))])
  qs = eval_qs(T,p,qt);
  dTqs = eval_dTqs(T,p,qt);
  ql = qt-qs;
  LV = lv(T);
  R = RD*(1-qt) + RV*qs;
  EXP = exp(-ql.*LV./CPL./T);
  dGdT = EXP .* R.^chi ./ CPL ./ qs.^gamma ...
             .*( dTqs.*( LV + RV*(RL./R - qt./qs).*T ) + CPL + ql.*(LV./T+CPVMCL) );
  G = T./qs.^gamma .* EXP .* R.^chi - G0;
  % Newton: T(n+1) = T(n) - G(Tn)/G'(Tn)
  dT = - G./dGdT;
  T = T + dT;
end%convergence
disp(['dT~' num2str(max(abs(dT)))])
q = eval_qs(T,p,qt);
qc = qt-q;


I = T<T0;% & qc>=0;% & (abs(theta_il-eval_theta_il(T,q,qc,0,p))<1e-3);
disp([num2str(sum(I)) '/' num2str(N)])
% I = true(N,1);

% figure;
% subplot(2,2,1)
% plot(Ttrue(I),Ttrue(I)-T(I),'.')
% grid on
% box on
% axis square
% xlabel('T (K)')
% ylabel('T-T_{sol} (K)')
% subplot(2,2,2)
% plot(qstrue(I),qstrue(I)-q(I),'.')
% grid on
% box on
% axis square
% xlabel('q_s (kg/kg)')
% ylabel('q_s-q_{s,sol} (kg/kg)')
% subplot(2,2,3)
% plot(qctrue(I),qctrue(I)-qc(I),'.')
% grid on
% box on
% axis square
% xlabel('q_c (kg/kg)')
% ylabel('q_c-q_{c,sol} (kg/kg)')
% subplot(2,2,4)
% plot(theta_il(I),theta_il(I)-eval_theta_il(T(I),q(I),qc(I),0,p(I)),'.')
% grid on
% box on
% axis square
% xlabel('\theta_{il} (K)')
% ylabel('\theta_{il}-\theta_{il,sol} (K)')

%% Check liquid-ice-conexisting cases
% Ice-free solution for liquid-ice-conexisting ==> ql>0 & T<T0
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

PI = (p/P0).^chi;
gamma = qt.*RV./CPL;

% Try to solve G(T)-G0 = 0
G0 = theta_il .* PI .* RL.^chi ./ qt.^gamma; % G0=theta_il/c1

% Initial guess for T has to be from the right given G(T)~exponential
% T = 243.04*LOG./(17.625-LOG) + 273.15;
LOG = log(p.*qt) - log(610.78*EPS);
T = 237.3*LOG./(17.27-LOG) + 273.15;

dT = 9999;
while max(abs(dT))>1e-1
  disp(['iteration: dT~' num2str(max(abs(dT)))])
  qs = eval_qs(T,p,qt);
  dTqs = eval_dTqs(T,p,qt);
  ql = qt-qs;
  LV = lv(T);
  R = RD*(1-qt) + RV*qs;
  EXP = exp(-ql.*LV./CPL./T);
  dGdT = EXP .* R.^chi ./ CPL ./ qs.^gamma ...
             .*( dTqs.*( LV + RV*(RL./R - qt./qs).*T ) + CPL + ql.*(LV./T+CPVMCL) );
  G = T./qs.^gamma .* EXP .* R.^chi - G0;
  % Newton: T(n+1) = T(n) - G(Tn)/G'(Tn)
  dT = - G./dGdT;
  T = T + dT;
end%convergence
disp(['dT~' num2str(max(abs(dT)))])
q = eval_qs(T,p,qt);
ql = qt-q;

I = (ql>0) & (T<T0);
disp([num2str(sum(I)) '/' num2str(N)])