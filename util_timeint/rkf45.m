%% Runge-Kutta-Fehlberg Method (RKF45) of order 5 (ode45)
function X = rkf45(tspan,X0,dt)
global Nzm
  X = nan(length(X0),length(tspan));
  yn = X0;
  k1 = nan(size(X0));
  k2 = nan(size(X0));
  k3 = nan(size(X0));
  k4 = nan(size(X0));
  k5 = nan(size(X0));
  k6 = nan(size(X0));
  ynp1 = nan(size(X0));
  yn = X0;
  X(:,1) = X0;
  for idt=1:length(tspan)-1
    t = tspan(idt);
    Nt = ( tspan(idt+1)-tspan(idt) )/dt;
    for idn=1:Nt
      t = t+dt;
      disp(t)
      % Implicitly solving massflux diffusion
      yn(2*Nzm+(1:Nzm)) = ImDiffMF(yn(2*Nzm+(1:Nzm)),dt/2); %Symm. Splitting only minor differences
      % Explicit EBS23 for other terms
      k1 = odeFun(t,yn);
      k2 = odeFun(t,yn+k1*(dt/4) );
      k3 = odeFun(t,yn+(3*k1+9*k2)*(dt/32) );
      k4 = odeFun(t,yn+(1932*k1-7200*k2+7296*k3)*(dt/2197) );
      k5 = odeFun(t,yn+((439/216)*k1-8*k2+(3680/513)*k3-(845/4104)*k4)*dt );
      k6 = odeFun(t,yn+(-(8/27)*k1+2*k2-(3544/2565)*k3+(1859/4104)*k4-(11/40)*k5)*dt );
%       ynp1 = yn + dt*(k1*(25/216) + k3*(1408/2565) + k4*(2197/4101) - k5/5);
      yn = yn + dt*( k1*(16/135) + k3*(6656/12825) + k4*(28561/56430) - k5*(9/50) + k6*(2/55) );
      % Nonnegative
      yn(Nzm+(1:Nzm)) = yn(Nzm+(1:Nzm)).*(yn(Nzm+(1:Nzm))>0);
      % Implicitly solving massflux diffusion (repeated for symmetric splitting)
      yn(2*Nzm+(1:Nzm)) = ImDiffMF(yn(2*Nzm+(1:Nzm)),dt/2); %dt/2 for symmetric splitting
    end
    X(:,idt+1) = yn;
  end
  X = X'; % Consistent with MATLAB ode23
end

function dXdt = odeFun(t,X)
global theta_e_mf qt_mf rho_mf rho_mfh k dz Nzm eps_tur eps_sl EBF EBT
  % disp(t)
  X = reshape(X,[Nzm,5]); % X=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum]
  Xext = [ [ones(k-1,1)*X(1,1);X(:,1)],...
           [ones(k-1,1)*X(1,2);X(:,2)],...
           [-X(k:-1:2,3);X(:,3)] ];
  Nzext = Nzm+k-1; %=length(Xext)/3
  dXextdz = zeros(Nzext,3);

  % Compute MFh(zm+dz/2) from MF(zm) as the mean of up- and down-wind approximations
  LMFh = zeros(Nzm,1); % MFh from more left stencil points
  RMFh = zeros(Nzm,1); % MFh from more right stencil points
  for idz=k+1:Nzext-k+1
    LMFh(idz-k) = reconstruction_weno(k, Xext([idz-k:idz+k-2],3) );
    RMFh(idz-k) = reconstruction_weno(k, Xext(flip([idz-k+1:idz+k-1]),3) );
  end
  MFh = (LMFh + RMFh)/2;
  % w at zm+dz/2 with up-/down-wind following Godunov Flux
  wh = ( LMFh.*(MFh>=0) + RMFh.*(MFh<0) )./rho_mfh;
  for idz=k+1:Nzext-k
    % Using WENO-dev
    dXextdz(idz,:)...
        = ( reconstruction_weno(k, Xext( [idz-k+1:idz+k-1]*(MFh(idz-k+1)>=0)+flip([idz-k+2:idz+k])*(MFh(idz-k+1)<0) ,:) ) ...
           - reconstruction_weno(k, Xext( [idz-k:idz+k-2]*(MFh(idz-k)>=0)+flip([idz-k+1:idz+k-1])*(MFh(idz-k)<0) ,:) ) )/dz;
  end
  % First zero at zm=0 (dXdz~=0 but dXdt=0 at the end of computation)
  % zeros(k,1) for domain top<---to be improved!!!!!
  dXdz = [zeros(1,3); dXextdz(k+1:Nzext-k,:); zeros(k,3)];
  % E: dynamic & turbulent entrainment contributions
  eps_dyn = (dXdz(:,3)>0).*dXdz(:,3);
  E1 = ( theta_e_mf-X(:,1) ) .*( eps_tur.*rho_mf + eps_sl + eps_dyn );
  E2 = ( qt_mf-X(:,2) ).*( eps_tur.*rho_mf + eps_sl + eps_dyn );
  % E3 includes advection of MF (as an input for nonLocalResponse)
  E3 = -(wh(2:end).^2-wh(1:end-1).^2)/(2*dz)...
        -X(2:end,3)./(rho_mf(2:end).^2).*( eps_tur.*rho_mf(2:end) + eps_sl(2:end) + eps_dyn(2:end) );
  % Ivert (T,q,ql,qi) for buoyancy and precipitation
  [T, Q, QL, QI] = INV_THETA_E(X(:,1), X(:,2));
  % Precipitation sinks
  [dtheta_e, dqt] = PRECIP_SINKS(T, Q, QL, QI);
  dXdt = [ ( E1 - dXdz(:,1).*X(:,3) )./rho_mf + dtheta_e,...
           ( E2 - dXdz(:,2).*X(:,3) )./rho_mf + dqt,...
           NONLOCAL_RESPONSE(T, Q, QL+QI, [0;E3]) + EBF*(t<EBT),...
           dtheta_e, -dqt];
  dXdt([1,end-10:end],:) = 0; % At zm=0 & domain top
  dXdt = dXdt(:);
