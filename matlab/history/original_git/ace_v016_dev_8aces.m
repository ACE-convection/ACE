%% Directory/file paths
dir_ace = pwd;

% Subroutines
dir_util_weno = [dir_ace '/util_weno/'];
dir_util_plume = [dir_ace '/util_plume/'];
dir_util_thermodynamics = [dir_ace '/util_thermodynamics/'];
addpath(dir_util_weno,dir_util_plume,dir_util_thermodynamics)

% Pre-computed anelastic basis for massflux
dir_basis = [dir_ace '/../data/basis/'];

% ARM best-estimate soundings (4 options from 3 sites)
dir_armbe = [dir_ace '/../data/soundings/'];
armfnlist = {'manus_3hr_ARMBEsonde_profiles.nc';
             'nauru_3hr_ARMBEsonde_profiles.nc';
             'maoarmbeatmM1.c1.20140101.003000.nc'};
           
%% Declare global for in-script functions
global theta_e_mf qt_mf Tv_mf p_mf rho_mf rho_mfh MB Z zm z p g k dz Nzm coarse_z
global eps_tur eps_sl eddiffu eddiwin qc_ramp dqc tau_pr EBF EBT qc_cap dt Ni Ai
global one_ace_only RF Wbar_eq_zero turn_off_mf_diff theta_e_diag Tim
global T Q QL QI
 
%% Loading pre-computed massflux basis
pcbsfn = 'COMPOSITE_ACE_BASIS_8ACEs.mat';
load([dir_basis pcbsfn]) % PMB(201,200,forcing-region,response-region)
D = DCASES; % Horizontal entity diameters in km
Ni = length(D) + 1; % Number of ACEs
Ai = [(pi/4)*[D(1)^2; D(2:end).^2-D(1:end-1).^2]; Lx*Ly-(pi/4)*D(end)^2]; % ACE area in km^2 (index i or ida)
Bi = [pi*D; 2*(Lx+Ly)]; % ACE outer perimeter in km (index i or ida)

%% Restart or continue a run
conti = 1; 
save_output = 0;
% output_filename = 'Manus_idp=208_8-ACEs_ebs23-debug.mat';
output_filename = 'Manus_idp=208_8-ACEs-noDH_ebs23-debug-imDamp_ssprk93-test.mat';
% output_filename = 'Manus_idp=208_Heaviside_7-ACEs_noDH_Next-DRY.mat';

%% Test Turning off nonlocal response
one_ace_only = 0;
Wbar_eq_zero = 0; %enforce domain mean w = 0
reduce_mf_diff = 0;
turn_off_mf_diff = 1;
turn_off_v_nonlocal = 0;
truncate_h_nonlocal = 0;
for i=1:Ni %response_region_index
  for j=1:Ni %forcing_region_index
    if truncate_h_nonlocal && abs(i-j)>=truncate_h_nonlocal
      PMB(:,:,j,i) = 0;
    end
    if turn_off_v_nonlocal && i==j
      PMB(:,:,j,i) = [zeros(1,size(PMB,2));eye(size(PMB,2))];
    end
% % %     if (i==1&&j>1)||(j==1&&i>1)
% % %       PMB(:,:,j,i) = 0;
% % %     end
  end
end

%% Set up parameters
plotting = 1;
savefigure = 0;
theta_e_diag = 1; Tim = [];

% ARM sounding option
arm = 1;%3; %1=Manus/2=Nauru/3,4=GOAmazon
armfn = armfnlist{arm};
pidx = 208;%314; % Profile index for environment

% Verital grids setup
dz = 100; % m; 5hPa~50m(surface)/250m(aloft)
coarse_z = 200/dz;
ztop = 40e3; % m
z = [dz/2:dz:ztop-dz/2]'; % z-grid for plume computation
zm = [0:dz:ztop]'; % z-grid for mass-flux for entrainment rate
p = [1000:-5:100]'*1e2; % 5-hPa grid

% For precip sinks
qc_ramp = 0.5e-3; % kg/kg; ramping for precip when qc>qc_ramp
dqc = 20; % kg/kg; transition for a smooth onset of precip ramp function
tau_pr = 5*60; % sec; relaxation timescale for precip

% For ODE solver
dt = 20;  % Delta t for ode solver %22s works for SSPRK(10,4) & SSPRK93
% Initiate for continuing runs
if conti==1
  Xminus1 = X(:,1:end-1);
  tminus1 = tspan(1:end-1);
  X0 = X(:,end);
  t0 = tspan(end); % t0=starting time; T0=triple point temperature.
  disp('Continue Previous Run...')
else
  disp('Start Anew!')
end
% DO NOT MODIFY THE IF SECTION
tspan = [0:1:60*1]*60; % sec
Nt = length(tspan);
% Update tspan for continuing runs
if conti==1
  tspan = tspan + t0;
end

% Initial mass flux = MF0*sin(pi*(z-zb)/(zt-zb)) for zb<z<zt (zeros elsewhere)
MF0 = 0.03; % kg/m^2/s
zt = 1e3; % km; top of initial MF
zb = 0e3; % km; Base of inital MF

% Initial thermal bubble in zm(BL); BL=[] for no bubble
BL = []; % BL=bubble levels
dTbl = 0; % T=T+dTbl in BL
dqsat = 1; %1=saturate zm(BL); 0=doing nothing
dqcbl = 0;%10e-3; % kg/kg; qc=dqcbl; ignored if dqsat~=1
dqbl = 0.8; % q=dqbl*q in BL; ignored if dqsat==1

% External buoyancy forcing (mimicking large-scale forcing)
EB = 0.01e-2; % m/s^2; magnitude of external buoyancy
zebb = 0; % Base of external buoyancy  layer
zebt = 14e3; % Top of external buoyancy  layer
% EBF = EB * normpdf(zm,(zebt-zebb)/2,(zebt-zebb)/7) / normpdf(0,0,(zebt-zebb)/7);
EBF = EB * sin(pi*zm/zebt).*(zm<zebt);
EBT = 0*60*60; % sec; EBF turned on for t<EBT

