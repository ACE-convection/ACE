% Test inverting T from theta_il assuming liquid-free but with ice
IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

%% With-ice-but-no-liquid (ql=0,qi>0) examples
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = T0 - 70*rand(N,1);
qsi = eval_qsi(T,p);
qt = (1+rand(N,1)).*qsi;
qsi = eval_qsi(T,p,qt);
qi = qt-qsi;
theta_il = eval_theta_il(T,qsi,0,qi,p);
Ttrue = T;
qstrue = qsi;
qitrue = qi;

CPL = CPD + (CPV-CPD)*qt;
RL = RD*(1-qt) + RV*qt;
% R = RD*(1-qt) + RV*qs;
chi = RL./CPL;

PI = (p./P0).^chi;
gamma = qt.*RV./CPL;

% Try to solve G(T)-G0 = 0
G0 = theta_il .* PI .* RL.^chi ./ qt.^gamma; % G0=theta_il/c1

% Initial guess for T has to be from the right given G(T)~exponential
% Tetens for ice: esi(T)~610.78*exp(21.875*(T-273.16)/(T-7.66))
LOG = log(p.*qt) - log(610.78*EPS);
T = 265.5*LOG./(21.875-LOG) + 273.16;

dT = 9999;
while max(abs(dT))>1e-1
  disp(['iteration: dT~' num2str(max(abs(dT)))])
  qsi = eval_qsi(T,p,qt);
  dTqsi = eval_dTqsi(T,p,qt);
  qi = qt-qsi;
  R = RD*(1-qt) + RV*qsi;
  EXP = exp(-qi.*LS./CPL./T);
  dGdT = EXP .* R.^chi ./ CPL ./ qsi.^gamma ...
             .*( dTqsi.*( LS + RV*(RL./R - qt./qsi).*T ) + CPL + LS*qi./T );
  G = T./qsi.^gamma .* EXP .* R.^chi - G0;
  % Newton: T(n+1) = T(n) - G(Tn)/G'(Tn)
  dT = - G./dGdT;
  T = T + dT;
end%convergence
disp(['dT~' num2str(max(abs(dT)))])
q = eval_qsi(T,p,qt);
qi = qt-q;

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
plot(qitrue,qitrue-qi,'.')
grid on
box on
axis square
xlabel('q_i (kg/kg)')
ylabel('q_i-q_{i,sol} (kg/kg)')
subplot(2,2,4)
plot(theta_il,theta_il-eval_theta_il(T,q,0,qi,p),'.')
grid on
box on
axis square
xlabel('\theta_{il} (K)')
ylabel('\theta_{il}-\theta_{il,sol} (K)')

%% Liquid-free solution in the presence of liquid (ice-free)
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = T0 + 30*rand(N,1);
qs = eval_qs(T,p);
qt = (1+rand(N,1)).*qs;
qs = eval_qs(T,p,qt);
ql = qt-qs;
theta_il = eval_theta_il(T,qs,ql,0,p);
Ttrue = T;
qstrue = qs;
qctrue = ql;

CPL = CPD + (CPV-CPD)*qt;
RL = RD*(1-qt) + RV*qt;
% R = RD*(1-qt) + RV*qs;
chi = RL./CPL;

PI = (p/P0).^chi;
gamma = qt.*RV./CPL;

% Try to solve G(T)-G0 = 0
G0 = theta_il .* PI .* RL.^chi ./ qt.^gamma; % G0=theta_il/c1

% Initial guess for T has to be from the right given G(T)~exponential
% Tetens for ice: es(T)~610.78*exp(21.875*(T-273.16)/(T-7.66))
LOG = log(p.*qt) - log(610.78*EPS);
T = 265.5*LOG./(21.875-LOG) + 273.16;

dT = 9999;
while max(abs(dT))>1e-1
  disp(['iteration: dT~' num2str(max(abs(dT)))])
  qsi = eval_qsi(T,p,qt);
  dTqsi = eval_dTqsi(T,p,qt);
  qi = qt-qsi;
  R = RD*(1-qt) + RV*qsi;
  EXP = exp(-qi.*LS./CPL./T);
  dGdT = EXP .* R.^chi ./ CPL ./ qsi.^gamma ...
             .*( dTqsi.*( LS + RV*(RL./R - qt./qsi).*T ) + CPL + LS*qi./T );
  G = T./qsi.^gamma .* EXP .* R.^chi - G0;
  % Newton: T(n+1) = T(n) - G(Tn)/G'(Tn)
  dT = - G./dGdT;
  T = T + dT;
end%convergence
disp(['dT~' num2str(max(abs(dT)))])
q = eval_qsi(T,p,qt);
qc = qt-q;


I = T>T0;% & (abs(theta_il-eval_theta_il(T,q,qc,0,p))<1e-3);
disp([num2str(sum(I)) '/' num2str(N)])
% I = true(N,1);

