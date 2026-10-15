format long
%% Directory/file paths
dir_ace = fileparts(mfilename('fullpath'));
addpath(dir_ace);
input_mode=getenv('ACE_INPUT_MODE');
if isempty(input_mode), input_mode='shared'; end
assert(ismember(input_mode,{'shared','legacy'}), 'ACE_INPUT_MODE must be shared or legacy');
shared_input=strcmp(input_mode,'shared');
input_file=getenv('ACE_INPUT_FILE');
if isempty(input_file), input_file=fullfile(dir_ace,'../data/input/goamazon314_88aces.nc'); end
if shared_input
  input=read_shared_input(input_file);
  assert(strcmp(input.schema,'ACE-case-input-2') && strcmp(input.geometry,'slab'), ...
      'KHN26 driver requires schema 2 slab geometry');
end

% Subroutines
dir_util_weno = [dir_ace '/util_weno/'];
dir_util_plume = [dir_ace '/util_plume/'];
dir_util_timeint = [dir_ace '/util_timeint/'];
dir_util_thermodynamics = [dir_ace '/util_thermodynamics/'];
addpath(dir_util_weno,dir_util_plume,dir_util_timeint,dir_util_thermodynamics)

% Data folder
% dir_data = [dir_ace '/../../data/'];
dir_data = fullfile(dir_ace,'data/');
legacy_data=getenv('ACE_LEGACY_DATA');
if ~isempty(legacy_data), dir_data=[legacy_data '/']; end
% dir_data = 'C:\Users\r9822\Dropbox\JULIACE\data\';

% Pre-computed anelastic basis for massflux
dir_basis = [dir_data  '/basis/'];

% ARM best-estimate soundings (4 options from 3 sites)
%dir_armbe = [dir_data '/soundings/'];
%armfnlist = {'manus_3hr_ARMBEsonde_profiles.nc';
%             'nauru_3hr_ARMBEsonde_profiles.nc';
%             'maoarmbeatmM1.c1.20140101.003000.nc'};
dir_armbe = [dir_data '/soundings/'];
armfnlist = {'acelevels_manaus.nc',
             'acelevels_manus.nc',
             'acelevels_nauru.nc',
             'acelevels_sgp.nc'};


%% Restart or continue a run
conti = 0; 
restart = 0; % conti with initial conditions reset
ensemble = 0; % Check dTbl=0.5K for ensemble
save_output = 1;
% output_filename = 'GoAmazon_idp=314_2DUNEVEN61ACEs_KHN26_dz=100m_kknw25linear-2clouds.mat'; %Ex~1.5s/1s; Im~1.3s/1s
% output_filename = 'GoAmazon_idp=314_2D101ACEs_KHN26_dz=100m_ensemble.mat'; %Ex~1.5s/1s; Im~1.3s/1s
%output_filename = 'GoAmazon_idp=314_2DUNEVEN41ACEs_KHN26_dz=100m-1cloud.mat';
output_filename = 'goamazon314_88aces.nc';
output_override=getenv('ACE_OUTPUT_FILE');
if ~isempty(output_override), output_filename=output_override; end

%%
%%
% load(['/home/yhkuo/Desktop/OUTPUT/' output_filename])
%%
%%

%% Loading pre-computed massflux basis
pcbsfn = 'COMPOSITE_ACE_BASIS_2D_KHN26_4UNEVEN.mat';%'COMPOSITE_ACE_BASIS_2D_KHN26_UNEVEN41ACEs.mat';%
if conti==0
  if shared_input
    PMB=input.PMB; PMDv=input.PMDv; PMD=input.PMD;
    D=(input.ace_width(:)/1000)'; Z=input.basis_z;
  else
    load([dir_basis pcbsfn]) % PMB(edge,coarse,forcing,response)
  end
%   D = 5*ones(1,88);%DCASES; % Horizontal entity diameters in km
  Ni = length(D); % Number of ACEs
  Ai = D'; % ACE area in km^2 (index i or ida)
  Bi = ones(Ni,1); % ACE outer perimeter in km (index i or ida)
  if shared_input
    Ai=input.ace_area(:)/1e6; Bi=input.ace_perimeter(:)/1000;
  end
end

%nzi = size(PMB,1);
%nzc = size(PMB,2);
%nfor = size(PMB,3);
%nres = size(PMB,4);
%
%ncoutput = 'mf_KHN26_4UNEVEN.nc';
%if isfile(ncoutput)
%  delete(ncoutput);
%end
%nccreate(ncoutput,'R','Dimensions',{'ncols-response',nres},'format','netcdf4')
%Dout = D;
%ncwrite(ncoutput,'R',Dout/2.*1.e3)
%ncwriteatt(ncoutput,'R','long_name','Width of slab ACE columns')
%ncwriteatt(ncoutput,'R','units','m')
%nccreate(ncoutput,'B','Dimensions',{'ncols-response',nres})
%ncwrite(ncoutput,'B',Bi*1.e3)
%ncwriteatt(ncoutput,'B','long_name','Perimeter of ACE columns')
%ncwriteatt(ncoutput,'B','units','m')
%nccreate(ncoutput,'A','Dimensions',{'ncols-response',nres})
%ncwrite(ncoutput,'A',Ai*1.e6)
%ncwriteatt(ncoutput,'A','long_name','Area of ACE columns')
%ncwriteatt(ncoutput,'A','units','m^2')
%nccreate(ncoutput,'Zc','Dimensions',{'nzc',nzc})
%ncwrite(ncoutput,'Zc',Z(1:nzc))
%ncwriteatt(ncoutput,'Zc','long_name','Height of grid center')
%ncwriteatt(ncoutput,'Zc','units','m')
%nccreate(ncoutput,'Zi','Dimensions',{'nzi',nzi})
%ncwrite(ncoutput,'Zi',Z)
%ncwriteatt(ncoutput,'Zi','long_name','Height of grid interface')
%ncwriteatt(ncoutput,'Zi','units','m')
%nccreate(ncoutput,'PMB','Dimensions',{'ncols-response',nres,'ncols-forcing',nfor,'nzc',nzc,'nzi',nzi})
%ncwrite(ncoutput,'PMB',permute(PMB,[4,3,2,1]))
%ncwriteatt(ncoutput,'PMB','long_name','Precomputed massflux basis')
%ncwriteatt(ncoutput,'PMB','units','unitless')
%
%error("output")


%% Test Turning off nonlocal response
one_ace_only = 0;
Wbar_eq_zero = 1; %enforce domain mean w = 0
reduce_mf_diff = 1;
activate_mf_diff = 0; %(0,1,2)=(no,explecit,implicit) mass flux diffusion;  %(42,41,42)s per min with (dz,ztop)=(100,40e3)m
turn_off_DHv = 0;
turn_off_DHh = 0;
% Explicit switches retain an off mode for control and historical cases.
for option={'DHH','DHV'}
  value=getenv(['ACE_' option{1}]);
  if ~isempty(value)
    assert(ismember(value,{'on','off'}), 'ACE_DHH/ACE_DHV must be on or off');
    if strcmp(option{1},'DHH'), turn_off_DHh=strcmp(value,'off');
    else, turn_off_DHv=strcmp(value,'off'); end
  end
