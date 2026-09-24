%% Directory/file paths
dir_ace = [pwd '/..'];

% Subroutines
dir_util_plume = [dir_ace '/util_plume/'];
dir_util_thermodynamics = [dir_ace '/util_thermodynamics/'];
addpath(dir_util_plume,dir_util_thermodynamics)

% ARM best-estimate soundings (4 options from 3 sites)
dir_armbe = [dir_ace '/../data/soundings/'];
armfnlist = {'manus_3hr_ARMBEsonde_profiles.nc';
          'nauru_3hr_ARMBEsonde_profiles.nc';
          'maoarmbeatmM1.c1.20140101.003000.nc'};

%% Declare global for subroutines
global RD g p qc_ramp

%% Set up parameters

% ARM sounding option
arm = 3; %1=Manus/2=Nauru/3,4=GOAmazon
armfn = armfnlist{arm};

% Verital grids setup
dz = 50; % m; 5hPa~50m(surface)/250m(aloft)
ztop = 40e3; % m
z = [dz/2:dz:ztop-dz/2]'; % z-grid for plume computation
zm = [0:dz:ztop]'; % z-grid for mass-flux for entrainment rate
p = [1000:-5:100]'*1e2; % 5-hPa grid

% For precip
qc_ramp = 5e-3; % kg/kg; ramping for precip when qc>qc_ramp

% Other pre-defined constants
IMPORT_CONSTANTS
Nzm = length(zm);

%% Pre-processing sounding data
[plev, pr, prw, ta, hus, date, ps, tas, huss] = LOAD_SOUNDINGS([dir_armbe armfn], arm);

% Interpolate sounding values to 5-hPa p-grid (_p)
[T_p, q_p, rho_p, z_p] = INTERP_P_GRID(plev, ta, hus);

% Fix surface conditions (output as cells of vectors)
[T_P, Q_P, RHO_P, Z_P, P_P] = FIX_SURFACE_CONDITIONS(T_p, q_p, rho_p, z_p, ps, tas, huss);

%% Plume computation
% DIB by default mixing
[THETA_E_DIB, QT_DIB, T_DIB, Q_DIB, QL_DIB, QI_DIB, B_DIB]...
                                = ENTRAIN_PLUME(T_P, Q_P, RHO_P, Z_P, P_P);

% Constant mixing
mixing = 5e-2; %/5hPa
[THETA_E_CnE, QT_CnE, T_CnE, Q_CnE, QL_CnE, QI_CnE, B_CnE]...
                                = ENTRAIN_PLUME(T_P, Q_P, RHO_P, Z_P, P_P, mixing);

% Non-entraining
[THETA_E_NE, QT_NE, T_NE, Q_NE, QL_NE, QI_NE, B_NE]...
                                = ENTRAIN_PLUME(T_P, Q_P, RHO_P, Z_P, P_P, 0);

% Collect 3 entrainment assumptions
B_PLU = cat(1, B_DIB, B_CnE, B_NE)'; % B_PLU{idp,entrain_assumption}(idz)
T_PLU = cat(1, T_DIB, T_CnE, T_NE)';
Q_PLU = cat(1, Q_DIB, Q_CnE, Q_NE)';
QL_PLU = cat(1, QL_DIB, QL_CnE, QL_NE)';
QI_PLU = cat(1, QI_DIB, QI_CnE, QI_NE)';

