IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

%% Qc-free
% N = 10000;
% p = 100e2 + 900e2*rand(N,1);
% Ttrue = 200 + 100*rand(N,1);
% qs = eval_qs(Ttrue,p);
% qsi = eval_qsi(Ttrue,p);
% qs(Ttrue<T0) = qsi(Ttrue<T0); clear qsi
% qtrue = 1.1*rand(N,1).*qs;
% qtrue(qtrue>qs) = qs(qtrue>qs);
% qltrue = 0;
% qitrue = 0;
% qttrue = qtrue + qltrue + qitrue;
% theta_e = eval_theta_e(Ttrue,qtrue,qltrue,qitrue,p);

%% Non-coexisting condensate
% N = 10000;
% p = 100e2 + 900e2*rand(N,1);
% Ttrue = 200 + 100*rand(N,1);
% % Ttrue = T0 + 30*rand(N,1);
% % Ttrue = T0 - 80*rand(N,1);
% qs = eval_qs(Ttrue,p);
% qsi = eval_qsi(Ttrue,p);
% qs(Ttrue<T0) = qsi(Ttrue<T0);
% qttrue = (1+rand(N,1)).*qs;
% qtrue = eval_qs(Ttrue,p,qttrue);
% qsi = eval_qsi(Ttrue,p,qttrue);
% qtrue(Ttrue<T0) = qsi(Ttrue<T0); clear qsi qs
% qltrue = (qttrue-qtrue).*(Ttrue>=T0);
% qitrue = (qttrue-qtrue).*(Ttrue<T0);
% theta_e = eval_theta_e(Ttrue,qtrue,qltrue,qitrue,p);

%% Coexisting
N = 10000;
p = 100e2 + 900e2*rand(N,1);
T = T0;
qs = eval_qs(T,p);
qsi = eval_qsi(T,p);
RN = rand(N,1);
qs = qs + RN.*(qsi-qs);
qt = (1+rand(N,1)).*qs;
qs = (1-RN).*eval_qs(T,p,qt)+RN.*eval_qsi(T,p,qt); %<--Evaluate q given qt
ql = (qt-qs).*rand(N,1);
qi = qt-qs-ql;
theta_e = eval_theta_e(T,qs,ql,qi,p);
Ttrue = T;
qtrue = qs;
qltrue = ql;
qitrue = qi;
qttrue = qtrue + qltrue + qitrue;

%%
T = nan(N,1);
Q = nan(N,1);
QL = nan(N,1);
QI = nan(N,1);
STEP = nan(N,1); %for debugging
CONTRAD = nan(N,1); %debugging
tic;
for i=1:N
%   [t,q,ql,qi,contradiction,step] = inv_T_from_theta_e(theta_e(i),qttrue(i),p(i));
  [t,q,ql,qi] = inv_T_from_theta_e(theta_e(i),qttrue(i),p(i));
  T(i) = t;
  Q(i) = q;
  QL(i) = ql;
  QI(i) = qi;
  STEP(i) = step;
  CONTRAD(i) = contradiction;
end
T_COST = toc;
disp(['AVG RUN TIME ~ ' num2str(T_COST/N) ' s'])

dtheta_e = theta_e - eval_theta_e(T,Q,QL,QI,p);
disp(['MAX ERROR: ' num2str(max(abs(dtheta_e))) ' K'])

I = QL>=0 & QI>=0 & Q<=qttrue;
disp(['Consistency: ' num2str(sum(I)) '/' num2str(N)])

I = (CONTRAD==1);
disp(['Contradiction: ' num2str(sum(I)) '/' num2str(N)])

I = (STEP==1);
disp(['Step 1: ' num2str(sum(I)) '/' num2str(N)])

I = (STEP==2);
disp(['Step 2: ' num2str(sum(I)) '/' num2str(N)])

I = (STEP==3);
disp(['Step 3: ' num2str(sum(I)) '/' num2str(N)])

I = (STEP==4);
disp(['Step 4: ' num2str(sum(I)) '/' num2str(N)])

figure;
subplot(2,2,1)
plot(Ttrue,Ttrue-T,'.')
grid on
box on
xlabel('T (K)')
ylabel('\Delta T (K)')
subplot(2,2,2)
plot(qtrue,qtrue-Q,'.')
grid on
box on
xlabel('Q (kg/kg)')
ylabel('\Delta Q (kg/kg)')
subplot(2,2,3)
plot(qltrue,qltrue-QL,'.')
grid on
box on
xlabel('Q_L (kg/kg)')
ylabel('\Delta Q_L (kg/kg)')
subplot(2,2,4)
plot(qitrue,qitrue-QI,'.')
grid on
box on
xlabel('Q_i (kg/kg)')
ylabel('\Delta Q_i (kg/kg)')