end
turn_off_v_nonlocal = 0;
truncate_h_nonlocal = 0;
zero_ref_buoyancy = 1;
if shared_input
  assert(turn_off_DHv || ~strcmp(input.PMDv_source_status,'disabled_zero_placeholder'), ...
      'Cannot activate unavailable PMDv');
  assert(turn_off_DHh || ~strcmp(input.PMD_source_status,'disabled_zero_placeholder'), ...
      'Cannot activate unavailable PMD');
end
for i=1:Ni %response_region_index
  for j=1:Ni %forcing_region_index
    if truncate_h_nonlocal && abs(i-j)>=truncate_h_nonlocal
      PMB(:,:,j,i) = 0;
      PMD(:,:,j,i) = 0;
      PMDv(:,:,j,i) = 0;
    end
    if turn_off_v_nonlocal && i==j
      PMB(:,:,j,i) = [zeros(1,size(PMB,2));eye(size(PMB,2))];
      PMD(:,:,j,i) = [zeros(1,size(PMD,2));eye(size(PMD,2))];
      PMDv(:,:,j,i) = [zeros(1,size(PMDv,2));eye(size(PMDv,2))]; 
    end
  end
end
if turn_off_DHv
  PMDv = 0;
end
if turn_off_DHh
  PMD = 0;
end

%% Set up parameters
plotting = 0;
savefigure = 1;
theta_e_diag = 1; 

% ARM sounding option
arm = 1;%1;% %1=Manus/2=Nauru/3,4=GOAmazon
armfn = armfnlist{arm};
pidx = 314;%208;% % Profile index for environment
pidx = 1342;
case_profile_index=pidx;
if shared_input
  arm=input.arm; case_profile_index=input.profile_index; pidx=1;
end

% Verital grids setup
dz = 100; % m; 5hPa~50m(surface)/250m(aloft)
coarse_z = 200/dz;
ztop = 40e3; % m
z = [dz/2:dz:ztop+dz/2]'; % z-grid for plume computation
zm = [0:dz:ztop]'; % z-grid for mass-flux for entrainment rate
p = [1000:-5:100]'*1e2; % nominal, unused grid in processed-input mode
if shared_input
  dz=input.dz; z=input.z; zm=input.zm; p=input.p;
  ztop=zm(end); coarse_z=(numel(zm)-1)/size(PMB,2);
end

% For precip sinks
qc_ramp = 0.5e-3; % kg/kg; ramping for precip when qc>qc_ramp
dqc = 20; % kg/kg; transition for a smooth onset of precip ramp function
tau_pr = 5*60; % sec; relaxation timescale for precip

% For ODE solver
dt = 6;  % dt=12 for dz=200m and SSPRK93
value=getenv('ACE_DT');
if ~isempty(value), dt=str2double(value); end
assert(isscalar(dt) && isfinite(dt) && dt>0, 'ACE_DT must be positive');
assert(abs(60/dt-round(60/dt))<=64*eps*max(1,60/dt), 'dt must divide 60 s');
% Initiate for continuing runs
if conti==1
  Xminus1 = X(:,:,:,1:end-1); % X(z,var,ACE-i,time)
  tminus1 = tspan(1:end-1);
  X0 = X(:,:,:,end);
  t0 = tspan(end); % t0=starting time; T0=triple point temperature.
  disp('Continue Previous Run...')
else
  disp('Start Anew!')
end
% DO NOT MODIFY THE IF SECTION
tspan = [0:1:60*8]*60; % sec
step_count=getenv('ACE_STEPS');
if ~isempty(step_count)
  steps=str2double(step_count); assert(isfinite(steps) && steps>=1 && steps==fix(steps));
  tspan=(0:steps)*dt;
end
%tspan = [0:6:60];
Nt = length(tspan);
% Update tspan for continuing runs
if conti==1
  tspan = tspan + t0;
end

% Initial mass flux = MF0*sin(pi*(z-zb)/(zt-zb)) for zb<z<zt (zeros elsewhere)
MF0 = 0*5; % kg/m^2/s
zt = 4e3; % km; top of initial MF
zb = 0e3; % km; Base of inital MF

% Initial thermal bubble in zm(BL); BL=[] for no bubble
BL = [11:51];%[21:101];% % BL=bubble levels
dTbl = 0.25;%-5;% % T=T+dTbl in BL
dqsat = 1; %1=saturate zm(BL); 0=doing nothing
dqcbl = 0;%5e-3; % kg/kg; qc=dqcbl; ignored if dqsat~=1
dqbl = 0.8; % q=dqbl*q in BL; ignored if dqsat==1

% External buoyancy forcing (mimicking large-scale forcing)
EB = 0.01e-2; % m/s^2; magnitude of external buoyancy
zebb = 0; % Base of external buoyancy  layer
zebt = 14e3; % Top of external buoyancy  layer
% EBF = EB * normpdf(zm,(zebt-zebb)/2,(zebt-zebb)/7) / normpdf(0,0,(zebt-zebb)/7);
EBF = EB * sin(pi*zm/zebt).*(zm<zebt);
EBT = 0*60*60; % sec; EBF turned on for t<EBT