% Compute CIN & CAPE
CAPE = cell(size(z_p,2),3);
CAPEIDZ = cell(size(z_p,2),3);
CIN = cell(size(z_p,2),3);
CINIDZ = cell(size(z_p,2),3);
[CIN, CINIDZ, CAPE, CAPEIDZ] = cellfun(@cin_cape_calc, B_PLU, repmat(Z_P',1,3),'UniformOutput',false);

%% Plot
TV_PLU = cellfun(@eval_Tv, T_PLU, Q_PLU, cellfun(@plus,QL_PLU,QI_PLU,'UniformOutput',false),'UniformOutput',false);
TV = cellfun(@eval_Tv, T_P, Q_P,'UniformOutput',false);
legend_flag = 0;
for idp=1:length(pr)
  figure
  subplot(1,2,1)
  try
    plot(zeros(length(CAPEIDZ{idp,3}),1),z_p(CAPEIDZ{idp,3},idp)/1e3,'c',zeros(length(CINIDZ{idp,3}),1),z_p(CINIDZ{idp,3},idp)/1e3,'g')
  catch
    legend_flag=1;
  end
  hold all
  plot(B_PLU{idp,1},Z_P{idp}/1e3,'b',B_PLU{idp,2},Z_P{idp}/1e3,'m',B_PLU{idp,3},Z_P{idp}/1e3,'r')
  if legend_flag==1
    legend('DIB','0.5%/5hPa','Non-entrain','Location','northwest')
    legend_flag = 0;
  else
    legend(num2str(CAPE{idp,3}),num2str(CIN{idp,3}),'DIB','0.5%/5hPa','Non-entrain','Location','northwest')
  end
  grid on
  box on
  xlabel('B (m/s)')
  ylabel('Height (km)')
  xlim([-0.3 0.1])
  ylim([0 14])
  title(datestr(date(idp)))
  set(gca,'fontsize',10)
  subplot(1,2,2)
  plot(TV_PLU{idp,1}-TV{idp},Z_P{idp}/1e3,'b',TV_PLU{idp,2}-TV{idp},Z_P{idp}/1e3,'m',TV_PLU{idp,3}-TV{idp},Z_P{idp}/1e3,'r')
  grid on
  box on
  xlabel('\Delta T_v (K)')
  ylabel('Height (km)')
  xlim([-5 2])
  ylim([0 14])
  title(['idp=' num2str(idp) '|pr=' num2str(pr(idp),'%.2f') 'mm/h'])
  set(gca,'fontsize',10)
  drawnow
  input('Hit Enter for next profile:')
  close
end

%% Subroutines
%%   implemented
%%     below:

function [THETA_E_PLU, QT_PLU, T_PLU, Q_PLU, QL_PLU, QI_PLU, B_PLU] = ENTRAIN_PLUME(T_P, Q_P, RHO_P, Z_P, P_P, mixing)
  THETA_E_PLU = cell(1,length(Z_P));
  QT_PLU = cell(1,length(Z_P));
  T_PLU = cell(1,length(Z_P));
  Q_PLU = cell(1,length(Z_P));
  QL_PLU = cell(1,length(Z_P));
  QI_PLU = cell(1,length(Z_P));
  if nargin==5 %Mixing ratio not prescribed
    [THETA_E_PLU, QT_PLU, T_PLU, Q_PLU, QL_PLU, QI_PLU]...
      = cellfun(@entrain_plume_calc, T_P, Q_P, RHO_P, Z_P, P_P,'UniformOutput',false);
  else
    MIXING = repmat(num2cell(mixing,1),1,length(Z_P));
    [THETA_E_PLU, QT_PLU, T_PLU, Q_PLU, QL_PLU, QI_PLU]...
      = cellfun(@entrain_plume_calc, T_P, Q_P, RHO_P, Z_P, P_P, MIXING,'UniformOutput',false);
  end
  TV_P = cellfun(@eval_Tv, T_P, Q_P,'UniformOutput',false);
  TV_PLU = cellfun(@eval_Tv, T_PLU, Q_PLU, cellfun(@plus,QL_PLU,QI_PLU,'UniformOutput',false),'UniformOutput',false);
  B_PLU = cellfun(@eval_B, TV_PLU, TV_P,'UniformOutput',false);
%   B_PLU = cellfun(@eval_B, T_PLU, T_P,'UniformOutput',false);
end
 
function [T_P, Q_P, RHO_P, Z_P, P_P] = FIX_SURFACE_CONDITIONS(t_p, q_p, rho_p, z_p, ps, tas, huss)
global RD g p
  if isempty(ps) % No surface data
    T_P = num2cell(t_p,1);
    Q_P = num2cell(q_p,1);
    RHO_P = num2cell(rho_p,1);
    Z_P = num2cell(z_p,1);
    P_P = num2cell(repmat(p,[1,size(t_p,2)]),1);
  else
    % Surface Tv and rho
    Tvs = eval_Tv(tas,huss);
    rhos = ps./Tvs/RD;
    % Allocate cells
    T_P = cell(1,length(ps));
    Q_P = cell(1,length(ps));
    RHO_P = cell(1,length(ps));
    Z_P = cell(1,length(ps));
    P_P = cell(1,length(ps));
    for idp=1:length(ps)
      if ps(idp)>1000e2
        T_P{idp} = [tas(idp);t_p(:,idp)];
        Q_P{idp} = [huss(idp);q_p(:,idp)];
        RHO_P{idp} = [rhos(idp);rho_p(:,idp)];
        Z_P{idp} = [0; z_p(:,idp) + (ps(idp)-1000e2)/g*( 1/rhos(idp)+1/rho_p(1,idp) )/2];
        P_P{idp} = [ps(idp);p];
      else
        midz = sum(p>ps(idp));
        T_P{idp} = [tas(idp);t_p(midz+1:end,idp)];
        Q_P{idp} = [huss(idp);q_p(midz+1:end,idp)];
        RHO_P{idp} = [rhos(idp);rho_p(midz+1:end,idp)];
        Z_P{idp} = [0; z_p(midz+1:end,idp)-z_p(midz)+(ps(idp)-1000e2)/g*( 1/rhos(idp)+1/rho_p(midz+1,idp) )/2];
        P_P{idp} = [ps(idp);p(midz+1:end)];
      end%ps
    end%idp
  end
end

function [T_p, q_p, rho_p, z_p] = INTERP_P_GRID(plev, ta, hus)
global RD g p
  % Interpolate sounding values to 5-hPa p-grid (_p)
  T_p = nan([length(p),size(ta,2)]);
  q_p = nan([length(p),size(ta,2)]);
  for idp=1:size(ta,2)
    T_p(:,idp) = interp1(plev,ta(:,idp),p);%,'pchip');
    q_p(:,idp) = interp1(plev,hus(:,idp),p);%,'pchip');
    % Fix negative q_p due to interp1
    q_p(q_p(:,idp)<0,idp) = 0;
  end%idp
  Tv_p = eval_Tv(T_p,q_p);
  rho_p = p./Tv_p/RD;
  % Compute height assuming hydrostatic balance
  z_p = (RD/g*(p(1)-p(2)))*cumtrapz(Tv_p./p);
