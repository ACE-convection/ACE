%% Condensate
IMPORT_CONSTANTS
% T0 = 273.15;
TI = T0-40;
ABS_TOL = 1e-3;

N = 1e6;
T = 163.15 + 155*rand(N,1);
% T = T0 + 45*rand(N,1);
% T = 163.15 + 80*[0:0.00001:1]';
P = 100e2 + 915e2*rand(N,1);
RH = 1+2*rand(N,1);
RH(T>300) = 1+0.1*rand(sum(T>300),1);
RH(T>310) = 1+0.05*rand(sum(T>310),1);
RH(T>320) = 1+0.025*rand(sum(T>320),1);
QT = eval_qs(T,P).*RH;
QS = nan(size(T));
QS(T>=T0) = eval_qs(T(T>=T0),P(T>=T0),QT(T>=T0));
QS(T<T0&T>TI) = eval_qsscl(T(T<T0&T>TI),P(T<T0&T>TI),QT(T<T0&T>TI));
QS(T<=TI) = eval_qsi(T(T<=TI),P(T<=TI),QT(T<=TI));
QC = QT-QS;
QL = nan(size(T));
QI = nan(size(T));
QL(T>=T0) = QC(T>=T0);
QI(T>=T0) = 0;
QL(T<T0&T>TI) = (T(T<T0&T>TI)-TI).*QC(T<T0&T>TI)/40;
QI(T<T0&T>TI) = (T0-T(T<T0&T>TI)).*QC(T<T0&T>TI)/40;
QL(T<=TI) = 0;
QI(T<=TI) = QC(T<=TI);
ES = eval_es(T);
ES(T<T0&T>TI) = eval_esscl(T(T<T0&T>TI));
ES(T<=TI) = eval_esi(T(T<=TI));

H = eval_h(T,QT,QS,QI);

I = (QT>=QS)&(ES<=P);
N = sum(I);
T = T(I);
P = P(I);
QT = QT(I);
Q = QS(I);
QL = QL(I);
QI = QI(I);
H = H(I);
HTL = eval_h(TI,QT,eval_qsscl(TI,P,QT),QT-eval_qsscl(TI,P,QT));

invT = nan(size(T));
invq = nan(size(T));
invql = nan(size(T));
invqi = nan(size(T));
S = zeros(size(T));
C = zeros(size(T));


for n=1:N
  tic;
  [invT(n),invq(n),invql(n),invqi(n),S(n)] = inv_T_from_h(H(n),QT(n),P(n));
  C(n) = toc;
end
Tcost=sum(C); 

invH = eval_h(invT,QT,invq,invqi);

disp(['dT: ' num2str(max(abs(T-invT))) 'K'])
disp(['dH: ' num2str(max(abs((H-invH)/CPD))) 'K'])
disp(['dq: ' num2str(max(abs((Q-invq)./Q*1e2))) '%'])
disp(['dqL: ' num2str(max(abs((QL-invql)./QL*1e2))) '%'])
disp(['dqi: ' num2str(max(abs((QI-invqi)./QI*1e2))) '%'])
disp(['Time: ' num2str(Tcost/N) 's']) 
%New time=0.99712e-04s
%Old time=1.1787e-04s

figure
subplot(1,4,1)
plot(T,T-invT,'x')
% ylim([-1 1])
subplot(1,4,2)
plot(T,(H-invH)/CPD,'x')
subplot(1,4,3)
plot(T,(Q-invq)./Q*1e2,'x')
% ylim([-1 1]*15)
subplot(1,4,4)
plot(T,(QL-invql)./QL*1e2,'o',T,(QI-invqi)./QI*1e2,'x')

figure
histogram(S)

%% No condensate
IMPORT_CONSTANTS
T0 = 273.15;
TI = T0-40;
ABS_TOL = 1e-3;

N = 1e6;
T = 180 + 160*rand(N,1);
P = 100e2 + 915e2*rand(N,1);
RH = rand(N,1);
QT = eval_qs(T,P).*RH;
QT(T<T0&T>TI) = eval_qsscl(T(T<T0&T>TI),P(T<T0&T>TI)).*RH(T<T0&T>TI);
QT(T<=TI) = eval_qsi(T(T<=TI),P(T<=TI)).*RH(T<=TI);
Q = QT;
QL = zeros(size(Q));
QI = zeros(size(Q));
H = eval_h(T,QT,Q,QI);
ES = eval_es(T);
ES(T<T0&T>TI) = eval_esscl(T(T<T0&T>TI));
ES(T<=TI) = eval_esi(T(T<=TI));

I = QT<1 & QT>0 & ES<=P;
N = sum(I);
T = T(I);
P = P(I);
QT = QT(I);
Q = Q(I);
QL = QL(I);
QI = QI(I);
H = H(I);

invT = nan(size(T));
invq = nan(size(T));
invql = nan(size(T));
invqi = nan(size(T));
S = zeros(size(T));
C = zeros(size(T));

for n=1:N
  tic;
  [invT(n),invq(n),invql(n),invqi(n),S(n)] = inv_T_from_h(H(n),QT(n),P(n));
  C(n)=toc;
end
Tcost=sum(C); 

invH = eval_h(invT,QT,invq,invqi);

disp(['dT: ' num2str(max(abs(T-invT))) 'K'])
disp(['dH: ' num2str(max(abs((H-invH)/CPD))) 'K'])
disp(['dq: ' num2str(max(abs((Q-invq)./Q*1e2))) '%'])
disp(['dqL: ' num2str(max(abs((QL-invql)./QL*1e2))) '%'])
disp(['dqi: ' num2str(max(abs((QI-invqi)./QI*1e2))) '%'])
disp(['Time: ' num2str(Tcost/N) 's']) 

figure
subplot(1,4,1)
plot(T,T-invT,'x')
% ylim([-1 1])
subplot(1,4,2)
plot(T,(H-invH)/CPD,'x')
subplot(1,4,3)
plot(T,(Q-invq)./Q*1e2,'x')
% ylim([-1 1]*15)
subplot(1,4,4)
plot(T,(QL-invql)./QL*1e2,'o',T,(QI-invqi)./QI*1e2,'x')

figure
histogram(S)