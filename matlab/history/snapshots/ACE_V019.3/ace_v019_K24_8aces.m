% %% Directory/file paths
dir_ace = pwd;

% Subroutines
dir_util_weno = [dir_ace '/util_weno/'];
dir_util_plume = [dir_ace '/util_plume/'];
dir_util_thermodynamics = [dir_ace '/util_thermodynamics/'];
addpath(dir_util_weno,dir_util_plume,dir_util_thermodynamics)

% Data folder
dir_data = [dir_ace '/data/'];

% Pre-computed anelastic basis for massflux
dir_basis = [dir_data '/basis/'];

% ARM best-estimate soundings (4 options from 3 sites)
dir_armbe = [dir_data '/soundings/'];
armfnlist = {'manus_3hr_ARMBEsonde_profiles.nc';
             'nauru_3hr_ARMBEsonde_profiles.nc';
             'maoarmbeatmM1.c1.20140101.003000.nc'};
           
%% Declare global for in-script functions
global theta_e_mf qt_mf Tv_mf p_mf rho_mf rho_mfh MB Z zm z p g k dz Nzm coarse_z
global eps_tur eps_sl eddiffu eddiwin qc_ramp dqc tau_pr EBF EBT qc_cap dt Ni Ai
global one_ace_only RF Wbar_eq_zero turn_off_mf_diff turn_off_DHv turn_off_DHh no_dyn_pres theta_e_diag Tim
global T Q QL QI
global theta_e_zc qt_zc Tv_zc p_zc rho_zc rho_zi PMB damp

 
%% Loading pre-computed massflux basis
% pcbsfn = 'COMPOSITE_ACE_BASIS_Heaviside_4ACEs.mat';
pcbsfn = 'COMPOSITE_ACE_BASIS_Heaviside_4ACEs.mat';
load([dir_basis pcbsfn]) % PMB(201,200,forcing-region,response-region)
% dcases = DCASES;
D = dcases;% % Horizontal entity diameters in km
Ni = length(D) + 1; % Number of ACEs
Ai =[(pi/4)*[D(1)^2; D(2:end).^2-D(1:end-1).^2]; Lx*Ly-(pi/4)*D(end)^2]; % ACE area in km^2 (index i or ida)
Bi = [pi*D; 2*(Lx+Ly)]; % ACE outer perimeter in km (index i or ida)

%% Restart or continue a run
conti = 0; 
save_output = 0;
output_filename = 'GoAm_idp=314_7-ACEs.mat';

%% Test Turning off nonlocal response
one_ace_only = 0;
Wbar_eq_zero = 0; %enforce domain mean w = 0
reduce_mf_diff = 1;
turn_off_mf_diff = 1;
turn_off_DHv = 0;
turn_off_DHh = 0;
no_dyn_pres = 0;
turn_off_v_nonlocal = 0;
truncate_h_nonlocal = 0;
% Turn off nonlocal interactions
for i=1:Ni %response_region_index
  for j=1:Ni %forcing_region_index
    if truncate_h_nonlocal && abs(i-j)>=truncate_h_nonlocal
      PMB(:,:,j,i) = 0;
    end
    if turn_off_v_nonlocal && i==j
      PMB(:,:,j,i) = [zeros(1,size(PMB,2));eye(size(PMB,2))];
    end
  end
end

%% Set up parameters
plotting = 1;
savefigure = 0;
theta_e_diag = 1; Tim = [];

% ARM sounding option
arm = 1;%3;% %1=Manus/2=Nauru/3,4=GOAmazon
armfn = armfnlist{arm};
pidx = 208;%314;% % Profile index for environment

% Verital grids setup
dz = 100; % m; 5hPa~50m(surface)/250m(aloft)
coarse_z = 200/dz;
ztop = 40e3; % m
z = [dz/2:dz:ztop+dz/2]'; % z-grid for plume computation
zm = [0:dz:ztop]'; % z-grid for mass-flux for entrainment rate
p = [1000:-5:100]'*1e2; % 5-hPa grid

% For precip sinks
qc_ramp = 0.5e-3; % kg/kg; ramping for precip when qc>qc_ramp
dqc = 20; % kg/kg; transition for a smooth onset of precip ramp function
tau_pr = 5*60; % sec; relaxation timescale for precip

% For ODE solver
dt = 6;  % dt=12 for dz=200m and SSPRK93
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
tspan = [0:1:60*2]*60; % sec
Nt = length(tspan);
% Update tspan for continuing runs
if conti==1
  tspan = tspan + t0;
end

% Initial mass flux = MF0*sin(pi*(z-zb)/(zt-zb)) for zb<z<zt (zeros elsewhere)
MF0 = 0*0.5; % kg/m^2/s
zt = 4e3; % km; top of initial MF
zb = 0e3; % km; Base of inital MF

