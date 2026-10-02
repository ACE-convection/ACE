function [theta_e, qt, T, q, ql, qi] = entrain_plume_calc(T_p, q_p, rho_p, z_p, p_p, mixing)
global qc_cap eps_tur
  Np = length(p_p);
  theta_e_p = eval_theta_e(T_p,q_p,0,0,p_p);
  
  if nargin==5 %Mixing ratio not prescribed
    % DIB profile
    W = sin( pi*z_p/14e3 );
    MF = rho_p .* W; % Mass flux
    zbar = ( z_p(1:end-1)+z_p(2:end) )/2;
    X = 2*( MF(2:end)-MF(1:end-1) )./( MF(2:end)+MF(1:end-1) ); % Values at zbar
    X(zbar>7e3 | ~(X>0)) = 0;
%     X = X + eps_tur*( z_p(2:end)-z_p(1:end-1) ); % Adding turbulent entrainment (eps_tur in 1/m)
    X(X>1) = 1;
  else
%     X = mixing.*( p_p(1:end-1)-p_p(2:end) )/5e2; % Mixing units = /5hPa
    X = mixing.*( z_p(2:end)-z_p(1:end-1) ); % Mixing units = /m
  end

  %% Average over lowest 500-m for initial parcel
  theta_e_i = mean( interp1(z_p,theta_e_p,[0:5:500]) );
  qt_i = mean( interp1(z_p,q_p,[0:5:500]) );
  [T_i, q_i, ql_i, qi_i] = inv_T_from_theta_e(theta_e_i, qt_i, p_p(1));

  %% Initiate with surface values
% %   theta_e_i = theta_e_p(1);
% %   T_i = T_p(1);
% %   q_i = q_p(1);
% %   qt_i = q_p(1);
% %   ql_i = 0;
% %   qi_i = 0;

  % Allocate
  theta_e = [theta_e_i;zeros(Np-1,1)];
  qt = [qt_i;zeros(Np-1,1)];
  T = [T_i;zeros(Np-1,1)];
  q = [q_i;zeros(Np-1,1)];
  ql = [ql_i;zeros(Np-1,1)];
  qi = [qi_i;zeros(Np-1,1)];
  for idz=2:Np
    theta_e(idz) = ( 1-X(idz-1) )*theta_e(idz-1) + X(idz-1)*( theta_e_p(idz)+theta_e_p(idz-1) )/2;
    qt(idz) = ( 1-X(idz-1) )*qt(idz-1) + X(idz-1)*( q_p(idz)+q_p(idz-1) )/2;
    [T(idz), q(idz), ql(idz), qi(idz)] = inv_T_from_theta_e(theta_e(idz), qt(idz), p_p(idz));
    T(idz) = real(T(idz));
    q(idz) = real(q(idz));
    ql(idz) = real(ql(idz));
    qi(idz) = real(qi(idz));
    qc = ql(idz)+qi(idz);
    if qc>qc_cap
      qt(idz) = q(idz) + qc_cap;
      ql(idz) = qc_cap*ql(idz)/qc;
      qi(idz) = qc_cap-ql(idz);
    end%qc_cap
    theta_e(idz) = eval_theta_e(T(idz),q(idz),ql(idz),qi(idz),p_p(idz));
  end%idz
end