%% Radiatively imposed profile (RIP)
%RIP = -1.5; % K/day
%zr = [0 9e3 14e3]';
%vr = [1 1.5 0]';
%gf = normpdf([-20:20]'*dz,0,300); % Gaussian filter for smoothing
%vrzm = conv(interp1(zr,vr,zm,'linear',0),gf,'same');
%RF = vrzm/max(vrzm)*RIP/3600/24; % ~dT/dt in K/s

% Turbulent entrainment rate
nju = 0.09; % Morrison (2017)
% eps_tur 1st/2nd column for outer/inner boundary of ACE-i
eps_tur = permute((nju/1e3)*[Bi./Ai,[0;Bi(1:end-1)./Ai(2:end)]],[3,2,1]); %(nju/1e3)*(4/D); % Note: D in km (4/D=1/G)
eps_tur(1,1,end) = 0;

% Eddy diffusivity substituting additional dynamic-induced pressure perturbation terms
D_edf = 5; % km
eddiffu = D_edf*1e3/4/pi; % km-->m
eddiwin = ceil(D_edf*1e3/2/dz); % Sliding window half-width for movmax
if reduce_mf_diff==1
  eddiffu = eddiffu/100;
elseif activate_mf_diff==0
  eddiffu = eddiffu*0;
end

% Spounge layer with Newtonian damping at domain top ztop
SLD = 6e3;%3e3; % e-folding depth in m %1e3 in KN23
SLTau = 180; % SL relaxation timescale in s %60 in KN23
eps_sl = exp( (z-z(end))/SLD )/SLTau;

% WENO scheme (reconstruction uses 2k-1 points)
k = 2; %reconstruction_wenoz for k>=3 (k=2 only for reconstruction_weno)

% Other pre-defined constants
IMPORT_CONSTANTS_NOGLOBAL
Nzm = length(zm);

%%% Pre-processing sounding data
%[plev, pr, ta, hus, prw, date, hh] = LOAD_SOUNDINGS([dir_armbe armfn], arm);
%
%%% KKNW25 RH-reduced (using GoAmazon idp=314 case)
%% % % [zip,pip,tip,qip,tvip,rhoip] = init_profile('linear');% control
%% % % ta(2:end,pidx) = interp1(pip,tip,plev(2:end),'makima');
%% % % hus(2:end,pidx) = interp1(pip,qip,plev(2:end),'makima');
%%%
%
%% Interpolate sounding values to 5-hPa p-grid (_p)
%[T_p, q_p, rho_p, z_p] = INTERP_P_GRID(plev, ta(:,pidx), hus(:,pidx), p);
%
%% Modify humidity to avoid theta_e supersaturation
%q_p = TWEAK_THETA_E(T_p, q_p, p);
%
%% Interpolate sounding values to 50-m z-grid (_env) & zm-grid (_zm)
%[T_env, q_env, Tv_env, theta_e_env, rho_env, p_z,...
% T_zm, q_zm, Tv_zm, theta_e_zm, rho_zm, p_zm,...
% theta_zm, theta_es_zm, rh_zm] = INTERP_Z_GRID(T_p, q_p, z_p, p, zm, z, dz);

%% Directly read processed data (JD Huang)

if shared_input
  z=input.z; zm=input.zm;
  T_env=input.T_env; q_env=input.qt_zc; Tv_env=input.Tv_zc;
  theta_e_env=input.theta_e_zc; rho_env=input.rho_zc; p_z=input.p_zc;
  T_zm=input.T_zm; q_zm=input.qt_mf; Tv_zm=input.Tv_mf;
  theta_e_zm=input.theta_e_mf; rho_zm=input.rho_mf; p_zm=input.p_mf;
else
start = [1, pidx];
count = [401, 1];

z = ncread([dir_armbe armfn],'zc');
T_env = ncread([dir_armbe armfn],'T_zc',start,count);
q_env = ncread([dir_armbe armfn],'Q_zc',start,count);
Tv_env = ncread([dir_armbe armfn],'Tv_zc',start,count);
theta_e_env = ncread([dir_armbe armfn],'theta_e_zc',start,count);
rho_env = ncread([dir_armbe armfn],'rho_zc',start,count);
p_z = ncread([dir_armbe armfn],'P_zc',start,count);

zm = ncread([dir_armbe armfn],'ze');
T_zm = ncread([dir_armbe armfn],'T_ze',start,count);
q_zm = ncread([dir_armbe armfn],'Q_ze',start,count);
Tv_zm = ncread([dir_armbe armfn],'Tv_ze',start,count);
theta_e_zm = ncread([dir_armbe armfn],'theta_e_ze',start,count);
rho_zm = ncread([dir_armbe armfn],'rho_ze',start,count);
p_zm = ncread([dir_armbe armfn],'P_ze',start,count);

end

%% Setup for time-integration
%day = date(pidx); % Can run multiple pidx cases (by adding a for-loop here)

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

[Ta, Qa, QLa, QIa] = INV_THETA_E(theta_e_zc,qt_zc,p_zc,theta_e_diag);
Tv_zc = eval_Tv(Ta,Qa,QLa+QIa);

% For implicit damping
damp = dt*(eps_sl./[rho_zc,rho_zc,rho_mf]);

% Initiate MF(t=0)
MF = MF0*sin( pi*(zm-zb)/(zt-zb) );
MF(zm>zt | zm<zb) = 0;

% Initiate for ODE solver
if conti == 0
  X0 = [theta_e_zc,qt_zc,MF,zeros(Nzm,2),...
        repmat([theta_e_zc,qt_zc,-MF/(length(D)-1),zeros(Nzm,2)],1,Ni-1,1)]; %<---variables defined on zm-grid
% % %   X0 = [theta_e_zc,qt_zc,MF,zeros(Nzm,2),...
% % %         theta_e_zc,qt_zc,-*MF,zeros(Nzm,2),...
% % %         theta_e_zc,qt_zc,-*MF,zeros(Nzm,2),...
% % %         theta_e_zc,qt_zc,-*MF,zeros(Nzm,2),...
% % %         repmat([theta_e_zc,qt_zc,zeros(Nzm,3)],1,Ni-4,1)]; %<---variables defined on zm-grid
  X0 = reshape(X0,[Nzm,5,Ni]); %(Nzm,5*Ni)-->(Nzm,5,Ni)
  t0 = 0;
  if ensemble==1
    rng("default")
    for idx=1:Ni
      if rand(1)<0.1
        bl = BL(1:round(rand(1)*length(BL)));
        X0(bl,2,idx) = eval_qsat2(T_zm(bl)+dTbl,p_mf(bl)) .* (1-dqcbl);
        X0(bl,1,idx) = eval_theta_e(T_zm(bl)+dTbl,X0(bl,2,idx),(dqsat==1)*dqcbl*((T_zm(bl)+dTbl)>=T0),(dqsat==1)*dqcbl*((T_zm(bl)+dTbl)<T0),p_mf(bl));
      end
    end
%     contourf(squeeze(X0(:,1,:)),[330:355],'linestyle','none')
%     colormap(spectral)
%     grid on
%     ylim([0 100])
%     disp(rand(2)+rand(3))
  % Adding BL/thermal bubble for inner-most ACE
  elseif ~isempty(BL)
    if dqsat==1
      X0(BL,2,1) = eval_qsat2(Ta(BL)+dTbl,p_zc(BL)) .* (1-dqcbl);
    else
      X0(BL,2,1) = q_env(BL)*dqbl;
    end
    X0(BL,1,1) = eval_theta_e(Ta(BL)+dTbl,X0(BL,2,1),(dqsat==1)*dqcbl*((T_env(BL)+dTbl)>=T0),(dqsat==1)*dqcbl*((T_env(BL)+dTbl)<T0),p_zc(BL));
    % 2nd cloud at the end
    % X0(:,:,end) = X0(:,:,1);
% %     for idx=2:10
% %       X0(:,:,idx) = X0(:,:,1);
% %     end
    % 1 narrow cloud
%     X0(:,:,44) = X0(:,:,1);
%     X0(:,:,1) = X0(:,:,2);
    % Wide initial bubble
%     X0(:,:,2) = X0(:,:,1);
%     X0(:,:,end-1) = X0(:,:,1);
%     X0(:,:,end) = X0(:,:,1);
  end
end

%% Restart
if restart==1
  X0(:,3,:) = 0; 
  rc = 66; % Column index for restart bubble 
  X0(BL,2,rc) = eval_qsat2(T(BL,end,rc)+dTbl,p_mf(BL)) .* (1-dqcbl);
  X0(BL,1,rc)=eval_theta_e(T(BL,end,rc)+dTbl,X0(BL,2,rc),(dqsat==1)*dqcbl*((T(BL,end,rc)+dTbl)>=T0),(dqsat==1)*dqcbl*((T(BL,end,rc)+dTbl)<T0),p_mf(BL));
end

%% Define a struc to warp static ACE attributes
model.PMB = PMB;
model.PMDv = PMDv;
model.PMD = PMD;
model.damp = damp;
model.dt = dt;
model.p_zc = p_zc;
model.rho_zc = rho_zc;
model.Tv_zc = Tv_zc;
model.theta_e_diag = theta_e_diag;
model.Wbar_eq_zero = Wbar_eq_zero;
model.Ai = Ai;
model.dz = dz;
model.one_ace_only = one_ace_only;
model.qt_zc = qt_zc;
model.theta_e_zc = theta_e_zc;
model.activate_mf_diff = activate_mf_diff;
model.Z = Z;
model.zm = zm;
model.coarse_z = coarse_z;
model.Ni = Ni;
model.k = k;
model.rho_zi = rho_zi;
model.Nzm = Nzm;
model.Ni = Ni;
model.eps_tur = eps_tur;
model.turn_off_DHv = turn_off_DHv;
model.turn_off_DHh = turn_off_DHh;
model.zero_ref_buoyancy = zero_ref_buoyancy;
model.qc_ramp = qc_ramp;
model.dqc = dqc;
model.tau_pr = tau_pr;
model.eddiffu = eddiffu;
model.eddiwin = eddiwin;
physics=getenv('ACE_PHYSICS'); if isempty(physics), physics='native'; end
assert(ismember(physics,{'native','none'}), 'ACE_PHYSICS must be native or none');
model.precip_enabled=strcmp(physics,'native');
validation_file=getenv('ACE_VALIDATE_INPUT');
if ~isempty(validation_file)
  save(validation_file,'X0','model','z','zm','D','Ta','Qa','QLa','QIa','case_profile_index','-v7.3');
  return
end

%% Time-integration
%%            in GPU
tic;
X = timeint(@ssprk93,tspan,X0,dt,model);
if conti==1
  X = cat(4,Xminus1,X);
  tspan = [tminus1 tspan];
  Nt = length(tspan);
end
Tcost = toc;
disp(['ODE solver time = ' num2str(Tcost) ' sec'])

% Derived variables evaluated via post-processing (z,time,ACE-i)
[theta_e, qt, mf, theta, RH, B,...
   qsat, qv, qc, ql, qi, Tv, T, dtheta_e_pr_accum, pr_accum] = POST_PROCESS(X,model);

disp('... done!')

if save_output
  %save(['OUTPUT\' output_filename],'-v7.3')
  % save(['/home/yhkuo/Desktop/OUTPUT/' output_filename],'-v7.3')

  %save(output_filename)

  %nt = size(tspan,2);
  nt = Inf; % unlimited dimension
  nc = size(mf,3);
  nz = size(mf,1);
  ncoutput = output_filename;
  assert(~isfile(ncoutput), 'Output already exists; choose a fresh ACE_OUTPUT_FILE');
  nccreate(ncoutput,'ace_width','Dimensions',{'ncols',nc},'format','netcdf4')
  ncwrite(ncoutput,'ace_width',D*1000)
  ncwriteatt(ncoutput,'ace_width','long_name','Width of slab ACE columns')
  ncwriteatt(ncoutput,'ace_width','units','m')
  nccreate(ncoutput,'height','Dimensions',{'zc',nz})
  ncwrite(ncoutput,'height',z)
  ncwriteatt(ncoutput,'height','long_name','Height')
  ncwriteatt(ncoutput,'height','units','m')
  nccreate(ncoutput,'time','Dimensions',{'time',nt})
  ncwrite(ncoutput,'time',tspan)
  ncwriteatt(ncoutput,'time','long_name','time of simulation')
  ncwriteatt(ncoutput,'time','units','s')

  nccreate(ncoutput,'mf','Dimensions',{'ncols',nc,'zc',nz,'time',nt})
  ncwrite(ncoutput,'mf',permute(mf,[3,1,2]))
  ncwriteatt(ncoutput,'mf','long_name','Vertical mass flux')
  ncwriteatt(ncoutput,'mf','units','kg m^-2 s^-1')
  nccreate(ncoutput,'the','Dimensions',{'ncols',nc,'zc',nz,'time',nt})
  ncwrite(ncoutput,'the',permute(theta_e,[3,1,2]))
  ncwriteatt(ncoutput,'the','long_name','Equivalent potential temperature')
  ncwriteatt(ncoutput,'the','units','K')
  nccreate(ncoutput,'th','Dimensions',{'ncols',nc,'zc',nz,'time',nt})
  ncwrite(ncoutput,'th',permute(theta,[3,1,2]))
  ncwriteatt(ncoutput,'th','long_name','Potential temperature')
  ncwriteatt(ncoutput,'th','units','K')
  nccreate(ncoutput,'qt','Dimensions',{'ncols',nc,'zc',nz,'time',nt})
  ncwrite(ncoutput,'qt',permute(qt,[3,1,2]))
  ncwriteatt(ncoutput,'qt','long_name','Mixing ratio of total water')
  ncwriteatt(ncoutput,'qt','units','kg kg^-1')
  nccreate(ncoutput,'qv','Dimensions',{'ncols',nc,'zc',nz,'time',nt})
  ncwrite(ncoutput,'qv',permute(qv,[3,1,2]))
  ncwriteatt(ncoutput,'qv','long_name','Mixing ratio of water vapor')
  ncwriteatt(ncoutput,'qv','units','kg kg^-1')
  nccreate(ncoutput,'ql','Dimensions',{'ncols',nc,'zc',nz,'time',nt})
  ncwrite(ncoutput,'ql',permute(ql,[3,1,2]))
  ncwriteatt(ncoutput,'ql','long_name','Mixing ratio of liquid water')
  ncwriteatt(ncoutput,'ql','units','kg kg^-1')
  nccreate(ncoutput,'qi','Dimensions',{'ncols',nc,'zc',nz,'time',nt})
  ncwrite(ncoutput,'qi',permute(qi,[3,1,2]))
  ncwriteatt(ncoutput,'qi','long_name','Mixing ratio of ice water')
  ncwriteatt(ncoutput,'qi','units','kg kg^-1')
  nccreate(ncoutput,'rh','Dimensions',{'ncols',nc,'zc',nz,'time',nt})
  ncwrite(ncoutput,'rh',permute(RH,[3,1,2])*100.)
  ncwriteatt(ncoutput,'rh','long_name','Relatvie humidity')
  ncwriteatt(ncoutput,'rh','units','%')
  nccreate(ncoutput,'B','Dimensions',{'ncols',nc,'zc',nz,'time',nt})
  ncwrite(ncoutput,'B',permute(B,[3,1,2]))
  ncwriteatt(ncoutput,'B','long_name','Buoyancy')
  ncwriteatt(ncoutput,'B','units','m s^-2')

  ncwriteatt(ncoutput,'/','reference_version','ACE v0.21.87');
  ncwriteatt(ncoutput,'/','dt_seconds',dt);
  ncwriteatt(ncoutput,'/','DHh_enabled',int32(~turn_off_DHh));
  ncwriteatt(ncoutput,'/','DHv_enabled',int32(~turn_off_DHv));
  ncwriteatt(ncoutput,'/','profile_index',double(case_profile_index));
  ncwriteatt(ncoutput,'/','physics',physics);
  if shared_input, ncwriteatt(ncoutput,'/','input_file',input_file); end
  disp(["successfully output to", ncoutput])
end

%% Operator-splitting Time-integration interacting with both CPU & GPU
function X = timeint(odeint,tspan,X0,dt,model)
  X = nan([size(X0),length(tspan)]);
  X(:,:,:,1) = X0;
  yn = X0;
  for idt=1:length(tspan)-1
    t = tspan(idt);
    Nt = ( tspan(idt+1)-tspan(idt) )/dt;
    for idn=1:Nt
      t = t+dt;
      disp(t)
      % Microphysical & Radiative tendencies
      [dTH, dQt, rho0B] = microrad(yn(:,1:2,:),model.p_zc,model.rho_zc,model.Tv_zc,model.theta_e_diag,model);
      dTH(:,:) = 0.;
      dQt(:,:) = 0.;
      % Time-integrate explicit terms (default: low-storage SSPRK93)
      yn = odeint(@expFun,yn,dTH,dQt,rho0B,model.dt,model.Wbar_eq_zero,model.Ai,model);
      % Microphysical & Radiative tendencies
      [dTH, dQt, rho0B] = microrad(yn(:,1:2,:),model.p_zc,model.rho_zc,model.Tv_zc,model.theta_e_diag,model);
      if model.precip_enabled
        yn(:,1:2,:) = yn(:,1:2,:) + permute(cat(3,dTH,dQt),[1,3,2])*dt;
      end
      % Implicit Newtonian damping
      yn = ImDamp(yn,model.theta_e_zc,model.qt_zc,model.Nzm,model.damp);
      % Implicitly solving massflux diffusion
      if model.activate_mf_diff==1
        yn(:,3,:) = ExDiffMF(yn(:,3,:),model.dt,model.dz,model.rho_zi,model.eddiffu);
      elseif model.activate_mf_diff==2
        yn(:,3,:) = ImDiffMF(yn(:,3,:),model.dt,model.dz,model.rho_zi,model.Ni,model.Nzm,model.eddiffu,model.eddiwin);
      end
    end%idn
    X(:,:,:,idt+1) = yn;
  end%idt
end

function [theta_e, qt, mf, theta, RH, B,... 
          qsat, qv, qc, ql, qi, Tv, T, dtheta_e_pr_accum, pr_accum] = POST_PROCESS(X,model)
  [Nzm,Nvar,Ni,Nt] = size(X); % Nvar=5 for simplified thermodynamics
  X = reshape(X,[Nvar*Nzm,Ni,Nt]); % X(var&z,ACE-i,time)
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
            = inv_T_from_theta_e(theta_e(idz,idt,ida), qt(idz,idt,ida), model.p_zc(idz));
      end
      theta(:,idt,ida) = eval_theta(T(:,idt,ida),model.p_zc);
      qsat(:,idt,ida) = eval_qsat(T(:,idt,ida),model.p_zc,qt(:,idt,ida));
    end
  end
  Tv = eval_Tv(T,q,ql+qi);
  RH = q./qsat;
  B = eval_B(Tv,model.Tv_zc);
  qc = (qt-qsat).*(qt>qsat);
  qv = qt-qc;
end

%% Subroutines 
%%   used in GPU
function dXdt = expFun(X,dTH,dQt,rho0B,model)
  % X(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum]
  % Compute tracer values Ci(zi) at interface points from C(zc=zi+dz/2)
  Ci = reconstruction_weno_vec(model.k,X(:,1:2,:),X(:,3,:)); % Ci(zi,var,ACE-i)
  % Vertical velocity w(zi) (mass flux already at zi)
  wi = X(:,3,:)./model.rho_zi; % (zi,1,ACE-i)
  % Vertical mass flux & velocity at zc=zi+dz/2
  mfc = squeeze(reconstruction_up3(X(:,3,:))); % (zi,1,ACE-i)-->(zc,1,ACE-i)-->(zc,ACE-i)
  % mfc = squeeze(reconstruction_weno_vec(k,X(:,3,:),mfc_up3));
  wc = mfc./model.rho_zc; % (zc,ACE-i)
  % Admfdz = (ACE area)*dmfdz for dynamic inflow/outflow at zc=zi+dz/2
  Admfdz = model.Ai'.* squeeze(( X(2:end,3,:)-X(1:end-1,3,:) )/model.dz); % (zc,1,ACE-i)-->(zc,ACE-i); size(Admfdz)=(Nzm-1,Ni)
  % ioflow = -Bi*rho_0*u_n (minus h. mass flux * lateral boundary length)
  ioflow = permute(cumsum(Admfdz,2),[1,3,2]); % ioflow(:,1,[i-1,i])=-rho0*u for ACE-i dynamic inflow/outflow
  % Vertical tracer flux rho_0*w*C at zi
  rho0wC = X(:,3,:).*Ci; % (zi,var,ACE-i)
  % Set surface fluxes
  rho0wC(1,:,:) = 0; % First try: zeros surface flux
  % Compute flux-based tendencies at zc=zi+dz/2
  dCdt = zeros(model.Nzm,2,model.Ni); % Add zeros(1,2,Ni) for model top
  dCdt(1:end-1,:,1) = -model.eps_tur(1,1,1)*( X(1:end-1,1:2,1)-X(1:end-1,1:2,2) )... % Turbulent entrainment
                +( ioflow(:,1,1).*( (ioflow(:,1,1)>0).*X(1:end-1,1:2,2) + (ioflow(:,1,1)<0).*X(1:end-1,1:2,1) )/model.Ai(1)...
                  -( rho0wC(2:end,:,1)-rho0wC(1:end-1,:,1) )/model.dz )./model.rho_zc(1:end-1); % Vertical mean flux convergence
  dCdt(1:end-1,:,2:end-1) = -model.eps_tur(1,1,2:end-1).*( X(1:end-1,1:2,2:end-1)-X(1:end-1,1:2,3:end) )...  % Turbulent entrainment
                     -model.eps_tur(1,2,2:end-1).*( X(1:end-1,1:2,2:end-1)-X(1:end-1,1:2,1:end-2) )...
                     +( ( ioflow(:,1,2:end-1).*( (ioflow(:,1,2:end-1)>0).*X(1:end-1,1:2,3:end) + (ioflow(:,1,2:end-1)<0).*X(1:end-1,1:2,2:end-1) )...
                         -ioflow(:,1,1:end-2).*( (ioflow(:,1,1:end-2)>0).*X(1:end-1,1:2,2:end-1) + (ioflow(:,1,1:end-2)<0).*X(1:end-1,1:2,1:end-2) ) )./permute(model.Ai(2:end-1),[3,2,1])...
                       -( rho0wC(2:end,:,2:end-1)-rho0wC(1:end-1,:,2:end-1) )/model.dz )./model.rho_zc(1:end-1); % Vertical mean flux convergence
  dCdt(1:end-1,:,end) = -model.eps_tur(1,1,end).*( X(1:end-1,1:2,end)-[X(1:end-1,1:2,end)] )... % Turbulent entrainment
                 -model.eps_tur(1,2,end).*( X(1:end-1,1:2,end)-X(1:end-1,1:2,end-1) )...
                 +( ( ioflow(:,1,end).*( (ioflow(:,1,end)>0).*X(1:end-1,1:2,end) + (ioflow(:,1,end)<0).*X(1:end-1,1:2,end) )...
                     -ioflow(:,1,end-1).*( (ioflow(:,1,end-1)>0).*X(1:end-1,1:2,end) + (ioflow(:,1,end-1)<0).*X(1:end-1,1:2,end-1) ) )/model.Ai(end)...
                   -( rho0wC(2:end,:,end)-rho0wC(1:end-1,:,end) )/model.dz )./model.rho_zc(1:end-1); % Vertical mean flux convergence
  % F(zc,ACE-i) = local non-PGF dynamic forcing for mass flux (excluding buoyancy and nonlocal effect) 
  ioflow = squeeze(ioflow); % (Nzm-1,1,Ni)-->(Nzm-1,Ni)
  % FH(zc,ACE-i) with size(FH)=(Nzm-1,Ni); turbulent entrainment & horizontal in/outflow
  FH = -squeeze(model.eps_tur(1,1,:))'.*( mfc(1:end-1,:)-[mfc(1:end-1,2:end),mfc(1:end-1,end)] )...
       -squeeze(model.eps_tur(1,2,:))'.*( mfc(1:end-1,:)-[mfc(1:end-1,1),mfc(1:end-1,1:end-1)] )... % Turbulent entrainment
       +( ioflow.*( (ioflow>0).*[wc(1:end-1,2:end),wc(1:end-1,end)] + (ioflow<0).*wc(1:end-1,:) )... % Horizontal inflow/outflow
         -[zeros(model.Nzm-1,1),ioflow(:,1:end-1)].*( ([zeros(model.Nzm-1,1),ioflow(:,1:end-1)]>0).*wc(1:end-1,:)...
         + ([zeros(model.Nzm-1,1),ioflow(:,1:end-1)]<0).*[zeros(model.Nzm-1,1),wc(1:end-1,1:end-1)] ) )./model.Ai';
  % F(zc,ACE-i) with size(F)=(Nzm-1,Ni); fill zeros(1,Ni) at domain top later
  F = FH - squeeze( X(2:end,3,:).*wi(2:end,1,:)-X(1:end-1,3,:).*wi(1:end-1,1,:) )/model.dz; % Vertical mean flux convergence
  % (d/dz)^2(FH) (zc,ACE-i)
  dz2FH = ([-FH(1,:);FH(1:end-1,:)]-2*FH +[FH(2:end,:);zeros(1,model.Ni)])/model.dz^2;
  % The other nonlocal acceleration term DHh arising from divergence of horiznotal momemtum flux in the horizontal
  DHh = [ioflow(:,1).^2, ioflow(:,2:end).^2-ioflow(:,1:end-1).^2]./model.rho_zc(1:end-1)./model.Ai';
  % Recall X(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum] 
  dXdt = [ dCdt+permute(cat(3,dTH,dQt),[1,3,2]),...
           permute(NONLOCAL_RESPONSE(rho0B,[F;zeros(1,model.Ni)],...
                                     (model.turn_off_DHv-1)*dz2FH,...
                                     (1-model.turn_off_DHh)*[DHh;zeros(1,model.Ni)],...
                                     model.Z,model.zm,model.coarse_z,model.Ni,model.PMB,model.PMDv,model.PMD,model.Ai,model.zero_ref_buoyancy),...
                                     [1,3,2]),... %+repmat(EBF*(t<EBT),[1,Ni]),[1,3,2]), ...
           -permute(cat(3,dTH,dQt),[1,3,2]) ]; % dXdt(z,var,ACE-i)
  dXdt(end-10:end,1:3,:) = 0; % At domain top
  if model.one_ace_only==1
    dXdt(:,:,2:end) = 0; % Shut down additional ACEs
  end 
end

function MF = ExDiffMF(MF,dt,dz,rho_zi,eddiffu)
  % MF(zi,1,ACE-i)
  wi = MF./rho_zi; %(zi,1,ACE-i)
  drho0wdz = (MF(2:end,:,:)-MF(1:end-1,:,:))/dz; %(zc,1,ACE-i); size(drho0wdz)=[Nzm-1,1,Ni]
  % Fick's law flux = - diffusivity*gradient
% % %   FLF = -abs(drho0wdz).*( eddiffu.*( max(wi)-min(wi) )./max(abs(drho0wdz)+eps) ).*drho0wdz; %(zc,1,ACE-i); size=[Nzm-1,1,Ni]
  FLF = -eddiffu.*abs(wi(2:end,:,:)-wi(1:end-1,:,:)).*drho0wdz;
  c = dt/dz;
  MF(2:end-1,:,:) = MF(2:end-1,:,:) - c*( FLF(2:end,:,:)-FLF(1:end-1,:,:) );
  % Double check w=0 at surface and model top
  MF([1,end-10:end],:,:) = 0;
end

function MF = ImDiffMF(MF,dt,dz,rho_zi,Ni,Nzm,eddiffu,eddiwin)
  % MF(z,1,ACE-i)-->MF(z,ACE-i)
  MF = squeeze(MF);
  wi = MF./rho_zi;
  drho0wdz = squeeze( (MF(2:end,:)-MF(1:end-1,:))/dz ); % (zc,ACE-i); size(drho0wdz)=[Nzm-1,Ni]
  % Vertical momentum diffusion coefficients
  mu_1 = abs(drho0wdz).*( eddiffu.*( max(wi)-min(wi) )./max(abs(drho0wdz)+eps) ); % (zc,ACE-i); size=[Nzm-1,Ni]
  mu_2 = movmax(mu_1,[1 1]*eddiwin,1); % (zc,ACE-i); size=[Nzm-1,1]
  c = dz/dt;
  mu_D = conv2(mu_2,ones(2*eddiwin+1,1)/(2*c*eddiwin+1),'same'); % (zc,ACE-i); size=[Nzm-1,1]
  for ida=1:Ni
    Mat = sparse(1:Nzm-2,1:Nzm-2,(c+mu_D(1:end-1,ida)+mu_D(2:end,ida)),Nzm-2,Nzm-2)+...
          sparse(1:Nzm-3,2:Nzm-2,-mu_D(2:end-1,ida),Nzm-2,Nzm-2)+...
          sparse(2:Nzm-2,1:Nzm-3,-mu_D(2:end-1,ida),Nzm-2,Nzm-2);
    MF(2:end-1,ida) = Mat\( c*MF(2:end-1,ida) );
  end%ida
  % Double check w=0 at surface and model top
  MF([1,end-10:end],:) = 0;
  MF = reshape(MF,[Nzm,1,Ni]);
  % % % MF(z,1,ACE-i)
  % % wi = squeeze(MF)./rho_zi; %(z,1,ACE-i)-->(z,ACE-i)
  % % drho0wdz = squeeze( (MF(2:end,:,:)-MF(1:end-1,:,:))/dz ); %(z,1,ACE-i)-->(zc,ACE-i); size(drho0wdz)=[Nzm-1,Ni]
  % % % Vertical momentum diffusion coefficients
  % % mu_1 = abs(drho0wdz).*( eddiffu.*( max(wi)-min(wi) )./max(abs(drho0wdz)+eps) ); %(zc,ACE-i); size=[Nzm-1,Ni]
  % % mu_2 = movmax(mu_1,[1 1]*eddiwin,1); %(zc,ACE-i); size=[Nzm-1,1]
  % % c = dz/dt;
  % % mu_D = conv2(mu_2,ones(2*eddiwin+1,1)/(2*c*eddiwin+1),'same'); %(zc,ACE-i); size=[Nzm-1,1]
  % % for ida=1:Ni
  % %   Mat = sparse(1:Nzm-2,1:Nzm-2,(c+mu_D(1:end-1,ida)+mu_D(2:end,ida)),Nzm-2,Nzm-2)+...
  % %         sparse(1:Nzm-3,2:Nzm-2,-mu_D(2:end-1,ida),Nzm-2,Nzm-2)+...
  % %         sparse(2:Nzm-2,1:Nzm-3,-mu_D(2:end-1,ida),Nzm-2,Nzm-2);
  % %   MF(2:end-1,:,ida) = Mat\( c*MF(2:end-1,:,ida) ); %(z,1,ACE-i)
  % % end%ida
  % % % Double check w=0 at surface and model top
  % % MF([1,end-10:end],:,:) = 0;
end

function dMFdt = NONLOCAL_RESPONSE(rho0B, F, dz2FH, DHh, Z, zm, coarse_z, Ni, PMB, PMDv, PMD, Ai, zero_ref_buoyancy)
  if zero_ref_buoyancy
    % Zero out reference buoyancy
    rho0B = rho0B - sum(rho0B.*(Ai'/sum(Ai)),2);
  end
  if coarse_z==1
    dMFdt = squeeze(sum(sum(PMB.*reshape((rho0B(1:end-1,:)+F(1:end-1,:)),coarse_z,[],Ni)...
                            +PMDv.*reshape(dz2FH,coarse_z,[],Ni)...
                            +PMD.*reshape(DHh(1:end-1,:),coarse_z,[],Ni),2),3)); % (zi,ACE-i)
  else
    dMFdt = interp1(Z,squeeze(sum(sum(PMB.*mean(reshape((rho0B(1:end-1,:)+F(1:end-1,:)),coarse_z,[],Ni))...
                                      +PMDv.*mean(reshape(dz2FH,coarse_z,[],Ni))...
                                      +PMD.*mean(reshape(DHh(1:end-1,:),coarse_z,[],Ni)),2),3)),zm,'makima'); % (zi,ACE-i)
  end
end

function [dTH, dQt, rho0B] = microrad(y, p_zc, rho_zc, Tv_zc, theta_e_diag, model)
  [T, Q, QL, QI] = INV_THETA_E(squeeze(y(:,1,:)), squeeze(y(:,2,:)), p_zc, theta_e_diag); % (z,ACE-i)
  [dTH, dQt] = PRECIP_SINKS(T, Q, QL, QI, p_zc, model.qc_ramp, model.dqc, model.tau_pr);
  % Radiative forcing
  % % % dT = 1e-8;  
  % % % dtheta_e = dtheta_e+ RF.* ( eval_theta_e(T+dT,Q,QL,QI,p_mf) - eval_theta_e(T,Q,QL,QI,p_mf) )/1e-8;
  Tv = eval_Tv(T, Q, QL+QI);
  rho0B = rho_zc.*eval_B(Tv, Tv_zc);
end

function [dtheta_e, dqt] = PRECIP_SINKS(T, q, ql, qi, p_zc, qc_ramp, dqc, tau_pr)
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

function [T, q, ql, qi] = INV_THETA_E(theta_e, qt, p_zc, theta_e_diag)
  [Nzm,Np] = size(theta_e);
  T = zeros(Nzm,Np);
  q = zeros(Nzm,Np);
  ql = zeros(Nzm,Np);
  qi = zeros(Nzm,Np);
  for idp=1:Np*Nzm
    [T(idp), q(idp), ql(idp), qi(idp)]...
          = inv_T_from_theta_e(theta_e(idp), qt(idp), p_zc(mod(idp-1,Nzm)+1));
  end
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
    P_MF = repmat(p_zc,[1,Np]);
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
  end
  T = real(T);
  q = real(q);
  ql = real(ql);
  qi = real(qi);
end

function X = ImDamp(X,theta_e_zc,qt_zc,Nzm,damp)
  % X(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum]
  % damp = dt*(eps_sl./[rho_zc,rho_zc,rho_mf])
  X(:,1:3,:) = ( X(:,1:3,:) + damp.*[theta_e_zc,qt_zc,zeros(Nzm,1)] )./(1+damp);
end

%% Subroutines used in CPU 
%%   (i.e., before GPU subroutines are called)
function [T_env, q_env, Tv_env, theta_e_env, rho_env, p_z,...
          T_zm, q_zm, Tv_zm, theta_e_zm, rho_zm, p_zm, theta_zm,...
          theta_es_zm, rh_zm] = INTERP_Z_GRID(T_p, q_p, z_p, p, zm, z, dz)
  RD = 287.04; 
  g = 9.80665;
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
    Tv_env(:,pidx) = eval_Tv(T_env(:,pidx),q_env(:,pidx),0);
    p_z(:,pidx) = interp1(z_p(:,pidx),p,z,'makima');
    midz = sum(z<=max(z_p(:,pidx)));
    for idz=midz+1:length(z)
      p_z(idz,pidx) = p_z(idz-1,pidx)*(1-g*dz/2/RD/Tv_env(idz-1,pidx))/(1+g*dz/2/RD/Tv_env(idz-1,pidx));
    end
    T_zm(:,pidx) = interp1(z_p(:,pidx),T_p(:,pidx),zm,'makima',T_p(end,pidx));
    q_zm(:,pidx) = interp1(z_p(:,pidx),q_p(:,pidx),zm,'makima',q_p(end,pidx));
    q_zm(q_zm(:,pidx)<0,pidx) = 0; % Fix negative q_zm due to interp1
    Tv_zm(:,pidx) = eval_Tv(T_zm(:,pidx),q_zm(:,pidx),0);
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
  rh_zm = q_zm./eval_qsat2(T_zm,p_zm);
end

function q_tw = TWEAK_THETA_E(T_p, q_p, p)
  theta_e = eval_theta_e(T_p,q_p,0,0,p);
  theta_es = eval_theta_es(T_p,p);
  theta_tw = theta_e;
  theta_tw(theta_e>theta_es) = theta_es(theta_e>theta_es)-0.1;
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

function [T_p, q_p, rho_p, z_p] = INTERP_P_GRID(plev, ta, hus, p)
  RD = 287.04; 
  g = 9.80665;
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
    Tv_p(:,pidx) = eval_Tv(T_p(:,pidx),q_p(:,pidx),0);
    rho_p(:,pidx) = p./Tv_p(:,pidx)/RD;
    % Compute height assuming hydrostatic balance
    z_p(:,pidx) = (RD/g*(p(1)-p(2)))*cumtrapz(Tv_p(:,pidx)./p);
  end
end

function [plev, pr, ta, hus, prw, date, hh] = LOAD_SOUNDINGS(armbefn, arm)
  g = 9.80665;
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
    hus = eval_q2(eval_es(ta).*rh/100,repmat(plev,[1,size(ta,2)])); % Evaluated w.r.t. liquid water
    prw = sum( (hus(1:end-1,:)+hus(2:end,:)) .* (plev(1:end-1)-plev(2:end)) ,1)'/2/g;
    date = date(avail);
    hh = hh(avail);
  end
end

%%
%%
%%
function [zip,pip,tip,qip,tvip,rhoip] = init_profile(casename)
  RD = 287.04; % gas constant of dry air
  %  Height [m]     Pressure [Pa]  Temperature [K] Specific Humidity [kg/kg] Heating Forcing [K/s] Moistening Forcing [kg/kg/s] Longwave Forcing [K/s] Shortwave Forcing [K/s]     U [m/s]         V [m/s]    
  switch casename
    case 'control'
      IP = [ 131.52838391  99578.91915163    296.55438232  1.673266850411891937e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
             289.97864807  97949.91546659    297.64855957  1.582421734929084778e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
             474.49026618  96058.39643441    297.05429077  1.604560948908329010e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
             685.19700548  93921.18448309    296.64520264  1.700756512582302094e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
             921.44938427  91556.38994717    295.68576050  1.683137379586696625e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            1182.76888249  88983.72365096    294.23962402  1.744279079139232635e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            1468.16035504  86224.19540957    292.37695312  1.602962985634803772e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            1977.51736073  82341.10502825    289.12118530  1.243595965206623077e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            2705.62438328  76572.76437306    286.26889038  8.816661313176155090e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            3644.01948849  69342.49044712    281.96749878  8.689201436936855316e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            4779.43572639  61148.81473122    276.53851318  6.220520008355379105e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            6064.31290315  52605.67003334    269.48092651  5.279533099383115768e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            7306.09281143  44704.77275285    260.84603882  2.322068903595209122e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            8518.15762274  37988.88359210    254.72683716  1.057708053849637508e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            9694.64449108  32280.26919165    247.20910645  7.716922555118799210e-04  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           10829.05760709  27427.85314797    238.33445740  3.528153465595096350e-04  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           11919.49289391  23303.22169280    229.01876831  1.307350321440026164e-04  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           12964.68110030  19797.21828025    219.40652466  4.439524855115450919e-05  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           13960.55907493  16822.50797749    209.82656860  1.352904018858680502e-05  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           14917.85879517  14299.40387607    201.69915771  4.332222033553989604e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           15841.80788577  12154.72407639    194.67286682  1.591559566804789938e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           16753.07327964  10331.71266317    192.00050354  1.226931999553926289e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           17646.13846979   8782.12302923    188.16571045  7.562057362520135939e-07  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           19045.53999513   7201.24505460    198.11062622  1.983422407647594810e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           20923.30653282   5459.54797417    200.63613892  2.971873300339211710e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           23360.55643097   3826.82997733    209.65176392  2.695391231100074947e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           26490.23669076   2461.22200042    217.23307800  2.681364549061981961e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           30398.18089116   1435.66322513    228.25141907  2.682006197574082762e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           35145.10292720    759.48196463    240.26202393  2.749030272752861492e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           40661.82969029    364.34656940    247.32139587  3.008777639479376376e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000];
    case 'linear'
      IP = [ 131.52838391  99578.91915163    296.55438232  1.673266850411891937e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
             289.97864807  97949.91546659    297.64855957  1.582421734929084778e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
             474.49026618  96058.39643441    297.05429077  1.604560948908329010e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
             685.19700548  93921.18448309    296.64520264  1.700756512582302094e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
             921.44938427  91556.38994717    295.68576050  1.683137379586696625e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            1182.76888249  88983.72365096    294.23962402  1.521850097924470901e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            1468.16035504  86224.19540957    292.37695312  1.353968121111392975e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            1977.51736073  82341.10502825    289.12118530  1.243595965206623077e-02  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            2705.62438328  76572.76437306    286.26889038  8.816661313176155090e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            3644.01948849  69342.49044712    281.96749878  8.689201436936855316e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            4779.43572639  61148.81473122    276.53851318  6.220520008355379105e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            6064.31290315  52605.67003334    269.48092651  5.279533099383115768e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            7306.09281143  44704.77275285    260.84603882  2.322068903595209122e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            8518.15762274  37988.88359210    254.72683716  1.057708053849637508e-03  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
            9694.64449108  32280.26919165    247.20910645  7.716922555118799210e-04  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           10829.05760709  27427.85314797    238.33445740  3.528153465595096350e-04  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           11919.49289391  23303.22169280    229.01876831  1.307350321440026164e-04  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           12964.68110030  19797.21828025    219.40652466  4.439524855115450919e-05  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           13960.55907493  16822.50797749    209.82656860  1.352904018858680502e-05  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           14917.85879517  14299.40387607    201.69915771  4.332222033553989604e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           15841.80788577  12154.72407639    194.67286682  1.591559566804789938e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           16753.07327964  10331.71266317    192.00050354  1.226931999553926289e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           17646.13846979   8782.12302923    188.16571045  7.562057362520135939e-07  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           19045.53999513   7201.24505460    198.11062622  1.983422407647594810e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           20923.30653282   5459.54797417    200.63613892  2.971873300339211710e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           23360.55643097   3826.82997733    209.65176392  2.695391231100074947e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           26490.23669076   2461.22200042    217.23307800  2.681364549061981961e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           30398.18089116   1435.66322513    228.25141907  2.682006197574082762e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           35145.10292720    759.48196463    240.26202393  2.749030272752861492e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000;
           40661.82969029    364.34656940    247.32139587  3.008777639479376376e-06  0.00000000000000e+00  0.000000000000000000000e+00  0.000000000000000e+00  0.0000000000000000e+00      0.00000000      0.00000000];
  end
  zip = IP(:,1);
  pip = IP(:,2);
  tip = IP(:,3);
  qip = IP(:,4);
  tvip = eval_Tv(tip,qip,0);
  rhoip = pip./tvip/RD;
end