end

function [plev, pr, prw, ta, hus, date, ps, tas, huss] = LOAD_SOUNDINGS(armbefn, arm)
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
    ps = [];
    tas = [];
    huss = [];
    date = time(avail)/3600/24 + datenum(1970,1,1);
  elseif arm==3 % GOAmazon
    ps = ncread(armbefn,'pressure_sfc')*1e2; % hPa-->Pa
    tas = ncread(armbefn,'temperature_sfc'); % K
    rhs = ncread(armbefn,'relative_humidity_sfc'); % in %
    plev = ncread(armbefn,'pressure')*1e2; % hPa-->Pa
    pr = ncread(armbefn,'precip_rate_sfc'); % mm/h
    ta = ncread(armbefn,'temperature_p')'; % K
    rh = ncread(armbefn,'relative_humidity_p')'; % in %
    time = ncread(armbefn,'time'); % 'seconds since 2014-1-1 0:00:00 0:00'
    date = time/3600/24 + datenum(2014,1,1);
    hh = floor(mod(date,1)*24);     
    % GOAmazon hh==5 & pr>2: [45, 457, 1179, 1343]
    avail = sum(~isnan(ta),2)==37 & sum(~isnan(rh),2)==37 & ~isnan(pr)...
                 & ~isnan(ps) & ~isnan(tas) & ~isnan(rhs) & hh==5;% & pr>0.5;% & pr>0;%
    ps = ps(avail);
    tas = tas(avail);
    rhs = rhs(avail);
    pr = pr(avail);
    ta = ta(avail,:)';
    rh = rh(avail,:)';
    hus = eval_q(eval_es(ta).*rh/100,repmat(plev,[1,size(ta,2)])); % Evaluated w.r.t. liquid water
    prw = sum( (hus(2:end,:)+hus(1:end-1,:)).*(plev(1:end-1)-plev(2:end)))'/2/g;
    huss = eval_q(eval_es(tas).*rhs/100,ps);
    date = date(avail);
%     ps = [];
%     tas = [];
%     huss = [];
  end
end