end

function dMFdt = NONLOCAL_RESPONSE(T, q, qc, E3)
global Tv_mf MB Z zm z g coarse_z
  Tv = eval_Tv(T, q, qc);
  B = g.*(Tv-Tv_mf)./Tv_mf;
  % dMFdt = L(B;D)<---averaged MF tendency in r<D/2
  dMFdt = interp1(Z,MB*mean(reshape(interp1(zm,B+E3,z),coarse_z,[]))',zm,'pchip');
  dMFdt(1) = 0;
end

function [dtheta_e, dqt] = PRECIP_SINKS(T, q, ql, qi)
global p_mf qc_ramp dqc tau_pr
  qc = ql+qi;
  dqt = -(qc_ramp/dqc/tau_pr) * log( 1+exp( (dqc/qc_ramp) * (qc-qc_ramp) ) );
  % Finite-difference estimate for d(theta_e)/dqc
  dql = 1e-8*ql./qc;
  dqi = 1e-8*qi./qc;
  dtheta_e = dqt.* ( eval_theta_e(T,q,ql+dql,qi+dqi,p_mf) - eval_theta_e(T,q,ql,qi,p_mf) )/1e-8;
  % Check qc>0
  dqt(qc<=0) = 0;
  dtheta_e(qc<=0) = 0;
end

function [T, q, ql, qi] = INV_THETA_E(theta_e, qt)
global p_mf Nzm
  T = zeros(Nzm,1);
  q = zeros(Nzm,1);
  ql = zeros(Nzm,1);
  qi = zeros(Nzm,1);
  for idz=1:Nzm
    [T(idz), q(idz), ql(idz), qi(idz)] = inv_T_from_theta_e(theta_e(idz), qt(idz), p_mf(idz));
  end
  % Double check values after inversion
  T = real(T);
  q = real(q);
  ql = real(ql);
  qi = real(qi);
end

function [theta_e, qt, mf, theta, RH, B,... 
          qsat, qc, ql, qi, Tv, T, dtheta_e_pr_accum, pr_accum] = POST_PROCESS(X)
global Tv_mf p_mf Nzm g
  theta_e = X(1:Nzm,:);
  qt = X(Nzm+1:2*Nzm,:);
  mf = X(2*Nzm+1:3*Nzm,:);
  dtheta_e_pr_accum = X(3*Nzm+1:4*Nzm,:);
  pr_accum = X(4*Nzm+1:end,:);
  Nt = size(X,2);
  theta = zeros(Nzm,Nt);
  qsat = zeros(Nzm,Nt);
  ql = zeros(Nzm,Nt);
  qi = zeros(Nzm,Nt);
  T = zeros(Nzm,Nt);
  for idt=1:Nt
    for idz=1:Nzm
      [T(idz,idt), q(idz,idt), ql(idz,idt), qi(idz,idt)]...
          = inv_T_from_theta_e(theta_e(idz,idt), qt(idz,idt), p_mf(idz));
    end
    theta(:,idt) = eval_theta(T(:,idt),p_mf);
    qsat(:,idt) = eval_qsat(T(:,idt),p_mf,qt(:,idt));
  end
  Tv = eval_Tv(T,q,ql+qi);
  RH = q./qsat;
  B = g.*(Tv-Tv_mf)./Tv_mf;
  qc = (qt-qsat).*(qt>qsat);
end

function [T_env, q_env, Tv_env, theta_e_env, rho_env, p_z,...
          T_zm, q_zm, Tv_zm, theta_e_zm, rho_zm, p_zm, theta_zm,...
          theta_es_zm, rh_zm] = INTERP_Z_GRID(T_p, q_p, z_p)
global RD g dz z zm p
  % Interpolate sounding values to 50-m z-grid (_env) & zm-grid (_zm)
  T_env = nan([length(z),size(T_p,2)]);
  q_env = nan([length(z),size(T_p,2)]);
  Tv_env = nan([length(z),size(T_p,2)]);
  p_z = nan([length(z),size(T_p,2)]);
  T_zm = nan([length(zm),size(T_p,2)]);
  q_zm = nan([length(zm),size(T_p,2)]);
  Tv_zm = nan([length(zm),size(T_p,2)]);
  p_zm = nan([length(zm),size(T_p,2)]);
  for pidx=1:size(T_p,2)
    T_env(:,pidx) = interp1(z_p(:,pidx),T_p(:,pidx),z,'pchip',T_p(end,pidx));
    q_env(:,pidx) = interp1(z_p(:,pidx),q_p(:,pidx),z,'pchip',q_p(end,pidx));
    q_env(q_env(:,pidx)<0,pidx) = 0; % Fix negative q_env due to interp1
    Tv_env(:,pidx) = eval_Tv(T_env(:,pidx),q_env(:,pidx));
    p_z(:,pidx) = interp1(z_p(:,pidx),p,z,'pchip');
    midz = sum(z<=max(z_p(:,pidx)));
    for idz=midz+1:length(z)
      p_z(idz,pidx) = p_z(idz-1,pidx)*(1-g*dz/2/RD/Tv_env(idz-1,pidx))/(1+g*dz/2/RD/Tv_env(idz-1,pidx));
    end
    T_zm(:,pidx) = interp1(z_p(:,pidx),T_p(:,pidx),zm,'pchip',T_p(end,pidx));
    q_zm(:,pidx) = interp1(z_p(:,pidx),q_p(:,pidx),zm,'pchip',q_p(end,pidx));
    q_zm(q_zm(:,pidx)<0,pidx) = 0; % Fix negative q_zm due to interp1
    Tv_zm(:,pidx) = eval_Tv(T_zm(:,pidx),q_zm(:,pidx));
    p_zm(:,pidx) = interp1(z_p(:,pidx),p,zm,'pchip');
    midz = sum(zm<=max(z_p(:,pidx)));
    for idz=midz+1:length(zm)
      p_zm(idz,pidx) = p_zm(idz-1,pidx)*(1-g*dz/2/RD/Tv_zm(idz-1,pidx))/(1+g*dz/2/RD/Tv_zm(idz-1,pidx));
    end
  end
  rho_env = p_z./Tv_env/RD;
  theta_e_env = eval_theta_e(T_env,q_env,0,0,p_z);
  rho_zm = p_zm./Tv_zm/RD;
  theta_e_zm = eval_theta_e(T_zm,q_zm,0,0,p_zm);
  theta_es_zm= eval_theta_es(T_zm,p_zm);
  theta_zm= eval_theta(T_zm,p_zm);
  rh_zm = q_zm./eval_qsat(T_zm,p_zm);
end

function [T_p, q_p, rho_p, z_p] = INTERP_P_GRID(plev, ta, hus)
global RD g p
  % Interpolate sounding values to 5-hPa p-grid (_p)
  T_p = nan([length(p),size(ta,2)]);
  q_p = nan([length(p),size(ta,2)]);
  Tv_p = nan([length(p),size(ta,2)]);
  rho_p = nan([length(p),size(ta,2)]);
  z_p = nan([length(p),size(ta,2)]);
  % pidx = find(prw==max(prw));
  for pidx=1:size(ta,2)
    T_p(:,pidx) = interp1(plev,ta(:,pidx),p,'pchip');
    q_p(:,pidx) = interp1(plev,hus(:,pidx),p,'pchip');
    % Fix negative q_p due to interp1
    q_p(q_p(:,pidx)<0,pidx) = 0;
    Tv_p(:,pidx) = eval_Tv(T_p(:,pidx),q_p(:,pidx));
    rho_p(:,pidx) = p./Tv_p(:,pidx)/RD;
    % Compute height assuming hydrostatic balance
    z_p(:,pidx) = (RD/g*(p(1)-p(2)))*cumtrapz(Tv_p(:,pidx)./p);
  end
end

function [plev, pr, ta, hus, prw, date, hh] = LOAD_SOUNDINGS(armbefn, arm)
global g
  % Load sounding data
  if arm<=2 % Manus or Nauru
    plev = ncread(armbefn,'pressure'); % Pa
    pr = ncread(armbefn,'pr'); % mm/h
    prw = ncread(armbefn,'prw'); % mm
    ta = ncread(armbefn,'ta'); % K
    hus = ncread(armbefn,'hus'); % kg/kg
%     rh = ncread(armbefn,'rh'); % in %; rh defined w.r.t. liquid (not ice)
    time = ncread(armbefn,'time_bnds'); % 'seconds since 1970-1-1 0:00:00 0:00'
    avail = sum(~isnan(ta),2)==37 & sum(~isnan(hus),2)==37 & ~isnan(pr);
    pr = pr(avail);
    prw = prw(avail);
    ta = ta(avail,:)';
    hus = hus(avail,:)';
%     rh = rh(avail,:)';
    date = time(avail)/3600/24 + datenum(1970,1,1);
    hh = floor(mod(date,1)*24); 
  elseif arm==3 % GOAmazon
    plev = ncread(armbefn,'pressure')*1e2; % hPa-->Pa
    pr = ncread(armbefn,'precip_rate_sfc'); % mm/h
    ta = ncread(armbefn,'temperature_p')'; % K
    rh = ncread(armbefn,'relative_humidity_p')'; % in %
    time = ncread(armbefn,'time'); % 'seconds since 2014-1-1 0:00:00 0:00'
    date = time/3600/24 + datenum(2014,1,1);
    hh = floor(mod(date,1)*24); 
    % GOAmazon hh==5 & pr>2: [45, 457, 1179, 1343]
    avail = sum(~isnan(ta),2)==37 & sum(~isnan(rh),2)==37 & ~isnan(pr) & hh==5;
    pr = pr(avail);
    ta = ta(avail,:)';
    rh = rh(avail,:)';
    hus = eval_q(eval_es(ta).*rh/100,repmat(plev,[1,size(ta,2)])); % Evaluated w.r.t. liquid water
    prw = sum( (hus(1:end-1,:)+hus(2:end,:)) .* (plev(1:end-1)-plev(2:end)) ,1)'/2/g;
    date = date(avail);
    hh = hh(avail);
  end
end

function [theta_e_plu, qt_plu, T_plu, q_plu, ql_plu, qi_plu, B_plu] = ENTRAIN_PLUME(T_p, q_p, rho_p, z_p, p_p, mixing)
global g
  theta_e_plu = zeros(size(z_p));
  qt_plu = zeros(size(z_p));
  T_plu = zeros(size(z_p));
  q_plu = zeros(size(z_p));
  ql_plu = zeros(size(z_p));
  qi_plu = zeros(size(z_p));
  if nargin==5 %Mixing ratio not prescribed
    for pidx=1:size(z_p,2)
      [theta_e_plu(:,pidx),... 
       qt_plu(:,pidx),...
       T_plu(:,pidx),...
       q_plu(:,pidx),...
       ql_plu(:,pidx),...
       qi_plu(:,pidx)] = entrain_plume_calc(T_p(:,pidx), q_p(:,pidx), rho_p(:,pidx), z_p(:,pidx), p_p);
    end
  else
    for pidx=1:size(z_p,2)
      [theta_e_plu(:,pidx),... 
       qt_plu(:,pidx),...
       T_plu(:,pidx),...
       q_plu(:,pidx),...
       ql_plu(:,pidx),...
       qi_plu(:,pidx)] = entrain_plume_calc(T_p(:,pidx), q_p(:,pidx), rho_p(:,pidx), z_p(:,pidx), p_p, mixing);
    end
  end
  Tv = eval_Tv(T_p, q_p, 0);
  Tv_plu = eval_Tv(T_plu, q_plu, ql_plu+qi_plu);
  B_plu = g*(Tv_plu-Tv)./Tv;
end