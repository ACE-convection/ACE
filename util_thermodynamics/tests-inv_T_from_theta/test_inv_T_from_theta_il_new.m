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
% theta_il = eval_theta_il(Ttrue,qtrue,qltrue,qitrue,p);

%% General non-coexisting
% N = 10000;
% p = 100e2 + 900e2*rand(N,1);
% Ttrue = 200 + 100*rand(N,1);
% qs = eval_qs(Ttrue,p);
% qsi = eval_qsi(Ttrue,p);
% qs(Ttrue<T0) = qsi(Ttrue<T0); clear qsi
% qttrue = 1.5*rand(N,1).*qs;
% qs = eval_qs(Ttrue,p,qttrue);
% qsi = eval_qsi(Ttrue,p,qttrue);
% qs(Ttrue<T0) = qsi(Ttrue<T0); clear qsi
% qc = (qttrue-qs).*(qttrue>qs);
% qtrue = qttrue;
% qtrue(qc>0) = qs(qc>0);
% qltrue = qc.*(Ttrue>T0);
% qitrue = qc.*(Ttrue<T0);
% theta_il = eval_theta_il(Ttrue,qtrue,qltrue,qitrue,p);

%% Coexisting
N = 10000;
p = 100e2 + 900e2*rand(N,1);
Ttrue = T0*ones(N,1);
qs = eval_qsi(Ttrue,p) + rand(N,1).*( eval_qs(Ttrue,p) - eval_qsi(Ttrue,p) );
qttrue = (1 + rand(N,1)).*qs;
qs = eval_qsi(Ttrue,p,qttrue) + rand(N,1).*( eval_qs(Ttrue,p,qttrue) - eval_qsi(Ttrue,p,qttrue) );
qc = qttrue-qs;
qtrue = qs;
qltrue = qc.*rand(N,1);
qitrue = qc-qltrue;
theta_il = eval_theta_il(Ttrue,qtrue,qltrue,qitrue,p);

%% 
T = nan(N,1);
Q = nan(N,1);
QL = nan(N,1);
QI = nan(N,1);
% STEP = nan(N,1); %for debugging
tic;
for i=1:N
%   [t,q,ql,qi,step] = inv_T_from_theta_il_new(theta_il(i),qttrue(i),p(i));
  [t,q,ql,qi] = inv_T_from_theta_il_new(theta_il(i),qttrue(i),p(i));
  T(i) = t;
  Q(i) = q;
  QL(i) = ql;
  QI(i) = qi;
%   STEP(i) = step;
end
T_COST = toc;
disp(['AVG RUN TIME ~ ' num2str(T_COST/N) ' s'])

dtheta_il = theta_il - eval_theta_il(T,Q,QL,QI,p);
disp(['MAX ERROR: ' num2str(max(abs(dtheta_il))) ' K'])

I = QL>=0 & QI>=0 & Q<=qttrue;
disp(['Consistency: ' num2str(sum(I)) '/' num2str(N)])

% sum(QI==0&QL==0)

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

% figure
% TAG = {'Q_c-free';'Q_i-free';'Q_L-free'};
% for step=1:3
%   subplot(1,3,step)
%   plot(Ttrue(STEP==step),T(STEP==step)-Ttrue(STEP==step),'.')
%   title(TAG{step})
%   grid on
%   box on
% end