load('GPUTEST_SAMPLE.mat')
Nzm = Nzm-1;
Qsat = eval_qsat2(T_zc,p_zc);
Qt = Qsat.*(0.75+0.3*rand(size(Qsat)));
Qc = (Qt-Qsat).*(Qt>Qsat);
Ql = Qc.*(T_zc>=273.1636783445389);
Qi = Qc-Ql;
Q = Qt-Qc;
THETA_E = eval_theta_e(T_zc, Q, Ql, Qi, p_zc);

Np = 1*121;
% figure
% hold on

THETA_E = repmat(THETA_E,[1,Np]);
Qt = repmat(Qt,[1,Np]);
P_ZC = repmat(p_zc,[1,Np]);

tic;
Np = size(THETA_E,2);
T = zeros(Nzm,Np);
q = zeros(Nzm,Np);
ql = zeros(Nzm,Np);
qi = zeros(Nzm,Np);
for idp=1:Np*Nzm
  [T(idp), q(idp), ql(idp), qi(idp)]...
        = inv_T_from_theta_e_nogpu(THETA_E(idp), Qt(idp), P_ZC(idp));
end
Tcost = toc;
disp(['CPU: ' num2str(Tcost)])
% plot(T-T_zc)

tic;
GTH = gpuArray(THETA_E);
GQT = gpuArray(Qt);
GPZ = gpuArray(P_ZC);
% Don't need to pre-allocate GT, Gq, Gql, Gqi (acturally faster)
[GT,Gq,Gql,Gqi] = arrayfun(@inv_T_from_theta_e,GTH,GQT,GPZ);
Tcost = toc;
disp(['GPU: ' num2str(Tcost)])
% % T = gather(GT);
% % q = gather(Gq);
% % ql = gather(Gql);
% % qi = gather(Gqi);
%   plot(T-T_zc,'-.')