% Initial thermal bubble in zm(BL); BL=[] for no bubble
BL = [11:51]; % BL=bubble levels
dTbl = 1; % T=T+dTbl in BL
dqsat = 1; %1=saturate zm(BL); 0=doing nothing
dqcbl = 0;%10e-3; % kg/kg; qc=dqcbl; ignored if dqsat~=1
dqbl = 0.8; % q=dqbl*q in BL; ignored if dqsat==1

% External buoyancy forcing (mimicking large-scale forcing)
EB = 0.01e-2; % m/s^2; magnitude of external buoyancy
zebb = 0; % Base of external buoyancy  layer
zebt = 14e3; % Top of external buoyancy  layer
% EBF = EB * normpdf(zm,(zebt-zebb)/2,(zebt-zebb)/7) / normpdf(0,0,(zebt-zebb)/7);
EBF = EB * sin(pi*zm/zebt).*(zm<zebt);
EBT = 1*60*60; % sec; EBF turned on for t<EBT

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
eps_tur = permute((nju/1e3)*[Bi./Ai,[0;Bi(1:end-1)./Ai(2:end)]],[3,2,1]); %(nju/1e3)*(4/D); % Note: D in km (4/D=1/G)

% Eddy diffusivity substituting additional dynamic-induced pressure perturbation terms
D_edf = nan(1,Ni);
for i=1:Ni
  PMB_diag = PMB(:,:,i,i);
  PMB_diag = sum(PMB_diag(:,30:50),2);
  PMB_diag = PMB_diag(Z<5e3&Z>1e3); % Fitting using 1<Z<5 km
  ZB = Z(Z<5e3&Z>1e3);
  n_coeff = polyfit(ZB,log(PMB_diag),1);
  D_edf(i) = pi/(n_coeff(1)*1e3);
end
eddiffu = D_edf*1e3/4/pi; %D*1e3/4/pi;
eddiwin = ceil(D_edf*1e3/2/dz); % Sliding window half-width for movmax
% % % eddiffu = [D(1);D(2:end)-D(1:end-1);2*sqrt(Lx*Ly/pi)-D(end)]*1e3/4/pi/dz; %D*1e3/4/pi/dz;
% % % eddiwin = ceil([D(1);D(2:end)-D(1:end-1);2*sqrt(Lx*Ly/pi)-D(end)]*1e3/2/dz); % Sliding window half-width for movmax
if reduce_mf_diff==1
  eddiffu = eddiffu/50;
elseif turn_off_mf_diff==1
  eddiffu = eddiffu*0;
end

% Spounge layer with Newtonian damping at domain top ztop
SLD = 6e3;%3e3; % e-folding depth in m %1e3 in KN23
SLTau = 180; % SL relaxation timescale in s %60 in KN23
% eps_sl = exp( (zm-zm(end))/SLD )/SLTau;
eps_sl = exp( (z-z(end))/SLD )/SLTau;

% WENO scheme (reconstruction uses 2k-1 points)
k = 6; %reconstruction_wenoz for k>=3 (k=2 only for reconstruction_weno)

% Other pre-defined constants
IMPORT_CONSTANTS
Nzm = length(zm);

%% Pre-processing sounding data
[plev, pr, ta, hus, prw, date, hh] = LOAD_SOUNDINGS([dir_armbe armfn], arm);

% Interpolate sounding values to 5-hPa p-grid (_p)
[T_p, q_p, rho_p, z_p] = INTERP_P_GRID(plev, ta(:,pidx), hus(:,pidx));

% Modify humidity to avoid theta_e supersaturation
q_p = TWEAK_THETA_E(T_p, q_p);

% Interpolate sounding values to 50-m z-grid (_env) & zm-grid (_zm)
[T_env, q_env, Tv_env, theta_e_env, rho_env, p_z,...
 T_zm, q_zm, Tv_zm, theta_e_zm, rho_zm, p_zm,...
 theta_zm, theta_es_zm, rh_zm] = INTERP_Z_GRID(T_p, q_p, z_p);

%% Traditional plume computations
qc_cap = 0.5e-3;% kg/kg; capping condensate for traditional plumes
% Deep-inflow B
[theta_e_dib, qt_dib, T_dib, q_dib, ql_dib, qi_dib, B_dib]...
     = ENTRAIN_PLUME(T_p, q_p, rho_p, z_p, p);
% No-mixing
mixing = 0;
[theta_e_nmx, qt_nmx, T_nmx, q_nmx, ql_nmx, qi_nmx, B_nmx]...
     = ENTRAIN_PLUME(T_p, q_p, rho_p, z_p, p, mixing);
% Constant mixing
% mixing = 5e-2; %/5hPa
mixing = 1e-3; %/m
[theta_e_cne, qt_cne, T_cne, q_cne, ql_cne, qi_cne, B_cne]...
     = ENTRAIN_PLUME(T_p, q_p, rho_p, z_p, mixing);

%% Setup for time-integration
day = date(pidx); % Can run multiple pidx cases (by adding a for-loop here)

