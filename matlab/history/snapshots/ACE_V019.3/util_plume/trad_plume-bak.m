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
global RD g p qc_cap

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
qc_cap = 5e-3; % kg/kg; capping for precip when qc>qc_cap

% Other pre-defined constants
IMPORT_CONSTANTS
Nzm = length(zm);

%% Pre-processing sounding data
[plev, pr, ta, hus, date, ps, tas, huss] = LOAD_SOUNDINGS([dir_armbe armfn], arm);

% Interpolate sounding values to 5-hPa p-grid (_p)
[T_p, q_p, rho_p, z_p] = INTERP_P_GRID(plev, ta, hus);

%% Plume computation
% DIB by default mixing
[theta_e_dib, qt_dib, T_dib, q_dib, ql_dib, qi_dib, B_dib]...
                                     = ENTRAIN_PLUME(T_p, q_p, rho_p, z_p);
% Constant mixing
mixing = 0.5e-2; %/5hPa
[theta_e_cm, qt_cm, T_cm, q_cm, ql_cm, qi_cm, B_cm]...
                                     = ENTRAIN_PLUME(T_p, q_p, rho_p, z_p, mixing);

% Non-entraining
[theta_e_ne, qt_ne, T_ne, q_ne, ql_ne, qi_ne, B_ne]...
                                     = ENTRAIN_PLUME(T_p, q_p, rho_p, z_p, 0);

% Collect 3 entrainment assumptions
B_plu = cat(3,B_dib,B_cm,B_ne);
T_plu = cat(3,T_dib,T_cm,T_ne);
q_plu = cat(3,q_dib,q_cm,q_ne);
ql_plu = cat(3,ql_dib,ql_cm,ql_ne);
qi_plu = cat(3,qi_dib,qi_cm,qi_ne);

% Compute CIN & CAPE
CAPE = zeros(size(z_p,2),3);
CAPEIDZ = cell(size(z_p,2),3);
CIN = zeros(size(z_p,2),3);
CINIDZ = cell(size(z_p,2),3);
for ide=1:3
  for idt=1:size(z_p,2)
    [CIN(idt,ide), CINIDZ{idt,ide}, CAPE(idt,ide), CAPEIDZ{idt,ide}] = cin_cape_calc(B_plu(:,idt,ide), z_p(:,idt));
  end%idt
end%ide
% % for idp=1:size(z_p,2)
% %   [cin, cinidz, cape, capeidz] = cin_cape_calc(B_plu(:,idp,3), z_p(:,idp));
% %   figure
% %   plot(B_plu(:,idp,3),z_p(:,idp),'k')
% %   hold all
% %   plot(B_plu(cinidz,idp,3),z_p(cinidz,idp),'b')
% %   plot(B_plu(capeidz,idp,3),z_p(capeidz,idp),'r')
% %   grid on
% %   box on
% %   title([num2str(cape) ' / ' num2str(cin)])
% %   drawnow
% %   input('Hit Enter:')
% %   close
% % end

%% Plot
Tv_plu = eval_Tv(T_plu, q_plu, ql_plu+qi_plu);
Tv = eval_Tv(T_p, q_p, 0);
for idp=1:size(z_p,2)
  figure
  subplot(1,2,1)
  plot(zeros(length(CAPEIDZ{idp,3}),1),z_p(CAPEIDZ{idp,3},idp)/1e3,'c',zeros(length(CINIDZ{idp,3}),1),z_p(CINIDZ{idp,3},idp)/1e3,'g')
  hold all
  plot(B_plu(:,idp,1),z_p(:,idp)/1e3,'b',B_plu(:,idp,2),z_p(:,idp)/1e3,'m',B_plu(:,idp,3),z_p(:,idp)/1e3,'r')
  legend(num2str(CAPE(idp,3)),num2str(CIN(idp,3)),'DIB','0.5%/5hPa','Non-entrain','Location','northwest')
  grid on
  box on
  xlabel('B (m/s)')
  ylabel('Height (km)')
  xlim([-0.3 0.1])
  ylim([0 14])
  title(datestr(date(idp)))
  set(gca,'fontsize',10)
  subplot(1,2,2)
  plot(Tv_plu(:,idp,1)-Tv(:,idp),z_p(:,idp)/1e3,'b',Tv_plu(:,idp,2)-Tv(:,idp),z_p(:,idp)/1e3,'m',Tv_plu(:,idp,3)-Tv(:,idp),z_p(:,idp)/1e3,'r')
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
function [theta_e_plu, qt_plu, T_plu, q_plu, ql_plu, qi_plu, B_plu] = ENTRAIN_PLUME(T_p, q_p, rho_p, z_p, mixing)
global g
  theta_e_plu = zeros(size(z_p));
  qt_plu = zeros(size(z_p));
  T_plu = zeros(size(z_p));
  q_plu = zeros(size(z_p));
  ql_plu = zeros(size(z_p));
  qi_plu = zeros(size(z_p));
  if nargin==4 %Mixing ratio not prescribed
    for pidx=1:size(z_p,2)
      [theta_e_plu(:,pidx),... 
       qt_plu(:,pidx),...
       T_plu(:,pidx),...
       q_plu(:,pidx),...
       ql_plu(:,pidx),...
       qi_plu(:,pidx)] = entrain_plume_calc(T_p(:,pidx), q_p(:,pidx), rho_p(:,pidx), z_p(:,pidx));
    end
  else
    for pidx=1:size(z_p,2)
      [theta_e_plu(:,pidx),... 
       qt_plu(:,pidx),...
       T_plu(:,pidx),...
       q_plu(:,pidx),...
       ql_plu(:,pidx),...
       qi_plu(:,pidx)] = entrain_plume_calc(T_p(:,pidx), q_p(:,pidx), rho_p(:,pidx), z_p(:,pidx),mixing);
    end
  end
  Tv = eval_Tv(T_p, q_p, 0);
  Tv_plu = eval_Tv(T_plu, q_plu, ql_plu+qi_plu);
  B_plu = g*(Tv_plu-Tv)./Tv;
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

function [plev, pr, ta, hus, date, ps, tas, huss] = LOAD_SOUNDINGS(armbefn, arm)
  % Load sounding data
  if arm<=2 % Manus or Nauru
    plev = ncread(armbefn,'pressure'); % Pa
    pr = ncread(armbefn,'pr'); % mm/h
%     prw = ncread(armbefn,'prw'); % mm
    ta = ncread(armbefn,'ta'); % K
    hus = ncread(armbefn,'hus'); % kg/kg
%     rh = ncread(armbefn,'rh'); % in %; rh defined w.r.t. liquid (not ice)
    time = ncread(armbefn,'time_bnds'); % 'seconds since 1970-1-1 0:00:00 0:00'
    avail = sum(~isnan(ta),2)==37 & sum(~isnan(hus),2)==37 & ~isnan(pr);
    pr = pr(avail);
%     prw = prw(avail);
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
    avail = sum(~isnan(ta),2)==37 & sum(~isnan(rh),2)==37 & ~isnan(pr) & hh==5 & pr>0.5;
    ps = ps(avail);
    tas = tas(avail);
    rhs = rhs(avail);
    pr = pr(avail);
    ta = ta(avail,:)';
    rh = rh(avail,:)';
    hus = eval_q(eval_es(ta).*rh/100,repmat(plev,[1,size(ta,2)])); % Evaluated w.r.t. liquid water
    huss = eval_q(eval_es(tas).*rhs/100,ps);
    date = date(avail);
  end
end