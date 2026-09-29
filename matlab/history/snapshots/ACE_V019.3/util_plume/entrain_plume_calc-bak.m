function [theta_e, qt, T, q, ql, qi] = entrain_plume_calc(T_p, q_p, rho_p, z_p, mixing)
global p qc_cap
  Np = length(p);
  theta_e_p = eval_theta_e(T_p,q_p,0,0,p);
  
  if nargin==4 %Mixing ratio not prescribed
    % DIB profile
    W = sin( pi*z_p/14e3 );
    MF = rho_p .* W; % Mass flux
    zbar = ( z_p(1:end-1)+z_p(2:end) )/2;
    X = 2*( MF(2:end)-MF(1:end-1) )./( MF(2:end)+MF(1:end-1) ); % Values at zbar
    X(zbar>7e3 | ~(X>0)) = 0;
    X(X>1) = 1;
  elseif length(mixing)==1 %Single-valued mixing ratio
    X = mixing*ones(Np-1,1);
  else %Mixing profile prescribed
    X = mixing;
  end

  % Allocate
  theta_e = [theta_e_p(1);zeros(Np-1,1)];
  qt = [q_p(1);zeros(Np-1,1)];
  T = [T_p(1);zeros(Np-1,1)];
  q = [q_p(1);zeros(Np-1,1)];
  ql = zeros(Np,1);
  qi = zeros(Np,1);
  for idz=2:Np
    theta_e(idz) = ( 1-X(idz-1) )*theta_e(idz-1) + X(idz-1)*( theta_e_p(idz)+theta_e_p(idz-1) )/2;
    qt(idz) = ( 1-X(idz-1) )*qt(idz-1) + X(idz-1)*( q_p(idz)+q_p(idz-1) )/2;
    [T(idz), q(idz), ql(idz), qi(idz)] = inv_T_from_theta_e(theta_e(idz), qt(idz), p(idz));
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
    theta_e(idz) = eval_theta_e(T(idz),q(idz),ql(idz),qi(idz),p(idz));
  end%idz
end