figure;
subplot(2,2,1)
plot(Ttrue(I),Ttrue(I)-T(I),'.')
grid on
box on
axis square
xlabel('T (K)')
ylabel('T-T_{sol} (K)')
subplot(2,2,2)
plot(qstrue(I),qstrue(I)-q(I),'.')
grid on
box on
axis square
xlabel('q_s (kg/kg)')
ylabel('q_s-q_{s,sol} (kg/kg)')
subplot(2,2,3)
plot(qctrue(I),qctrue(I)-qc(I),'.')
grid on
box on
axis square
xlabel('q_c (kg/kg)')
ylabel('q_c-q_{c,sol} (kg/kg)')
subplot(2,2,4)
plot(theta_il(I),theta_il(I)-eval_theta_il(T(I),q(I),0,qc(I),p(I)),'.')
grid on
box on
axis square
xlabel('\theta_{il} (K)')
ylabel('\theta_{il}-\theta_{il,sol} (K)')

%% Check liquid-ice-conexisting cases
% Liquid-free solution for liquid-ice-conexisting ==> qi>0 & T>T0
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
% Tetens for ice: es(T)~610.78*exp(21.875*(T-273.16)/(T-7.66))
LOG = log(p.*qt) - log(610.78*EPS);
T = 265.5*LOG./(21.875-LOG) + 273.16;

dT = 9999;
while max(abs(dT))>1e-1
  disp(['iteration: dT~' num2str(max(abs(dT)))])
  qsi = eval_qsi(T,p,qt);
  dTqsi = eval_dTqsi(T,p,qt);
  qi = qt-qsi;
  R = RD*(1-qt) + RV*qsi;
  EXP = exp(-qi.*LS./CPL./T);
  dGdT = EXP .* R.^chi ./ CPL ./ qsi.^gamma ...
             .*( dTqsi.*( LS + RV*(RL./R - qt./qsi).*T ) + CPL + LS*qi./T );
  G = T./qsi.^gamma .* EXP .* R.^chi - G0;
  % Newton: T(n+1) = T(n) - G(Tn)/G'(Tn)
  dT = - G./dGdT;
  T = T + dT;
end%convergence
disp(['dT~' num2str(max(abs(dT)))])
q = eval_qsi(T,p,qt);
qc = qt-q;

I = qc>0 & T>T0;
disp([num2str(sum(I)) '/' num2str(N)])

figure;
subplot(2,2,1)
plot(Ttrue*ones(N,1),Ttrue-T(I),'.')
grid on
box on
axis square
xlabel('T (K)')
ylabel('T-T_{sol} (K)')
subplot(2,2,2)
plot(qstrue(I),qstrue(I)-q(I),'.')
grid on
box on
axis square
xlabel('q_s (kg/kg)')
ylabel('q_s-q_{s,sol} (kg/kg)')
subplot(2,2,3)
plot(qltrue(I)+qitrue(I),qltrue(I)+qitrue(I)-qc(I),'.')
grid on
box on
axis square
xlabel('q_c (kg/kg)')
ylabel('q_c-q_{c,sol} (kg/kg)')
subplot(2,2,4)
plot(theta_il(I),theta_il(I)-eval_theta_il(T(I),q(I),0,qc(I),p(I)),'.')
grid on
box on
axis square
xlabel('\theta_{il} (K)')
ylabel('\theta_{il}-\theta_{il,sol} (K)')

%% Additional check: liquid-free solution for supercooled liquid
%% ==> Solutions for most cases reasonable: all with qi>0; <1% with T>T0. 
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = T0 - 70*rand(N,1);
qs = eval_qs(T,p);
qt = (1+rand(N,1)).*qs;
qs = eval_qs(T,p,qt);
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
% Tetens for ice: es(T)~610.78*exp(21.875*(T-273.16)/(T-7.66))
LOG = log(p.*qt) - log(610.78*EPS);
T = 265.5*LOG./(21.875-LOG) + 273.16;

dT = 9999;
while max(abs(dT))>1e-1
  disp(['iteration: dT~' num2str(max(abs(dT)))])
  qsi = eval_qsi(T,p,qt);
  dTqsi = eval_dTqsi(T,p,qt);
  qi = qt-qsi;
  R = RD*(1-qt) + RV*qsi;
  EXP = exp(-qi.*LS./CPL./T);
  dGdT = EXP .* R.^chi ./ CPL ./ qsi.^gamma ...
             .*( dTqsi.*( LS + RV*(RL./R - qt./qsi).*T ) + CPL + LS*qi./T );
  G = T./qsi.^gamma .* EXP .* R.^chi - G0;
  % Newton: T(n+1) = T(n) - G(Tn)/G'(Tn)
  dT = - G./dGdT;
  T = T + dT;
end%convergence
disp(['dT~' num2str(max(abs(dT)))])
q = eval_qsi(T,p,qt);
qi = qt-q;

disp(num2str(sum(qi>0)))
disp(num2str(sum(T<T0)))