% _mf(h) = properties of mass flux; will be used as constant reference during time-integration
theta_e_mf = theta_e_zm; 
qt_mf = q_zm;
Tv_mf = Tv_zm;
p_mf = p_zm;
rho_mf = rho_zm; 
rho_mfh = interp1(zm,rho_mf,zm+dz/2,'makima');

% _zc = cell center
theta_e_zc = theta_e_env;
qt_zc = q_env;
Tv_zc = Tv_env;
p_zc = p_z;
rho_zc = rho_env;
rho_zi = rho_zm; 

% For implicit damping
damp = dt*(eps_sl./[rho_zc,rho_zc,rho_mf]);

% Initiate MF(t=0)
MF = MF0*sin( pi*(zm-zb)/(zt-zb) );
MF(zm>zt | zm<zb) = 0;

% Initiate for ODE solver
if conti == 0
  X0 = [theta_e_zc,qt_zc,MF,zeros(Nzm,2),...
        repmat([theta_e_zc,qt_zc,zeros(Nzm,3)],1,Ni-2,1)...
        theta_e_zc,qt_zc,-MF*Ai(1)/Ai(end),zeros(Nzm,2)]; %<---variables defined on zm-grid
  % % X0 = [repmat([theta_e_zc,qt_zc,zeros(Nzm,3)],1,Ni-1,1)...
  % %               theta_e_zc,qt_zc,MF,zeros(Nzm,2)]; %<---variables defined on zm-grid
  t0 = 0;
  % Adding BL/thermal bubble for inner-most ACE
  if ~isempty(BL)
    if dqsat==1
      X0(BL,2) = eval_qsat(T_zm(BL)+dTbl,p_mf(BL)) .* (1-dqcbl);
    else
      X0(BL,2) = q_zm(BL)*dqbl;
    end
    X0(BL,1)=eval_theta_e(T_zm(BL)+dTbl,X0(BL,2),(dqsat==1)*dqcbl*((T_zm(BL)+dTbl)>=T0),(dqsat==1)*dqcbl*((T_zm(BL)+dTbl)<T0),p_mf(BL));
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
if plotting==1
  % figure('Units','normalized','Position',[0 0 1 1]*0.9)
  % cmp = colormap(turbo(Nt));
  % for i=1:Ni
  %   subplot(1,Ni,i)
  %   hold on
  %   for idt=1:Nt
  %     plot(B(:,idt,i),z/1e3,'color',cmp(idt,:),'linewidth',2)
  %   end
  %   xlabel(['Buoy (m/s^2)'])
  %   ylabel('Height (km)')
  %   xlim([-0.2,0.2])
  %   ylim([0 18])
  %   grid on
  %   box on
  %   title(['ACE-' num2str(i)])
  %   set(gca,'fontsize',20)
  % end
  % 
  % figure('Units','normalized','Position',[0 0 1 1]*0.9)
  % cmp = colormap(turbo(Nt));
  % for i=1:Ni
  %   subplot(1,Ni,i)
  %   hold on
  %   for idt=1:Nt
  %     plot(mf(:,idt,i),zm/1e3,'color',cmp(idt,:),'linewidth',2)
  %   end
  % %   if i==1
  % %     xlim([-4 12])
  % %   elseif i==2
  % %     xlim([-3 5])
  % %   elseif i==3
  % %     xlim([-0.8 0.5])
  % %   else
  % %     xlim([-0.15 0.1])
  % %   end
  %   xlabel(['MF (kg/m s^2)'])
  %   ylabel('Height (km)')
  %   ylim([0 18])
  %   grid on
  %   box on
  %   title(['ACE-' num2str(i)])
  %   set(gca,'fontsize',20)
  % end
  % 
  % figure('Units','normalized','Position',[0 0 1 1]*0.9)
  % cmp = colormap(turbo(Nt));
  % for i=1:Ni
  %   subplot(1,Ni,i)
  %   hold on
  %   for idt=1:Nt
  %     plot(qc(:,idt,i)*1e3,z/1e3,'color',cmp(idt,:),'linewidth',2)
  %   end
  %   xlabel(['q_c (g/kg)'])
  %   ylabel('Height (km)')
  %   ylim([0 18])
  %   grid on
  %   box on
  %   title(['ACE-' num2str(i)])
  %   set(gca,'fontsize',20)
  % end
  % 
  figure('Units','normalized','Position',[0 0 1 1]*0.9)
  cmp = colormap(turbo(Nt));
  for i=1:Ni
    subplot(1,Ni,i)
    hold on
    for idt=1:Nt
      plot((qv(:,idt,i)+qc(:,idt,i))*1e3,z/1e3,'color',cmp(idt,:),'linewidth',2)
    end
    xlabel(['q_v (g/kg)'])
    ylabel('Height (km)')
    ylim([0 18])
    grid on
    box on
    title(['ACE-' num2str(i)])
    set(gca,'fontsize',20)
  end
  
  figure('Units','normalized','Position',[0 0 1 1]*0.9)
  cmp = colormap(turbo(Nt));
  for i=1:Ni
    subplot(1,Ni,i)
    hold on
    for idt=1:Nt
      plot(RH(:,idt,i)*1e2,z/1e3,'color',cmp(idt,:),'linewidth',2)
    end
    xlabel(['RH (%)'])
    ylabel('Height (km)')
    ylim([0 18])
    grid on
    box on
    title(['ACE-' num2str(i)])
    set(gca,'fontsize',20)
  end
  
  figure('Units','normalized','Position',[0 0 1 1]*0.9)
  cmp = colormap(turbo(Nt));
  for i=1:Ni
    subplot(1,Ni,i)
    hold on
    for idt=1:Nt
      plot(theta_e(:,idt,i),z/1e3,'color',cmp(idt,:),'linewidth',2)
    end
    xlabel(['\theta_e (K)'])
    ylabel('Height (km)')
    xlim([325 380])
    ylim([0 18])
    grid on
    box on
    title(['ACE-' num2str(i)])
    set(gca,'fontsize',20)
  end

  % figure
  % cmp = colormap(jet(Ni));
  % hold on
  % for idp=1:Ni
  %   plot((tspan(1:end-1)/60+0.5)/60,...
  %        squeeze(sum(pr_accum(:,2:end,idp)-pr_accum(:,1:end-1,idp)))*60,'color',cmp(idp,:))
  % end
  % sig=Ai(1:end)/sum(Ai(1:end));
  % plot((tspan(1:end-1)/60+0.5)/60,...
  %        sum(sig'.*squeeze(sum(pr_accum(:,2:end,:)-pr_accum(:,1:end-1,:)))*60,2),'k','linewidth',2)
  % grid on
  % box on
  % set(gca,'fontsize',15)
  % xlabel('Time (h)')
  % ylabel('Precip (mm/h)')
  % xlim([0 tspan(end)/3600])
  % xticks([0:3:48])
end%plotting

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
      % SSPRK93 (low-storage) for explicit terms
      yn = SSPRK93(yn,t,dt,Inonneg);
      % Implicitly solving massflux diffusion
      if ~turn_off_mf_diff
        yn = ImDiffMF(yn,dt);
      end
      % Implicit Newtonian damping
      yn = ImDamp(yn);
%       disp(norm(yn(:)))
    end%idn
    X(:,idt+1) = yn;
  end%idt
  X = X'; % Consistent with MATLAB ode23
end

function dXdt = expFun(X,t,rkstage)
global theta_e_mf qt_mf rho_mf rho_mfh k dz Nzm eps_tur Ni Ai one_ace_only turn_off_DHv turn_off_DHh 
global EBF EBT RF p_mf zm z
global T Q QL QI
global theta_e_zc qt_zc Tv_zc p_zc rho_zc rho_zi no_dyn_pres
  X = reshape(X,[Nzm,5,Ni]); % X(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum]  
  if rkstage==1 % Do inv_T_from_theta_e only once for every dt
    % Ivert (T,q,ql,qi) for buoyancy, precipitation, and radiation
    [T, Q, QL, QI] = INV_THETA_E(squeeze(X(:,1,:)), squeeze(X(:,2,:))); % (z,ACE-i)
  end
  % Precipitation sinks
  [dtheta_e, dqt] = PRECIP_SINKS(T, Q, QL, QI); % (z,ACE-i)
% % %   % Radiative forcing
% % %   dT = 1e-8;  
% % %   dtheta_e = dtheta_e+ RF.* ( eval_theta_e(T+dT,Q,QL,QI,p_mf) - eval_theta_e(T,Q,QL,QI,p_mf) )/1e-8;
  
  % Compute tracer values Ci(zi) at interface points from C(zc=zi+dz/2)
  Ci = reconstruction_weno_vec(k,X(:,1:2,:),X(:,3,:)); % Ci(zi,var,ACE-i)
  % Vertical velocity w(zi) (mass flux already at zi)
  wi = X(:,3,:)./rho_zi; % (zi,1,ACE-i)
  % Vertical mass flux & velocity at zc=zi+dz/2
  mfc = squeeze(reconstruction_up3(X(:,3,:))); % (zc,1,ACE-i)-->(zc,ACE-i)
  % mfc_up3 = reconstruction_up3(X(:,3,:)); % (zc,1,ACE-i)-->(zc,ACE-i)
  % mfc = squeeze(reconstruction_weno_vec(k,X(:,3,:),mfc_up3));
  % mfc = squeeze(reconstruction_weno_vec_k56asym(k,X(:,3,:),mfc_up3));
%   mfcl = reconstruction_weno_vec(k,X(:,3,:),ones(size(X(:,3,:))));
%   mfcr = reconstruction_weno_vec(k,X(:,3,:),-ones(size(X(:,3,:))));
%   mfc = reconstruction_weno_vec(k,X(:,3,:),permute(mfcl+mfcr,[1,3,2]));
  wc = mfc./rho_zc; % (zc,ACE-i)
  % Admfdz = (ACE area)*dmfdz for dynamic inflow/outflow at zc=zi+dz/2
  Admfdz = Ai'.* squeeze(( X(2:end,3,:)-X(1:end-1,3,:) )/dz); % (zc,1,ACE-i)-->(zc,ACE-i); size(Admfdz)=(Nzm-1,Ni)
  % ioflow = -Bi*rho_0*u_n (minus h. mass flux * lateral boundary length)
  ioflow = permute(cumsum(Admfdz,2),[1,3,2]); % ioflow(:,1,[i-1,i]) for ACE-i dynamic inflow/outflow
  % Vertical tracer flux rho_0*w*C at zi
  rho0wC = X(:,3,:).*Ci; % (zi,var,ACE-i)
  % Set surface fluxes
  rho0wC(1,:,:) = 0; % First try: zeros surface flux
  % Compute flux-based tendencies at zc=zi+dz/2
  dCdt = zeros(Nzm-1,2,Ni); % Add zeros(1,2,Ni) for model top at the end
  dCdt(:,:,1) = -eps_tur(1,1,1)*( X(1:end-1,1:2,1)-X(1:end-1,1:2,2) )... % Turbulent entrainment
                +( ioflow(:,1,1).*( (ioflow(:,1,1)>0).*X(1:end-1,1:2,2) + (ioflow(:,1,1)<0).*X(1:end-1,1:2,1) )/Ai(1)...
                  -( rho0wC(2:end,:,1)-rho0wC(1:end-1,:,1) )/dz )./rho_zc(1:end-1); % Vertical mean flux convergence
  dCdt(:,:,2:Ni-1) = -eps_tur(1,1,2:Ni-1).*( X(1:end-1,1:2,2:Ni-1)-X(1:end-1,1:2,3:Ni) )...  % Turbulent entrainment
                     -eps_tur(1,2,2:Ni-1).*( X(1:end-1,1:2,2:Ni-1)-X(1:end-1,1:2,1:Ni-2) )... 
                     +( ( ioflow(:,1,2:Ni-1).*( (ioflow(:,1,2:Ni-1)>0).*X(1:end-1,1:2,3:Ni) + (ioflow(:,1,2:Ni-1)<0).*X(1:end-1,1:2,2:Ni-1) )...
                         -ioflow(:,1,1:Ni-2).*( (ioflow(:,1,1:Ni-2)>0).*X(1:end-1,1:2,2:Ni-1) + (ioflow(:,1,1:Ni-2)<0).*X(1:end-1,1:2,1:Ni-2) ) )./permute(Ai(2:Ni-1),[3,2,1])...
                       -( rho0wC(2:end,:,2:Ni-1)-rho0wC(1:end-1,:,2:Ni-1) )/dz )./rho_zc(1:end-1); % Vertical mean flux convergence          
  dCdt(:,:,Ni) = -eps_tur(1,1,Ni).*( X(1:end-1,1:2,Ni)-[theta_e_zc(1:end-1),qt_zc(1:end-1)] )... % Turbulent entrainment
                 -eps_tur(1,2,Ni).*( X(1:end-1,1:2,Ni)-X(1:end-1,1:2,Ni-1) )...              
                 +( ( ioflow(:,1,Ni).*( (ioflow(:,1,Ni)>0).*[theta_e_zc(1:end-1),qt_zc(1:end-1)] + (ioflow(:,1,Ni)<0).*X(1:end-1,1:2,Ni) )...
                     -ioflow(:,1,Ni-1).*( (ioflow(:,1,Ni-1)>0).*X(1:end-1,1:2,Ni) + (ioflow(:,1,Ni-1)<0).*X(1:end-1,1:2,Ni-1) ) )/Ai(Ni)...
                   -( rho0wC(2:end,:,Ni)-rho0wC(1:end-1,:,Ni) )/dz )./rho_zc(1:end-1); % Vertical mean flux convergence
  % F(zc,ACE-i) = local non-PGF dynamic forcing for mass flux (excluding buoyancy and nonlocal effect) 
  ioflow = squeeze(ioflow); % (Nzm-1,1,Ni)-->(Nzm-1,Ni) at zc=zi+dz/2
  % FH(zc,ACE-i) with size(FH)=(Nzm-1,Ni); turbulent entrainment & horizontal in/outflow---to be doubled to include a(D_H) contribution
  FH = -squeeze(eps_tur(1,1,:))'.*( mfc(1:end-1,:)-[mfc(1:end-1,2:Ni),mfc(1:end-1,Ni)] )...
       -squeeze(eps_tur(1,2,:))'.*( mfc(1:end-1,:)-[mfc(1:end-1,1),mfc(1:end-1,1:Ni-1)] )... % Turbulent entrainment
       +( ioflow.*( (ioflow>0).*[wc(1:end-1,2:Ni),wc(1:end-1,Ni)] + (ioflow<0).*wc(1:end-1,:) )... % Horizontal inflow/outflow
         -[zeros(Nzm-1,1),ioflow(:,1:Ni-1)].*( ([zeros(Nzm-1,1),ioflow(:,1:Ni-1)]>0).*wc(1:end-1,:) + ([zeros(Nzm-1,1),ioflow(:,1:Ni-1)]<0).*[zeros(Nzm-1,1),wc(1:end-1,1:Ni-1)] ) )./Ai';
  % F(zc,ACE-i) with size(F)=(Nzm-1,Ni); fill zeros(1,Ni) at domain top later
  F = (2-turn_off_DHv)*FH - squeeze( X(2:end,3,:).*wi(2:end,1,:)-X(1:end-1,3,:).*wi(1:end-1,1,:) )/dz; % Plus vertical mean flux convergence
% % %   Admfdzi = Ai'.* squeeze(( mfc(2:end,:,:)-mfc(1:end-1,:,:) )/dz); % (zc,1,ACE-i)-->(zc,ACE-i); size(Admfdzi)=(Nzm-1,Ni) at zi(2:end)
% % %   % ioflowi = -Bi*rho_0*u_n (minus h. mass flux * lateral boundary length) at zi
% % %   ioflowi = squeeze(permute(cumsum(Admfdzi,2),[1,3,2])); % (Nzm-1,1,Ni)-->(Nzm-1,Ni) at zi(2:end)
% % %   % FHi(zi,ACE-i) with size(FHi)=(Nzm,Ni); fill zeros(1,Ni) at surface
% % %   FHi = [zeros(1,Ni);
% % %          -squeeze(eps_tur(1,1,:))'.*( mfi(1:end-1,:)-[mfi(1:end-1,2:Ni),mfi(1:end-1,Ni)] )-...
% % %           squeeze(eps_tur(1,2,:))'.*( mfi(1:end-1,:)-[mfi(1:end-1,1),mfi(1:end-1,1:Ni-1)] )+... % Turbulent entrainment
% % %           ( ioflowi.*( (ioflowi>0).*[wi(1:end-1,2:Ni),wi(1:end-1,Ni)] + (ioflowi<0).*wi(1:end-1,:) )-... % Horizontal inflow/outflow
% % %             [zeros(Nzm-1,1),ioflowi(:,1:Ni-1)].*( ([zeros(Nzm-1,1),ioflowi(:,1:Ni-1)]>0).*wi(1:end-1,:) + ([zeros(Nzm-1,1),ioflowi(:,1:Ni-1)]<0).*[zeros(Nzm-1,1),wi(1:end-1,1:Ni-1)] ) )]./Ai';
  % Simple computation of FHi and Fi yields stable integration when nonlocal effect is completely shutdown
  FHi = [zeros(1,Ni);0.5*( FH(1:end-1,:)+FH(2:end,:) );zeros(1,Ni)];
  Fi = [zeros(1,Ni);0.5*( F(1:end-1,:)+F(2:end,:) );zeros(1,Ni)];
%   FHi = interp1(z(2:end),FH,zm,'makima',0);
%   Fi = interp1(z(2:end),F,zm,'makima',0);
  % Recall X(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum] 
  dXdt = [ [dCdt;zeros(1,2,Ni)]+permute(cat(3,dtheta_e,dqt),[1,3,2]),...
           permute((1-turn_off_DHv)*FHi+no_dyn_pres*Fi+ ...%Flg+...
                   NONLOCAL_RESPONSE(T,Q,QL+QI,(1-no_dyn_pres)*[F;zeros(1,Ni)])+repmat(EBF*(t<EBT),[1,Ni]),[1,3,2]), ...
           -permute(cat(3,dtheta_e,dqt),[1,3,2]) ]; % dXdt(z,var,ACE-i)
  dXdt(end-10:end,1:3,:) = 0; % At domain top
  if one_ace_only==1
    dXdt(:,:,2:end) = 0; % Shut down additional ACEs
  end
  dXdt = dXdt(:);
end

function X = ImDamp(X)
global Nzm Ni theta_e_zc qt_zc damp
  X = reshape(X,[Nzm,5,Ni]); % X(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum]
  % damp = dt*(eps_sl./[rho_zc,rho_zc,rho_mf])
  X(:,1:3,:) = ( X(:,1:3,:) + damp.*[theta_e_zc,qt_zc,zeros(Nzm,1)] )./(1+damp);
  X = X(:);
end

function X = ImDiffMF(X,dt)
global Nzm Ni eddiffu eddiwin rho_zi dz
  X = reshape(X,[Nzm,5,Ni]); % X(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum]
  % Vertical velocity w(zi) (mass flux already at zi)
  wi = squeeze(X(:,3,:)./rho_zi); % (zi,1,ACE-i)-->(zi,ACE-i)
  drho0wdz = squeeze( (X(2:end,3,:)-X(1:end-1,3,:))/dz ); % (zc,ACE-i); size(drho0wdz)=[Nzm-1,Ni]
  % Vertical momentum diffusion coefficients
  mu_1 = abs(drho0wdz).*( eddiffu.*( max(wi)-min(wi) )./max(abs(drho0wdz)+eps) ); % (zc,ACE-i); size=[Nzm-1,Ni]
  c = dz/dt;
  for ida=1:Ni
    mu_2 = movmax(mu_1(:,ida),[1 1]*eddiwin(ida)); % (zc,ACE-i); size=[Nzm-1,1]
    mu_D = conv(mu_2,ones(2*eddiwin(ida)+1,1)/(2*c*eddiwin(ida)+1),'same'); % (zc,ACE-i); size=[Nzm-1,1]
    Mat = sparse(1:Nzm-2,1:Nzm-2,(c+mu_D(1:end-1)+mu_D(2:end)),Nzm-2,Nzm-2)+...
          sparse(1:Nzm-3,2:Nzm-2,-mu_D(2:end-1),Nzm-2,Nzm-2)+...
          sparse(2:Nzm-2,1:Nzm-3,-mu_D(2:end-1),Nzm-2,Nzm-2);
    X(2:end-1,3,ida) = Mat\( c*X(2:end-1,3,ida) );
  end%ida
  % Double check w=0 at surface and model top
  X([1,end-10:end],3,:) = 0;
  X = X(:);
end

function dMFdt = NONLOCAL_RESPONSE(T, q, qc, F)
global Tv_zc Z zm  g coarse_z Ni PMB rho_zc
  Tv = eval_Tv(T, q, qc);
  rho0B = g*rho_zc.*(Tv-Tv_zc)./Tv_zc;
  if coarse_z==1
    dMFdt = squeeze(sum(sum(PMB.*reshape((rho0B(1:end-1,:)+F(1:end-1,:)),coarse_z,[],Ni),2),3)); % (zi,ACE-i)
  else
    dMFdt = interp1(Z,squeeze(sum(sum(PMB.*mean(reshape((rho0B(1:end-1,:)+F(1:end-1,:)),coarse_z,[],Ni)),2),3)),zm,'makima'); % (zi,ACE-i)
  end
end

function [dtheta_e, dqt] = PRECIP_SINKS(T, q, ql, qi)
global p_zc qc_ramp dqc tau_pr 
  qc = ql+qi;
  dqt = -(qc_ramp/dqc/tau_pr) * log( 1+exp( (dqc/qc_ramp) * (qc-qc_ramp) ) );
  % Finite-difference estimate for d(theta_e)/dqc
  dql = 1e-8*ql./qc;
  dqi = 1e-8*qi./qc;
  dtheta_e = dqt.* ( eval_theta_e(T,q,ql+dql,qi+dqi,p_zc) - eval_theta_e(T,q,ql,qi,p_zc) )/1e-8;
  % Check qc>0
  dqt(qc<=0) = 0;
  dtheta_e(qc<=0) = 0;
end

function [T, q, ql, qi] = INV_THETA_E(theta_e, qt)
global p_zc Nzm theta_e_diag Tim
  Np = size(theta_e,2);
  T = zeros(Nzm,Np);
  q = zeros(Nzm,Np);
  ql = zeros(Nzm,Np);
  qi = zeros(Nzm,Np);
  for idp=1:Np*Nzm
    [T(idp), q(idp), ql(idp), qi(idp)]...
          = inv_T_from_theta_e(theta_e(idp), qt(idp), p_zc(mod(idp-1,Nzm)+1));
  end
% %   Np = size(theta_e,2);
% %   GTH = gpuArray(theta_e);
% %   GQT = gpuArray(qt);
% %   GPZ = gpuArray(repmat(p_zc,[1,Np]));
% %   GT = gpuArray(zeros(Nzm,Np));
% %   Gq = gpuArray(zeros(Nzm,Np));
% %   Gql = gpuArray(zeros(Nzm,Np));
% %   Gqi = gpuArray(zeros(Nzm,Np));
% %   [GT,Gq,Gql,Gqi] = arrayfun(@inv_T_from_theta_e,GTH,GQT,GPZ);
% %   T = gather(GT);
% %   q = gather(Gq);
% %   ql = gather(Gql);
% %   qi = gather(Gqi);
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
global Tv_zc p_zc Nzm g Ni
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
            = inv_T_from_theta_e(theta_e(idz,idt,ida), qt(idz,idt,ida), p_zc(idz));
      end
      theta(:,idt,ida) = eval_theta(T(:,idt,ida),p_zc);
      qsat(:,idt,ida) = eval_qsat(T(:,idt,ida),p_zc,qt(:,idt,ida));
    end
  end
  Tv = eval_Tv(T,q,ql+qi);
  RH = q./qsat;
  B = g.*(Tv-Tv_zc)./Tv_zc;
  qc = (qt-qsat).*(qt>qsat);
  qv = qt-qc;
end

function q_tw = TWEAK_THETA_E(T_p, q_p)
global p
  theta_e = eval_theta_e(T_p,q_p,0,0,p);
  theta_es = eval_theta_es(T_p,p);
  theta_tw = theta_e;
  theta_tw(theta_e>theta_es) = theta_es(theta_e>theta_es);
  q_tw = q_p;
  for idz=1:length(theta_e)
    if theta_es(idz)<theta_e(idz)
      dq = 999;
      while dq>1e-7
        dq = 1e-8*( eval_theta_e(T_p(idz),q_tw(idz),0,0,p(idz))-theta_tw(idz) )...
                  /( eval_theta_e(T_p(idz),q_tw(idz)+1e-8,0,0,p(idz))-eval_theta_e(T_p(idz),q_tw(idz),0,0,p(idz)) );
        q_tw(idz) = q_tw(idz) - dq;
      end
    end
  end%idz
  q_tw(q_tw<=0) = q_p(q_tw<=0);
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
    T_env(:,pidx) = interp1(z_p(:,pidx),T_p(:,pidx),z,'makima',T_p(end,pidx));
    q_env(:,pidx) = interp1(z_p(:,pidx),q_p(:,pidx),z,'makima',q_p(end,pidx));
    q_env(q_env(:,pidx)<0,pidx) = 0; % Fix negative q_env due to interp1
    Tv_env(:,pidx) = eval_Tv(T_env(:,pidx),q_env(:,pidx));
    p_z(:,pidx) = interp1(z_p(:,pidx),p,z,'makima');
    midz = sum(z<=max(z_p(:,pidx)));
    for idz=midz+1:length(z)
      p_z(idz,pidx) = p_z(idz-1,pidx)*(1-g*dz/2/RD/Tv_env(idz-1,pidx))/(1+g*dz/2/RD/Tv_env(idz-1,pidx));
    end
    T_zm(:,pidx) = interp1(z_p(:,pidx),T_p(:,pidx),zm,'makima',T_p(end,pidx));
    q_zm(:,pidx) = interp1(z_p(:,pidx),q_p(:,pidx),zm,'makima',q_p(end,pidx));
    q_zm(q_zm(:,pidx)<0,pidx) = 0; % Fix negative q_zm due to interp1
    Tv_zm(:,pidx) = eval_Tv(T_zm(:,pidx),q_zm(:,pidx));
    p_zm(:,pidx) = interp1(z_p(:,pidx),p,zm,'makima');
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
    T_p(:,pidx) = interp1(plev,ta(:,pidx),p,'makima');
    q_p(:,pidx) = interp1(plev,hus(:,pidx),p,'makima');
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

function yn = SSPRK93(yn,t,dt,Inonneg)
global Wbar_eq_zero Nzm Ni
  K1 = expFun(yn,t,1); %expFun(y,rkstage)
  yi = yn+(dt/6)*K1;
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); % Non-negative qt
  K2 = expFun(yi,t,2);
  yi = yn+(dt/6)*(K1+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
  K2 = K2 + expFun(yi,t,3);
  yi = yn+(dt/6)*(K1+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
  K2 = K2 + expFun(yi,t,4);
  yi = yn+(dt/6)*(K1+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
  K2 = K2 + expFun(yi,t,5);
  yi = yn+(dt/6)*(K1+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
  K2 = (K2 + expFun(yi,t,6))/15;
  yi = yn+dt*(K1/6+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
  K1 = K1 + expFun(yi,t,7);
  yi = yn+dt*(K1/6+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0);
  K1 = K1 + expFun(yi,t,8);
  yi = yn+dt*(K1/6+K2);
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0);
  yn = yn + dt*((K1 + expFun(yi,t,9))/6+K2);
  yn(Inonneg) = yn(Inonneg).*(yn(Inonneg)>0); % Non-negative qt
  if Wbar_eq_zero==1
    % Adjust mass flux tendency for outermost ACE for neutual domain mean
    yn = reshape(yn,[Nzm,5,Ni]);
    yn(:,3,:) = yn(:,3,:) - mean(yn(:,3,:),3);
    yn = yn(:);
  end
end

function yn = SSPRK33(yn,t,dt,Inonneg)
global Wbar_eq_zero  Nzm Ni
  K1 = expFun(yn,t,1); %expFun(y,rkstage)
  yi = yn+dt*K1;
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); % Non-negative qt
  K2 = yi+dt*expFun(yi,t,2);
  yi = 0.75*yn+0.25*K2;
%       yi(Inonneg) = yi(Inonneg).*(yi(Inonneg)>0); 
  K2 = yi+dt*expFun(yi,t,3);
  yn = (yn+2*K2)/3;
  yn(Inonneg) = yn(Inonneg).*(yn(Inonneg)>0); % Non-negative qt
  if Wbar_eq_zero==1
    % Adjust mass flux tendency for outermost ACE for neutual domain mean
    yn = reshape(yn,[Nzm,5,Ni]);
    yn(:,3,:) = yn(:,3,:) - mean(yn(:,3,:),3);
    yn = yn(:);
  end
end

%%
% % % figure('Units','normalized','Position',[0 0 1 1]*0.9)
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