IMPORT_CONSTANTS
P0 = 1000e2;
T0 = 273.16;

%% Liquid-only cases
% N = 1000000;
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
% qitrue = zeros(N,1);

%% Ice-only examples
N = 1000000;
p = 100e2 + 900e2*rand(N,1);
T = T0 - 73.16*rand(N,1);
% qsi = eval_qsi(T,p);
% qt = (1+rand(N,1)).*qsi;
% q = eval_qsi(T,p,qt);
% qi = qt-qsi;
% theta_e = eval_theta_e(T,q,0,qi,p);
% Ttrue = T;
% qtrue = q;
% qitrue = qi;
% qltrue = zeros(N,1);
qs = eval_qs(T,p);
qs(T<T0) = eval_qsi(T(T<T0),p(T<T0));
qt = (1+rand(N,1)).*qs;
q = eval_qs(T,p,qt);
q(T<T0) = eval_qsi(T(T<T0),p(T<T0),qt(T<T0));
ql = (qt-q).*(T>=T0);
qi = (qt-q).*(T<T0);
theta_e = eval_theta_e(T,q,ql,qi,p);
Ttrue = T;
qtrue = q;
qltrue = ql;
qitrue = qi;

%% Non-coexisting ice or liquid
% N = 1000000;
% p = 100e2 + 900e2*rand(N,1);
% T = 200 + 100*rand(N,1);
% qs = eval_qs(T,p);
% qs(T<T0) = eval_qsi(T(T<T0),p(T<T0));
% qt = (1+rand(N,1)).*qs;
% q = eval_qs(T,p,qt);
% q(T<T0) = eval_qsi(T(T<T0),p(T<T0),qt(T<T0));
% ql = (qt-q).*(T>=T0);
% qi = (qt-q).*(T<T0);
% theta_e = eval_theta_e(T,q,ql,qi,p);
% Ttrue = T;
% qtrue = q;
% qltrue = ql;
% qitrue = qi;

%% Co-existing
% N = 1000000;
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

%% Qc-free
% N = 1000000;
% p = 100e2 + 900e2*rand(N,1);
% T = 200 + 100*rand(N,1);
% qs = eval_qs(T,p);
% qsi = eval_qsi(T,p);
% qs(T<T0) = qsi(T<T0);
% qt = qs.*rand(N,1);
% ql = 0;
% qi = 0;
% q = qt;
% theta_e = eval_theta_e(T,q,ql,qi,p);
% Ttrue = T;
% qtrue = qt;
% qltrue = ql;
% qitrue = qi;

%%
CPL = CPD + (CL-CPD)*qt;
RE = RD*(1-qt);
chi = RE./CPL;
G0 = theta_e .* (p.*RE/P0).^chi;

% F(T0) & F0
R = RE + RV*qt; %RE+RV*q
gamma = RV*qt./CPL; %RV*q/CPL
e = p.*qt./(EPS+(1-EPS)*qt);
F0 = theta_e .* (p.*RE./R/P0).^chi .* e.^gamma;
FT0 = T0 * eval_es(T0).^gamma .* exp(qt./CPL*lv(T0)/T0);

% H(T0)
dC = CL-ci(T0);
qsi = eval_qsi(T0,p,qt);
qi = qt-qsi;
dTqsi = eval_dTqsi(T0,p,qt);
LV = lv(T0);
R = RE + RV*qsi;
HT0 = T0 .* R.^chi .* (T0./T0).^(dC*qi./CPL) ...
         .* exp((qsi.*LV./T0 - LF/T0*qi)./CPL);
       
% G(T0)
qs = eval_qs(T0,p,qt);
R = RE + RV*qs;
GT0 = T0 .* R.^chi .* exp(qs.*lv(T0)./CPL./T0);

%%
disp([num2str(sum(F0<FT0)) '/' num2str(N)])
disp([num2str(sum(G0<HT0)) '/' num2str(N)])
disp([num2str(sum(G0<GT0)) '/' num2str(N)])
disp([num2str(sum(Ttrue<T0)) '/' num2str(N)])
disp([num2str(sum(Ttrue<T0 & F0<FT0 & G0<HT0 & G0<GT0)) '/' num2str(N)])
% disp([num2str(sum(F0>FT0)) '/' num2str(N)])
% disp([num2str(sum(G0>HT0)) '/' num2str(N)])
% disp([num2str(sum(G0>GT0)) '/' num2str(N)])
% disp([num2str(sum(Ttrue>T0)) '/' num2str(N)])
% disp([num2str(sum(Ttrue>T0 & F0>FT0 & G0>HT0 & G0>GT0)) '/' num2str(N)])