% Radiatively imposed profile (RIP)
RIP = -1.5; % K/day
zr = [0 9e3 14e3]';
vr = [1 1.5 0]';
gf = normpdf([-20:20]'*dz,0,300); % Gaussian filter for smoothing
vrzm = conv(interp1(zr,vr,zm,'linear',0),gf,'same');
RF = vrzm/max(vrzm)*RIP/3600/24; % ~dT/dt in K/s

% Turbulent entrainment rate
nju = 0.09; % Morrison (2017)
% eps_tur 1st/2nd column for outer/inner boundary of ACE-i
eps_tur = (nju/1e3)*[Bi./Ai,[0;Bi(1:end-1)./Ai(2:end)]]; %(nju/1e3)*(4/D); % Note: D in km (4/D=1/G)

% Eddy diffusivity substituting additional dynamic-induced pressure perturbation terms
D_edf = nan(Ni,1);
for i=1:Ni
  PMB_diag = PMB(:,:,i,i);
  PMB_diag = sum(PMB_diag(:,30:50),2);
  PMB_diag = PMB_diag(Z<5e3&Z>1e3); % Fitting using 1<Z<5 km
  ZB = Z(Z<5e3&Z>1e3);
  n_coeff = polyfit(ZB,log(PMB_diag),1);
  D_edf(i) = pi/(n_coeff(1)*1e3);
end
eddiffu = D_edf*1e3/4/pi/dz; %D*1e3/4/pi/dz;
eddiwin = ceil(D_edf*1e3/2/dz); % Sliding window half-width for movmax
% % % eddiffu = [D(1);D(2:end)-D(1:end-1);2*sqrt(Lx*Ly/pi)-D(end)]*1e3/4/pi/dz; %D*1e3/4/pi/dz;
% % % eddiwin = ceil([D(1);D(2:end)-D(1:end-1);2*sqrt(Lx*Ly/pi)-D(end)]*1e3/2/dz); % Sliding window half-width for movmax
if reduce_mf_diff==1
  eddiffu = eddiffu/50;
elseif turn_off_mf_diff==1
  eddiffu = eddiffu*0;
end

% Spounge layer with Newtonian damping at domain top ztop
SLD = 3e3;%3e3; % e-folding depth in m %1e3 in KN23
SLTau = 180; % SL relaxation timescale in s %60 in KN23
eps_sl = exp( (zm-zm(end))/SLD )/SLTau;

% WENO scheme (reconstruction uses 2k-1 points)
k = 2; %reconstruction_wenoz for k>=3 (k=2 only for reconstruction_weno)

% Other pre-defined constants
IMPORT_CONSTANTS
Nzm = length(zm);

%% Pre-processing sounding data
[plev, pr, ta, hus, prw, date, hh] = LOAD_SOUNDINGS([dir_armbe armfn], arm);

% Interpolate sounding values to 5-hPa p-grid (_p)
[T_p, q_p, rho_p, z_p] = INTERP_P_GRID(plev, ta, hus);

% Interpolate sounding values to 50-m z-grid (_env) & zm-grid (_zm)
[T_env, q_env, Tv_env, theta_e_env, rho_env, p_z,...
 T_zm, q_zm, Tv_zm, theta_e_zm, rho_zm, p_zm,...
 theta_zm, theta_es_zm, rh_zm] = INTERP_Z_GRID(T_p, q_p, z_p);

%% Traditional plume computations
qc_cap = 0.5e-3;% kg/kg; capping condensate for traditional plumes
% Deep-inflow B
[theta_e_dib, qt_dib, T_dib, q_dib, ql_dib, qi_dib, B_dib]...
     = ENTRAIN_PLUME(T_p(:,pidx), q_p(:,pidx), rho_p(:,pidx), z_p(:,pidx), p);
% No-mixing
mixing = 0;
[theta_e_nmx, qt_nmx, T_nmx, q_nmx, ql_nmx, qi_nmx, B_nmx]...
     = ENTRAIN_PLUME(T_p(:,pidx), q_p(:,pidx), rho_p(:,pidx), z_p(:,pidx), p, mixing);
% Constant mixing
% mixing = 5e-2; %/5hPa
mixing = 1e-3; %/m
[theta_e_cne, qt_cne, T_cne, q_cne, ql_cne, qi_cne, B_cne]...
     = ENTRAIN_PLUME(T_p(:,pidx), q_p(:,pidx), rho_p(:,pidx), z_p(:,pidx), p, mixing);

%% Setup for time-integration
day = date(pidx); % Can run multiple pidx cases (by adding a for-loop here)

% _mf(h) = properties of mass flux; will be used as constant reference during time-integration
theta_e_mf = theta_e_zm(:,pidx); 
qt_mf = q_zm(:,pidx);
Tv_mf = Tv_zm(:,pidx);
p_mf = p_zm(:,pidx);
rho_mf = rho_zm(:,pidx); 
rho_mfh = interp1(zm,rho_mf,zm+dz/2,'pchip');

% Mass-flux basis MB(Z,Bi)=PMB*rho_0(Z)
rho_Z = rho_mf(1:coarse_z:end);
MB = PMB.*rho_Z; % MB(201,200,forcing-region,response-region)

% Initiate MF(t=0)
MF = MF0*sin( pi*(zm-zb)/(zt-zb) );
MF(zm>zt | zm<zb) = 0;

% Initiate for ODE solver
if conti == 0
% % %   X0 = [theta_e_mf,qt_mf,MF,zeros(Nzm,2),...
% % %         repmat([theta_e_mf,qt_mf,zeros(Nzm,3)],1,Ni-2,1)...
% % %         theta_e_mf,qt_mf,-MF*Ai(1)/Ai(end),zeros(Nzm,2)]; %<---variables defined on zm-grid
  X0 = [repmat([theta_e_mf,qt_mf,zeros(Nzm,3)],1,Ni-1,1)...
                theta_e_mf,qt_mf,MF,zeros(Nzm,2)]; %<---variables defined on zm-grid
  t0 = 0;
  % Adding BL/thermal bubble for inner-most ACE
  if ~isempty(BL)
    if dqsat==1
      X0(BL,2) = eval_qsat(T_zm(BL,pidx)+dTbl,p_mf(BL)) .* (1-dqcbl);
    else
      X0(BL,2) = q_zm(BL,pidx)*dqbl;
    end
    X0(BL,1)=eval_theta_e(T_zm(BL,pidx)+dTbl,X0(BL,2),(dqsat==1)*dqcbl*((T_zm(BL,pidx)+dTbl)>=T0),(dqsat==1)*dqcbl*((T_zm(BL,pidx)+dTbl)<T0),p_mf(BL));
  end
end

%% Time integration
tic;
% reshape(X,[Nzm,5,Ni]) = X(z,var,ACE-i) = [theta_e_mf, qt_mf, MF, dtheta_e_pr_accum, pr_accum]
X = timeint(tspan,X0(:),dt); 
X = X';
if conti==1
  X = [Xminus1 X];
  tspan = [tminus1 tspan];
  Nt = length(tspan);
end
Tcost = toc;
disp(['ODE solver time = ' num2str(Tcost) ' sec'])

% Derived variables evaluated via post-processing (z,time,ACE-i)
[theta_e, qt, mf, theta, RH, B,...
   qsat, qv, qc, ql, qi, Tv, T, dtheta_e_pr_accum, pr_accum] = POST_PROCESS(X);

if save_output==1
  save(output_filename)
end

%%
figure('Units','normalized','Position',[0 0 1 1])
cmp = colormap(turbo(Nt));
for i=1:Ni
  subplot(1,Ni,i)
  hold all
  for idt=1:Nt
    plot(B(:,idt,i),zm/1e3,'color',cmp(idt,:),'linewidth',2)
  end
  xlabel(['Buoy (m/s^2)'])
  ylabel('Height (km)')
  xlim([-0.2,0.2])
  ylim([0 18])
  grid on
  box on
  title(['ACE-' num2str(i)])
  set(gca,'fontsize',20)
end

figure('Units','normalized','Position',[0 0 1 1])
cmp = colormap(turbo(Nt));
for i=1:Ni
  subplot(1,Ni,i)
  hold all
  for idt=1:Nt
    plot(mf(:,idt,i),zm/1e3,'color',cmp(idt,:),'linewidth',2)
  end
  if i==1
    xlim([-4 12])
  elseif i==2
    xlim([-3 5])
  elseif i==3
    xlim([-0.8 0.5])
  else
    xlim([-0.15 0.1])
  end
  xlabel(['MF (kg/m s^2)'])
  ylabel('Height (km)')
  ylim([0 18])
  grid on
  box on
  title(['ACE-' num2str(i)])
  set(gca,'fontsize',20)
end

figure('Units','normalized','Position',[0 0 1 1])
cmp = colormap(turbo(Nt));
for i=1:Ni
  subplot(1,Ni,i)
  hold all
  for idt=1:Nt
    plot(qc(:,idt,i)*1e3,zm/1e3,'color',cmp(idt,:),'linewidth',2)
  end
  xlabel(['q_c (g/kg)'])
  ylabel('Height (km)')
  ylim([0 18])
  grid on
  box on
  title(['ACE-' num2str(i)])
  set(gca,'fontsize',20)
end

figure('Units','normalized','Position',[0 0 1 1])
cmp = colormap(turbo(Nt));
for i=1:Ni
  subplot(1,Ni,i)
  hold all
  for idt=1:Nt
    plot(qv(:,idt,i)*1e3,zm/1e3,'color',cmp(idt,:),'linewidth',2)
  end
  xlabel(['q_v (g/kg)'])
  ylabel('Height (km)')
  ylim([0 18])
  grid on
  box on
  title(['ACE-' num2str(i)])
  set(gca,'fontsize',20)
end

figure('Units','normalized','Position',[0 0 1 1])
cmp = colormap(turbo(Nt));
for i=1:Ni
  subplot(1,Ni,i)
  hold all
  for idt=1:Nt
    plot(RH(:,idt,i)*1e2,zm/1e3,'color',cmp(idt,:),'linewidth',2)
  end
  xlabel(['RH (%)'])
  ylabel('Height (km)')
  ylim([0 18])
  grid on
  box on
  title(['ACE-' num2str(i)])
  set(gca,'fontsize',20)
end

figure
cmp = colormap(jet(Ni));
hold all
for idp=1:Ni
  plot((tspan(1:end-1)/60+0.5)/60,...
       squeeze(sum(pr_accum(:,2:end,idp)-pr_accum(:,1:end-1,idp)))*60,'color',cmp(idp,:))
end
sig=Ai(1:end)/sum(Ai(1:end));
plot((tspan(1:end-1)/60+0.5)/60,...
       sum(sig'.*squeeze(sum(pr_accum(:,2:end,:)-pr_accum(:,1:end-1,:)))*60,2),'k','linewidth',2)
grid on
box on
set(gca,'fontsize',15)
xlabel('Time (h)')
ylabel('Precip (mm/h)')
xlim([0 tspan(end)/3600])
xticks([0:3:48])

%% Subroutines
%%   implemented
%%     below:
%% Operator-splitting Time-integration
function X = timeint(tspan,X0,dt)
global Nzm Ni turn_off_mf_diff
  X = nan(length(X0),length(tspan));
  yn = X0;
  X(:,1) = X0;
  % For non-negative qt
  Inonneg = (5*[1:Ni]-4)*Nzm+[1:Nzm]';
  Inonneg = Inonneg(:);
  for idt=1:length(tspan)-1
    t = tspan(idt);
    Nt = ( tspan(idt+1)-tspan(idt) )/dt;
    for idn=1:Nt
      t = t+dt;
      disp(t)
      % Explicit terms
      % SSPRK93 (low-storage) %dt<=22
      K1 = expFun(yn,1); %expFun(y,rkstage)
      yi = yn+(dt/6)*K1;
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); % Non-negative qt
      K2 = expFun(yi,2);
      yi = yn+(dt/6)*(K1+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
      K2 = K2 + expFun(yi,3);
      yi = yn+(dt/6)*(K1+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
      K2 = K2 + expFun(yi,4);
      yi = yn+(dt/6)*(K1+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
      K2 = K2 + expFun(yi,5);
      yi = yn+(dt/6)*(K1+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
      K2 = (K2 + expFun(yi,6))/15;
      yi = yn+dt*(K1/6+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
      K1 = K1 + expFun(yi,7);
      yi = yn+dt*(K1/6+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0);
      K1 = K1 + expFun(yi,8);
      yi = yn+dt*(K1/6+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0);
      yn = yn + dt*((K1 + expFun(yi,9))/6+K2);
      yn(Inonneg) = yn(Inonneg).*(yn(Inonneg)>0); % Non-negative qt
      % Implicitly solving massflux diffusion
      if ~turn_off_mf_diff
        for i=1:Ni
          yn((5*i-3)*Nzm+(1:Nzm)) = ImDiffMF(yn((5*i-3)*Nzm+(1:Nzm)),dt,i);
        end
      end
      % Implicit Newtonian damping
      yn = ImDamp(yn,dt);
%       disp(norm(yn(:)))
    end%idn
    X(:,idt+1) = yn;
  end%idt
  X = X'; % Consistent with MATLAB ode23
end

function dXdt = expFun(X,rkstage)
global theta_e_mf qt_mf rho_mf rho_mfh k dz Nzm eps_tur Ni Ai one_ace_only Wbar_eq_zero 
global EBF EBT RF p_mf
global T Q QL QI
  X = reshape(X,[Nzm,5,Ni]); % X(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum]
  % Compute MFh(zm+dz/2) from MF(zm) as the mean of up- and down-wind approximations
  LMFh = zeros(Nzm,3,Ni); % MFh from more left stencil points
  RMFh = zeros(Nzm,3,Ni); % MFh from more right stencil points
  for idz=1:Nzm
    if idz>=k && idz<=Nzm-k
      LMFh(idz,:,:) = reshape(reconstruction_weno(k,X(idz-k+1:idz+k-1,1:3,:)),1,3,Ni);
      RMFh(idz,:,:) = reshape(reconstruction_weno(k,X(idz+k:-1:idz-k+2,1:3,:)),1,3,Ni);
    elseif idz<k
      LMFh(idz,:,:) = reshape(reconstruction_weno(k,[ [ones(k-idz,2,Ni).*X(1,1:2,:),-X(k-idz+1:-1:2,3,:)]; X(1:k-1+idz,1:3,:) ]),1,3,Ni);
      RMFh(idz,:,:) = reshape(reconstruction_weno(k,[ X(k+idz:-1:1,1:3,:); [ones(k-idz-1,2,Ni).*X(1,1:2,:),-X(2:k-idz,3,:)] ]),1,3,Ni);
%     else %idz=Nzm-k+1:Nzm<--can be omitted because of treatment in model-top sponge layer
%       LMFh(idz,:,:) = reshape(reconstruction_weno(k, X([idz-k+1:Nzm,Nzm*ones(1,idz-Nzm+k-1)],1:3,:) ),1,3,Ni);
%       RMFh(idz,:,:) = reshape(reconstruction_weno(k, X([Nzm*ones(1,idz-Nzm+k),Nzm:-1:idz-k+2],1:3,:) ),1,3,Ni);
    end
  end
  MFh = (LMFh(:,3,:) + RMFh(:,3,:))/2; %<--using average for flow direction; (zm+dz/2,ACE-i)
  % w at zm+dz/2 with up-/down-wind following Godunov Flux
  wh = squeeze( LMFh(:,3,:).*(MFh>=0) + RMFh(:,3,:).*(MFh<0) )./rho_mfh; % (zm+dz/2,ACE-i)

  % First zero at zm=0 & zeros(k,1) for domain top<---to be improved!!!!!
  dadz = [ zeros(1,3,Ni);
           ( LMFh(2:Nzm-k,:,:).*(MFh(2:Nzm-k,:,:)>=0)+RMFh(2:Nzm-k,:,:).*(MFh(2:Nzm-k,:,:)<0) ...
            -LMFh(1:Nzm-k-1,:,:).*(MFh(1:Nzm-k-1,:,:)>=0)-RMFh(1:Nzm-k-1,:,:).*(MFh(1:Nzm-k-1,:,:)<0) )/dz;
           zeros(k,3,Ni) ];  % (z,var,ACE-i)
  
  if rkstage==1 % Do inv_T_from_theta_e only once for every dt
    % Ivert (T,q,ql,qi) for buoyancy, precipitation, and radiation
    [T, Q, QL, QI] = INV_THETA_E(squeeze(X(:,1,:)), squeeze(X(:,2,:))); % (z,ACE-i)
  end
  % Precipitation sinks
  [dtheta_e, dqt] = PRECIP_SINKS(T, Q, QL, QI); % (z,ACE-i)

% % %   % Radiative forcing
% % %   dT = 1e-8;  
% % %   dtheta_e = dtheta_e+ RF.* ( eval_theta_e(T+dT,Q,QL,QI,p_mf) - eval_theta_e(T,Q,QL,QI,p_mf) )/1e-8;
  
  % Admfdz = (ACE area)*dmfdz for dynamic inflow/outflow
  Admfdz = Ai'.* squeeze(dadz(:,end,:)); % (z,ACE-i)  [da1dz(:,end),da2dz(:,end),da3dz(:,end),da4dz(:,end)]; 
  ED = cumsum(Admfdz,2); % ED(:,[i-1,i]) for ACE-i dynamic entrainment/detrainment
  if Wbar_eq_zero==1
    % Adjust mass flux tendency for outermost ACE for neutual domain mean
    ED(:,end) = 0;
  end
  % EDI(z,var,ACE-i): ACE-i tracer tendency (advection + tur + dyn entrain/detrain)
  EDI = zeros(Nzm,2,Ni);
  for ida=1:Ni
    if ida==1
      EDI(:,:,ida) = - dadz(:,1:2,ida).*X(:,3,ida) ... % - (eps_sl./rho_mf).*(X(:,1:2,ida)-[theta_e_mf,qt_mf]) ...
          - eps_tur(ida,1)*(X(:,1:2,ida)-X(:,1:2,ida+1)) ...
          + ( ED(:,ida).*( (ED(:,ida)>0).*X(:,1:2,ida+1) + (ED(:,ida)<0).*X(:,1:2,ida) ) ...
                                                    -Admfdz(:,ida).*X(:,1:2,ida) )./(rho_mf*Ai(ida));
    elseif ida<Ni
      EDI(:,:,ida) = - dadz(:,1:2,ida).*X(:,3,ida) ... % - (eps_sl./rho_mf).*(X(:,1:2,ida)-[theta_e_mf,qt_mf]) ...
          - eps_tur(ida,1)*(X(:,1:2,ida)-X(:,1:2,ida+1)) - eps_tur(ida,2)*(X(:,1:2,ida)-X(:,1:2,ida-1)) ...
          + ( ED(:,ida).*( (ED(:,ida)>0).*X(:,1:2,ida+1) + (ED(:,ida)<0).*X(:,1:2,ida) ) ...
              -ED(:,ida-1).*( (ED(:,ida-1)>0).*X(:,1:2,ida) + (ED(:,ida-1)<0).*X(:,1:2,ida-1) ) ...
                                                    -Admfdz(:,ida).*X(:,1:2,ida) )./(rho_mf*Ai(ida));
    else
      EDI(:,:,ida) = - dadz(:,1:2,ida).*X(:,3,ida) ... % - (eps_sl./rho_mf).*(X(:,1:2,ida)-[theta_e_mf,qt_mf]) ...
          - eps_tur(ida,1)*(X(:,1:2,ida)-[theta_e_mf,qt_mf]) - eps_tur(ida,2)*(X(:,1:2,ida)-X(:,1:2,ida-1)) ...
          + ( ED(:,ida).*( (ED(:,ida)>0).*[theta_e_mf,qt_mf] + (ED(:,ida)<0).*X(:,1:2,ida) ) ...
              -ED(:,ida-1).*( (ED(:,ida-1)>0).*X(:,1:2,ida) + (ED(:,ida-1)<0).*X(:,1:2,ida-1) ) ...
                                                    -Admfdz(:,ida).*X(:,1:2,ida) )./(rho_mf*Ai(ida));
    end
  end
  % EDMF(z,ACE-i) = massflux tendency (excluding nonlocal & external forcing)
  EDMF = - ( rho_mfh(2:end).*wh(2:end,:).^2 - rho_mfh(1:end-1).*wh(1:end-1,:).^2 )/dz ...
         ... % - eps_sl(2:end).*squeeze(X(2:end,3,:)) ...
         - eps_tur(:,1)'.*( squeeze(X(2:end,3,:))-[squeeze(X(2:end,3,2:end)),zeros(Nzm-1,1)] ) ...
         - eps_tur(:,2)'.*( squeeze(X(2:end,3,:))-[zeros(Nzm-1,1),squeeze(X(2:end,3,1:end-1))] ) ...
         + ( ED(2:end,:).*( (ED(2:end,:)>0).*[squeeze(X(2:end,3,2:end)),zeros(Nzm-1,1)] ...
                             + (ED(2:end,:)<0).*squeeze(X(2:end,3,:)) ) ...
             -[zeros(Nzm-1,1),ED(2:end,1:end-1)].*( ([zeros(Nzm-1,1),ED(2:end,1:end-1)]>0).*squeeze(X(2:end,3,:)) ...
                                                    +([zeros(Nzm-1,1),ED(2:end,1:end-1)]<0).*[zeros(Nzm-1,1),squeeze(X(2:end,3,1:end-1))] )  ...
            )./Ai'; % EDMF(z,ACE-i)

  dXdt = [ EDI+permute(cat(3,dtheta_e,dqt),[1,3,2]), ... 
           ...%permute(NONLOCAL_RESPONSE(T, Q, QL+QI, [zeros(1,Ni);EDMF]) + repmat(EBF*(t<EBT),[1,Ni]),[1,3,2]), ...
           permute(NONLOCAL_RESPONSE(T, Q, QL+QI, [zeros(1,Ni);EDMF]),[1,3,2]), ...
           -permute(cat(3,dtheta_e,dqt),[1,3,2]) ]; % dXdt(z,var,ACE-i)
  dXdt([1,end-10:end],:,:) = 0; % At zm=0 & domain top
  if one_ace_only==1
    dXdt(:,:,2:end) = 0; % Shut down additional ACEs
  end
  if Wbar_eq_zero==1
    % Adjust mass flux tendency for outermost ACE for neutual domain mean
    dXdt(:,3,end) = -sum( dXdt(:,3,1:end-1).*permute(Ai(1:end-1),[3,2,1]),3 )/Ai(end);
  end
  dXdt = dXdt(:);
end

function X = ImDamp(X,dt)
global theta_e_mf qt_mf rho_mf Nzm eps_sl Ni
  X = reshape(X,[Nzm,5,Ni]); % X(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum]
  d = dt*(eps_sl./rho_mf);
  X(:,1:3,:) = ( X(:,1:3,:) + d.*[theta_e_mf,qt_mf,zeros(Nzm,1)] )./(1+d);
  X = X(:);
end

function MF = ImDiffMF(MF,dt,ida)
global rho_mf k dz Nzm eddiffu eddiwin
  % disp(t)
  Xext = [-MF(k:-1:2);MF];
  Nzext = Nzm+k-1; %=length(Xext)/3
  dXextdz = zeros(Nzext,1);

  % Compute MFh(zm+dz/2) from MF(zm) as the mean of up- and down-wind approximations
  LMFh = zeros(Nzm,1); % MFh from more left stencil points
  RMFh = zeros(Nzm,1); % MFh from more right stencil points
  for idz=k+1:Nzext-k+1
    LMFh(idz-k) = reconstruction_weno(k, Xext([idz-k:idz+k-2]) );
    RMFh(idz-k) = reconstruction_weno(k, Xext(flip([idz-k+1:idz+k-1])) );
  end
  MFh = (LMFh + RMFh)/2;
% % %   for idz=k+1:Nzext-k
% % %     dXextdz(idz)...
% % %         = ( reconstruction_weno(k, Xext( [idz-k+1:idz+k-1]*(MFh(idz-k+1)>=0)+flip([idz-k+2:idz+k])*(MFh(idz-k+1)<0) ) ) ...
% % %            - reconstruction_weno(k, Xext( [idz-k:idz+k-2]*(MFh(idz-k)>=0)+flip([idz-k+1:idz+k-1])*(MFh(idz-k)<0) ) ) )/dz;
% % %   end
  dXextdz(k+1:Nzext-k)...
       = ( LMFh(2:Nzm-k).*(MFh(2:Nzm-k)>=0)+RMFh(2:Nzm-k).*(MFh(2:Nzm-k)<0) ...
          -LMFh(1:Nzm-k-1).*(MFh(1:Nzm-k-1)>=0)-RMFh(1:Nzm-k-1).*(MFh(1:Nzm-k-1)<0) )/dz;
  % First zero at zm=0 (dXdz~=0 but dXdt=0 at the end of computation)
  % zeros(k,1) for domain top<---to be improved!!!!!
  dXdz = [0; dXextdz(k+1:Nzext-k); zeros(k,1)]; %length(dXdz)=Nzm  
  % Eddy Diffusion for Momentum
  ED = abs(dXdz)*( eddiffu(ida)*(max(MF./rho_mf)-min(MF./rho_mf))/max(abs(dXdz)+eps)/dz );
  ED = movmax(ED,[1 1]*eddiwin(ida));
  ED = conv(ED,ones(2*eddiwin(ida)+1,1)/(2*eddiwin(ida)+1),'same')*dt; %length(dXdz)=Nzm
  Mat = sparse(1:Nzm-2,1:Nzm-2,1+2*ED(2:end-1),Nzm-2,Nzm-2) +...
        sparse(1:Nzm-3,2:Nzm-2,-ED(2:end-2),Nzm-2,Nzm-2) +...
        sparse(2:Nzm-2,1:Nzm-3,-ED(3:end-1),Nzm-2,Nzm-2);
  MF(2:end-1) = Mat\MF(2:end-1);
  MF([1,end-10:end]) = 0;
end

function dMFdt = NONLOCAL_RESPONSE(T, q, qc, EDMF)
global Tv_mf MB Z zm z g coarse_z Ni
  Tv = eval_Tv(T, q, qc);
  B = g.*(Tv-Tv_mf)./Tv_mf;
  dMFdt = interp1(Z,squeeze(sum(sum(MB.*mean(reshape(( B(1:end-1,:)+B(2:end,:)+EDMF(1:end-1,:)+EDMF(2:end,:) )/2,coarse_z,[],Ni)),2),3)),zm,'pchip');
% % %   dMFdt = interp1(Z,squeeze(sum(sum(MB.*mean(reshape(interp1(zm,B+EDMF,z),coarse_z,[],Ni)),2),3)),zm,'pchip');
  dMFdt(1,:) = 0;
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
global p_mf Nzm theta_e_diag Tim
  Np = size(theta_e,2);
  T = zeros(Nzm,Np);
  q = zeros(Nzm,Np);
  ql = zeros(Nzm,Np);
  qi = zeros(Nzm,Np);
  for idp=1:Np*Nzm
    [T(idp), q(idp), ql(idp), qi(idp)]...
          = inv_T_from_theta_e(theta_e(idp), qt(idp), p_mf(mod(idp-1,Nzm)+1));
  end
% % %   for idp=1:Np
% % %     for idz=1:Nzm
% % %       [T(idz,idp), q(idz,idp), ql(idz,idp), qi(idz,idp)]...
% % %             = inv_T_from_theta_e(theta_e(idz,idp), qt(idz,idp), p_mf(idz));
% % %     end
% % %   end
  % Double check values after inversion
  if theta_e_diag && sum(abs(imag(T(:)))+abs(imag(q(:)))+abs(imag(ql(:)))+abs(imag(qi(:))))>0
    format long
    Ii = ( imag(T(:))~=0 | imag(q(:))~=0 | imag(ql(:))~=0 | imag(qi(:))~=0 );
    disp('Imaginary values occur in thermodynamic inversion:')
    disp('theta_e (K): ')
    disp(theta_e(Ii));
    disp('qt (kg/kg): ')
    disp(qt(Ii));
    disp('p (Pa): ')
    P_MF = repmat(p_mf,[1,Np]);
    disp(P_MF(Ii))
    disp('T (K): ')
    disp(T(Ii));
    disp('q (kg/kg): ')
    disp(q(Ii));
    disp('Double checking inverted values implied theta_e (K): ')
    disp(eval_theta_e(T(Ii),q(Ii),ql(Ii),qi(Ii),P_MF(Ii)))
    disp('theta_e difference (K): ')
    dtheta_e = eval_theta_e(T(Ii),q(Ii),ql(Ii),qi(Ii),P_MF(Ii))-theta_e(Ii);
    disp(dtheta_e)
    Tim(end+1) = 1;
  end
  T = real(T);
  q = real(q);
  ql = real(ql);
  qi = real(qi);
end

function [theta_e, qt, mf, theta, RH, B,... 
          qsat, qv, qc, ql, qi, Tv, T, dtheta_e_pr_accum, pr_accum] = POST_PROCESS(X)
global Tv_mf p_mf Nzm g Ni
  Nt = size(X,2);
  X = reshape(X,[5*Nzm,Ni,size(X,2)]); % X(var&z,ACE-i,time)
  X = permute(X,[1,3,2]); % X(var&z,time,ACE-i)
  theta_e = X(1:Nzm,:,:);
  qt = X(Nzm+1:2*Nzm,:,:);
  mf = X(2*Nzm+1:3*Nzm,:,:);
  dtheta_e_pr_accum = X(3*Nzm+1:4*Nzm,:,:);
  pr_accum = X(4*Nzm+1:end,:,:);
  theta = zeros(Nzm,Nt,Ni);
  qsat = zeros(Nzm,Nt,Ni);
  q = zeros(Nzm,Nt,Ni);
  ql = zeros(Nzm,Nt,Ni);
  qi = zeros(Nzm,Nt,Ni);
  T = zeros(Nzm,Nt,Ni);
  for ida=1:Ni
    for idt=1:Nt
      for idz=1:Nzm
        [T(idz,idt,ida), q(idz,idt,ida), ql(idz,idt,ida), qi(idz,idt,ida)]...
            = inv_T_from_theta_e(theta_e(idz,idt,ida), qt(idz,idt,ida), p_mf(idz));
      end
      theta(:,idt,ida) = eval_theta(T(:,idt,ida),p_mf);
      qsat(:,idt,ida) = eval_qsat(T(:,idt,ida),p_mf,qt(:,idt,ida));
    end
  end
  Tv = eval_Tv(T,q,ql+qi);
  RH = q./qsat;
  B = g.*(Tv-Tv_mf)./Tv_mf;
  qc = (qt-qsat).*(qt>qsat);
  qv = qt-qc;
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

%%
% % % figure('Units','normalized','Position',[0 0 1 1])
% % % cmp = colormap(turbo(Nt));
% % % for i=1:Ni
% % %   subplot(1,Ni,i)
% % %   hold all
% % %   for idt=1:Nt
% % %     plot(theta_e(:,idt,i),zm/1e3,'color',cmp(idt,:),'linewidth',2)
% % %   end
% % %   xlabel(['\theta_e (K)'])
% % %   ylabel('Height (km)')
% % %   ylim([0 40])
% % %   grid on
% % %   box on
% % %   title(['ACE-' num2str(i)])
% % %   set(gca,'fontsize',20)
% % % end

%% Explicit RK time integrators
%%
% %       % SSPRK93 %dt<=22
% %       k1 = expFun(yn);
% %       k2 = expFun(yn+(dt/6)*k1);
% %       k3 = expFun(yn+(dt/6)*(k1+k2));
% %       k4 = expFun(yn+(dt/6)*(k1+k2+k3));
% %       k5 = expFun(yn+(dt/6)*(k1+k2+k3+k4));
% %       k6 = expFun(yn+(dt/6)*(k1+k2+k3+k4+k5));
% %       k7 = expFun(yn+(dt/6)*k1+(dt/15)*(k2+k3+k4+k5+k6));
% %       k8 = expFun(yn+(dt/6)*(k1+k7)+(dt/15)*(k2+k3+k4+k5+k6));
% %       k9 = expFun(yn+(dt/6)*(k1+k7+k8)+(dt/15)*(k2+k3+k4+k5+k6));
% %       yn = yn + (dt/6)*(k1+k7+k8+k9) + (dt/15)*(k2+k3+k4+k5+k6);
% %       % SSPRK93 (low-storage) %dt<=22
% %       K1 = expFun(yn);
% %       K2 = expFun(yn+(dt/6)*K1);
% %       K2 = K2 + expFun(yn+(dt/6)*(K1+K2));
% %       K2 = K2 + expFun(yn+(dt/6)*(K1+K2));
% %       K2 = K2 + expFun(yn+(dt/6)*(K1+K2));
% %       K2 = (K2 + expFun(yn+(dt/6)*(K1+K2)))/15;
% %       K1 = K1 + expFun(yn+dt*(K1/6+K2));
% %       K1 = K1 + expFun(yn+dt*(K1/6+K2));
% %       yn = yn + dt*((K1 + expFun(yn+dt*(K1/6+K2)))/6+K2);
% % %       % SSPRK(10,4) %dt<=22
% % %       k1 = expFun(yn);
% % %       k2 = expFun(yn+(dt/6)*k1);
% % %       k3 = expFun(yn+(dt/6)*(k1+k2));
% % %       k4 = expFun(yn+(dt/6)*(k1+k2+k3));
% % %       k5 = expFun(yn+(dt/6)*(k1+k2+k3+k4));
% % %       k6 = expFun(yn+(dt/15)*(k1+k2+k3+k4+k5));
% % %       k7 = expFun(yn+(dt/15)*(k1+k2+k3+k4+k5)+(dt/6)*k6);
% % %       k8 = expFun(yn+(dt/15)*(k1+k2+k3+k4+k5)+(dt/6)*(k6+k7));
% % %       k9 = expFun(yn+(dt/15)*(k1+k2+k3+k4+k5)+(dt/6)*(k6+k7+k8));
% % %       k10 = expFun(yn+(dt/15)*(k1+k2+k3+k4+k5)+(dt/6)*(k6+k7+k8+k9));
% % %       yn = yn + (dt/10)*(k1+k2+k3+k4+k5 + k6+k7+k8+k9 + k10);
% % %       % SSPRK(10,4) (low-storage) %dt<=22
% % %       K1 = expFun(yn);
% % %       K1 = K1 + expFun(yn+(dt/6)*K1);
% % %       K1 = K1 + expFun(yn+(dt/6)*K1);
% % %       K1 = K1 + expFun(yn+(dt/6)*K1);
% % %       K1 = K1 + expFun(yn+(dt/6)*K1);
% % %       K2 = expFun(yn+(dt/15)*K1);
% % %       K2 = K2 + expFun(yn+(dt/15)*K1+(dt/6)*K2);
% % %       K2 = K2 + expFun(yn+(dt/15)*K1+(dt/6)*K2);
% % %       K2 = K2 + expFun(yn+(dt/15)*K1+(dt/6)*K2);
% % %       yn = yn + (dt/10)*(K1+K2 + expFun(yn+(dt/15)*K1+(dt/6)*K2));
% %       % SSPRK42 %dt<=10
% %       k1 = expFun(yn);
% %       k2 = expFun(yn+(dt/3)*k1);
% %       k3 = expFun(yn+(dt/3)*(k1+k2));
% %       k4 = expFun(yn+(dt/3)*(k1+k2+k3));
% %       yn = yn + (dt/4)*(k1+k2+k3+k4);
% %       % SSPRK42 (low-storage)
% %       K1 = expFun(yn);
% %       K1 = K1 + expFun(yn+(dt/3)*K1);
% %       K1 = K1 + expFun(yn+(dt/3)*K1);
% %       yn = yn + (dt/4)*(K1 + expFun(yn+(dt/3)*K1));
% % %       % eSSPRK54 %dt<=8
% % %       k1 = yn + (0.391752226571890*dt)*expFun(yn);
% % %       k2 = 0.444370493651235*yn + 0.555629506348765*k1 + (0.368410593050371*dt)*expFun(k1);
% % %       k3 = 0.620101851488403*yn + 0.379898148511597*k2 + (0.251891774271694*dt)*expFun(k2);
% % %       Fk3 = expFun(k3);
% % %       k4 = 0.178079954393132*yn + 0.821920045606868*k3 + (0.544974750228521*dt)*Fk3;
% % %       yn = 0.517231671970585*k2 + 0.096059710526147*k3 + (0.063692468666290*dt)*Fk3 +...
% % %            0.386708617503268*k4 + (0.226007483236906*dt)*expFun(k4);
% %       % SSPRK33 %dt<=8
% %       y1 = yn + dt*expFun(yn);
% %       y2 = 0.75*yn + 0.25*(y1 + dt*expFun(y1));
% %       yn = (yn + 2*(y2 + dt*expFun(y2)))/3;
% % %       % SSPRK22 %dt<=6
% % %       y1 = yn + dt*expFun(yn);
% % %       yn = 0.5*(yn + y1 + dt*expFun(y1));
% %       % RK5 %dt=12
% %       K1 = expFun(yn);
% %       yi = yn+(dt/4)*K1;
% %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); % Non-negative qt
% %       K2 = expFun(yi);
% %       yi = yn+(dt/8)*(K1+K2);
% %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
% %       K3 = expFun(yi);
% %       yi = yn+(dt/2)*K3;
% %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
% %       K4 = expFun(yi);
% %       yi = yn+(3*dt/16)*(K1-2*K2+2*K3+3*K4);
% %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
% %       K5 = expFun(yi);
% %       yi = yn+(dt/7)*(-3*K1+8*K2+6*K3-12*K4+8*K5);
% %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
% %       K6 = expFun(yi);
% %       yn = yn + (dt/90)*(7*(K1+K6)+32*(K3+K5)+12*K4);
% %       yn(Inonneg) = yn(Inonneg).*(yn(Inonneg)>0);
% % %       % SSPRK85 (Ruuth-Spiteri) %dt=12
% % %       K1 = expFun(yn);
% % %       yi = yn+(0.276*dt)*K1;
% % %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); % Non-negative qt
% % %       K2 = expFun(yi);
% % %       yi = yn+dt*(0.15*K1+0.289*K2);
% % %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
% % %       K3 = expFun(yi);
% % %       yi = yn+dt*(0.057*K1+0.11*K2+0.203*K3);
% % %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
% % %       K4 = expFun(yi);
% % %       yi = yn+dt*(0.169*K1+0.326*K2+0.451*K3);
% % %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
% % %       K5 = expFun(yi);
% % %       yi = yn+dt*(0.062*K1+0.119*K2+0.199*K3+0.521*K4-0.001*K5);
% % %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
% % %       K6 = expFun(yi);
% % %       yi = yn+dt*(0.111*K1+0.214*K2+0.116*K3+0.223*K4-0.037*K5+0.228*K6);
% % %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
% % %       K7 = expFun(yi);
% % %       yi = yn+dt*(0.071*K1+0.137*K2+0.155*K3+0.043*K4-0.164*K5+0.044*K6+0.103*K7);
% % %       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0);
% % %       K8 = expFun(yi);
% % %       yn = yn + dt*(0.107*K1+0.149*K2+0.105*K3+0.125*K4-0.068*K5+0.128*K6+0.298*K7+0.156*K8);
% % %       yn(Inonneg) = yn(Inonneg).*(yn(Inonneg)>0); 