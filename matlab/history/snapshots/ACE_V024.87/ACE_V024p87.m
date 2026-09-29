% ACE_V024p87.m -- 2-D periodic array of Anelastic Convective Entities (ACEs) with immersed-boundary terrain.
% 
% Yi-Hung Kuo (yhkuo@atmos.ucla.edu) 
% Atmospheric & Oceanic Sciences, UCLA
%
% WHAT THIS IS. A 2-D (x, z) periodic array of ACEs, one entity per column, marched in the MF (rho0 w)
% representation with the precomputed ACE response kernels K1 = inv(Lap) dxx and K2 = inv(Lap) dx
% (truncated to +-NT columns):
% dMF/dt = K1[rho0 B + F_z] - K2[dz(F_x)]. Production grid: Nx = 880 entities of dx = 500 m (Lx = 440 km),
% dz = 100 m, Lz = 40 km, dt = 6 s. The forcing layers use the three-tier L3 tiling (100 m below 2 km,
% 200 m from 2 to 18 km, 400 m above); the basis is selected by (dx, NT) from the
% COMPOSITE_ACE_BASIS_2D_V024_dx=<dx>_NT=<NT>.mat files in data/basis/ (K1 and K2 tables in one file).
%
% EVERYWHERE-IB TERRAIN. ONE rock BUFFER row (nbuf = 1 x dz) below the physical ground: zm = -100 .. 40000 m
% (402 interfaces), so EVERY column has kbot >= nbuf and the flat ground is an immersed-boundary surface
% exactly like a mountain top -- body node at the ground row (psi' = PsiBar R, hard), tendency-level MF = 0
% via the K1 buffer-cell source, vorticity bound-sheet exclusion (omx) at the ground row, tracer ghost copy
% into the buffer. Base wind ubar = 0 inside the buffer row (PsiBar(ground) = 0), so the buffer blocks no
% base flux. Terrain geometry: h(x) continuous (bell / h_override), kbot = floor(h/dz) solid cells, the cell
% kbot+1 is the PARTIAL cell of solid fraction rsol. PURE IMMERSED BOUNDARY (the only mode here): the surface
% enters ONLY through the psi(h_f) constraint and the vorticity exclusion mask -- no finite-volume fractions
% (K1/K2 source weights ace.vk / ace.ak, tracer volumes and area exchange are all 1), no thin-cell threshold.
%
% CLOSURE. Per stage, the CAPACITANCE (hard) closure topo_solver = 'cap' (production): unknowns = vorticity
% at the body nodes (+ one closure vorticity per partial face, + a second per face under IBNOSLIP); the free
% streamfunction psi_cur is built EXACTLY from the state (cumsum of MF along x, level constants from the
% gauge'd rho0 u at the anchor face Ni); the required increment Dpsi_b = PsiBar(z) R(t) - psi_cur is solved
% with the precomputed body capacitance C_b and stamped with the SAME responses. Responses = the discrete
% Green's function of the periodic/Dirichlet Poisson problem, cosine-TAPERED to zero beyond +-NT columns
% (cap_mode = 'taper', default; 'trunc' = hard cut, 'exact' = whole-domain solve, GATE DIAGNOSTIC ONLY --
% a march never does a global Poisson). The psi-Dirichlet
% elliptic solver (topo_solver = 'psi', BUILD_PSI/PSI_STAGE) is kept as the GATE TWIN (G14c, exact-cap vs
% psi). Hard constraints: rock MF = 0 and wall u_tot = 0 hold exactly; the truncation tail is reported as a
% diagnostic. Gauge: 'fluid' (fluid-face mean of rho0u' = 0 per level) with the psi/cap level constant
% carried in state slot 7.
%
% MOMENTUM. Vorticity-flux (Lamb) form (lamb_form = 1, the production default): div(rho0 u u) = rho0 grad K
% - rho0 u x omega, F_x = -rho0 w omega, F_z = +rho0 u omega, the gradient part dropped analytically with its
% anelastic remainder rho0' dx(K) fed to K2. The transported quantity is the vorticity: eta_dot =
% -div(rho0 v omega-hat) as a flux divergence with UPWIND reconstruction of omega-hat -- WENO(2k-1) by
% default (lamb_upwind_weno = 1; preset UPWIND_UP3 = 1 selects the up3 two-stencil pair instead) -- fed to K2
% alone while K1 keeps rho0 B + entrainment. Bound-sheet rows are excluded via om(phiw_mask) = 0. LAMB = 0
% restores the flux form (K2_CHANNEL, up3w_g; kept as the comparison path, gate G13).
%
% OPTIONS. IBSLOPE = 1: the surface point of every face sits at the terrain height h(x_f) (bell: analytic;
% h_override terrains: mw.h_fun(x) when given, else the mean of the two neighbouring column heights) instead of
% the higher neighbouring column top, so the psi(h_f) constraint follows the slope; rock cells are unchanged.
% IBNOSLIP = 1: no-slip as a SECOND hard constraint on every face (partial faces: extrapolated
% d(psi')/dz at the true surface height; block faces incl. the flat ground: one-sided 2nd-order slope from
% the two fluid cells above). VISC = nu: explicit vertical viscosity on u_tot and w as F_x / F_z forcings
% with the IB wall stress (VISCWALL = 0 -> stress-free). MEANU = 1 (default): the level-mean (k = 0)
% momentum equation marched through the gauge slot 7 -- viscous/SGS term + Reynolds-stress divergence over
% all columns + the mountain's pressure drag diagnosed each stage from the vertical momentum equation +
% level-mean sponge; the closure's mean response then takes the Neumann-lid step profile. MEANU = 0 turns
% the whole level-mean equation off (the level mean then changes only through the closure). SGSML = 1:
% mixing-length SGS nu_t = kappa u* min(z_loc, z_n) + log-law wall model tau_w = rho0 u*^2 (LL_Z0, LL_ZN,
% LL_TAUN, LL_NUDGE). Time integration: SSPRK(9,3) with a per-stage terrain state closure.
%
% RUN MODES (preset RUN_MODE before running the script; default 'mwgates'):
%   mwgates  gate battery only (G13, G9, G10, G11, G14c) -- the certification battery
%   mw       nonlinear mountain wave, H = 1500 m, a = 5 km, U0 = 15 m/s, 4 h (geometry/length from the presets)
%   mwsine   continuous random sine topography (NSINE / HSINE / MSINE_LO / MSINE_HI)
%   mwextend continue a finished run from its .mat (EXTTAG, EXTT)
%   mwpost   rebuild the save from a checkpoint (MWPOST_TAG, MWPOST_H)
%   cwbubble CW16 EXP2 cold bubble on a gentle slope
%   rayleigh Rayleigh/Stokes viscous consistency test (VISC, RT)
%   loglaw   log-law equilibrium consistency test (wall model + SGS, LL_*)
% Any other RUN_MODE is rejected with an error; the ARM sounding is still loaded because it builds the
% base `ace` struct and serves the SND = 'arm' case preset.
%
% PRESETS (set as plain variables before running the script; every one has a default):
%   grid / kernels  NX (880), DX (500 m), NT (30), KFILE (explicit basis file)
%   time            DT (6 s)
%   mountain        MW_H (1500 m), MW_A (5e3 m), MW_HLIN (300 m), MW_U0 (15), MW_TAU (4a/U0; 0 = impulsive),
%                   MW_T (4 h), MW_DTOUT (600 s)
%   case            SND ('ideal' | 'arm'), UBAR ('uniform' | 'profile'), IC ('rest' | 'coldblock'),
%                   IC_COLS, IC_BL, IC_DT, IC_DQC
%   dynamics        MEANU (1), MEANUSPONGE (1), DRY (0), LAMB (1; 0 = flux form), UPWIND_UP3 (0),
%                   CAPMODE ('taper'; 'exact' is a gate diagnostic only)
%   boundary layer  VISC (0 m2/s), VISCWALL (1), IBNOSLIP (0), IBSLOPE (0), SGSML (0), LL_Z0 (0.1 m), LL_ZN (3000 m),
%                   LL_TAUN (600 s), LL_NUDGE (0)
%   run control     SKIPGATES, RESUME, EXTTAG / EXTT, NSINE / HSINE / MSINE_LO / MSINE_HI, RT, RN1, RNOSLIP,
%                   LL_T, MWPOST_TAG / MWPOST_H
%   output          OUTDIR ('OUTPUT'): directory for every file the run writes (created if absent)
% Example: matlab -batch "RUN_MODE='mw'; SKIPGATES=1; ACE_V024p87"
%
% CERTIFICATION. The gate battery (RUN_MODE = 'mwgates') must print ALL T2b GATES PASS, and the GATE / G14c
% lines must reproduce the reference fingerprint logs line by line. The gates are: G13 (vorticity-flux vs
% flux form on a flat smooth field), G9 (flat ground with a ramped ubar stays at rest), G10 (wall u_tot and
% rock identities under the ramped ubar), G11 (ubar-reversed mirror twin: MF / tracers even, eta odd), and
% G14c (hard-closure identities plus the exact-cap vs psi-Dirichlet twin). The K-wiring gates at build time
% check the tap-loop applies against the stacked and layer-loop references to 1e-12. The two consistency
% tests are RUN_MODE = 'rayleigh' (vs the erf similarity solution) and RUN_MODE = 'loglaw' (vs a 1-D
% constant-stress reference).
%
% DATA-FILE DEPENDENCIES (all resolved relative to pwd). The composite basis
% data/basis/COMPOSITE_ACE_BASIS_2D_V024_dx=<dx>_NT=<NT>.mat (K1 and K2 tables; built offline by
% util_basis/V024p87_CONSTRUCT_KERNELS.m); the util_weno / util_timeint / util_thermodynamics / util_plume libraries on
% the path; the ARM sounding .nc file in data/soundings/ (dir_armbe below).
%
% OUTPUT. Everything the run writes goes into the directory OUTDIR (preset; default 'OUTPUT', relative to
% the working directory, created if it does not exist): the records ACE_V024p87_<Nx>_<tag>.mat (-v7.3), the
% checkpoints <tag>_ckpt.mat / <tag>_ckpt0.mat (RESUME = 1 continues from them), and the progress stamps in
% progress_V024p87.log. The continuation reads (RESUME, mwpost's MWPOST_TAG checkpoint, mwextend's EXTTAG
% record) are looked up in the same directory. Input data files -- the kernel tables and the
% soundings -- are NOT affected and stay where they are.
%% Paths / flags / geometry / knobs
% dMF/dt = K1[rho0*B+F] - K2[dz(F_x)]; 7-slot state (see the IC section below).
dir_ace = pwd;
addpath([dir_ace '/util_weno/'],[dir_ace '/util_plume/'], ...
        [dir_ace '/util_timeint/'],[dir_ace '/util_thermodynamics/']);

% HOW TO CHANGE: point dir_armbe at the ARMBE .nc directory. arm=3 -> GOAmazon.
dir_armbe = [dir_ace '/data/soundings/'];   % the GOAmazon ARMBE file ships in ./data/soundings/
armfnlist = {'manus_3hr_ARMBEsonde_profiles.nc';
             'nauru_3hr_ARMBEsonde_profiles.nc';
             'maoarmbeatmM1.c1.20140101.003000.nc'};


%% Geometry (Lx = 440 km periodic; dz = 100 m, Lz = 40 km)
% HOW TO CHANGE: Nx sets the number of periodic entities; the kernels rebuild for
% the matching k-ladder. dx must stay 5 km (kernel forcing-box width).
Nx = 880; if exist('NX','var'), Nx = NX; end                     % entities (preset NX); the kernel tables do not depend on it
Dkm = 0.5; if exist('DX','var'), Dkm = DX/1e3; end                % entity width (preset DX in m; default 500 m)
D  = Dkm*ones(Nx,1);                  % entity diameters in km (length unit: km)
Ni = length(D);                       % number of ACEs
Ai = D;                               % entity width in km (index i)
Bi = ones(Nx,1);                      % entity outer perimeter in km

%% Solver / physics flags
Wbar_eq_zero = 1;      % enforce domain-mean w=0 (ESSENTIAL for periodic ioflow closure)
% HOW TO CHANGE: turn_on_K2=0 reproduces the K1-only run.
turn_on_K2 = 1;
nbuf = 1;                                        % rock BUFFER rows below the physical ground (everywhere IB)
% C1 isothermal transition above the top ARM level. HOW TO CHANGE: iso_C1=1 replaces
% the constant T-fill (C0 kink) with a lapse-relaxation of scale d_iso; =0 baseline.
iso_C1 = 0; d_iso = 2000;
% Prescribed background wind ubar(z) (C1-smooth). HOW TO CHANGE: ubar_on toggles it;
% U0 plateau speed; z_ramp sin^2 ramp top; zd0/zd1 cosine-decay start/end.
ubar_on = 0; U0 = 10; z_ramp = 3e3; zd0 = 18e3; zd1 = 30e3;

plotting = 0; savefigure = 1; theta_e_diag = 1;

% ARM sounding option
arm = 3;    % 1=Manus/2=Nauru/3=GOAmazon.  HOW TO CHANGE: sounding site.
armfn = armfnlist{arm};
pidx = 314; % HOW TO CHANGE: which sounding column.

% Vertical grids
dz = 100;                                       % m (the kernel tables are built for dz = 100 m, dx = 500 m)
coarse_z = 200/dz;                              % =2 (200-m forcing layers)
ztop = 40e3;                                    % m
zm = [-nbuf*dz:dz:ztop]';                       % interfaces (402): zm(1) = -dz buffer bottom (kernel Dirichlet row), zm(nbuf+1) = 0 = physical ground
z  = zm + dz/2;                                 % cell centers (402): z(1) = -dz/2 = the rock buffer cell
p  = [1000:-5:100]'*1e2;                         % 5-hPa grid

% Precip sinks / time step
qc_ramp = 0.5e-3; dqc = 20; tau_pr = 5*60;
dt = 6; if exist('DT','var'), dt = DT; end        % time step (s) (preset DT)

% Initial mass flux (the base state is at rest; the case IC comes from the IC preset in SETUP_MW)
MF0 = 0*5; zt = 4e3; zb = 0e3;

% Turbulent entrainment
nju = 0.09;
eps_tur = permute((nju/1e3)*[Bi./Ai,[0;Bi(1:end-1)./Ai(2:end)]],[3,2,1]);

% Sponge: eps_sl profile (SPONGE IRON RULE -- always on)
SLD = 6e3; SLTau = 180; eps_sl = exp((z-z(end))/SLD)/SLTau;

k = 2;                                          % WENO order for the certified tracer/MF chain

%% ---- TERRAIN (block topography; MF/eta' split architecture) ----
% Mountain in 100-m quantized kbot per column (cols 37:47, crest 1.2 km at 42).
% HOW TO CHANGE: terrain_on (0 => flat, bit-identical machinery no-ops), terrain_cols/kbot.
terrain_on = 0;                                  % no terrain in the base ace (mountain-wave cases build their own)
terrain_cols = []; terrain_kbot = [];
kbot = zeros(1,Nx); kbot(terrain_cols) = terrain_kbot;
% Forcing layers: 100 m below z_split, 200 m above.
z_split = 2000 + nbuf*dz;                       % KERNEL coordinate (z' = z + nbuf*dz): top of the 100-m forcing tier (rock cells must lie below)
% L3 three-tier forcing bases: 100 m below 2 km, 200 m from 2 to 18 km, 400 m above.
tiers = [2000 100; 18000 200; ztop 400]; ed_ = 0; zlo_ = 0;
for t_ = 1:size(tiers,1), ed_ = [ed_, (zlo_ + tiers(t_,2)):tiers(t_,2):tiers(t_,1)]; zlo_ = tiers(t_,1); end %#ok<AGROW>
edges = [0, ed_ + nbuf*dz];                     % KERNEL coordinate: the buffer layer [0, nbuf*dz] first, then the physical tiers (Nlay=156)
Nlay = numel(edges)-1;
assert(max(kbot)*dz + 400 <= z_split, 'z_split must clear the crest by >= 400 m');
if ~exist('RUN_MODE','var'), RUN_MODE = 'mwgates'; end
assert(any(strcmp(RUN_MODE, {'mwgates','mw','mwsine','mwextend','mwpost','cwbubble','rayleigh','loglaw'})), 'unknown RUN_MODE ''%s'': valid modes are mwgates, mw, mwsine, mwextend, mwpost, cwbubble, rayleigh, loglaw', RUN_MODE);
ndead = round(1000/dz) + 1;                     % top dead zone rows (~1 km + top): 11 at dz=100, 6 at dz=200
% Vorticity-flux (Lamb) form of BOTH momentum-flux terms. HOW TO CHANGE:
% preset LAMB=0 from the batch call for the flux form (the comparison path).
lamb_form = 1; if exist('LAMB','var'), lamb_form = LAMB; end
resume_ckpt = exist('RESUME','var') && RESUME;   % preset RESUME=1 to continue a run from its <tag>_ckpt.mat
lamb_upwind_weno = 1; if exist('UPWIND_UP3','var') && UPWIND_UP3, lamb_upwind_weno = 0; end   % omega-hat reconstruction: 1 = WENO(2k-1) (default), 0 = up3 two-stencil pair
partial_on = 1; if exist('PARTIAL','var'), partial_on = PARTIAL; end        % partial-step terrain (PARTIAL=0 => block geometry)
partial_ib = 1;                                                               % PURE IMMERSED BOUNDARY (the only mode): psi(h_f) constraint + Lamb exclusion only;
                                                                              %   NO finite-volume fractions (K1/K2 weights, tracer volumes, area exchange all 1), no thin-cell threshold.
partial_vmin = 0; if exist('VMIN','var'), partial_vmin = VMIN; end            % minimum fluid fraction of a partial cell (IB default 0 = no threshold)
partial_smin = 0.02; if exist('SMIN','var'), partial_smin = SMIN; end         % minimum SOLID fraction (below: flat/block; the bell tail is a few m high over most of the domain)
ib_noslip = 0; if exist('IBNOSLIP','var'), ib_noslip = IBNOSLIP; end            % IB option: no-slip as a second hard constraint per face (partial AND block faces)
ib_slope = 0; if exist('IBSLOPE','var'), ib_slope = IBSLOPE; end               % IB option: surface point of every face at the terrain height h(x_f) (0 = higher neighbouring column top)
visc_nu = 0; if exist('VISC','var'), visc_nu = VISC; end                          % explicit vertical viscosity (m2/s) on u_tot and w
visc_wall = 1; if exist('VISCWALL','var'), visc_wall = VISCWALL; end              % 1 = IB wall stress rho0 nu u(first cell)/(dz/2) ; 0 = stress-free wall
dry = 0; if exist('DRY','var'), dry = DRY; end                                    % 1: no phase change (unsaturated inversion, no precip sinks): dry dynamics
snd_src = 'ideal'; if exist('SND','var'), snd_src = SND; end                      % 'ideal' constant-N sounding | 'arm' GOAmazon pidx (iso_C1_s = 1)
ubar_src = 'uniform'; if exist('UBAR','var'), ubar_src = UBAR; end                % 'uniform' U0 with the sin^2 ramp | 'profile' C1 shear UBAR_PROFILE (U0, z_ramp, zd0, zd1)
ic_src = 'rest'; if exist('IC','var'), ic_src = IC; end                            % 'rest' | 'coldblock' (cold block: IC_COLS, IC_BL (physical cell rows), IC_DT, IC_DQC)
ic_cols = 40:49; if exist('IC_COLS','var'), ic_cols = IC_COLS; end
ic_BL = 1:25; if exist('IC_BL','var'), ic_BL = IC_BL; end
ic_dT = -6; if exist('IC_DT','var'), ic_dT = IC_DT; end
ic_dqc = 3e-3; if exist('IC_DQC','var'), ic_dqc = IC_DQC; end
mean_u = 1; if exist('MEANU','var'), mean_u = MEANU; end                          % level-mean momentum equation: 1 on (default) ; 0 off
sgs_ml = 0; if exist('SGSML','var'), sgs_ml = SGSML; end                          % mixing-length SGS nu_t = kappa u* min(z_loc, z_n) + wall model tau_w = rho0 u*^2
ll_z0 = 0.1; if exist('LL_Z0','var'), ll_z0 = LL_Z0; end                          % roughness length (m) of the wall model
ll_zn = 3000; if exist('LL_ZN','var'), ll_zn = LL_ZN; end                         % mixing-length cap / nudging base height (m)
ll_taun = 600; if exist('LL_TAUN','var'), ll_taun = LL_TAUN; end                  % relaxation time (s) of the level-mean wind above z_n
ll_nudge = 0; if exist('LL_NUDGE','var'), ll_nudge = LL_NUDGE; end                % 1: relax the level-mean wind to ubar R above z_n (loglaw test drive)
mean_u_sponge = 1; if exist('MEANUSPONGE','var'), mean_u_sponge = MEANUSPONGE; end % MEANU=1: sponge eps_sl(z) on the level-mean wind (iron rule; 0 = record only)
p87sfx = [repmat(sprintf('_nu%g', visc_nu), 1, double(visc_nu > 0)) repmat('_mu1', 1, double(mean_u > 0)) repmat('_ml', 1, double(sgs_ml > 0)) ...
          repmat('_dry', 1, dry) repmat('_arm', 1, strcmp(snd_src,'arm')) repmat('_ushear', 1, strcmp(ubar_src,'profile')) repmat(sprintf('_cold%d-%d', ic_cols(1), ic_cols(end)), 1, strcmp(ic_src,'coldblock')) repmat(sprintf('_dt%g', dt), 1, double(dt ~= 6))];
fpre = sprintf('ACE_V024p87_%d_', Nx);                                      % output prefix
% ---- MOUNTAIN WAVE. U1-rig parameters kept where the 5-km grid
% allows (U0=15, N=0.01, C1 sin^2 ramp of duration 4a/U0); geometry scaled to a=20 km (=4 dx).
% Idealized DRY two-layer sounding (N1 troposphere -> N2 stratosphere, tanh transition; a
% constant-N=0.01 column cannot reach 40 km: Exner pi hits 0 near 35 km). ubar UNIFORM in z
% (no upper decay: a decaying ubar would plant a critical level inside the weak-sponge band).
% Wall target u_tot=0 => ioflow = rho*ubar(t)*s at every wall cell; gauge = 'fluid' (fluid-
% face mean of rho0u' = 0 per level, so far-field u_tot = ubar at EVERY level; with ubar=0 the
% 'fluid' and 'all' gauges coincide exactly, so the ubar=0 cases are untouched). HOW TO CHANGE: mw.* below.
mw = struct();
mw.U0 = 15; mw.N1 = 0.01; mw.N2 = 0.025; mw.ztr = 17e3; mw.wtr = 1500;   % wind + N(z) profile
mw.Ts = 300; mw.ps = 1000e2; mw.qv0 = 1e-5;                              % surface T, p ; trace qv (dry)
mw.a = 5e3; if exist('MW_A','var'), mw.a = MW_A; end; mw.xc_face = Nx/2;  % bell half-width (preset MW_A, m); centre = face Nx/2 | Nx/2+1 (Pm-symmetric)
if exist('MW_U0','var'), mw.U0 = MW_U0; end
mw.H = 1500; if exist('MW_H','var'), mw.H = MW_H; end; mw.H_lin = 300; if exist('MW_HLIN','var'), mw.H_lin = MW_HLIN; end   % bell heights (presets MW_H, MW_HLIN; H = 0 => flat everywhere-IB ground)
mw.tau = 4*mw.a/mw.U0; if exist('MW_TAU','var'), mw.tau = MW_TAU; end     % ramp duration (U1 rule 4a/U; preset MW_TAU, 0 = impulsive)
mw.T = 4*3600; if exist('MW_T','var'), mw.T = MW_T*3600; end; mw.dtout = 600; if exist('MW_DTOUT','var'), mw.dtout = MW_DTOUT; end   % length (preset MW_T, h) and output interval (MW_DTOUT, s)
mw.gauge = 'fluid';                                                      % 'fluid' (default) | 'all' (all-face mean) [kkt solver only]
mw.topo_solver = 'cap'; mw.partial = partial_on; mw.vmin = partial_vmin; mw.smin = partial_smin; mw.ib = partial_ib; mw.ib_slope = ib_slope; mw.ib_noslip = ib_noslip; mw.visc_nu = visc_nu; mw.visc_wall = visc_wall; mw.mean_u = mean_u; mw.sgs_ml = sgs_ml; mw.ll_z0 = ll_z0; mw.ll_zn = ll_zn; mw.ll_taun = ll_taun; mw.ll_nudge = ll_nudge; mw.mean_u_sponge = mean_u_sponge;   % partial-step IB ; topo_solver 'cap' = production (body capacitance, hard) ; 'psi' = the gate twin only
mw.snd = snd_src; mw.ubar = ubar_src; mw.ic = ic_src; mw.ic_cols = ic_cols; mw.ic_BL = ic_BL; mw.ic_dT = ic_dT; mw.ic_dqc = ic_dqc; mw.z_ramp = z_ramp; mw.zd0 = zd0; mw.zd1 = zd1;
mw.cap_mode = 'taper'; if exist('CAPMODE','var'), mw.cap_mode = CAPMODE; end   % preset CAPMODE='exact' = whole-domain Poisson closure per stage (no +-NT window)                                                   % 'taper' (k~=0 part of psi cosine-tapered to 0 beyond +-NT; k=0 part kept) | 'trunc' (hard cut) | 'exact' (verification twin of the psi solve)
IMPORT_CONSTANTS_NOGLOBAL
Nzm = length(zm);
fprintf('geometry: Ni=%d entities (D=%g km), Lx=%g km periodic; Nzm=%d @ dz=%g m; turn_on_K2=%d\n', ...
        Ni, D(1), Ni*D(1), Nzm, dz, turn_on_K2);

%% ======== [V024: kernels] ========
%% Load the kernel tables (built by util_basis/V024p87_CONSTRUCT_KERNELS.m):
% K1 = inv(Lap)*dxx (7-tap c-rule truncation), K2 = inv(Lap)*dx (6-tap closed odd pairs),
% forcing layers = edges (100 m below z_split, 200 m above). The full kernels are not
% needed by the march; only the truncated tables are loaded. HOW TO CHANGE: rebuild via
% util_basis/V024p87_CONSTRUCT_KERNELS.m (never edit the .mat by hand).
maxNumCompThreads(4);
Nx = Ni; dx = D(1)*1e3; Lx = Nx*dx;
NT_req = 30; if exist('NT','var'), NT_req = NT; end               % truncation half-width (preset NT): 30 for D = 500 m, 3 for the coarse D = 5 km set
if exist('KFILE','var')
  kfile = KFILE;                                                   % explicit composite basis file (preset KFILE)
else
  if mod(dx, 1000) == 0, dxtag = sprintf('%gkm', dx/1000); else, dxtag = sprintf('%gm', dx); end
  kfile = [dir_ace '/data/basis/' sprintf('COMPOSITE_ACE_BASIS_2D_V024_dx=%s_NT=%d.mat', dxtag, NT_req)];   % the basis ships in ./data/basis/
  assert(isfile(kfile), 'no composite basis for dx=%s, NT=%d (%s): run util_basis/V024p87_CONSTRUCT_KERNELS.m', dxtag, NT_req, kfile);
end
T = load(kfile); PMBt = T.PMB_trunc; K2t = T.K2_trunc;
NT = T.params.NT; assert(NT == NT_req, 'truncation half-width mismatch (basis NT %d vs preset %d)', NT, NT_req);
assert(Ni >= 2*NT + 2, 'Ni must exceed the truncation window 2NT+2');
w1_di = mod([0, 1:NT, -(1:NT)], Ni) + 1; w2_di = mod(-(NT-1):NT, Ni) + 1;   % tap orders for THIS Ni: K1 Delta 0,+1..+NT,-1..-NT ; K2 Delta -(NT-1)..NT (the tables depend on (D, NT, tiling, nbuf) only)
assert(T.params.dx == dx && T.params.nbuf == nbuf, 'basis entity width / buffer-row mismatch');
assert(max(abs(T.params.edges(:)-edges(:)))==0, 'layer edges mismatch');
assert(isequal(size(PMBt),[2*NT+1,numel(zm),Nlay]) && isequal(size(K2t),[2*NT,numel(zm),Nlay]), 'kernel size mismatch');
fprintf('basis: %s (Nx=%d dx=%g m, +-%d columns, Nlay=%d L3 forcing tiling)\n', kfile, Ni, dx, NT, Nlay);

%% Sounding preprocessing (ARM nc)
  [plev, pr, ta, hus, prw, date, hh] = LOAD_SOUNDINGS([dir_armbe armfn], arm);
  [T_p, q_p, rho_p, z_p] = INTERP_P_GRID(plev, ta(:,pidx), hus(:,pidx), p);
q_p = TWEAK_THETA_E(T_p, q_p, p);
% iso_C1/d_iso passed through; iso_C1=0 (default) is bit-identical to the plain fill.
[T_env, q_env, Tv_env, theta_e_env, rho_env, p_z,...
 T_zm, q_zm, Tv_zm, theta_e_zm, rho_zm, p_zm,...
 theta_zm, theta_es_zm, rh_zm] = INTERP_Z_GRID_BUF(nbuf, T_p, q_p, z_p, p, zm, z, dz, iso_C1, d_iso);   % buffer rows padded
day = date(pidx);

theta_e_mf = theta_e_zm;
qt_mf = q_zm;
Tv_mf = Tv_zm;
p_mf = p_zm;
rho_mf = rho_zm;
rho_mfh = interp1(zm,rho_mf,zm+dz/2,'makima');

theta_e_zc = theta_e_env;
qt_zc = q_env;
Tv_zc = Tv_env;
p_zc = p_z;
rho_zc = rho_env;
rho_zi = rho_zm;

damp = dt*(eps_sl./[rho_zc,rho_zc,rho_mf]);      % sponge iron rule (eps_sl)

MF = MF0*sin( pi*(zm-zb)/(zt-zb) );
MF(zm>zt | zm<zb) = 0;

% Prescribed background wind on both grids (evaluated always; consumed only if ubar_on).
ubar_zc = UBAR_PROFILE(z,  U0, z_ramp, zd0, zd1);   % on cell centers z
ubar_zm = UBAR_PROFILE(zm, U0, z_ramp, zd0, zd1);   % on interfaces zm
fprintf('sounding done: theta_e_zc(1)=%.2f K  qt_zc(1)=%.4g kg/kg  rho_zc(1)=%.3f ; ubar max=%.2f m/s\n', ...
        theta_e_zc(1), qt_zc(1), rho_zc(1), max(ubar_zc));


%% Initial condition (resting base state) + eta diagnosis + ace struct
% STATE LAYOUT: X(z,var,ACE), var 1-5 [theta_e,qt,MF,dTHpr,pracc]; var 6 = eta on
% the 401-row zm grid (rows 2..400 live, rows 1/401 zero; 3rd dim = FACE index f)
% -- a DIAGNOSTIC re-slaved to MF every step; var 7 = the psi-gauge reference cref
% (rows 1..Nzc of entity 1), set by the stage closure.
% The base X0 is the resting base state; the case IC comes from the IC preset in SETUP_MW.
X0 = [theta_e_zc,qt_zc,MF,zeros(Nzm,4),...
      repmat([theta_e_zc,qt_zc,-MF/(Ni-1),zeros(Nzm,4)],1,Ni-1,1)];
X0 = reshape(X0,[Nzm,7,Ni]);
t0 = 0;

ace.damp = damp;
ace.dt = dt;
ace.dry = dry;                                  % DRY=1: dry dynamics (unsaturated inversion, no precip sinks)
ace.p_zc = p_zc;
ace.rho_zc = rho_zc;
ace.Tv_zc = Tv_zc;
ace.theta_e_diag = theta_e_diag;
ace.Wbar_eq_zero = Wbar_eq_zero;
ace.Ai = Ai;
ace.dz = dz;
ace.qt_zc = qt_zc;
ace.theta_e_zc = theta_e_zc;
ace.zm = zm;
ace.Ni = Ni;
ace.k = k;
ace.rho_zi = rho_zi;
ace.Nzm = Nzm;
ace.eps_tur = eps_tur;
ace.qc_ramp = qc_ramp;
ace.dqc = dqc;
ace.tau_pr = tau_pr;
% ubar params
ace.dx = D(1)*1e3;
ace.ubar_on = ubar_on;
ace.ubar_zc = ubar_zc;
ace.ubar_zm = ubar_zm;
% V024: model time (set per stage by the integrator), ubar time-ramp (0 = none, i.e. the
% static profile), and the level gauge for ioflow ('fluid' | 'all'; flat => plain mean).
ace.t = 0; ace.ubar_tau = 0; ace.gauge = mw.gauge;
ace.ndead = ndead; ace.nbuf = nbuf; ace.lamb = lamb_form; ace.lamb_upwind_weno = lamb_upwind_weno;
% RUN CONTROL / DIAGNOSTIC STATE carried by the struct (no hidden module state): ace.run (resume flag,
% output directory, closure print throttle), ace.rec (TOPO / LAMB / MEANU accumulators), ace.inv (theta_e
% inversion cold-restart flag and warm caches), ace.diag (gate diagnostic hooks). Every function that MUTATES
% them returns the updated ace.
ace.run = struct('resume', resume_ckpt, 'outdir', 'OUTPUT', 'closure_print_left', 0);
ace.rec = struct('topo', [], 'lamb', [], 'meanu', []);
ace.inv = struct('reset', [], 'Tp', [], 'QLp', [], 'QIp', [], 'Tp_dry', []);
ace.meanu = struct('dmfdt_prev', []);
ace.diag = struct('k2', [], 'lamb', [], 'expf', [], 'psi', [], 'exp_trace', []);

% K1/PMB + K2 channels -- TRUNCATED tables on the MIXED tiling; cell->layer via Lmap.
ace.PMBt = PMBt; ace.K2t = K2t; ace.turn_on_K2 = turn_on_K2;
ace.edges = edges; ace.Nlay = Nlay;
[ace.lay_of_cell, ace.Lmap] = LAYER_MAP(Nzm-1, dz, edges);      % (Nlay x Nzc)
ace.w1_di = w1_di; ace.w2_di = w2_di; ace.NT = NT;
ii = (1:Ni)';
ace.gw1 = mod((ii-1)-(w1_di-1), Ni) + 1;          % (Ni x 61) source-entity gather
ace.gw2 = mod((ii-1)-(w2_di-1), Ni) + 1;          % (Ni x 60) source-face gather
ace.eps_out = squeeze(eps_tur(1,1,:))'; ace.eps_in = squeeze(eps_tur(1,1,:))';

% ---- stacked+folded K tables, generalized to +-NT taps ----
Nlay5 = Nlay; Nz5 = size(PMBt,2); nt1 = 2*NT+1; nt2 = 2*NT;
Kb1 = zeros(nt1*Nlay5, Nz5); GW1b = zeros(Ni, nt1*Nlay5);
for lay5 = 1:Nlay5
  Kb1((lay5-1)*nt1+(1:nt1),:) = squeeze(PMBt(:,:,lay5));
  GW1b(:,(lay5-1)*nt1+(1:nt1)) = ace.gw1 + (lay5-1)*Ni;
end
Kb2 = zeros(nt2*Nlay5, Nz5); GW2b = zeros(Ni, nt2*Nlay5);
for lay5 = 1:Nlay5
  Kb2((lay5-1)*nt2+(1:nt2),:) = squeeze(K2t(:,:,lay5));
  GW2b(:,(lay5-1)*nt2+(1:nt2)) = ace.gw2 + (lay5-1)*Ni;
end
% K1 even fold: keep centre + positive taps (positions 1..NT+1); add the negative taps (NT+2..2NT+1) into positions 2..NT+1
ace.c1keep = reshape((0:Nlay5-1)*nt1 + (1:NT+1)', [], 1)';
ace.c1minus= reshape((0:Nlay5-1)*nt1 + (NT+2:2*NT+1)', [], 1)';
ace.p1dst  = reshape((0:Nlay5-1)*(NT+1) + (2:NT+1)', [], 1)';
ace.Kbig1F = Kb1(ace.c1keep,:);
% K2 odd-pair fold: tap order Delta = -(NT-1)..NT (positions 1..2NT); lead = Delta 0,-1,..,-(NT-1) = positions NT, NT-1, .., 1 ;
% partner (1-Delta) = Delta 1..NT = positions NT+1..2NT ; K(1-Delta) = -K(Delta)
ace.c2lead = reshape((0:Nlay5-1)*nt2 + (NT:-1:1)', [], 1)';
ace.c2part = reshape((0:Nlay5-1)*nt2 + (NT+1:2*NT)', [], 1)';
ace.Kbig2F = Kb2(ace.c2lead,:);
ace.GW1big = GW1b; ace.GW2big = GW2b;
clear Kb1 Kb2 GW1b GW2b
% ---- TAP-LOOP K apply (speed-up): the stacked single-GEMM path gathers an
%      Ni x (ntaps*Nlay) source matrix (~90 MB) on EVERY call -- memory-bound (profile: K1+K2 = 63 % of a step at
%      ~18 GFLOP/s). The tap loop uses circshift of the small (Ni x Nlay) source and NT+1 (K1) / NT (K2) GEMMs of
%      Ni x Nlay x Nz with the SAME folded tables (even fold K1, odd-pair fold K2): identical arithmetic content,
%      different summation order (certified below against the stacked path AND the layer loops, <= 1e-12 rel).
ace.K1tap = cell(NT+1,1); for d = 0:NT, ace.K1tap{d+1} = squeeze(PMBt(1+d,:,:)).'; end          % tap Delta = +d (positions 1..NT+1) -> (Nlay x Nz)
ace.K2tap = cell(NT,1);   for m = 0:NT-1, ace.K2tap{m+1} = squeeze(K2t(NT-m,:,:)).'; end        % lead tap Delta = -m (position NT-m) -> (Nlay x Nz)
ace.NTtap = NT;
% defaults for the geometry weights (flat until TERRAIN_MASKS sets them): all ones / no exclusion
ace.vk = ones(Nzm-1,Ni); ace.ak = ones(Nzm-1,Ni); ace.Aface = ones(Nzm-1,Ni); ace.vfrac = ones(Nzm-1,Ni); ace.omx_mask = false(Nzm,Ni); ace.rsol = zeros(1,Ni); ace.pface = []; ace.pcol = [];
% wiring insurance: stacked/folded paths == layer loops (<= 1e-12 rel)
rng(5); tB = randn(Nzm,Ni); tF = randn(Nzm,Ni); tD = randn(Nzm-1,Ni);
gK1w = max(abs(NONLOCAL_RESPONSE_CONV(tB,tF,ace) - NONLOCAL_RESPONSE_CONV_ORIG(tB,tF,ace)),[],'all') ...
       / max(abs(NONLOCAL_RESPONSE_CONV_ORIG(tB,tF,ace)),[],'all');
gK2w = max(abs(K2TAIL(tD,ace) - K2TAIL_ORIG(tD,ace)),[],'all') / max(abs(K2TAIL_ORIG(tD,ace)),[],'all');
S1 = (ace.Lmap * (tB(1:end-1,:) + tF(1:end-1,:))).'; gK1s = max(abs(K1_APPLY_LAYERS(S1,ace) - K1_APPLY_STACKED(S1,ace)),[],'all') / max(abs(K1_APPLY_STACKED(S1,ace)),[],'all');
S2 = (ace.Lmap * tD).'; gK2s = max(abs(K2_APPLY_LAYERS(S2,ace) - K2_APPLY_STACKED(S2,ace)),[],'all') / max(abs(K2_APPLY_STACKED(S2,ace)),[],'all');
fprintf('GATE V024 K wiring: K1 %.3e | K2 %.3e (<=1e-12) ; tap-loop vs stacked: K1 %.3e | K2 %.3e\n', gK1w, gK2w, gK1s, gK2s);
assert(gK1w <= 1e-12 && gK2w <= 1e-12 && gK1s <= 1e-12 && gK2s <= 1e-12, 'K wiring insurance FAILED');
clear tB tF tD

% ---- V024 TERRAIN masks + mixed-basis capacitance (top faces: K1 rock sources;
%      walls: K2 vortex-sheet responses) ----
ace = TERRAIN_MASKS(ace, kbot, terrain_on);
ace = BUILD_V024_CAP(ace);


% IC eta diagnosis: (rho0 u) = -ioflow(IC MF); eta per definition. The resting IC has MF = 0
% -> eta = 0; the general path is still exercised.
eta0 = ETA_IC_DIAGNOSE(X0, ace);
X0(:,6,:) = permute(eta0,[1,3,2]);
X0(1,6,:) = 0;
X0(Nzm,6,:) = 0;
X0(:,7,:) = 0;
fprintf('IC: resting base state ; ace built ; turn_on_K2=%d ; max|eta0|=%.2e\n', ...
        ace.turn_on_K2, max(abs(eta0(:))));


%% ======== [V024: gates + runs] ========
maxNumCompThreads(4);
ace.run.closure_print_left = 0;
ace.rec.topo = struct('n',0,'maxr',0,'maxq',0,'maxdE',0,'sumdE',0,'tworep',0);
% OUTPUT DIRECTORY (preset OUTDIR, default 'OUTPUT'): every file this run writes lands here, and the
% continuation reads (RESUME / mwpost / mwextend) are looked up here. Input data files are unaffected.
ace.run.outdir = 'OUTPUT'; if exist('OUTDIR','var'), ace.run.outdir = OUTDIR; end
if ~isfolder(ace.run.outdir), mkdir(ace.run.outdir); end
fprintf('output directory: %s\n', ace.run.outdir);
progress_file = OUTP('progress_V024p87.log', ace.run.outdir);
pf_ = fopen(progress_file,'a'); fprintf(pf_,'[%s] ACE_V024p87 start RUN_MODE=%s\n', datestr(now,'HH:MM:SS'), RUN_MODE); fclose(pf_);

% sounding for the terrain runs: iso_C1=1, ubar OFF under the mountain
iso_C1_s = 1; ubar_on_s = 0;
[Te,qe,Tve,thee,rhoe,pz, Tzm3,qzm3,Tvzm3,theezm,rhozm,pzm3,thzm,thes,rh] = INTERP_Z_GRID_BUF(nbuf,T_p,q_p,z_p,p,zm,z,dz,iso_C1_s,d_iso);
% ARM sounding as a case preset (SND='arm'): both grids, iso_C1_s = 1 (run-3 convention); consumed by SETUP_MW like the ideal sounding
mw.arm = struct('T_zc',Te,'q_zc',qe,'Tv_zc',Tve,'theta_e_zc',thee,'rho_zc',rhoe,'p_zc',pz,'theta_zc',Te.*(1e5./pz).^(287.04/1005.7), ...
                'T_zm',Tzm3,'q_zm',qzm3,'Tv_zm',Tvzm3,'theta_e_zm',theezm,'rho_zm',rhozm,'p_zm',pzm3,'theta_zm',thzm, ...
                'N2_zm',9.80665./thzm.*gradient(thzm, dz),'N2_zc',9.80665./(Te.*(1e5./pz).^(287.04/1005.7)).*gradient(Te.*(1e5./pz).^(287.04/1005.7), dz),'pidx',pidx,'iso_C1',iso_C1_s);




% ===================== MOUNTAIN WAVE =====================
if any(strcmp(RUN_MODE, {'mwgates','mw','mwpost','cwbubble','mwextend','mwsine'}))
  [aceMW, X0mw, snd] = SETUP_MW(ace, mw, mw.H, z, zm, dz, dt, eps_sl);
  fprintf('MW sounding: Ts=%g K ps=%g hPa N1=%g N2=%g ztr=%g m ; rho_s=%.3f ; theta(0)=%.2f theta(15km)=%.2f T(17km)=%.1f T(40km)=%.1f p(40km)=%.2f hPa\n', ...
          mw.Ts, mw.ps/100, mw.N1, mw.N2, mw.ztr, snd.rho_zc(1), snd.theta_zc(1), snd.theta_zc(find(z>=15e3,1)), snd.T_zc(find(z>=17e3,1)), snd.T_zc(end-1), snd.p_zc(end-1)/100);
  fprintf('MW terrain (H=%g m, a=%g km): kbot=%s ; crest %g m ; %d cols ; Nb=%d (C1 %d + C3 %d) rank=%d null=%d cond(C)=%.3e cond(Sm)=%.3e ; ubar U0=%g tau=%g s gauge=%s\n', ...
          mw.H, mw.a/1e3, mat2str(aceMW.kbot(aceMW.kbot>nbuf)), (max(aceMW.kbot)-nbuf)*dz, nnz(aceMW.kbot>nbuf), aceMW.cap.Nb, aceMW.cap.Nc1, aceMW.cap.Nc3, aceMW.cap.rk, aceMW.cap.nnull, aceMW.cap.condC, aceMW.cap.condSm, mw.U0, mw.tau, aceMW.gauge);
end
if any(strcmp(RUN_MODE, {'mwgates','mw'})) && ~exist('SKIPGATES','var')
  MW_GATES(ace, aceMW, X0mw, mw, z, zm, dz, dt, eps_sl);    % preset SKIPGATES=1 to launch a run without re-running the battery
end
if strcmp(RUN_MODE, 'mw')
  RUN_MW([fpre sprintf('mw_H%g_a%g_U%g', mw.H, mw.a/1e3, mw.U0) repmat('_fx',1,~lamb_form) repmat('_exact',1,strcmp(mw.cap_mode,'exact')) repmat('_sl',1,partial_ib*ib_slope) repmat('_ns',1,partial_ib*ib_noslip) p87sfx], mw, aceMW, X0mw, snd, dt, progress_file);
end
if strcmp(RUN_MODE, 'mwpost')
  % recover a finished-but-unsaved march from its checkpoint (MWPOST_TAG / MWPOST_H preset)
  if ~exist('MWPOST_H','var'), MWPOST_H = mw.H; end
  if ~exist('MWPOST_TAG','var'), MWPOST_TAG = [fpre 'mw_H1000_a20_U15']; end
  mwp = mw; mwp.H = MWPOST_H;
  [aceMP, ~, sndp] = SETUP_MW(ace, mwp, mwp.H, z, zm, dz, dt, eps_sl);
  ck = load(OUTP([MWPOST_TAG '_ckpt.mat'], ace.run.outdir));
  fprintf('mwpost: %s from checkpoint (%d outputs, t_end=%g s)\n', MWPOST_TAG, numel(ck.tspan_ckpt), ck.tspan_ckpt(end));
  POST_MW(MWPOST_TAG, mwp, aceMP, sndp, ck.Xckpt, ck.tspan_ckpt, false, numel(ck.tspan_ckpt), NaN, dt, progress_file);
end
if strcmp(RUN_MODE, 'mwsine')
  % CONTINUOUS random topography: h(x) = sum of NSINE periodic sine modes (integer mode numbers m in
  % [MSINE_LO, MSINE_HI] over Lx = 440 km, amplitudes ~ 1/m, fixed seed), shifted so min h = 0 and scaled to HSINE peak.
  % Terrain everywhere (no flat far field): linear reference uses the actual h (mw_analysis reads h_sv). U0 = 15, N = 0.01,
  % ramp 4*a_eff/U0 with a_eff = 20 km, 5 h, 10-min outputs. Not Pm-symmetric (random phases) -> G11 not applicable.
  NS_ = 16; if exist('NSINE','var'), NS_ = NSINE; end
  HS_ = 600; if exist('HSINE','var'), HS_ = HSINE; end
  mlo = 4; mhi = 44; if exist('MSINE_LO','var'), mlo = MSINE_LO; end, if exist('MSINE_HI','var'), mhi = MSINE_HI; end
  rng(7); mset = sort(randperm(mhi - mlo + 1, NS_) + mlo - 1); ph = 2*pi*rand(1, NS_); amp = 1 ./ mset;
  xi = ((1:Ni)-0.5)*ace.dx; Lx_ = Ni*ace.dx; hs = zeros(1,Ni);
  for q_ = 1:NS_, hs = hs + amp(q_)*sin(2*pi*mset(q_)*xi/Lx_ + ph(q_)); end
  hs_min = min(hs); hs_scl = HS_/max(hs - hs_min);
  hs = (hs - hs_min) * hs_scl;
  hs_fun = @(x) (sum(amp(:) .* sin(2*pi*mset(:)*x(:).'/Lx_ + ph(:)), 1) - hs_min) * hs_scl;   % the same terrain as a function of x (face heights under IBSLOPE)
  mws = mw; mws.U0 = 15; mws.a = 20e3; mws.tau = 4*mws.a/mws.U0; mws.T = 5*3600; mws.dtout = 600; mws.H = HS_; mws.h_override = hs; mws.h_fun = hs_fun;
  [aceS, X0s, snds] = SETUP_MW(ace, mws, mws.H, z, zm, dz, dt, eps_sl);
  fprintf('SINE topography: %d modes m=%s ; h max %.0f m mean %.0f m std %.0f m ; max |dh/dx| %.3f ; kbot max %d ; Nb=%d\n', NS_, mat2str(mset), max(hs), mean(hs), std(hs), max(abs(diff(hs)))/ace.dx, max(aceS.kbot), aceS.capb.Nb);
  RUN_MW([fpre sprintf('mwsine%d_H%d_U15', NS_, HS_) repmat('_fx',1,~lamb_form) repmat('_sl',1,partial_ib*ib_slope) repmat('_ns',1,partial_ib*ib_noslip) p87sfx], mws, aceS, X0s, snds, dt, progress_file);
end
if strcmp(RUN_MODE, 'loglaw')
  % log-law EQUILIBRIUM consistency check. Flat everywhere-IB ground, neutral (N1 = 1e-4),
  % U0 uniform switched on impulsively; NO no-slip constraint (free-slip kinematics): the boundary condition is the WALL
  % MODEL tau_w = rho0 u*^2 with u* = kappa u1/ln((dz/2+z0)/z0), plus the mixing-length SGS nu_t = kappa u* min(z, z_n);
  % the level-mean wind above z_n is relaxed to U0 (Couette-type drive) so the equilibrium below z_n has CONSTANT stress
  % => u = (u*/kappa) ln(z/z0), u* = kappa U0/ln(z_n/z0). x-uniform: lives in the k = 0 mode (MEANU = 1).
  % Presets: LL_Z0 (0.1 m), LL_ZN (3000 m), LL_TAUN (600 s), LL_T (hours, 6), MEANU.
  mwl2 = mw; mwl2.h_override = zeros(1,Ni); mwl2.H = 0; mwl2.tau = 0; mwl2.dtout = 600; mwl2.N1 = 1e-4;
  mwl2.T = 6*3600; if exist('LL_T','var'), mwl2.T = LL_T*3600; end
  mwl2.ib_noslip = 0; mwl2.visc_nu = 0; mwl2.sgs_ml = 1; mwl2.ll_nudge = 1; mwl2.mean_u = 1;   % the level-mean equation is required by this test
  [aceL2, X0l2, sndl2] = SETUP_MW(ace, mwl2, mwl2.H, z, zm, dz, dt, eps_sl);
  us_ = 0.4*mwl2.U0/log(mwl2.ll_zn/mwl2.ll_z0);
  fprintf('LOGLAW: flat everywhere-IB, U0=%g impulsive, wall model + mixing-length SGS (z0=%g m, z_n=%g m, tau_n=%g s), no-slip %d, MEANU %d ; expected u*=%.3f m/s, nu_t(z_n)=%.0f m2/s ; %g h\n', ...
          mwl2.U0, mwl2.ll_z0, mwl2.ll_zn, mwl2.ll_taun, mwl2.ib_noslip, mwl2.mean_u, us_, 0.4*us_*mwl2.ll_zn, mwl2.T/3600);
  RUN_MW([fpre sprintf('loglaw_U%g_z0%g_zn%g_mu%d', mwl2.U0, mwl2.ll_z0, mwl2.ll_zn/1e3, mwl2.mean_u)], mwl2, aceL2, X0l2, sndl2, dt, progress_file);
end
if strcmp(RUN_MODE, 'rayleigh')
  % Rayleigh/Stokes consistency test. Flat ground (buffer row only, everywhere IB), neutral
  % (N1 = 1e-4), uniform U0 switched on IMPULSIVELY (tau = 0: the first closure stage brings the wall to rest), no-slip as
  % the hard IB constraint on every ground face, explicit vertical viscosity nu with the IB wall stress, level-mean
  % momentum equation (MEANU = 1; the problem is x-uniform = k = 0 mode). Analytic (Boussinesq, semi-infinite):
  % u(z,t) = U0 erf(z / (2 sqrt(nu t))). Presets: VISC (default 50 m2/s), RT (hours, default 4), RN1.
  mwr = mw; mwr.h_override = zeros(1,Ni); mwr.H = 0; mwr.tau = 0; mwr.dtout = 600;
  mwr.N1 = 1e-4; if exist('RN1','var'), mwr.N1 = RN1; end
  mwr.T = 4*3600; if exist('RT','var'), mwr.T = RT*3600; end
  mwr.ib_noslip = 1; if exist('RNOSLIP','var'), mwr.ib_noslip = RNOSLIP; end
  mwr.visc_nu = 50; if exist('VISC','var'), mwr.visc_nu = VISC; end
  mwr.mean_u = 1;                        % the level-mean equation is required by this test
  [aceR, X0r, sndr] = SETUP_MW(ace, mwr, mwr.H, z, zm, dz, dt, eps_sl);
  fprintf('RAYLEIGH: flat everywhere-IB ground, U0=%g impulsive, nu=%g m2/s (wall stress %d), no-slip %d, MEANU %d, N1=%g ; Nb=%d capb Nb=%d ; %g h\n', ...
          mwr.U0, mwr.visc_nu, aceR.visc_wall, mwr.ib_noslip, mwr.mean_u, mwr.N1, aceR.cap.Nb, aceR.capb.Nb, mwr.T/3600);
  RUN_MW([fpre sprintf('rayleigh_U%g_nu%g_mu%d', mwr.U0, mwr.visc_nu, mwr.mean_u) repmat('_ns',1,mwr.ib_noslip) repmat('_nowall',1,double(~aceR.visc_wall))], mwr, aceR, X0r, sndr, dt, progress_file);
end
if strcmp(RUN_MODE, 'mwextend')
  % EXTEND a finished mountain-wave run: restart from the saved final state Xlast of
  % <EXTTAG>.mat and march another EXTT seconds with the SAME geometry/closure presets; ubar ramp off (tau = 0, R = 1).
  % The extension file's tspan is RELATIVE (0..EXTT); absolute time = t_end(base) + tspan.
  assert(exist('EXTTAG','var') == 1, 'mwextend: preset EXTTAG = base tag');
  if ~exist('EXTT','var'), EXTT = 4*3600; end
  B = load(OUTP([EXTTAG '.mat'], ace.run.outdir), 'Xlast', 'tspan_save', 'mw');
  mwe = mw; mwe.H = B.mw.H; mwe.a = B.mw.a; mwe.tau = 0; mwe.T = EXTT; mwe.dtout = mw.dtout;
  [aceE, ~, snde] = SETUP_MW(ace, mwe, mwe.H, z, zm, dz, dt, eps_sl);
  X0e = B.Xlast; t_base = B.tspan_save(end);
  fprintf('EXTEND %s from t=%g s by %g s (ramp off, R=1)\n', EXTTAG, t_base, EXTT);
  RUN_MW([EXTTAG sprintf('_ext%gh', (t_base+EXTT)/3600)], mwe, aceE, X0e, snde, dt, progress_file);
end
if strcmp(RUN_MODE, 'cwbubble')
  % CW16 EXP2 analogue: Straka cold bubble sliding down a gentle slope. Neutral resting atmosphere
  % (N1 -> 1e-4), plateau 1.2 km high / half-width 5 km, constant slope 0.08 to the foot at |x-xc| = 20 km, dry;
  % dtheta = -15 K (cos(pi L)+1)/2, L = sqrt(((x-xc)/xr)^2 + ((z-zc)/zr)^2), xr = 4 km, zr = 2 km, zc = 3.2 km (2 km
  % above the plateau). CW16: dx = dz = 200 m, dt = 1 s, 1 h, 75 m2/s diffusion. Here dx = 500 m, dz = 100 m, dt = 3 s,
  % ILES (WENO+ZS, no explicit diffusion), 1 h, 2-min outputs. Same test for block / partial / IB by the usual presets.
  mwb = mw; mwb.U0 = 0; mwb.tau = 1; mwb.N1 = 1e-4; mwb.T = 3600; mwb.dtout = 120; mwb.H = 1200; mwb.a = 20e3;
  xi = ((1:Ni)-0.5)*ace.dx; xcb = mw.xc_face*ace.dx; rb = abs(xi - xcb);
  hb = zeros(1,Ni); hb(rb < 5e3) = 1200; mb = rb >= 5e3 & rb < 20e3; hb(mb) = 1200 - 0.08*(rb(mb) - 5e3);
  mwb.h_override = hb; mwb.h_fun = @(x) 1200*(abs(x - xcb) < 5e3) + (1200 - 0.08*(abs(x - xcb) - 5e3)).*(abs(x - xcb) >= 5e3 & abs(x - xcb) < 20e3); dtb = 3;
  [aceB, X0b, sndb] = SETUP_MW(ace, mwb, mwb.H, z, zm, dz, dtb, eps_sl); aceB.ubar_on = 0; aceB.dt = dtb;
  xr = 4e3; zr = 2e3; zcb = 3200; nbub = 0;
  for i = 1:Ni
    for k = 1:Nzm-1
      zk = z(k); Lb = sqrt(((xi(i)-xcb)/xr)^2 + ((zk-zcb)/zr)^2);              % physical height (buffer row below z = 0)
      if Lb < 1 && k > aceB.kbot(i)
        dth = -15*(cos(pi*Lb)+1)/2; Tb = sndb.T_zc(k) + dth*(sndb.T_zc(k)/sndb.theta_zc(k));
        X0b(k,1,i) = eval_theta_e(Tb, sndb.q_zc(k), 0, 0, sndb.p_zc(k)); nbub = nbub + 1;
      end
    end
  end
  e0b = ETA_IC_DIAGNOSE(X0b, aceB); X0b(:,6,:) = permute(e0b,[1,3,2]); X0b(1,6,:) = 0; X0b(Nzm,6,:) = 0; X0b(:,7,:) = 0;
  fprintf('CW16-EXP2 bubble: %d cells, dtheta min %.2f K ; plateau 1200 m |x-xc|<5 km, slope 0.08 to 20 km ; kbot max %d ; N1=%g ; dt=%g s ; 1 h\n', nbub, -15, max(aceB.kbot), mwb.N1, dtb);
  RUN_MW([fpre 'cwbubble_slope008' repmat('_sl',1,partial_ib*ib_slope) repmat('_ns',1,partial_ib*ib_noslip) p87sfx], mwb, aceB, X0b, sndb, dtb, progress_file);
end
pf_ = fopen(progress_file,'a'); fprintf(pf_,'[%s] ACE_V024p87 done RUN_MODE=%s\n', datestr(now,'HH:MM:SS'), RUN_MODE); fclose(pf_);

%% ================= local functions =================
function p = OUTP(f, outdir)
  % Path of a run OUTPUT file: ace.run.outdir (preset OUTDIR, default 'OUTPUT') joined with the file name.
  % Used at EVERY site that writes a run output or reads a continuation of one. Input data files
  % (kernel tables, soundings) do NOT go through it.
  d = 'OUTPUT'; if ~isempty(outdir), d = outdir; end
  p = fullfile(d, f);
end

function ubar = UBAR_PROFILE(zz, U0, z_ramp, zd0, zd1)
  % C1-smooth prescribed wind: sin^2 ramp 0..z_ramp, plateau U0 to zd0, cosine
  % decay zd0..zd1, 0 above. Slopes match (=0) at all joints.
  ubar = zeros(size(zz));
  m1 = (zz>=0)&(zz<=z_ramp);
  m2 = (zz>z_ramp)&(zz<=zd0);
  m3 = (zz>zd0)&(zz<=zd1);
  ubar(m1) = U0 * sin(pi*zz(m1)/(2*z_ramp)).^2;
  ubar(m2) = U0;
  ubar(m3) = U0 * 0.5 * (1 + cos(pi*(zz(m3)-zd0)/(zd1-zd0)));
end

function varargout = INTERP_Z_GRID_BUF(nbuf, T_p, q_p, z_p, p, zm, z, dz, iso_C1, d_iso)
  % the ARM sounding is interpolated on the PHYSICAL rows (zm >= 0) and the nbuf buffer rows below the ground
  % are padded with the surface (first physical row) values -- the buffer is rock, its state is never marched.
  varargout = cell(1, 15);
  [varargout{:}] = INTERP_Z_GRID(T_p, q_p, z_p, p, zm(nbuf+1:end), z(nbuf+1:end), dz, iso_C1, d_iso);
  for q_ = 1:15, v = varargout{q_}; varargout{q_} = [repmat(v(1,:), nbuf, 1); v]; end
end

function [T_env, q_env, Tv_env, theta_e_env, rho_env, p_z,...
          T_zm, q_zm, Tv_zm, theta_e_zm, rho_zm, p_zm, theta_zm,...
          theta_es_zm, rh_zm] = INTERP_Z_GRID(T_p, q_p, z_p, p, zm, z, dz, iso_C1, d_iso)
  % Above the top ARM level z_t=max(z_p), T is constant-filled (C0 kink). iso_C1=1
  % replaces T for z>z_t (env AND zm grids) with the lapse-relaxation closed form
  % T(z)=T(z_t)+Gamma_t*d_iso*(1-exp(-(z-z_t)/d_iso)), Gamma_t from the two topmost
  % ARM levels; z<=z_t untouched. iso_C1=0 reproduces the plain fill exactly.
  if nargin<8||isempty(iso_C1), iso_C1=0; end
  if nargin<9||isempty(d_iso),  d_iso=2000; end
  RD = 287.04; g = 9.80665;
  T_env = nan([length(z),size(T_p,2)]);  q_env = nan([length(z),size(T_p,2)]);
  Tv_env = nan([length(z),size(T_p,2)]); p_z = nan([length(z),size(T_p,2)]);
  T_zm = nan([length(zm),size(T_p,2)]);  q_zm = nan([length(zm),size(T_p,2)]);
  Tv_zm = nan([length(zm),size(T_p,2)]); p_zm = nan([length(zm),size(T_p,2)]);
  for pidx=1:size(T_p,2)
    T_env(:,pidx) = interp1(z_p(:,pidx),T_p(:,pidx),z,'makima',T_p(end,pidx));
    q_env(:,pidx) = interp1(z_p(:,pidx),q_p(:,pidx),z,'makima',q_p(end,pidx));
    q_env(q_env(:,pidx)<0,pidx) = 0;
    if iso_C1==1
      zt = max(z_p(:,pidx));
      Gt = (T_p(end,pidx)-T_p(end-1,pidx))/(z_p(end,pidx)-z_p(end-1,pidx));
      hi = z>zt;
      T_env(hi,pidx) = T_p(end,pidx) + Gt*d_iso*(1-exp(-(z(hi)-zt)/d_iso));
    end
    Tv_env(:,pidx) = eval_Tv(T_env(:,pidx),q_env(:,pidx),0);
    p_z(:,pidx) = interp1(z_p(:,pidx),p,z,'makima');
    midz = sum(z<=max(z_p(:,pidx)));
    for idz=midz+1:length(z)
      p_z(idz,pidx) = p_z(idz-1,pidx)*(1-g*dz/2/RD/Tv_env(idz-1,pidx))/(1+g*dz/2/RD/Tv_env(idz-1,pidx));
    end
    T_zm(:,pidx) = interp1(z_p(:,pidx),T_p(:,pidx),zm,'makima',T_p(end,pidx));
    q_zm(:,pidx) = interp1(z_p(:,pidx),q_p(:,pidx),zm,'makima',q_p(end,pidx));
    q_zm(q_zm(:,pidx)<0,pidx) = 0;
    if iso_C1==1
      zt = max(z_p(:,pidx));
      Gt = (T_p(end,pidx)-T_p(end-1,pidx))/(z_p(end,pidx)-z_p(end-1,pidx));
      hi = zm>zt;
      T_zm(hi,pidx) = T_p(end,pidx) + Gt*d_iso*(1-exp(-(zm(hi)-zt)/d_iso));
    end
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
  RD = 287.04; g = 9.80665;
  T_p = nan([length(p),size(ta,2)]);  q_p = nan([length(p),size(ta,2)]);
  Tv_p = nan([length(p),size(ta,2)]); rho_p = nan([length(p),size(ta,2)]);
  z_p = nan([length(p),size(ta,2)]);
  for pidx=1:size(ta,2)
    T_p(:,pidx) = interp1(plev,ta(:,pidx),p,'makima');
    q_p(:,pidx) = interp1(plev,hus(:,pidx),p,'makima');
    q_p(q_p(:,pidx)<0,pidx) = 0;
    Tv_p(:,pidx) = eval_Tv(T_p(:,pidx),q_p(:,pidx),0);
    rho_p(:,pidx) = p./Tv_p(:,pidx)/RD;
    z_p(:,pidx) = (RD/g*(p(1)-p(2)))*cumtrapz(Tv_p(:,pidx)./p);
  end
end

function [plev, pr, ta, hus, prw, date, hh] = LOAD_SOUNDINGS(armbefn, arm)
  g = 9.80665;
  if arm<=2
    plev = ncread(armbefn,'pressure');
    pr = ncread(armbefn,'pr');
    prw = ncread(armbefn,'prw');
    ta = ncread(armbefn,'ta');
    hus = ncread(armbefn,'hus');
    time = ncread(armbefn,'time_bnds');
    avail = sum(~isnan(ta),2)==37 & sum(~isnan(hus),2)==37 & ~isnan(pr);
    pr = pr(avail);
    prw = prw(avail);
    ta = ta(avail,:)';
    hus = hus(avail,:)';
    date = time(avail)/3600/24 + datenum(1970,1,1);
    hh = floor(mod(date,1)*24);
  elseif arm==3
    plev = ncread(armbefn,'pressure')*1e2;
    pr = ncread(armbefn,'precip_rate_sfc'); ta = ncread(armbefn,'temperature_p')';
    rh = ncread(armbefn,'relative_humidity_p')'; time = ncread(armbefn,'time');
    date = time/3600/24 + datenum(2014,1,1); hh = floor(mod(date,1)*24);
    avail = sum(~isnan(ta),2)==37 & sum(~isnan(rh),2)==37 & ~isnan(pr) & hh==5;
    pr = pr(avail); ta = ta(avail,:)'; rh = rh(avail,:)';
    hus = eval_q2(eval_es(ta).*rh/100,repmat(plev,[1,size(ta,2)]));
    prw = sum( (hus(1:end-1,:)+hus(2:end,:)) .* (plev(1:end-1)-plev(2:end)) ,1)'/2/g;
    date = date(avail); hh = hh(avail);
  end
end

function eta = ETA_IC_DIAGNOSE(X0, ace)
  % From the IC MF diagnose (rho0 u) = -ioflow (zero-mean gauge) and
  % eta = dz_c2m(rho0u) - dx_c2f(MF). Consistent by construction at t = 0.
  Nzm = ace.Nzm;
  Ni = ace.Ni;
  MF = squeeze(X0(:,3,:));
  Admfdz = ace.Ai' .* ( ( MF(2:end,:) - MF(1:end-1,:) ) / ace.dz );
  ioflow = GAUGE_IO(cumsum(Admfdz, 2), ace);
  rho0u = -ioflow;
  dz_rho0u = ( rho0u(2:end,:) - rho0u(1:end-1,:) ) / ace.dz;
  dx_MF = ( circshift(MF,-1,2) - MF ) / ace.dx;
  eta = zeros(Nzm, Ni);
  eta(2:Nzm-1,:) = dz_rho0u - dx_MF(2:Nzm-1,:);
  eta(1,:) = 0;
  eta(Nzm,:) = 0;
end

function X = ETA_RESYNC(X, ace)
  % Re-slave the eta DIAGNOSTIC (slot 6) to the CURRENT MF (post-ImDamp), so the sponge
  % reaches it implicitly through continuity. Called at the end of every outer step.
  % Slot 7 (the psi/cap gauge reference) is kept as the closure left it.
  if isfield(ace,'topo_solver') && any(strcmp(ace.topo_solver,{'psi','cap'})) && ace.terrain_on
    ace = PSI_CREF(ace, X);
    eta = ETA_OF(squeeze(X(:,3,:)), ace);
    X(:,6,:) = permute(eta,[1,3,2]); X(1,6,:) = 0; X(ace.Nzm,6,:) = 0;
    return;
  end
  eta = ETA_IC_DIAGNOSE(X, ace);
  X(:,6,:) = permute(eta,[1,3,2]); X(1,6,:) = 0; X(ace.Nzm,6,:) = 0;
end

function [X, blew_up, bstep, ace] = timeint_ckpt(odeint,tspan,X0,dt,ace,ckpt_every,ckpt_file,progress_file,tag)
  % Guarded time integration with CHECKPOINTING + progress stamps. On non-finite state
  % (incl. inv_T fail-fast NaN) the march stops and returns the partial trajectory.
  X = nan([size(X0),length(tspan)]); X(:,:,:,1) = X0;
  yn = X0; blew_up = false; bstep = length(tspan);
  for idt=1:length(tspan)-1
    Nt = ( tspan(idt+1)-tspan(idt) )/dt;
    for idn=1:Nt
      ace.t = tspan(idt) + (idn-1)*dt;      % model time at step start (ubar ramp)
      [yn, ace] = MARCH1(yn, ace);
    end%idn
    X(:,:,:,idt+1) = yn;
    if any(~isfinite(yn),'all')
      blew_up = true; bstep = idt+1;
      fprintf('  [guard] non-finite at output %d (t=%g s); stopping.\n', idt+1, tspan(idt+1));
      pf = fopen(progress_file,'a'); fprintf(pf,'[%s] %s BLEW_UP at output %d (t=%g s)\n', datestr(now,'HH:MM:SS'), tag, idt+1, tspan(idt+1)); fclose(pf);
      return;
    end
    if mod(idt, ckpt_every)==0
      Xckpt = X(:,:,:,1:idt+1); tspan_ckpt = tspan(1:idt+1); %#ok<NASGU>
      save(ckpt_file,'Xckpt','tspan_ckpt','-v7.3');
      pf = fopen(progress_file,'a');
      if ~isempty(ace.rec.lamb) && isstruct(ace.rec.lamb) && ace.rec.lamb.n > 0
        fprintf(pf,'[%s] %s output %d/%d t=%g s max|MF|=%.4g W_L=%.3e KE=%.3e\n', datestr(now,'HH:MM:SS'), tag, idt+1, length(tspan), tspan(idt+1), max(abs(yn(:,3,:)),[],'all'), ace.rec.lamb.WL_last, ace.rec.lamb.KE_last);
      else
        fprintf(pf,'[%s] %s output %d/%d t=%g s max|MF|=%.4g\n', datestr(now,'HH:MM:SS'), tag, idt+1, length(tspan), tspan(idt+1), max(abs(yn(:,3,:)),[],'all'));
      end
      fclose(pf);
    end
  end%idt
end

function [dXdt, ace] = expFun(X,dTH,dQt,rho0B,ace)
  [dXdt, ~, ace] = expFun_split(X,dTH,dQt,rho0B,ace);
end

function [dXdt, dMF_K2c, ace] = expFun_split(X,dTH,dQt,rho0B,ace)
  % X(z,var,ACE-i) 7 slots. Returns the full tendency and -K2[dzFx].
  % V024 TERRAIN: ghost copy-from-above as the WENO reconstruction input for solid
  % tracer cells; exchange/FH face masks across wall/solid faces; solid tracer
  % tendency zero; total dMF -> level-mean removal -> top-face C1
  % correction (K1 rock sources, workless) -> rock-interior interfaces zero.
  if ace.terrain_on
    Xadv = X; Xadv(ace.ghost_dst_lin) = X(ace.ghost_src_lin);
  else
    Xadv = X;
  end
  Ci = reconstruction_weno_vec(ace.k,Xadv(:,1:2,:),X(:,3,:));
  wi = X(:,3,:)./ace.rho_zi;
  mfc = squeeze(reconstruction_up3(X(:,3,:)));          % up3-by-own-sign OK for MF (one-signed)
  wc = mfc./ace.rho_zc;
  Admfdz = ace.Ai'.* squeeze(( X(2:end,3,:)-X(1:end-1,3,:) )/ace.dz);

  if ~isempty(ace.run.closure_print_left) && ace.run.closure_print_left>0
    fprintf('  [closure] max_z |sum_i Ai*dMFdz| = %.3e\n', max(abs(sum(Admfdz,2))));
    ace.run.closure_print_left = ace.run.closure_print_left - 1;
  end
  cref_in = []; if isfield(ace,'cref_io'), cref_in = ace.cref_io; end
  ace = PSI_CREF(ace, X);                     % psi mode: gauge reference from slot 7
  ioflow = GAUGE_IO(cumsum(Admfdz,2), ace);   % level gauge (flat: zero-mean; terrain: fluid-face mean; psi: face-1 reference)

  if ace.ubar_on
    ubc = UBAR_NOW(ace);
    ioflow_adv = ioflow - ace.rho_zc(1:end-1).*ubc(1:end-1)*(ace.Ai(1)/ace.dx);
  else
    ioflow_adv = ioflow;
  end

  rho0wC = X(:,3,:).*Ci; rho0wC(1,:,:) = 0;

  % periodic tracer tendency (exchange transport = ioflow_adv); TERRAIN face masks
  Xr = X(1:end-1,1:2,:); Xrp = circshift(Xr,-1,3); Xrm = circshift(Xr,1,3);
  iofl = permute(ioflow_adv,[1,3,2]); ioflm = circshift(iofl,1,3);
  epsO = permute(ace.eps_out,[1,3,2]); epsI = permute(ace.eps_in,[1,3,2]);
  Aip = permute(ace.Ai,[3,2,1]);
  Mf  = permute(ace.Mface,[1,3,2]);                     % (Nzc x 1 x Ni) face f=i mask (binary: fully blocked = 0)
  Mfm = circshift(Mf,1,3);                              % face f=i-1
  Af  = permute(ace.Aface,[1,3,2]); Afm = circshift(Af,1,3);   % open-area fractions (exchange terms); == Mf for block
  Vk  = permute(ace.vk,[1,3,2]);                        % fluid volume fraction of the partial cell (1 elsewhere)
  iofl = iofl.*Mf; ioflm = ioflm.*Mfm;
  dCdt = zeros(ace.Nzm,2,ace.Ni);
  dCdt(1:end-1,:,:) = ...
        -epsO.*Af.*( Xr - Xrp ) -epsI.*Afm.*( Xr - Xrm )...
        +( ( iofl.*( (iofl>0).*Xrp + (iofl<0).*Xr )...
            -ioflm.*( (ioflm>0).*Xr + (ioflm<0).*Xrm ) )./Aip...
          -( rho0wC(2:end,:,:)-rho0wC(1:end-1,:,:) )/ace.dz )./(ace.rho_zc(1:end-1).*Vk);
  if ace.terrain_on
    dCdt(ace.solid_c2_lin) = 0;
  end

  % periodic FH assembly (exchange transport = ioflow_adv); TERRAIN face masks
  mfcL = mfc(1:end-1,:); mfcLp = circshift(mfcL,-1,2); mfcLm = circshift(mfcL,1,2);
  wcL = wc(1:end-1,:); wcLp = circshift(wcL,-1,2); wcLm = circshift(wcL,1,2);
  MfF = ace.Mface; MfmF = circshift(MfF,1,2);
  AfF = ace.Aface; AfmF = circshift(AfF,1,2);           % area-weighted column exchange
  iof = ioflow_adv.*MfF; iofL = circshift(ioflow_adv,1,2).*MfmF;
  FH_eps = -ace.eps_out.*AfF.*( mfcL - mfcLp ) -ace.eps_in.*AfmF.*( mfcL - mfcLm );   % parameterized column exchange (kept in both forms)
  FH_io  = ( iof.*( (iof>0).*wcLp + (iof<0).*wcL )...
            -iofL.*( (iofL>0).*wcL + (iofL<0).*wcLm ) )./ace.Ai';                       % -dx(rho0 u w) (flux form only)

  rho0u_used = -ioflow;                                      % (rho0 u) on zc faces from continuity + the level gauge
  dcref = [];                                                % level-mean momentum tendency (gauge slot 7), empty = none
  if isfield(ace,'lamb') && ace.lamb
    % Lamb/vorticity form -- F_z = +rho0 u omega, F_x = -rho0 w omega, plus the
    % anelastic remainder rho0' dx(K) of the dropped gradient term as a direct vorticity source.
    [FzL, K2resp_L, ace] = LAMB_CHANNEL(rho0u_used, wi, ace);
    if isfield(ace,'visc_nu') && (ace.visc_nu > 0 || ace.mean_u > 0 || (isfield(ace,'sgs_ml') && ace.sgs_ml))
      [Fzv, K2v, dcref, ace] = VISC_MEANU(rho0u_used, wi, rho0B, ace); FzL = FzL + Fzv; K2resp_L = K2resp_L + K2v;   % viscous / MEANU
    end
    F = FH_eps + FzL;
    if ace.turn_on_K2, dMF_K2c = -K2resp_L; else, dMF_K2c = zeros(ace.Nzm, ace.Ni); end
  else
    F = FH_eps + FH_io - squeeze( X(2:end,3,:).*wi(2:end,1,:)-X(1:end-1,3,:).*wi(1:end-1,1,:) )/ace.dz;
    if ace.turn_on_K2
      [K2c_, ace] = K2_CHANNEL(rho0u_used, wi, ace); dMF_K2c = -K2c_;
    else
      dMF_K2c = zeros(ace.Nzm, ace.Ni);
    end
  end
  dMF_K1 = NONLOCAL_RESPONSE_CONV(rho0B, [F;zeros(1,ace.Ni)], ace);
  if ~isempty(ace.diag.expf) && isstruct(ace.diag.expf) && ace.diag.expf.on
    ace.diag.expf.F = F; ace.diag.expf.FH_eps = FH_eps; ace.diag.expf.dMF_K1 = dMF_K1; ace.diag.expf.dMF_K2c = dMF_K2c; ace.diag.expf.rho0u_used = rho0u_used;
  end
  dMF = dMF_K1 + dMF_K2c; dMF(end-ace.ndead+1:end,:) = 0;
  if ~isempty(ace.diag.exp_trace) && ace.diag.exp_trace > 0
    fprintf('  [expFun] max|dMF_K1|=%.3e max|dMF_K2c|=%.3e max|rho0u_used|=%.3e max|MF|=%.3e\n', max(abs(dMF_K1(:))), max(abs(dMF_K2c(:))), max(abs(rho0u_used(:))), max(abs(X(:,3,:)),[],'all'));
    ace.diag.exp_trace = ace.diag.exp_trace - 1;
  end

  % TERRAIN: rock-interior interfaces carry no tendency (MF stays exactly 0 there) --
  % masked FIRST so the level-mean removal below sees the final rock zeros.
  % expFun-end level-mean removal: every stage tendency is
  % level-mean-free by construction (terrain-aware: redistributed over FREE interfaces).
  if ace.Wbar_eq_zero == 1
    dMF = WBAR_REMOVE(dMF, ace);
  end
  % TERRAIN tendency-level closure: A_z = 0 on EVERY rock interface (interior + top face)
  % via the K1 rock-cell source sub-system (raw kernel columns -> kernel-consistent, zero
  % level sums; workless: sources sit where w == 0).
  if ace.terrain_on && ace.cap.Nb > 0
    r1 = dMF(ace.cap.c1_lin);
    q1 = -( ace.cap.U11 \ ( ace.cap.L11 \ r1(ace.cap.p11) ) ) ./ ace.cap.cs1(:);
    dMF = dMF + CAP_STAMP([q1(:); zeros(ace.cap.Nc3,1)], ace, 'c1');
    % the raw K1 columns are non-zero in the top-11 dead zone; re-apply the dead zone HERE so
    % the A_z used for eta-dot / U_p-dot below is exactly the slot-3 tendency (two-rep identity).
    dMF(end-ace.ndead+1:end,:) = 0;
  end

  % eta tendency on the CORRECTED dMF: A_z = dMF; A_x = -cumsum(Ai*dz(A_z)) with the level
  % gauge; eta-dot = dz(A_x) - dx(A_z). Under the cap/psi closure eta is a DIAGNOSTIC
  % (re-slaved to MF each step), so its tendency is zeroed and slot 7 carries the gauge.
  A_z = dMF;
  Az_dz = ace.Ai' .* ( ( A_z(2:end,:) - A_z(1:end-1,:) ) / ace.dz );
  A_x = -GAUGE_IO(cumsum(Az_dz, 2), ace);
  deta = zeros(ace.Nzm, ace.Ni);
  dAx_dz = ( A_x(2:end,:) - A_x(1:end-1,:) ) / ace.dz;
  dAz_dx = ( circshift(A_z,-1,2) - A_z ) / ace.dx;
  deta(2:ace.Nzm-1,:) = dAx_dz - dAz_dx(2:ace.Nzm-1,:);

  if isfield(ace,'topo_solver') && any(strcmp(ace.topo_solver,{'psi','cap'})) && ace.terrain_on
    deta = 0*deta;                             % cap/psi mode: eta is a diagnostic; slot 7 carries the gauge (constant within a step)
  end
  dXdt = [ dCdt+permute(cat(3,dTH,dQt),[1,3,2]), permute(dMF,[1,3,2]), ...
           -permute(cat(3,dTH,dQt),[1,3,2]), permute(deta,[1,3,2]), zeros(ace.Nzm,1,ace.Ni) ];
  if ~isempty(dcref) && isfield(ace,'topo_solver') && strcmp(ace.topo_solver,'cap') && ace.terrain_on
    dXdt(1:ace.Nzm-1,7,1) = reshape(dcref, [], 1, 1);        % MEANU: level-mean momentum equation via the gauge reference (anchor face Ni)
  end
  dXdt(end-ace.ndead+1:end,1:3,:) = 0;
  if ~isempty(cref_in), ace.cref_io = cref_in; end
end

function [K2resp, ace] = K2_CHANNEL(rho0u_in, wi, ace)
  % Assemble F_x on entity FACES from the (reconstructed) rho0u, dz(F_x) by WENO5-
  % upwind (local w sign), map cells->mixed layers (Lmap), stacked K2 apply.
  % V024 TERRAIN: (1) rho0u zero at TRUE rock interior
  % rows k <= min(kbot(f),kbot(f+1)) (pair-symmetric); (2) Phi_uu zero at wall/solid
  % faces (fx_mask, k <= kbot_face); (3) Phi_uw zero in-solid + terrain-top faces;
  % up3w terrain guard row; (5) F_x ghost copy-from-above below each face-column's
  % terrain top (reconstruction input only); (7) dz(F_x) solid rows zero.
  % UPWIND Phi_uu: u at cell centres by the up3 two-stencil pair
  % biased by sign(u) along x (self-sign is parity-consistent horizontally: the sign
  % flip and the x-orientation flip compose), replacing the centred face-pair mean.
  Ni = ace.Ni; Nzm = ace.Nzm; dx = ace.Ai(1)*1e3; dz = ace.dz;
  rho_zc = ace.rho_zc(1:end-1); wiF = squeeze(wi);

  s_km_m = ace.Ai(1) / dx;                         % = 1e-3 (Ai[km]/dx[m])
  rho0u_f = rho0u_in / s_km_m;                     % SI rho0*u'
  if ace.ubar_on
    ubc = UBAR_NOW(ace);
    rho0u_tot = rho0u_f + rho_zc .* ubc(1:end-1);
  else
    rho0u_tot = rho0u_f;
  end
  % TERRAIN: the TOTAL rho0u is zero inside true rock (acts on u' + ubar; with ubar=0
  % identical to zeroing u' -- 0/s == 0 exactly).
  if ace.terrain_on && ~isempty(ace.k2_rock_lin)
    rho0u_tot(ace.k2_rock_lin) = 0;
  end

  % F_x^uu (SI): upwind-biased cell-centre u (up3 by sign of the local mean u).
  u_face = rho0u_tot ./ rho_zc;                    % face f = i (between cells i and i+1)
  % Wall ghost (option): masked wall/rock faces in the stencil carry the fluid-side value, so
  % the body's slip layer is not read as a momentum-flux convergence spread over the adjacent
  % 5-km cell (which shed the bound vortex sheet off lee corners as a growing jet).
  if ace.terrain_on && isfield(ace,'wall_ghost_u') && ace.wall_ghost_u && ~isempty(ace.ghu_dst_lin)
    u_face(ace.ghu_dst_lin) = 0.5*( u_face(ace.ghu_src1_lin) + u_face(ace.ghu_src2_lin) );
  end
  uL  = circshift(u_face, 1,2);                    % face i-1 (left face of cell i)
  uR  = u_face;                                    % face i   (right face of cell i)
  uLL = circshift(u_face, 2,2);                    % face i-2
  uRR = circshift(u_face,-1,2);                    % face i+1
  sgn = uL + uR; sp = sgn>0; sm = sgn<0; s0 = ~(sp|sm);
  u_ctr = ( (5*uL + 2*uR - uLL)/6 ).*sp + ( (2*uL + 5*uR - uRR)/6 ).*sm + 0.5*(uL+uR).*s0;
  Phi_uu = rho_zc .* u_ctr.^2;
  Fx_uu = -( circshift(Phi_uu,-1,2) - Phi_uu ) / dx;
  if ace.terrain_on, Fx_uu(ace.fx_mask) = 0; end

  % F_x^uw (SI): rho0u zc->zm by UP3W (carrying-w upwind; terrain guard), Phi_uw = rho0u^zm*w_f.
  w_f = 0.5*( wiF + circshift(wiF,-1,2) );            % (Nzm, Ni) face w at zm interfaces
  ru3 = up3w_g( rho0u_tot, w_f(2:Nzm,:), ace );       % (Nzm-1,Ni) to zm(2..Nzm)
  rho0u_zm = zeros(Nzm, Ni); rho0u_zm(2:Nzm,:) = ru3; rho0u_zm(1,:) = 0;
  Phi_uw = rho0u_zm .* w_f; Phi_uw(1,:) = 0;
  if ace.terrain_on, Phi_uw(ace.phiw_mask) = 0; end
  Fx_uw = -( Phi_uw(2:Nzm,:) - Phi_uw(1:Nzm-1,:) ) / dz;

  Fx = Fx_uu + Fx_uw; Fx(end-ace.ndead+1:end,:) = 0;   % top dead zone (~1 km)
  if ace.terrain_on && ~isempty(ace.fxg_dst_lin)
    Fx(ace.fxg_dst_lin) = Fx(ace.fxg_src_lin);      % ghost copy-from-above (free-slip, recon input only)
  end

  % dz(F_x): WENO5 (k=3) upwind by local face-w sign; w=0 -> average both biases.
  Fx3 = reshape(Fx, [Nzm-1, 1, Ni]);
  cP = ones(Nzm-1,1,Ni); cM = -ones(Nzm-1,1,Ni);
  fL = reshape( reconstruction_weno_vec(3, Fx3, cP), [Nzm-1, Ni] );
  fU = reshape( reconstruction_weno_vec(3, Fx3, cM), [Nzm-1, Ni] );
  wface_c = w_f(1:Nzm-1,:); wp = wface_c>0; wm = wface_c<0; wz = ~(wp|wm);
  Fx_face = fL.*wp + fU.*wm + 0.5*(fL+fU).*wz;
  Fx_faceF = [Fx_face; zeros(1,Ni)];
  dzFx = ( Fx_faceF(2:Nzm,:) - Fx_faceF(1:Nzm-1,:) ) / dz;
  if ace.terrain_on, dzFx(ace.fx_mask) = 0; end     % no vorticity source inside rock

  K2resp = K2TAIL(dzFx .* ace.ak, ace);             % partial rows weighted by the open fraction
  % mirror-parity diagnostic hook (gates only)
  if ~isempty(ace.diag.k2) && isstruct(ace.diag.k2) && ace.diag.k2.on
    ace.diag.k2.rho0u_in = rho0u_in; ace.diag.k2.rho0u_tot = rho0u_tot; ace.diag.k2.u_ctr = u_ctr; ace.diag.k2.Phi_uu = Phi_uu; ace.diag.k2.Fx_uu = Fx_uu;
    ace.diag.k2.rho0u_zm = rho0u_zm; ace.diag.k2.Phi_uw = Phi_uw; ace.diag.k2.Fx_uw = Fx_uw; ace.diag.k2.Fx = Fx; ace.diag.k2.Fx_face = Fx_face; ace.diag.k2.dzFx = dzFx; ace.diag.k2.K2resp = K2resp;
  end
end

function [FzL, K2resp, ace] = LAMB_CHANNEL(rho0u_in, wi, ace)
  % Vorticity-flux (Lamb) form of the momentum-flux terms.
  %   div(rho0 u u) = rho0 grad K - rho0 u x omega,  K = |u|^2/2,  omega = dz(u) - dx(w)  (2-D)
  %   => F_x = -rho0 w omega,  F_z = +rho0 u omega ;  the gradient part is DROPPED analytically
  %   (its Boussinesq curl is identically zero -- no discrete cancellation is relied upon); its
  %   anelastic remainder rho0'(z) dx(K) is a genuine vorticity source and is fed to the K2
  %   channel directly (dMF += K2[S]  <=>  dzFx_eff = dzFx - S, since dMF_K2c = -K2[dzFx_eff]).
  % omega is the KINEMATIC vorticity from u_tot and w = MF/rho0 (VVM convention;
  % the mass-weighted slot-6 eta would carry a spurious rho0' u w term). BOUNDARY vorticity: the
  % rows k <= kbf(f)+1 on each face (wall rows + the slip layer on the terrain top) hold the
  % rock-to-fluid velocity jump = bound vortex sheet of the body; it is NOT fluid vorticity and
  % is excluded from the vorticity-flux terms (phiw_mask), leaving the walls to the kinematic closure.
  Ni = ace.Ni; Nzm = ace.Nzm; dx = ace.Ai(1)*1e3; dz = ace.dz;
  rho_zc = ace.rho_zc(1:end-1); rho_zm = ace.rho_zi(:); wiF = squeeze(wi);
  s_km_m = ace.Ai(1) / dx;
  rho0u_f = rho0u_in / s_km_m;
  if ace.ubar_on
    ubc = UBAR_NOW(ace); rho0u_tot = rho0u_f + rho_zc .* ubc(1:end-1);
  else
    rho0u_tot = rho0u_f;
  end
  if ace.terrain_on && ~isempty(ace.k2_rock_lin), rho0u_tot(ace.k2_rock_lin) = 0; end
  u_face = rho0u_tot ./ rho_zc ./ ace.ak;                   % (Nzc x Ni) faces, SI (true velocity on partial faces = areal flux / open fraction)
  w_f = 0.5*( wiF + circshift(wiF,-1,2) );                  % (Nzm x Ni) w on faces
  % kinematic vorticity on (zm rows, faces)
  om = zeros(Nzm, Ni);
  dxw = ( circshift(wiF,-1,2) - wiF ) / dx;                 % dx(w) on faces at zm rows
  om(2:Nzm-1,:) = ( u_face(2:end,:) - u_face(1:end-1,:) )/dz - dxw(2:Nzm-1,:);
  if ace.terrain_on, om(ace.omx_mask) = 0; end              % bound sheet rows excluded (+ first node above a partial face)
  % ===== UPWIND vorticity-flux form (production) =====
  % dz(F_x) - dx(F_z) = -div(rho0 v omega) is discretised as a flux divergence on the vorticity nodes with the
  % transported omega reconstructed UPWIND (WENO(2k-1) by default, or the up3 two-stencil pair) by the sign of
  % the carrying mass flux, i.e. VVM's eta advection: vorticity-conserving (flux form) with implicit upwind
  % dissipation, no gradient term.
  % x-flux at (zm row k, column i) = rho0u(k,i) * omega_hat ; z-flux at (zc row k, face f) = rho0w(k,f) * omega_hat.
  q = om;                                                    % masked kinematic vorticity at nodes (zm, faces)
  % --- x-flux through column i (between nodes f=i-1 and f=i): rho0u at (zm, column) = 4-point average
  ru = rho0u_tot;                                            % (Nzc x Ni) at (zc, faces)
  ru_zm = zeros(Nzm, Ni); ru_zm(2:Nzm-1,:) = 0.5*( ru(1:Nzm-2,:) + ru(2:Nzm-1,:) );    % faces, zm rows
  ru_col = 0.5*( ru_zm + circshift(ru_zm,1,2) );             % column i: faces i-1 and i
  qm1 = circshift(q,1,2); qm2 = circshift(q,2,2); qp1 = q;   % nodes f=i-1 (qm1), i-2 (qm2), i (q), i+1
  qpp = circshift(q,-1,2);
  if isfield(ace,'lamb_upwind_weno') && ace.lamb_upwind_weno
    % WENO(2k-1) along x (periodic), carrier sign = rho0u at the column picks the upwind side
    qhx = WENO_X_PERIODIC(ace.k, q, ru_col);
  else
    sp = ru_col > 0; sm = ru_col < 0; s0 = ~(sp|sm);
    qhx = ( (5*qm1 + 2*q - qm2)/6 ).*sp + ( (2*qm1 + 5*q - qpp)/6 ).*sm + 0.5*(qm1 + q).*s0;
  end
  Fxq = ru_col .* qhx;                                       % (Nzm x Ni) x-flux at column i
  Fxq(1,:) = 0; Fxq(Nzm,:) = 0;
  % --- z-flux through zc row k (between nodes k and k+1) on face f: rho0w at (zc, face) = average of w_f rows
  rw_f = 0.5*( w_f(1:Nzm-1,:) + w_f(2:Nzm,:) ) .* rho_zc;   % (Nzc x Ni) rho0 w at (zc, faces)
  qk = q(1:Nzm-1,:); qk1 = q(2:Nzm,:);
  qkm1 = [q(1,:); q(1:Nzm-2,:)]; qk2 = [q(3:Nzm,:); q(Nzm,:)];
  if isfield(ace,'lamb_upwind_weno') && ace.lamb_upwind_weno
    % WENO(2k-1) along z via the certified routine: nodes act as 'cells', output at the interface BELOW node idx
    % = zc row idx-1 (between nodes idx-1 and idx); carrier at that interface = rho0 w(zc row idx-1)
    c3 = zeros(Nzm, 1, Ni); c3(2:Nzm,1,:) = reshape(rw_f, [Nzm-1,1,Ni]);
    vw = reshape(reconstruction_weno_vec(ace.k, reshape(q,[Nzm,1,Ni]), c3), [Nzm, Ni]);   % routine returns (1,z,var,ACE) -> (Nzm x Ni)
    qhz = vw(2:Nzm,:);
  else
    wp = rw_f > 0; wm = rw_f < 0; wz = ~(wp|wm);
    qhz = ( (5*qk + 2*qk1 - qkm1)/6 ).*wp + ( (2*qk + 5*qk1 - qk2)/6 ).*wm + 0.5*(qk + qk1).*wz;
  end
  Fzq = rw_f .* qhz;                                         % (Nzc x Ni) z-flux at (zc, faces)
  Fzq(end-ace.ndead+1:end,:) = 0;
  if ace.terrain_on, Fzq(ace.fx_mask) = 0; Fzq(ace.omx_mask(1:Nzm-1,:)) = 0; end   % no vorticity flux through solid faces / into body rows
  % --- divergence at nodes: etadot(k,f) = -[Fxq(k,f+1) - Fxq(k,f)]/dx - [Fzq(k,f) - Fzq(k-1,f)]/dz
  etadot = zeros(Nzm, Ni);
  etadot(2:Nzm-1,:) = -( circshift(Fxq(2:Nzm-1,:),-1,2) - Fxq(2:Nzm-1,:) )/dx - ( Fzq(2:Nzm-1,:) - Fzq(1:Nzm-2,:) )/dz;
  etadot(1,:) = 0; etadot(Nzm,:) = 0; etadot(end-ace.ndead+1:end,:) = 0;
  if ace.terrain_on, etadot(ace.omx_mask) = 0; end
  eta_c = 0.5*( etadot(1:Nzm-1,:) + etadot(2:Nzm,:) );
  u_c = 0.5*( u_face + circshift(u_face,1,2) ); w_c = 0.5*( wiF(1:Nzm-1,:) + wiF(2:Nzm,:) );
  Kc = 0.5*( u_c.^2 + w_c.^2 ); if ace.terrain_on, Kc(ace.solid_zc) = 0; end
  drho = ( rho_zm(2:Nzm) - rho_zm(1:Nzm-1) ) / dz; S = drho .* ( circshift(Kc,-1,2) - Kc ) / dx;
  if ace.terrain_on, S(ace.fx_mask) = 0; end
  S(end-ace.ndead+1:end,:) = 0;
  dzFx_eff = eta_c - S; if ace.terrain_on, dzFx_eff(ace.fx_mask) = 0; end
  K2resp = K2TAIL(dzFx_eff .* ace.ak, ace);   % open-fraction weight
  FzL = zeros(Nzm-1, Ni);
  if ~isempty(ace.rec.lamb) && isstruct(ace.rec.lamb)
    MFn = wiF .* rho_zm(:); psi0 = [0; -cumsum(rho0u_tot(:,end))*dz]; PSI = psi0 + cumsum(MFn, 2)*dx;
    WL = -sum(sum(PSI .* etadot)) * dx * dz;                 % energy-type: psi . etadot (dissipative upwind -> non-zero, should be negative-definite on average)
    KE = 0.5 * sum(sum(rho_zc .* (u_c.^2 + w_c.^2))) * dx * dz;
    ace.rec.lamb.n = ace.rec.lamb.n + 1; ace.rec.lamb.WL_last = WL; ace.rec.lamb.WL_max = max(ace.rec.lamb.WL_max, abs(WL));
    ace.rec.lamb.WL_sum = ace.rec.lamb.WL_sum + WL; ace.rec.lamb.WL_abs_sum = ace.rec.lamb.WL_abs_sum + abs(WL); ace.rec.lamb.KE_last = KE;
    ace.rec.lamb.ens_last = sum(sum(q .* etadot)) * dx * dz;
    ace.rec.lamb.circ_last = sum(sum(etadot)) * dx * dz;        % total vorticity tendency: flux form -> ~0 (boundary fluxes only)
  end
  if ~isempty(ace.diag.lamb) && isstruct(ace.diag.lamb) && ace.diag.lamb.on
    ace.diag.lamb.om = om; ace.diag.lamb.FxL = zeros(Nzm-1, Ni); ace.diag.lamb.FzL = FzL; ace.diag.lamb.S = S; ace.diag.lamb.dzFx = eta_c; ace.diag.lamb.etadot = etadot; ace.diag.lamb.PSI = [0; -cumsum(rho0u_tot(:,end))*dz] + cumsum(wiF .* rho_zm(:), 2)*dx;
  end
end

function r = up3w_g(c, w, ace)
  % up3 two-stencil pair (3rd order), upwind by the CARRYING velocity w. c(z) at zc ->
  % output at zc+dz/2 (row k -> face zm(k+1)). w>0: (5c+2c_{+1}-c_{-1})/6 ; w<0:
  % (2c+5c_{+1}-c_{+2})/6 ; w=0: average. Linear in c -> parity-preserving.
  % Bottom-row guard (flat): row 1 -> non-wrapping centred value. TERRAIN guard: the
  % row targeting the first fluid flux face above each face-column's wall top (output
  % row kbot_face+1) must not pull rock rows into the stencil -> centred value too.
  c1p = circshift(c,-1,1); c1m = circshift(c,1,1); c2p = circshift(c,-2,1);
  Bp = ( 5*c + 2*c1p - c1m )/6;
  Bm = ( 2*c + 5*c1p - c2p )/6;
  wp = w>0; wm = w<0; wz = ~(wp|wm);
  r = Bp.*wp + Bm.*wm + 0.5*(Bp+Bm).*wz;
  r(1,:) = 0.5*( c(1,:) + c1p(1,:) );
  if ace.terrain_on && ~isempty(ace.guard_lin)
    cc = 0.5*( c + c1p );
    r(ace.guard_lin) = cc(ace.guard_lin);
  end
end

function dMFdt = NONLOCAL_RESPONSE_CONV(rho0B, F, ace)
  % stacked + parity-folded single-GEMM K1 apply on the MIXED tiling (cells -> layers by Lmap).
  Sval = ( rho0B(1:end-1,:) + F(1:end-1,:) ) .* ace.vk;   % partial cells carry their fluid-volume fraction (vk == 1 elsewhere)
  S = (ace.Lmap * Sval).';                          % (Ni x Nlay)
  dMFdt = K1_APPLY_LAYERS(S, ace);
end

function dMFdt = NONLOCAL_RESPONSE_CONV_ORIG(rho0B, F, ace)
  % layer-loop reference (wiring insurance only).
  Ni = ace.Ni; Nz = size(ace.PMBt,2); Nlay = size(ace.PMBt,3);
  Sval = rho0B(1:end-1,:) + F(1:end-1,:);
  S = (ace.Lmap * Sval).';
  dMFdt = zeros(Ni, Nz);
  for lay = 1:Nlay
    Sg = S(ace.gw1 + (lay-1)*Ni);
    dMFdt = dMFdt + Sg * squeeze(ace.PMBt(:,:,lay));
  end
  dMFdt = dMFdt';
end

function [dTH, dQt, rho0B, ace] = microrad(y, p_zc, rho_zc, Tv_zc, theta_e_diag, ace)
  if isfield(ace,'dry') && ace.dry
    % DRY: unsaturated inversion (no condensate, no precip sinks); buoyancy from Tv as usual
    [T, Q, ace] = INV_THETA_E_DRY(squeeze(y(:,1,:)), squeeze(y(:,2,:)), p_zc, ace);
    dTH = zeros(size(T)); dQt = zeros(size(T)); Tv = eval_Tv(T, Q, 0*Q); rho0B = rho_zc.*eval_B(Tv, Tv_zc); return;
  end
  [T, Q, QL, QI, ace] = INV_THETA_E(squeeze(y(:,1,:)), squeeze(y(:,2,:)), p_zc, theta_e_diag, ace);
  [dTH, dQt] = PRECIP_SINKS(T, Q, QL, QI, p_zc, ace.qc_ramp, ace.dqc, ace.tau_pr);
  Tv = eval_Tv(T, Q, QL+QI);
  rho0B = rho_zc.*eval_B(Tv, Tv_zc);
end

function [dtheta_e, dqt] = PRECIP_SINKS(T, q, ql, qi, p_zc, qc_ramp, dqc, tau_pr)
  qc = ql+qi;
  dqt = -(qc_ramp/dqc/tau_pr) * log( 1+exp( (dqc/qc_ramp) * (qc-qc_ramp) ) );
  dql = 1e-8*ql./qc; dqi = 1e-8*qi./qc;
  dtheta_e = dqt.* ( eval_theta_e(T,q,ql+dql,qi+dqi,p_zc) - eval_theta_e(T,q,ql,qi,p_zc) )/1e-8;
  dqt(qc<=0) = 0; dtheta_e(qc<=0) = 0;
end

function [T, q, ace] = INV_THETA_E_DRY(theta_e, qt, p_zc, ace)
  % DRY inversion: theta_e(T, qv = qt, 0, 0, p) = theta_e by a vectorised secant-Newton (warm start from the previous call
  % via ace.inv.Tp_dry; cold start T = theta_e (p/p0)^kappa). No saturation branch, no condensate carried.
  Tp = ace.inv.Tp_dry;
  if ~isempty(ace.inv.reset) && ace.inv.reset, Tp = []; ace.inv.reset = 0; end
  [Nzm, Np] = size(theta_e); pf = repmat(p_zc(:), 1, Np); q = qt; z0 = 0*q;
  if isempty(Tp) || ~isequal(size(Tp), size(theta_e)), T = theta_e .* (pf/1e5).^(287.04/1005.7); else, T = Tp; end
  for it_ = 1:8
    f0 = eval_theta_e(T, q, z0, z0, pf) - theta_e;
    if max(abs(f0(:))) < 1e-9, break; end
    f1 = eval_theta_e(T + 0.01, q, z0, z0, pf) - theta_e;
    T = T - 0.01 * f0 ./ (f1 - f0);
  end
  ace.inv.Tp_dry = T;
end

function [T, q, ql, qi, ace] = INV_THETA_E(theta_e, qt, p_zc, theta_e_diag, ace) %#ok<INUSD>
  % Batched Newton (unit test 3: EXACT vs the scalar loop, 4.65x) with
  % warm-jump step 0 (unit test 4b: 1.40x, agreement 3.8e-5 K, fallback ~0.2%).
  % Warm state = previous call's converged (T,ql,qi) in ace.inv.Tp/QLp/QIp (first
  % call cold). Nonconvergent cells are FLAGGED and NaN'ed -- the
  % march's nonfinite guard then stops the integration cleanly.
  Tp = ace.inv.Tp; QLp = ace.inv.QLp; QIp = ace.inv.QIp;
  if ~isempty(ace.inv.reset) && ace.inv.reset, Tp = []; QLp = []; QIp = []; ace.inv.reset = 0; end   % gate twins: cold restart
  [Nzm,Np] = size(theta_e);
  pf = repmat(p_zc(:), 1, Np);
  if isempty(Tp) || numel(Tp) ~= Nzm*Np
    [T,q,ql,qi,ws] = inv_T_batch_warm(theta_e(:), qt(:), pf(:), [], [], []);
  else
    [T,q,ql,qi,ws] = inv_T_batch_warm(theta_e(:), qt(:), pf(:), Tp, QLp, QIp);
  end
  if ws.nonconv.any
    fprintf('INV_THETA_E: %d cells FLAGGED nonconvergent -> NaN out\n', ws.nonconv.count);
  end
  ace.inv.Tp = T; ace.inv.QLp = ql; ace.inv.QIp = qi;
  T = reshape(T,Nzm,Np); q = reshape(q,Nzm,Np); ql = reshape(ql,Nzm,Np); qi = reshape(qi,Nzm,Np);
end

function X = ImDamp(X,theta_e_zc,qt_zc,Nzm,damp)
  % Relaxes slots 1-3 only. Slots 6-7 (the eta diagnostic and the gauge reference) are NOT
  % damped here (a z-varying damp does not commute with dz and would break the eta
  % definition); the sponge reaches eta implicitly via the post-ImDamp ETA_RESYNC.
  X(:,1:3,:) = ( X(:,1:3,:) + damp.*[theta_e_zc,qt_zc,zeros(Nzm,1)] )./(1+damp);
end

function [theta_e, qt, mf, theta, RH, B,...
          qsat, qv, qc, ql, qi, Tv, T, dtheta_e_pr_accum, pr_accum, eta] = POST_PROCESS(X,ace)
  % X is (Nzm, 7, Ni, Nt). Slots 1-5 sliced explicitly; eta = slot 6 (Nzm x Nt x Ni-face).
  [Nzm,Nvar,Ni,Nt] = size(X);
  eta = permute(squeeze(X(:,6,:,:)),[1,3,2]);
  X = reshape(X(:,1:5,:,:),[5*Nzm,Ni,Nt]); X = permute(X,[1,3,2]);
  theta_e = X(1:Nzm,:,:); qt = X(Nzm+1:2*Nzm,:,:); mf = X(2*Nzm+1:3*Nzm,:,:);
  dtheta_e_pr_accum = X(3*Nzm+1:4*Nzm,:,:); pr_accum = X(4*Nzm+1:5*Nzm,:,:);
  theta = zeros(Nzm,Nt,Ni); qsat = zeros(Nzm,Nt,Ni); q = zeros(Nzm,Nt,Ni);
  ql = zeros(Nzm,Nt,Ni); qi = zeros(Nzm,Nt,Ni); T = zeros(Nzm,Nt,Ni);
  for ida=1:Ni
    for idt=1:Nt
      for idz=1:Nzm
        [T(idz,idt,ida), q(idz,idt,ida), ql(idz,idt,ida), qi(idz,idt,ida)]...
            = inv_T_from_theta_e(theta_e(idz,idt,ida), qt(idz,idt,ida), ace.p_zc(idz));
      end
      theta(:,idt,ida) = eval_theta(T(:,idt,ida),ace.p_zc);
      qsat(:,idt,ida) = eval_qsat(T(:,idt,ida),ace.p_zc,qt(:,idt,ida));
    end
  end
  Tv = eval_Tv(T,q,ql+qi); RH = q./qsat; B = eval_B(Tv,ace.Tv_zc);
  qc = (qt-qsat).*(qt>qsat); qv = qt-qc;
end

function [yn, ace] = MARCH1(yn, ace)
  if ~isempty(ace.inv.reset) && ace.inv.reset, ace.meanu.dmfdt_prev = []; end   % MEANU: a cold (re)start also forgets the lagged MF tendency (gate twins!)
  [dTH,dQt,rho0B,ace] = microrad(yn(:,1:2,:),ace.p_zc,ace.rho_zc,ace.Tv_zc,ace.theta_e_diag,ace);
  MF0_ = squeeze(yn(:,3,:));
  [yn, ace] = ssprk93_topo(@expFun,yn,dTH,dQt,rho0B,ace.dt,ace.Wbar_eq_zero,ace.Ai,ace);
  ace.meanu.dmfdt_prev = ( squeeze(yn(:,3,:)) - MF0_ ) / ace.dt;                % MEANU: dt(rho0 w) of the completed step (lagged one step)
  % two-representation record (eta slot vs ETA_OF(MF)) BEFORE ImDamp: the sponge damps
  % MF but not eta by design, and ETA_RESYNC re-slaves eta afterwards.
  if ace.terrain_on && ~isempty(ace.rec.topo)
    et = ETA_OF(squeeze(yn(:,3,:)), ace);
    ace.rec.topo.tworep = max(ace.rec.topo.tworep, max(abs(squeeze(yn(:,6,:)) - et),[],'all'));
  end
  yn = ImDamp(yn,ace.theta_e_zc,ace.qt_zc,ace.Nzm,ace.damp);
  tstep_ = ace.t; ace.t = ace.t + ace.dt;   % end-of-step time for the post-ImDamp closure
  [yn, ace] = TOPO_STAGE(yn, ace);          % post-ImDamp state closure (rock + walls)
  yn = ETA_RESYNC(yn, ace);
  ace.t = tstep_;
end

function [Fzv, K2v, dcref, ace] = VISC_MEANU(rho0u_in, wi, rho0B, ace)
  % explicit VERTICAL viscosity on u_tot (faces) and w (columns) as momentum forcings on the ACE routes
  % (F_z^v -> K1 input, dz(F_x^v) -> K2 input) with the IB wall stress tau_w = rho0 nu u(first fluid cell)/(dz/2)
  % (visc_wall = 1; 0 = stress-free), and the LEVEL-MEAN momentum tendency of the k = 0 mode through the gauge slot 7:
  % d(cref_io)/dt = -s [ <F_x^v> - dz<rho0 u_tot w> - drag ]  (cref_io = -s rho0 u' at the anchor face; shifting it
  % shifts u' uniformly on the level). With mean_u = 0 the cap gauge changes the level mean ONLY through the closure.
  % Partial faces: half-cell wall distance dz/2 regardless of the opening (recorded).
  Ni = ace.Ni; Nzm = ace.Nzm; Nzc = Nzm-1; dx = ace.Ai(1)*1e3; dz = ace.dz; nu = ace.visc_nu; s = ace.Ai(1)/ace.dx;
  rho_zc = ace.rho_zc(1:Nzc); rho_zm = ace.rho_zi(:); wiF = squeeze(wi);
  rho0u_f = rho0u_in / (ace.Ai(1)/dx);
  if ace.ubar_on, ubc = UBAR_NOW(ace); rho0u_tot = rho0u_f + rho_zc .* ubc(1:Nzc); else, rho0u_tot = rho0u_f; end
  if ace.terrain_on && ~isempty(ace.k2_rock_lin), rho0u_tot(ace.k2_rock_lin) = 0; end
  u_face = rho0u_tot ./ rho_zc;                                          % (Nzc x Ni) SI, faces
  kbf = ace.kbot_face(:).'; kb = ace.kbot(:).'; nd = ace.ndead;
  Fzv = zeros(Nzc, Ni); K2v = zeros(Nzm, Ni); Fxv = zeros(Nzc, Ni);
  ml = isfield(ace,'sgs_ml') && ace.sgs_ml;
  if nu > 0 || ml
    % interface viscosity nu_if (zm rows x faces) and wall stress tauw (faces) at the surface row k1 = kbf+1:
    %   constant nu: nu_if = nu, tauw = rho0 nu u1/(dz/2) (visc_wall)  |  mixing length (sgs_ml):
    %   u* = kappa |u1| / ln((dz/2+z0)/z0) from the first fluid cell, nu_if = kappa u* min(z_loc, z_n), tauw = rho0 u*^2 sgn(u1)
    kap = 0.4; nu_if = zeros(Nzm, Ni); tau = zeros(Nzm, Ni); tauw = zeros(1, Ni);
    if ml
      lnz = log((dz/2 + ace.ll_z0)/ace.ll_z0);
      for f = 1:Ni
        k1 = kbf(f) + 1; u1 = u_face(k1, f); us = kap*abs(u1)/lnz;
        jj = (k1+1:Nzm-1).'; nu_if(jj, f) = kap*us*min((jj - k1)*dz, ace.ll_zn);
        tauw(f) = rho_zm(k1) * kap^2 * u1*abs(u1) / lnz^2;
      end
    else
      nu_if(2:Nzm-1, :) = nu;
      for f = 1:Ni, k1 = kbf(f) + 1; if ace.visc_wall, tauw(f) = rho_zm(k1) * nu * u_face(k1, f) / (dz/2); end, end
    end
    % tau_xz at zm rows on faces: fluid interfaces j >= kbf+2 ; wall stress at the surface row j = kbf+1 ; 0 inside
    tau(2:Nzm-1,:) = rho_zm(2:Nzm-1) .* nu_if(2:Nzm-1,:) .* ( u_face(2:Nzc,:) - u_face(1:Nzc-1,:) ) / dz;
    for f = 1:Ni, if kbf(f) >= 1, tau(1:kbf(f), f) = 0; tau(kbf(f)+1, f) = tauw(f); end, end
    tau(Nzm,:) = 0; tau(end-nd+1:end,:) = 0;
    Fxv = ( tau(2:Nzm,:) - tau(1:Nzm-1,:) ) / dz;                            % F_x^v at (zc, faces)
    if ace.terrain_on, Fxv(ace.fx_mask) = 0; end
    Fxv(end-nd+1:end,:) = 0;
    % K2 route: F_x^v to zm rows (centred; ghost copy-from-above at the surface row, as the flux-form path), dz at cells
    Fxg = Fxv; if ace.terrain_on && ~isempty(ace.fxg_dst_lin), Fxg(ace.fxg_dst_lin) = Fxg(ace.fxg_src_lin); end
    Fx_zm = zeros(Nzm, Ni); Fx_zm(2:Nzm-1,:) = 0.5*( Fxg(1:Nzc-1,:) + Fxg(2:Nzc,:) );
    dzFxv = ( Fx_zm(2:Nzm,:) - Fx_zm(1:Nzm-1,:) ) / dz;
    if ace.terrain_on, dzFxv(ace.fx_mask) = 0; end
    dzFxv(end-nd+1:end,:) = 0;
    K2v = K2TAIL(dzFxv .* ace.ak, ace);
    % F_z^v = dz(rho0 nu_t dz w) at zm rows in FLUX form: tau_z at cells = rho0(cell) nu_c (w(j+1)-w(j))/dz, nu_c = mean of the
    % interface values on the column's right face (w = 0 on the surface row is the natural boundary), then averaged to cells
    nu_c = 0.5*( nu_if(1:Nzc,:) + nu_if(2:Nzm,:) );
    tz = rho_zc .* nu_c .* ( wiF(2:Nzm,:) - wiF(1:Nzc,:) ) / dz;              % (Nzc x Ni)
    Fz_zm = zeros(Nzm, Ni); Fz_zm(2:Nzm-1,:) = ( tz(2:Nzc,:) - tz(1:Nzc-1,:) ) / dz;
    for i = 1:Ni, Fz_zm(1:kb(i)+1, i) = 0; end
    Fzv = 0.5*( Fz_zm(1:Nzc,:) + Fz_zm(2:Nzm,:) );
    if ace.terrain_on, Fzv(ace.solid_zc) = 0; end
    Fzv(end-nd+1:end,:) = 0;
  end
  dcref = zeros(Nzc, 1); dsp = zeros(Nzc, 1);
  if ace.mean_u > 0
    dmean = mean(Fxv, 2);                                                    % <F_x^v> per level (rock faces contribute 0)
    if isfield(ace,'ll_nudge') && ace.ll_nudge
      % optional: relax the level-mean wind to ubar R above z_n (Couette-type upper boundary of the log layer)
      ubc_ = UBAR_NOW(ace); zc_ = ace.zm(1:Nzc) + dz/2; um_ = mean(u_face, 2); rel = zc_(:) > ace.ll_zn;
      dmean(rel) = dmean(rel) - rho_zc(rel) .* ( um_(rel) - ubc_(rel) ) / ace.ll_taun;
    end
    % Reynolds-stress divergence of the level mean: -dz<rho0 u_tot w>, u_tot at (zm rows, columns) from the four (zc, face) values
    u_zm = zeros(Nzm, Ni); u_zm(2:Nzm-1,:) = 0.5*( u_face(1:Nzc-1,:) + u_face(2:Nzc,:) );
    u_col = 0.5*( u_zm + circshift(u_zm, 1, 2) );                          % column i: faces i-1 and i
    uw = rho_zm .* wiF .* u_col; uw([1 Nzm],:) = 0;
    muw = mean(uw, 2);
    % MEANU = 1: level-mean momentum equation with the PHYSICAL pressure drag. The Reynolds
    % divergence is taken over ALL columns (rock interfaces carry w = 0), and the mountain's pressure force on the fluid is
    % added per level from p' diagnosed by the VERTICAL momentum equation integrated down from the top
    % (dz p' = rho0 B - dt(rho0 w) - dx(rho0 u w) - dz(rho0 w w): one column cumsum per stage, NO elliptic solve; dt(rho0 w)
    % = the previous completed step's MF tendency). Per column the surface pressure (first fluid cell) times the signed
    % height span of the surface segment inside each level (ace.wseg, continuous h) is the force on the mountain; minus that,
    % over L dz, is the force on the fluid per volume.
    rs_ = -( muw(2:Nzm) - muw(1:Nzc) ) / dz;
    dmean = dmean + rs_;
    if isfield(ace,'wseg') && nnz(ace.wseg) > 0
      dtrw = zeros(Nzm, Ni); if ~isempty(ace.meanu.dmfdt_prev) && isequal(size(ace.meanu.dmfdt_prev), size(wiF)), dtrw = ace.meanu.dmfdt_prev; end
      rw_face = 0.5*( wiF + circshift(wiF, -1, 2) );                          % rho0 w at (interface, face i)
      u_if = zeros(Nzm, Ni); u_if(2:Nzm-1,:) = 0.5*( u_face(1:Nzc-1,:) + u_face(2:Nzc,:) );
      flx_ = u_if .* rw_face; dx_ruw = ( flx_ - circshift(flx_, 1, 2) ) / dx;
      w_if = wiF ./ rho_zm; rww_c = rho_zc .* ( 0.5*( w_if(1:Nzc,:) + w_if(2:Nzm,:) ) ).^2;
      dz_rww = zeros(Nzm, Ni); dz_rww(2:Nzm-1,:) = ( rww_c(2:Nzc,:) - rww_c(1:Nzc-1,:) ) / dz;
      rb_if = zeros(Nzm, Ni); rb_if(2:Nzm-1,:) = 0.5*( rho0B(1:Nzc-1,:) + rho0B(2:Nzc,:) );
      dpdz = rb_if - dtrw - dx_ruw - dz_rww;                                 % (Nzm x Ni) at interfaces (rows 1, Nzm zero)
      S_ = flipud(cumsum(flipud(dpdz), 1)); pc_ = -dz * S_(2:Nzm, :);       % p'(cell k) = -dz * sum_{j >= k+1} dpdz(j) ; p'(top cell) = 0
      ps_ = pc_(ace.kfirst_lin);                                             % surface pressure per column (first fluid cell)
      Dp_ = ace.wseg * ps_(:);                                               % (Nzc x 1) force on the MOUNTAIN per level (N per unit y)
      dmean = dmean - Dp_ / (Ni*dx*dz);                                      % force on the FLUID per volume
      if ~isempty(ace.rec.meanu), ace.rec.meanu.n = ace.rec.meanu.n + 1; ace.rec.meanu.D_last = sum(Dp_); ace.rec.meanu.D_sum = ace.rec.meanu.D_sum + sum(Dp_); ace.rec.meanu.D_max = max(ace.rec.meanu.D_max, abs(sum(Dp_))); end
    end
    if ~(isfield(ace,'mean_u_sponge') && ~ace.mean_u_sponge)
      % sponge eps_sl(z) on the level-mean wind (sponge iron rule): absorbs the EP flux deposited in the top dead zone
      eps_k = ace.damp(1:Nzc,1) .* rho_zc(:) / ace.dt; ubs_ = UBAR_NOW(ace);
      dsp = - eps_k .* rho_zc(:) .* ( mean(u_face, 2) - ubs_(1:Nzc) );       % kept separate: acts in the dead zone too
    end
    dcref = -s * dmean;
    dcref(1:ace.nbuf) = 0; dcref(end-nd+1:end) = 0;
    dcref = dcref - s * dsp; dcref(1:ace.nbuf) = 0;                          % level-mean sponge: everywhere incl. the top dead zone (no cref drift there)
  end
end

function K2resp = K2TAIL(dzFx, ace)
  % stacked + odd-pair-folded K2 apply on the MIXED tiling (cells -> layers by Lmap).
  Slay = (ace.Lmap * dzFx).';                       % (Ni x Nlay)
  K2resp = K2_APPLY_LAYERS(Slay, ace);
end

function K2resp = K2TAIL_ORIG(dzFx, ace)
  % layer-loop reference (wiring insurance only).
  Ni = ace.Ni; Nlay = size(ace.K2t,3); Nz = size(ace.K2t,2);
  Slay = (ace.Lmap * dzFx).';
  acc = zeros(Ni, Nz);
  for lay = 1:Nlay
    Sg = Slay(ace.gw2 + (lay-1)*Ni);
    acc = acc + Sg * squeeze(ace.K2t(:,:,lay));
  end
  K2resp = acc';
end

function [yn, ace] = ssprk93_topo(expFun,yn,dTH,dQt,rho0B,dt,Wbar_eq_zero,Ai,ace)
  % EXACT replica of the certified util_timeint/ssprk93.m plus the per-STAGE terrain
  % state closure TOPO_STAGE after every stage state (no-op when terrain_on=false ->
  % bit-identical to ssprk93; gate G0b). The end-of-step Wbar sweep is the verbatim
  % original when flat, and the terrain-aware free-interface version otherwise.
  % Stage-state times (time-dependent ubar): c = 1/6,2/6,3/6,4/6,5/6, 1/2, 2/3, 5/6, 1;
  % ace.t is set to the time of the state being closed / differentiated.
  t0 = ace.t;
  [K1, ace] = expFun(yn,dTH,dQt,rho0B,ace);
  ace.t = t0 + dt/6;   [yi, ace] = TOPO_STAGE(yn+(dt/6)*K1, ace);
  [K2, ace] = expFun(yi,dTH,dQt,rho0B,ace);
  ace.t = t0 + 2*dt/6; [yi, ace] = TOPO_STAGE(yn+(dt/6)*(K1+K2), ace);
  [Ks, ace] = expFun(yi,dTH,dQt,rho0B,ace); K2 = K2 + Ks;
  ace.t = t0 + 3*dt/6; [yi, ace] = TOPO_STAGE(yn+(dt/6)*(K1+K2), ace);
  [Ks, ace] = expFun(yi,dTH,dQt,rho0B,ace); K2 = K2 + Ks;
  ace.t = t0 + 4*dt/6; [yi, ace] = TOPO_STAGE(yn+(dt/6)*(K1+K2), ace);
  [Ks, ace] = expFun(yi,dTH,dQt,rho0B,ace); K2 = K2 + Ks;
  ace.t = t0 + 5*dt/6; [yi, ace] = TOPO_STAGE(yn+(dt/6)*(K1+K2), ace);
  [Ks, ace] = expFun(yi,dTH,dQt,rho0B,ace); K2 = (K2 + Ks)/15;
  ace.t = t0 + dt/2;   [yi, ace] = TOPO_STAGE(yn+dt*(K1/6+K2), ace);
  [Ks, ace] = expFun(yi,dTH,dQt,rho0B,ace); K1 = K1 + Ks;
  ace.t = t0 + 2*dt/3; [yi, ace] = TOPO_STAGE(yn+dt*(K1/6+K2), ace);
  [Ks, ace] = expFun(yi,dTH,dQt,rho0B,ace); K1 = K1 + Ks;
  ace.t = t0 + 5*dt/6; [yi, ace] = TOPO_STAGE(yn+dt*(K1/6+K2), ace);
  [Ks, ace] = expFun(yi,dTH,dQt,rho0B,ace); yn = yn + dt*((K1 + Ks)/6+K2);
  ace.t = t0 + dt;
  yn(:,2,:) = yn(:,2,:).*( yn(:,2,:)>0 ); % Non-negative qt
  if Wbar_eq_zero==1
    if ace.terrain_on
      yn(:,3,:) = reshape(WBAR_REMOVE(squeeze(yn(:,3,:)), ace), [ace.Nzm,1,ace.Ni]);
    else
      yn(:,3,:) = yn(:,3,:) - sum(yn(:,3,:).*permute(Ai/sum(Ai),[3,2,1]),3);
    end
  end
  [yn, ace] = TOPO_STAGE(yn, ace);
  ace.t = t0;
end

function MF = WBAR_REMOVE(MF, ace)
  % Level-mean (Ai-weighted, all columns) removal, redistributed over FREE interfaces
  % only (strictly above each column's top face) so rock/top-face zeros stay exact.
  % Flat: free = all rows but the ground -> identical to the all-column mean removal.
  lm = MF * ace.Ai(:);                             % (Nzm x 1) Ai-weighted level sums
  MF = MF - lm .* ace.wfree;                       % uniform delta over free cols: sum_i Ai*delta = lm
end

function [X, ace] = TOPO_STAGE(X, ace)
  % Per-stage STATE closure. Production: the hard body CAPACITANCE closure (topo_solver = 'cap',
  % CAPB_STAGE); topo_solver = 'psi' is the psi-Dirichlet elliptic twin used by the gates.
  % No-op when terrain_on = false.
  if isfield(ace,'topo_solver') && strcmp(ace.topo_solver,'cap')
    if ace.terrain_on, [X, ace] = CAPB_STAGE(X, ace); end
    return;
  end
  if isfield(ace,'topo_solver') && strcmp(ace.topo_solver,'psi')
    if ace.terrain_on, [X, ace] = PSI_STAGE(X, ace); end
    return;
  end
end

function io = IOFLOW_OF(MF, ace)
  % -rho0u on faces at zc: cumsum_i(Ai*dz(MF)) with zero-mean gauge (the march's ioflow).
  Az_dz = ace.Ai' .* ((MF(2:end,:) - MF(1:end-1,:))/ace.dz);
  io = GAUGE_IO(cumsum(Az_dz,2), ace);
end

function ace = BUILD_SOFT(ace)
  % Soft-boundary index sets (VVM-faithful): body nodes (zm rows 2..kbf(f)+1 on face f),
  % masked-velocity index sets, body-mean gauge weights, and the FFT/tridiagonal Poisson constants.
  Ni = ace.Ni; Nzm = ace.Nzm; Nzc = Nzm-1; dx = ace.dx; dz = ace.dz;
  kbf = ace.kbot_face(:).'; kb = ace.kbot(:).';
  body = false(Nzm, Ni);                                   % vorticity nodes on/in the body (excl. ground row)
  for f=1:Ni, if kbf(f)>0, body(2:kbf(f)+1, f) = true; end, end
  ufm = false(Nzc, Ni);                                    % body FACES for u masking (k <= kbf)
  for f=1:Ni, if kbf(f)>0, ufm(1:kbf(f), f) = true; end, end
  mfm = false(Nzm, Ni);                                    % rock interfaces incl. top faces (k <= kb+1) for MF masking
  for i=1:Ni, if kb(i)>0, mfm(1:kb(i)+1, i) = true; end, end
  % gauge weights: body-face mean at blocked levels, plain mean elsewhere
  nb = sum(ufm, 2); hasbody = nb > 0;
  gwb = zeros(Nzc, Ni);
  gwb(~hasbody, :) = 1/Ni;
  for k = find(hasbody).', gwb(k, ufm(k,:)) = 1/nb(k); end
  soft = struct('body',body,'body_lin',find(body),'ufm',ufm,'mfm',mfm,'nbody',nnz(body));
  ub = ace.ubar_zc(1:Nzc); rho = ace.rho_zc(1:Nzc); soft.PsiBar = [0; cumsum(rho(:).*ub(:))*dz];   % (Nzm x 1) unit-R PsiBar
  soft.lam = (2 - 2*cos(2*pi*(0:Ni-1)/Ni)) / dx^2;        % x-eigenvalues of -d2/dx2 (periodic)
  ace.soft = soft; ace.gwb = gwb; ace.hasbody = double(hasbody(:));
  fprintf('BUILD_SOFT: %d body vorticity nodes, %d body faces (u masked), %d rock interfaces (MF masked); blocked levels %d\n', soft.nbody, nnz(ufm), nnz(mfm), nnz(hasbody));
end

function [dMF, dpsi] = POISSON_DMF(deta, ace)
  % EXACT inversion of a vorticity increment on the whole periodic domain: -Lap(dpsi) = deta with
  % dpsi = 0 at ground/top, periodic in x (FFT in x, tridiagonal in z); dMF = dx(dpsi). Consistent
  % with ETA_OF: ETA_OF(dMF) reproduces deta at every interior node (5-point identity).
  Nzm = ace.Nzm; Ni = ace.Ni; dx = ace.dx; dz = ace.dz; n = Nzm-2;
  F = fft(deta(2:Nzm-1,:), [], 2);                         % (n x Ni) complex, rows k=2..Nzm-1
  a = -1/dz^2 * ones(n,1); d = ace.soft.lam(:).' + 2/dz^2;   % diag per wavenumber (1 x Ni), off-diag a
  % Thomas algorithm vectorised over wavenumbers
  cp = zeros(n, Ni); dp = zeros(n, Ni);
  cp(1,:) = a(1) ./ d; dp(1,:) = F(1,:) ./ d;
  for k = 2:n
    den = d - a(k)*cp(k-1,:);
    cp(k,:) = a(k) ./ den;
    dp(k,:) = (F(k,:) - a(k)*dp(k-1,:)) ./ den;
  end
  P = zeros(n, Ni); P(n,:) = dp(n,:);
  for k = n-1:-1:1, P(k,:) = dp(k,:) - cp(k,:).*P(k+1,:); end
  dpsi = zeros(Nzm, Ni); dpsi(2:Nzm-1,:) = real(ifft(P, [], 2));
  dMF = ( dpsi - circshift(dpsi,1,2) ) / dx;
end

function psi = PSI_OF_STATE(MF, rho0u, ace)
  % EXACT discrete streamfunction of a state (SI): psi(k, f=Ni) = -sum_{j<k} rho0u(j, Ni) dz (psi=0 at
  % the ground), psi(k, f=i) = psi(k, Ni) + sum_{j<=i} MF(k, j) dx. By the discrete continuity identity
  % rho0u(k,f) = -(psi(k+1,f)-psi(k,f))/dz then holds on EVERY face (no Green's function involved).
  Nzm = ace.Nzm; dx = ace.dx; dz = ace.dz;
  psi0 = [0; -cumsum(rho0u(:,end))*dz];                    % (Nzm x 1) at face Ni
  psi = psi0 + cumsum(MF, 2)*dx;                           % face i = right face of column i
end

function dMF = CAPB_STAMP_ROWS(q, cb, Nzm, Ni)
  % FAST stamp: per distinct source row, one GEMM of the row's windowed response (Nzm x ncol) with the shifted
  % row-source matrix (ncol x Ni) -- the per-source scatter loop up to summation order (build-time insurance (b)).
  dMF = zeros(Nzm, Ni);
  for r = 1:cb.nrow
    qr = zeros(1, Ni); qr(cb.col_of_row{r}) = q(cb.src_of_row{r});
    if any(qr), dMF = dMF + cb.Rrow(:,:,r) * qr(cb.shift_idx); end
  end
end

function ace = BUILD_CAPB(ace)
  % Body capacitance: response of a unit vorticity at body node b
  % is the EXACT Poisson streamfunction dpsi_b (Dirichlet ground/top, periodic x), split into its
  % per-level x-mean psibar_b(k) (the k=0 part: a level constant, never windowed) and psi'_b(k,i)
  % (k~=0). cap_mode: 'exact' keeps psi' whole; 'taper' multiplies psi' by a cosine taper -> 0 beyond
  % +-NT columns of the source; 'trunc' hard-cuts it. Stored: Rmf_b = dx(psi'_b) on the 2NT+2 window
  % columns, psibar_b, psi'_b at the anchor face Ni (for the gauge reference). C_b(a,b) = psibar_b(k_a) + psi'_b(a).
  % The k=0 part makes C_b full rank (the body-mean gauge had discarded it: rank deficit = #blocked levels).
  Ni = ace.Ni; Nzm = ace.Nzm; NT = ace.NT; sf = ace.soft; dx = ace.dx; dz = ace.dz;
  % unknowns = body-node vorticities (rows 2..kbf+1) + one closure vorticity at the first fluid node (kbf+2,f)
  % of every PARTIAL face; constraints = psi = PsiBar R at the body nodes + the EXTRAPOLATED psi(h_f) = PsiBar(h_f) R
  % on every partial face (linear extrapolation from the fluid nodes kbf+2, kbf+3: weights (1-lam), lam, lam = r_f - 1).
  pf = []; if isfield(ace,'pface'), pf = ace.pface(:).'; end
  kbf = ace.kbot_face(:).'; Np = numel(pf);
  pnode = zeros(Np,1); Wn1 = zeros(Np,1); Wn2 = zeros(Np,1); Ww1 = zeros(Np,1); Ww2 = zeros(Np,1); cons_k = zeros(Np,1); cons_cell = ones(Np,1); cons_frac = zeros(Np,1);
  for q_ = 1:Np
    f = pf(q_); k2 = kbf(f)+2; k3 = kbf(f)+3; lam = ace.rface(f) - 1;
    assert(k3 <= Nzm - ace.ndead, 'BUILD_CAPB: partial face too high');
    pnode(q_) = k2 + (f-1)*Nzm; Wn1(q_) = k2 + (f-1)*Nzm; Wn2(q_) = k3 + (f-1)*Nzm; Ww1(q_) = 1 - lam; Ww2(q_) = lam;
    cons_k(q_) = kbf(f)+1; cons_cell(q_) = kbf(f)+1; cons_frac(q_) = ace.rface(f)*dz;   % PsiBar(h_f) = PsiBar(z_{kbf+1}) + rho0 ubar(cell kbf+1) r_f dz
  end
  ns = isfield(ace,'ib_noslip') && ace.ib_noslip;
  src_lin = [sf.body_lin(:); pnode]; Nb0 = numel(sf.body_lin); Nb = Nb0 + Np;
  % constraint functional W (Nb x Nzm*Ni, sparse): rows 1..Nb0 unit at the body node; rows Nb0+1.. extrapolation pair
  Wi = [1:Nb0, Nb0+(1:Np), Nb0+(1:Np)]; Wj = [sf.body_lin(:).', Wn1.', Wn2.']; Wv = [ones(1,Nb0), Ww1.', Ww2.'];
  [kbody_, ~] = ind2sub([Nzm, Ni], sf.body_lin);
  cons_k = [kbody_(:); cons_k]; cons_cell = [ones(Nb0,1); cons_cell]; cons_frac = [zeros(Nb0,1); cons_frac];
  cons_type = [zeros(Nb0+Np,1)];                                          % 0 = psi value target
  if ns
    % IBNOSLIP (CW16 u_b = 0 as a HARD constraint): d(psi')/dz at the surface point = rho0(z_s) ubar R, i.e. u_tot = 0 there.
    % d(psi')/dz at z_s by linear extrapolation of the two face-row differences above: D2 = (psi_{k3}-psi_{k2})/dz at
    % z = z_{k2}+dz/2, D3 = (psi_{k4}-psi_{k3})/dz at z_{k2}+3dz/2 ; D(z_s) = D2 + (D3-D2)*(z_s - z_{k2} - dz/2)/dz.
    % Second unknown per face: closure vorticity at node (kbf+3, f).
    pnode2 = zeros(Np,1); Wi2 = []; Wj2 = []; Wv2 = [];
    for q_ = 1:Np
      f = pf(q_); k2 = kbf(f)+2; k3 = k2+1; k4 = k2+2; lam = ace.rface(f) - 1;         % z_s - z_{k2} = lam*dz
      assert(k4 <= Nzm - ace.ndead, 'BUILD_CAPB: no-slip face too high');
      a = (lam - 0.5);                                                       % (z_s - z_{k2} - dz/2)/dz
      c2 = (1 - a)/dz; c3 = a/dz;                                             % D(z_s) = c2*(psi3-psi2) + c3*(psi4-psi3)
      pnode2(q_) = k3 + (f-1)*Nzm;
      Wi2 = [Wi2, Nb+q_, Nb+q_, Nb+q_]; Wj2 = [Wj2, k2+(f-1)*Nzm, k3+(f-1)*Nzm, k4+(f-1)*Nzm]; Wv2 = [Wv2, -c2, c2-c3, c3];
    end
    src_lin = [src_lin; pnode2]; Wi = [Wi, Wi2]; Wj = [Wj, Wj2]; Wv = [Wv, Wv2]; Nb = Nb + Np;
    cons_k = [cons_k; reshape(kbf(pf),[],1) + 1]; cons_cell = [cons_cell; reshape(kbf(pf),[],1) + 1]; cons_frac = [cons_frac; reshape(ace.rface(pf),[],1)*dz];
    cons_type = [cons_type; ones(Np,1)];                                    % 1 = psi-slope target (rho0 ubar at z_s)
    % BLOCK faces (body present, no partial opening; with the buffer row = every non-partial face incl. the flat
    % ground). Surface node k1 = kbf+1 (a body node, psi fixed there); u_tot(z_s) = 0 by one-sided 2nd-order extrapolation
    % from the two fluid cells above: D(z_s) = 1.5 D1 - 0.5 D2, D1 = (psi_{k2}-psi_{k1})/dz, D2 = (psi_{k3}-psi_{k2})/dz.
    % Second unknown per face: closure vorticity at the first fluid node (k2 = kbf+2, f).
    bfc = find(kbf >= 1 & ace.rface(:).' == 0); Nbf = numel(bfc);
    pnode3 = zeros(Nbf,1); Wi3 = zeros(1,3*Nbf); Wj3 = zeros(1,3*Nbf); Wv3 = zeros(1,3*Nbf);
    for q_ = 1:Nbf
      f = bfc(q_); k1 = kbf(f)+1; k2 = k1+1; k3 = k1+2;
      assert(k3 <= Nzm - ace.ndead, 'BUILD_CAPB: block no-slip face too high');
      pnode3(q_) = k2 + (f-1)*Nzm;
      Wi3(3*q_-2:3*q_) = Nb + q_; Wj3(3*q_-2:3*q_) = [k1, k2, k3] + (f-1)*Nzm; Wv3(3*q_-2:3*q_) = [-1.5, 2, -0.5]/dz;
    end
    src_lin = [src_lin; pnode3]; Wi = [Wi, Wi3]; Wj = [Wj, Wj3]; Wv = [Wv, Wv3]; Nb = Nb + Nbf;
    cons_k = [cons_k; reshape(kbf(bfc),[],1) + 1]; cons_cell = [cons_cell; reshape(kbf(bfc),[],1) + 1]; cons_frac = [cons_frac; zeros(Nbf,1)];
    cons_type = [cons_type; ones(Nbf,1)];
  end
  W = sparse(Wi, Wj, Wv, Nb, Nzm*Ni);
  [kb_, fb_] = ind2sub([Nzm, Ni], src_lin);
  mu2 = isfield(ace,'mean_u') && ace.mean_u > 0; ndrop_mu2 = 0;
  % MEANU = 1: the closure keeps its level-mean (k = 0) response, but the mean part takes the PHYSICAL lid
  % condition d(psibar)/dz = 0 (no mean-flow change aloft) instead of psibar(top) = 0: psibar_step = psibar_tent - s_above*z
  % (the 1-D mean operator has no rho0 weight, the profile is linear above the source). The body force's level mean is then
  % confined to the levels at/below the body vorticity (drag = momentum sink; no column-integral constraint, no compensation
  % aloft); the level-mean momentum equation carries the Reynolds stress. C_b keeps full rank through the k = 0 part.
  zr_ = ((1:Nzm).' - 1) * dz;                                              % height above the bottom row (mean-part coordinate)
  ncol = 2*NT+2; Cb = zeros(Nb, Nb);
  psibar = zeros(Nb, Nzm); psi1 = zeros(Nb, Nzm);
  wt = ones(1, 2*NT+1);
  if strcmp(ace.cap_mode,'taper')
    ntap = round(NT/3); ramp = 0.5*(1 - cos(pi*(1:ntap)/(ntap+1))); wt(1:ntap) = ramp; wt(end:-1:end-ntap+1) = ramp;
  end
  t0 = tic;
  % FAST: the Poisson response is x-translation-invariant (periodic x, coefficients depend on z only): ONE reference
  % solve per distinct source ROW (source at column 1); every source of that row is a column shift of it. Stored per row:
  % the windowed dx(psi') on the 2NT+2 window columns (offsets -NT..NT+1 from the source column) and the level constant.
  rows = unique(kb_(:)).'; nrow = numel(rows); rowidx = zeros(Nzm,1); rowidx(rows) = 1:nrow;
  Rrow = zeros(Nzm, ncol, nrow); PBrow = zeros(Nzm, nrow); PProw = zeros(Nzm, Ni, nrow);
  wcols1 = mod((-NT:NT), Ni) + 1; mcols1 = mod((-NT:NT+1), Ni) + 1;       % windows of a source at column 1
  for r = 1:nrow
    deta = zeros(Nzm, Ni); deta(rows(r), 1) = 1;
    [~, dpsi] = POISSON_DMF(deta, ace);                     % exact (Nzm x Ni), psi = 0 at ground/top
    pb = mean(dpsi, 2); pp = dpsi - pb;                     % k=0 / k~=0 split
    if mu2, sl_ = (pb(Nzm) - pb(rows(r))) / (zr_(Nzm) - zr_(rows(r))); pb = pb - sl_*zr_; end   % MEANU=1: step (Neumann-lid) mean response
    if ~strcmp(ace.cap_mode,'exact'), ppw = zeros(Nzm, Ni); ppw(:, wcols1) = pp(:, wcols1) .* wt; pp = ppw; end
    dMFp = ( pp - circshift(pp,1,2) ) / dx;                 % MF = dx(psi') non-zero on window and window+1
    Rrow(:,:,r) = dMFp(:, mcols1); PBrow(:,r) = pb; PProw(:,:,r) = pp;
  end
  % insurance (a): a DIRECTLY solved off-centre source (the last one) equals the shifted reference, same windowing
  bchk = Nb; rchk = rowidx(kb_(bchk)); deta = zeros(Nzm, Ni); deta(kb_(bchk), fb_(bchk)) = 1; [~, dchk] = POISSON_DMF(deta, ace);
  pbc = mean(dchk, 2); ppc = dchk - pbc; if mu2, sl_ = (pbc(Nzm) - pbc(kb_(bchk))) / (zr_(Nzm) - zr_(kb_(bchk))); pbc = pbc - sl_*zr_; end
  if ~strcmp(ace.cap_mode,'exact'), wc = mod((fb_(bchk)-1) + (-NT:NT), Ni) + 1; ppw = zeros(Nzm, Ni); ppw(:, wc) = ppc(:, wc) .* wt; ppc = ppw; end
  dref = PBrow(:,rchk) + circshift(PProw(:,:,rchk), fb_(bchk)-1, 2);
  eqv = max(abs(dref(:) - reshape(pbc + ppc, [], 1))) / max(abs(dchk(:)));
  for b = 1:Nb
    r = rowidx(kb_(b)); pp = circshift(PProw(:,:,r), fb_(b)-1, 2);
    psibar(b,:) = PBrow(:,r).'; psi1(b,:) = pp(:,end).';    % psi' at the anchor face Ni
    Cb(:, b) = W * reshape(PBrow(:,r) + pp, [], 1);         % response used by the closure (windowed unless exact)
  end
  clear PProw
  condCb = cond(Cb);
  [L, U, p] = lu(Cb, 'vector');
  % row-source index sets for the online GEMM stamp: window column j (offset j-NT-1) of column c receives source f = c-(j-NT-1)
  src_of_row = cell(1,nrow); col_of_row = cell(1,nrow);
  for r = 1:nrow, src_of_row{r} = find(kb_(:) == rows(r)); col_of_row{r} = fb_(src_of_row{r}); end
  shift_idx = zeros(ncol, Ni); for j = 1:ncol, shift_idx(j,:) = mod((0:Ni-1) - (j-NT-1), Ni) + 1; end
  cbt = struct('Nb',Nb,'nrow',nrow,'Rrow',Rrow,'src_of_row',{src_of_row},'col_of_row',{col_of_row},'shift_idx',shift_idx);
  % insurance (b): row-GEMM stamp of a random q equals the per-source scatter of the shifted windows (summation order only)
  rs_ = rng; rng(3); qg = randn(Nb,1); rng(rs_); dG = CAPB_STAMP_ROWS(qg, cbt, Nzm, Ni); dL = zeros(Nzm, Ni);
  for b = 1:Nb, mc = mod((fb_(b)-1) + (-NT:NT+1), Ni) + 1; dL(:, mc) = dL(:, mc) + qg(b) * Rrow(:,:,rowidx(kb_(b))); end
  gg = max(abs(dG(:) - dL(:))) / max(abs(dL(:)));
  assert(eqv < 1e-10 && gg < 1e-12, sprintf('BUILD_CAPB FAST insurance failed: equivariance %.2e, GEMM-vs-scatter %.2e', eqv, gg));
  ace.capb = struct('Nb',Nb,'Nb0',Nb0,'Np',Np,'nrow',nrow,'Rrow',Rrow,'src_of_row',{src_of_row},'col_of_row',{col_of_row},'shift_idx',shift_idx,'eqv',eqv,'gemm_gate',gg,'psibar',psibar,'psi1',psi1,'Cb',Cb,'L',L,'U',U,'p',p(:),'condCb',condCb,'kb',kb_,'fb',fb_,'mode',ace.cap_mode, ...
                    'W',W,'cons_k',cons_k,'cons_cell',cons_cell,'cons_frac',cons_frac,'cons_type',cons_type,'src_lin',src_lin,'pnode',pnode,'noslip',double(ns),'mu2',double(mu2),'ndrop_mu2',ndrop_mu2);
  fprintf('BUILD_CAPB (%s): %d body-node + %d partial-face sources%s, MF responses %s, cond(C_b)=%.3e, build %.1f s\n', ace.cap_mode, Nb0, Np, repmat(sprintf(' + no-slip rows (%d partial + %d block faces)', Np, Nb-Nb0-2*Np),1,ns), mat2str(size(Rrow)), condCb, toc(t0));
  fprintf('BUILD_CAPB FAST: %d distinct source rows ; equivariance (direct vs shifted reference) %.2e ; row-GEMM vs scatter %.2e\n', nrow, eqv, gg);
  if mu2, fprintf('BUILD_CAPB MEANU=1: mean (k=0) response with the Neumann-lid STEP profile (no mean flow aloft; drag confined at/below the body) ; Nb=%d\n', Nb); end
end

function [X, ace] = CAPB_STAGE(X, ace)
  % hard closure: psi_cur exactly from the state (cref gauge), solve C_b q = PsiBar R(t) - psi_cur
  % on the body nodes, stamp dMF = sum q_b Rmf_b and update the gauge reference (slot 7) by
  % d(rho0 u)(face Ni) = -dz( sum q_b (psibar_b + psi'_b(:,Ni)) ).
  Nzm = ace.Nzm; Ni = ace.Ni; Nzc = Nzm-1; dz = ace.dz; s = ace.Ai(1)/ace.dx; sf = ace.soft; cb = ace.capb;
  cref_in = []; if isfield(ace,'cref_io'), cref_in = ace.cref_io; end
  ace = PSI_CREF(ace, X);
  MF = squeeze(X(:,3,:));
  io = IOFLOW_OF(MF, ace); rho0u = -io/s;
  psi = PSI_OF_STATE(MF, rho0u, ace);
  R_t = 1; if ace.ubar_on && isfield(ace,'ubar_tau') && ace.ubar_tau > 0 && ace.t < ace.ubar_tau, R_t = sin(pi*max(ace.t,0)/(2*ace.ubar_tau))^2; end
  if ~ace.ubar_on, R_t = 0; end
  PsiBar_rt = [0; cumsum(ace.rho_zc(1:Nzc).*ace.ubar_zc(1:Nzc))*dz];      % runtime ubar (sign/magnitude), unit R
  rub = ace.rho_zc(1:Nzc).*ace.ubar_zc(1:Nzc);
  tgt = ( PsiBar_rt(cb.cons_k) + rub(cb.cons_cell).*cb.cons_frac ) * R_t;   % body nodes: PsiBar(z_k) R ; partial faces: PsiBar(h_f) R
  if isfield(cb,'noslip') && cb.noslip
    isl = cb.cons_type == 1; tgt(isl) = rub(cb.cons_cell(isl)) * R_t;      % no-slip rows: d(psi')/dz at z_s = rho0 ubar R (u_tot = 0)
  end
  rhs = tgt - cb.W * psi(:);
  q = cb.U \ (cb.L \ rhs(cb.p));
  if strcmp(cb.mode,'exact')
    % exact mode: one whole-domain Poisson solve of the body-vorticity increment (no window storage) -- GATE DIAGNOSTIC ONLY
    deta = zeros(Nzm, Ni); deta(cb.src_lin) = q;
    [dMF, dpsi] = POISSON_DMF(deta, ace);
    if isfield(cb,'mu2') && cb.mu2                          % MEANU=1: step (Neumann-lid) mean response (linear above the highest source)
      pbe = mean(dpsi, 2); kmx = max(cb.kb); zr_ = ((1:Nzm).' - 1) * dz; sl_ = (pbe(Nzm) - pbe(kmx)) / (zr_(Nzm) - zr_(kmx)); dpsi = dpsi - sl_*zr_;
    end
    dpsi1 = dpsi(:,end);
  else
    dMF = CAPB_STAMP_ROWS(q, cb, Nzm, Ni);                  % FAST: one GEMM per source row
    dpsi1 = (q.' * (cb.psibar + cb.psi1)).';               % (Nzm x 1) psi increment at the anchor face Ni (windowed responses)
  end
  MFn = MF + dMF;
  drho0u1 = -( dpsi1(2:Nzm) - dpsi1(1:Nzm-1) ) / dz;       % (Nzc x 1)
  X(:,3,:) = reshape(MFn, [Nzm,1,Ni]);
  X(:,7,:) = 0; X(1:Nzc,7,1) = ace.cref_io(:) + (-s) * drho0u1;   % gauge reference (io units) at the anchor face Ni
  if ~isempty(ace.rec.topo)
    ace.rec.topo.n = ace.rec.topo.n + 1; ace.rec.topo.maxr = max(ace.rec.topo.maxr, max(abs(rhs))); ace.rec.topo.maxq = max(ace.rec.topo.maxq, max(abs(q)));
    dE = 0.5*sum(sum((MFn.^2 - MF.^2) .* ace.Ai(:).')); ace.rec.topo.maxdE = max(ace.rec.topo.maxdE, abs(dE)); ace.rec.topo.sumdE = ace.rec.topo.sumdE + dE;
  end
  if ~isempty(cref_in), ace.cref_io = cref_in; end
end

function vw = WENO_X_PERIODIC(k, q, c)
  % WENO(2k-1) reconstruction along x (PERIODIC), same stencils/weights as util_weno/reconstruction_weno_vec
  % but without its ground-row (idx 2,3) reduced-order modification. q(:,f): values at faces; output vw(:,i):
  % value at column i (between faces i-1 and i); c(:,i): carrier at column i (>=0 -> upwind side = faces i-1, i-2,..).
  p = 2; eps_ = 1e-10;
  sh = @(a,n) circshift(a, n, 2);                              % sh(q,1) = face i-1 ; sh(q,-1) = face i+1
  if k == 2
    beta = cat(3, (sh(q,-1)-q).^2, (q-sh(q,1)).^2, (sh(q,1)-sh(q,2)).^2);
    dpos = reshape([0 2/3 1/3],1,1,3); dneg = reshape([1/3 2/3 0],1,1,3);
    d = dpos.*(c>=0) + dneg.*(c<0);
    alpha = d./(eps_ + beta).^p; w = alpha./sum(alpha,3);
    vw = w(:,:,1).*(1.5*q - 0.5*sh(q,-1)) + w(:,:,2).*(0.5*(sh(q,1)+q)) + w(:,:,3).*(-0.5*sh(q,2) + 1.5*sh(q,1));
  elseif k == 3
    beta = cat(3, ...
      1.083333333333333*(sh(q,-2)-2*sh(q,-1)+q).^2 + 0.25*(sh(q,-2)-4*sh(q,-1)+3*q).^2, ...
      1.083333333333333*(sh(q,1)-2*q+sh(q,-1)).^2 + 0.25*(3*sh(q,1)-4*q+sh(q,-1)).^2, ...
      1.083333333333333*(sh(q,2)-2*sh(q,1)+q).^2 + 0.25*(sh(q,2)-q).^2, ...
      1.083333333333333*(sh(q,3)-2*sh(q,2)+sh(q,1)).^2 + 0.25*(sh(q,3)-4*sh(q,2)+3*sh(q,1)).^2);
    dpos = reshape([0 0.3 0.6 0.1],1,1,4); dneg = reshape([0.1 0.6 0.3 0],1,1,4);
    d = dpos.*(c>=0) + dneg.*(c<0);
    alpha = d./(eps_ + beta).^p; w = alpha./sum(alpha,3);
    vw = w(:,:,1).*(1.833333333333333*q - 1.166666666666667*sh(q,-1) + 0.333333333333333*sh(q,-2)) + ...
         w(:,:,2).*(0.333333333333333*sh(q,1) + 0.833333333333333*q - 0.166666666666667*sh(q,-1)) + ...
         w(:,:,3).*(-0.166666666666667*sh(q,2) + 0.833333333333333*sh(q,1) + 0.333333333333333*q) + ...
         w(:,:,4).*(0.333333333333333*sh(q,3) - 1.166666666666667*sh(q,2) + 1.833333333333333*sh(q,1));
  else
    error('WENO_X_PERIODIC: k=%d not implemented (2 or 3)', k);
  end
end

function ace = BUILD_PSI(ace)
  % Sparse 5-point Poisson operator for psi' on the (zm rows x faces) nodes with Dirichlet nodes:
  % ground (k=1), top (k=Nzm) and every body node (k <= kbot_face(f)+1: rock interior, wall rows
  % and the top-of-wall corner row) -- there psi_tot = 0, i.e. psi' = PsiBar(z_k) R(t) with
  % PsiBar(z) = int_0^z rho0 ubar0 dz. Periodic in x. -Lap is SPD: Cholesky factorised once.
  % Discrete consistency: with MF = dx(psi), rho0u = -dz(psi) the code's ETA_OF equals -Lap(psi)
  % node by node, so the interior vorticity is reproduced exactly after the solve.
  Ni = ace.Ni; Nzm = ace.Nzm; Nzc = Nzm-1; dx = ace.dx; dz = ace.dz;
  kbf = ace.kbot_face(:).';                              % (1 x Ni)
  isD = false(Nzm, Ni); isD(1,:) = true; isD(Nzm,:) = true;
  for f=1:Ni, if kbf(f)>0, isD(1:kbf(f)+1, f) = true; end, end
  lin_int = find(~isD); Nu = numel(lin_int);
  idx = zeros(Nzm, Ni); idx(lin_int) = 1:Nu;
  [kI, fI] = ind2sub([Nzm, Ni], lin_int);
  % PsiBar unit (R = 1) at zm rows: cumulative sum of rho0 ubar0 dz over the cells below
  ub = ace.ubar_zc(1:Nzc); rho = ace.rho_zc(1:Nzc);
  PsiBar = [0; cumsum(rho(:).*ub(:))*dz];                % (Nzm x 1), PsiBar(1) = 0
  psiD_unit = zeros(Nzm, Ni); PB = repmat(PsiBar, 1, Ni); psiD_unit(isD) = PB(isD);
  psiD_unit(1,:) = 0; psiD_unit(Nzm,:) = 0;              % ground/top: psi' = 0 (PsiBar(top) is not imposed; top is a lid streamline of the perturbation)
  cx = 1/dx^2; cz = 1/dz^2;
  rows = zeros(5*Nu,1); cols = rows; vals = rows; n = 0; rD = zeros(Nu,1);
  for q_ = 1:Nu
    k = kI(q_); f = fI(q_);
    n = n+1; rows(n) = q_; cols(n) = q_; vals(n) = 2*cx + 2*cz;          % -Lap diagonal
    nb = [k-1, f, cz; k+1, f, cz; k, mod(f-2,Ni)+1, cx; k, mod(f,Ni)+1, cx];
    for m=1:4
      kk = nb(m,1); ff = nb(m,2); c = nb(m,3);
      if isD(kk,ff)
        rD(q_) = rD(q_) + c*psiD_unit(kk,ff);                             % Dirichlet neighbour -> rhs
      else
        n = n+1; rows(n) = q_; cols(n) = idx(kk,ff); vals(n) = -c;
      end
    end
  end
  A = sparse(rows(1:n), cols(1:n), vals(1:n), Nu, Nu);
  % on every PARTIAL face the first fluid node (kbf+2,f) is a GHOST node: its Laplace row is replaced by the
  % extrapolated Dirichlet condition (1-lam) psi_{k2} + lam psi_{k3} = PsiBar(h_f) R  (lam = r_f - 1), no eta there.
  ghost = []; pf = []; if isfield(ace,'pface'), pf = ace.pface(:).'; end
  if ~isempty(pf)
    kbf = ace.kbot_face(:).'; A = A.';                                     % transpose: column edits are cheap in CSC
    for f = pf
      k2 = kbf(f)+2; k3 = kbf(f)+3; lam = ace.rface(f) - 1; q2 = idx(k2,f); q3 = idx(k3,f);
      assert(q2 > 0 && q3 > 0, 'BUILD_PSI: partial ghost node is Dirichlet');
      A(:, q2) = 0; A(q2, q2) = 1 - lam; A(q3, q2) = lam;                    % (transposed) row q2
      rD(q2) = PsiBar(kbf(f)+1) + rho(kbf(f)+1)*ub(kbf(f)+1)*ace.rface(f)*dz;   % PsiBar(h_f), unit R
      ghost(end+1) = q2;
    end
    A = A.';
  end
  t0 = tic;
  if isempty(ghost), dec = decomposition(A, 'chol'); else, dec = decomposition(A, 'lu'); end
  tf = toc(t0);
  psi = struct('Nu',Nu,'lin_int',lin_int,'isD',isD,'psiD_unit',psiD_unit,'rD',rD,'dec',dec,'PsiBar',PsiBar,'tfact',tf,'ub_build',ace.ubar_zc(1),'ghost',ghost(:));
  ace.psi = psi;
  fprintf('BUILD_PSI: %d interior nodes, %d Dirichlet nodes (%d body) ; Cholesky %.1f s ; psi'' on the body = PsiBar(z) R(t), PsiBar(crest)=%.3e\n', ...
          Nu, nnz(isD), nnz(isD) - 2*Ni, tf, PsiBar(max(ace.kbot)+1));
end

function [X, ace] = PSI_STAGE(X, ace)
  % VVM-style closure: solve -Lap(psi') = eta'_interior with psi' = PsiBar R(t)
  % on the body; stamp MF = dx(psi'); store the psi gauge reference (rho0 u'_psi at the anchor face Ni) in
  % slot 7. Boundary vorticity is whatever -Lap(psi') is on the boundary rows (diagnosed).
  Nzm = ace.Nzm; Ni = ace.Ni; Nzc = Nzm-1; dx = ace.dx; dz = ace.dz; s = ace.Ai(1)/ace.dx;
  cref_in = []; if isfield(ace,'cref_io'), cref_in = ace.cref_io; end
  ace = PSI_CREF(ace, X); psi = ace.psi;
  MF = squeeze(X(:,3,:));
  io = IOFLOW_OF(MF, ace); rho0u = -io / s;               % SI, (Nzc x Ni) faces
  eta = zeros(Nzm, Ni);
  dxMF = ( circshift(MF,-1,2) - MF ) / dx;
  eta(2:Nzm-1,:) = ( rho0u(2:end,:) - rho0u(1:end-1,:) )/dz - dxMF(2:Nzm-1,:);
  R = 1; if ace.ubar_on && isfield(ace,'ubar_tau') && ace.ubar_tau > 0 && ace.t < ace.ubar_tau, R = sin(pi*max(ace.t,0)/(2*ace.ubar_tau))^2; end
  if ~ace.ubar_on, R = 0; end
  if psi.ub_build ~= 0, R = R * ace.ubar_zc(1) / psi.ub_build; end        % runtime ubar sign/magnitude (uniform profile assumed)
  rhs = eta(psi.lin_int) + R * psi.rD;
  if isfield(psi,'ghost') && ~isempty(psi.ghost), rhs(psi.ghost) = R * psi.rD(psi.ghost); end   % ghost rows: no vorticity
  PSI = R * psi.psiD_unit;                                % Dirichlet values everywhere, then fill the interior
  PSI(psi.lin_int) = psi.dec \ rhs;
  MFn = ( PSI - circshift(PSI,1,2) ) / dx;               % MF(k,i) = (psi(k,i) - psi(k,i-1))/dx
  MFn(1,:) = 0; MFn(Nzm,:) = 0;
  X(:,3,:) = reshape(MFn, [Nzm,1,Ni]);
  rho0u_psi = -( PSI(2:Nzm,:) - PSI(1:Nzm-1,:) ) / dz;   % SI, faces
  X(:,7,:) = 0; X(1:Nzc,7,1) = -s * rho0u_psi(:,end);     % gauge reference (io units) at face Ni (slot 7, entity 1)
  if ~isempty(ace.rec.topo)
    dMF = MFn - MF;
    ace.rec.topo.n = ace.rec.topo.n + 1; ace.rec.topo.maxr = max(ace.rec.topo.maxr, max(abs(dMF(:))));
    dE = 0.5*sum(sum((MFn.^2 - MF.^2) .* ace.Ai(:).'));
    ace.rec.topo.maxdE = max(ace.rec.topo.maxdE, abs(dE)); ace.rec.topo.sumdE = ace.rec.topo.sumdE + dE;
  end
  if ~isempty(ace.diag.psi) && isstruct(ace.diag.psi) && ace.diag.psi.on
    ace.diag.psi.eta_in = eta; ace.diag.psi.PSI = PSI; ace.diag.psi.rho0u_psi = rho0u_psi; ace.diag.psi.MF_in = MF; ace.diag.psi.MF_out = MFn; ace.diag.psi.R = R;
  end
  if ~isempty(cref_in), ace.cref_io = cref_in; end
end

function io = GAUGE_IO(io, ace)
  % Level gauge of the cumulative horizontal flux. Flat (or gauge 'all'): remove the all-face
  % mean (bit-twins hold). Terrain with gauge 'fluid': remove the FLUID-face
  % mean per level (weights ace.gw = Mface/N_fluid), so the far-field u_tot equals ubar at every
  % level instead of ubar*Ni/N_fluid (the spurious ring-jet of the all-face gauge under a blocked
  % level). With ubar = 0 both gauges give identical constrained states (walls => in-rock io = 0).
  if isfield(ace,'topo_solver') && any(strcmp(ace.topo_solver,{'psi','cap'})) && ace.terrain_on && isfield(ace,'cref_io') && ~isempty(ace.cref_io)
    % PSI gauge: the level constant is fixed by the last elliptic solve (rho0 u'_psi at the anchor face Ni),
    % so io == -s*rho0u'_psi on every face (walls: u_tot = 0 exactly; far field: ubar).
    io = io - (io(:,end) - ace.cref_io(:));          % anchor face = Ni (its own mirror image; far from the mountain)
  elseif ace.terrain_on && isfield(ace,'gw') && ~isempty(ace.gw)
    io = io - sum(io.*ace.gw, 2);
  else
    io = io - mean(io, 2);
  end
end

function ace = PSI_CREF(ace, X)
  % pull the psi-gauge reference (slot 7, rows 1..Nzc, entity 1; io units) from the state
  if isfield(ace,'topo_solver') && any(strcmp(ace.topo_solver,{'psi','cap'})) && ace.terrain_on
    ace.cref_io = squeeze(X(1:ace.Nzm-1,7,1));
  end
end

function ub = UBAR_NOW(ace)
  % Prescribed background wind at the current model time ace.t: static profile times the C1
  % sin^2 ramp R(t) (ace.ubar_tau = 0 => R = 1). Zero when ubar_on = 0.
  if ~ace.ubar_on, ub = zeros(size(ace.ubar_zc)); return; end
  R = 1;
  if isfield(ace,'ubar_tau') && ace.ubar_tau > 0 && ace.t < ace.ubar_tau
    R = sin(pi*max(ace.t,0)/(2*ace.ubar_tau))^2;
  end
  ub = R * ace.ubar_zc;
end

function eta = ETA_OF(MF, ace)
  % Linear functional: eta = dz(rho0u) - dx(MF), rho0u = -ioflow(MF).
  Nzm = ace.Nzm;
  rho0u = -IOFLOW_OF(MF, ace);
  dz_rho0u = ( rho0u(2:end,:) - rho0u(1:end-1,:) ) / ace.dz;
  dx_MF = ( circshift(MF,-1,2) - MF ) / ace.dx;
  eta = zeros(Nzm, ace.Ni);
  eta(2:Nzm-1,:) = dz_rho0u - dx_MF(2:Nzm-1,:);
end

function R = K1_APPLY_LAYERS(S, ace)
  % TAP-LOOP even-folded K1 apply from LAYER-space input S (Ni x Nlay) -> (Nzm x Ni):
  % R(i,:) = S(i,:) K(0) + sum_{d=1..NT} [S(i-d,:) + S(i+d,:)] K(+d)   (K(-d) = K(+d), Gate 2 evenness)
  R = S * ace.K1tap{1};
  for d = 1:ace.NTtap
    R = R + ( circshift(S, d, 1) + circshift(S, -d, 1) ) * ace.K1tap{d+1};
  end
  R = R.';
end
function R = K1_APPLY_LAYERS_SUB(S, ace, lays)
  % tap-loop K1 apply restricted to the layer subset lays (S is Ni x numel(lays)): same sums as K1_APPLY_LAYERS.
  R = S * ace.K1tap{1}(lays,:);
  for d = 1:ace.NTtap
    R = R + ( circshift(S, d, 1) + circshift(S, -d, 1) ) * ace.K1tap{d+1}(lays,:);
  end
  R = R.';
end
function R = K1_APPLY_STACKED(S, ace)
  % (record / insurance twin) stacked + even-folded single-GEMM K1 apply.
  Sg = S(ace.GW1big);
  SgF = Sg(:, ace.c1keep);
  SgF(:, ace.p1dst) = SgF(:, ace.p1dst) + Sg(:, ace.c1minus);
  R = ( SgF * ace.Kbig1F )';
end

function R = K2_APPLY_LAYERS(Slay, ace)
  % TAP-LOOP odd-pair-folded K2 apply from LAYER-space input (Ni x Nlay) -> (Nzm x Ni):
  % R(i,:) = sum_{m=0..NT-1} [S(i+m,:) - S(i-1-m,:)] K(-m)   (K(1-Delta) = -K(Delta), Gate 3 odd pairs)
  R = ( Slay - circshift(Slay, 1, 1) ) * ace.K2tap{1};
  for m = 1:ace.NTtap-1
    R = R + ( circshift(Slay, -m, 1) - circshift(Slay, m+1, 1) ) * ace.K2tap{m+1};
  end
  R = R.';
end
function R = K2_APPLY_STACKED(Slay, ace)
  % (record / insurance twin) stacked + odd-pair-folded single-GEMM K2 apply.
  Sg = Slay(ace.GW2big);
  R = ( (Sg(:, ace.c2lead) - Sg(:, ace.c2part)) * ace.Kbig2F )';
end

function [lay_of_cell, Lmap] = LAYER_MAP(Nzc, dz, edges)
  % lay_of_cell(k) = layer of zc cell k in the mixed tiling [edges(lay),edges(lay+1));
  % Lmap (Nlay x Nzc) averages cells into their layer (1 cell/layer below z_split).
  Nlay = numel(edges)-1; zc = ((1:Nzc)'-0.5)*dz;
  lay_of_cell = zeros(Nzc,1);
  for k=1:Nzc, lay_of_cell(k) = find(edges(1:end-1) <= zc(k) & zc(k) < edges(2:end), 1); end
  cnt = accumarray(lay_of_cell, 1, [Nlay,1]);
  Lmap = zeros(Nlay, Nzc);
  for k=1:Nzc, Lmap(lay_of_cell(k),k) = 1/cnt(lay_of_cell(k)); end
end

function ace = TERRAIN_MASKS(ace, kbot, terr_on)
  % All terrain index sets. kbot (1 x Ni) in cells.
  % terr_on=false or kbot==0 => trivial masks (Mface==1, empty index lists).
  Ni = ace.Ni; Nzm = ace.Nzm; Nzc = Nzm-1;
  ace.kbot = kbot; ace.terrain_on = logical(terr_on) && any(kbot>0);
  kb = @(i) kbot( mod(i-1,Ni)+1 );
  kbf = zeros(1,Ni); for f=1:Ni, kbf(f) = max(kb(f), kb(f+1)); end
  rf_hf = [];                                                 % IBSLOPE: face openings from the terrain height h(x_f)
  if isfield(ace,'hface') && ~isempty(ace.hface) && terr_on
    rf_hf = zeros(1,Ni);
    for f=1:Ni
      hz = ace.hface(f)/ace.dz + ace.nbuf; kf = max(kbf(f), floor(hz + 1e-9)); r = max(hz - kf, 0);   % the face is never lower than either column top
      if r < ace.hface_smin, r = 0; end
      if r > 0 && (1 - r) < ace.hface_vmin, kf = kf + 1; r = 0; end
      kbf(f) = kf; rf_hf(f) = r;
    end
  end
  ace.kbot_face = kbf;
  solid_zc = false(Nzc,Ni); rock_if = false(Nzm,Ni); free_if = true(Nzm,Ni);
  for i=1:Ni
    if kb(i)>0, solid_zc(1:kb(i),i) = true; rock_if(2:kb(i),i) = true; free_if(1:kb(i)+1,i) = false; end
  end
  free_if(1,:) = false;
  ace.solid_zc = solid_zc; ace.rock_if_lin = find(rock_if);
  % redistribution weights: uniform delta over FREE columns such that sum_i Ai*delta_i = level sum
  rs = sum(free_if .* ace.Ai(:).', 2); rs(rs==0) = 1;
  ace.wfree = free_if ./ rs;                          % (Nzm x Ni): delta_i = lm / sum_free(Ai)
  Mface = ones(Nzc,Ni); for f=1:Ni, if kbf(f)>0, Mface(1:kbf(f),f) = 0; end, end
  ace.Mface = Mface;
  % level gauge weights: 'fluid' => fluid-face mean per level; 'all' => all-face mean
  if isfield(ace,'gauge') && strcmp(ace.gauge,'all')
    ace.gw = [];
  else
    nf = sum(Mface,2); nf(nf==0) = 1; ace.gw = Mface ./ nf;
  end
  sc = []; gd = []; gs = [];
  for i=1:Ni
    for k=1:kb(i)
      for slot=1:2
        sc(end+1) = k + (slot-1)*Nzm + (i-1)*Nzm*2;
        gd(end+1) = k + (slot-1)*Nzm + (i-1)*Nzm*7;
        gs(end+1) = (kb(i)+1) + (slot-1)*Nzm + (i-1)*Nzm*7;
      end
    end
  end
  ace.solid_c2_lin = sc(:); ace.ghost_dst_lin = gd(:); ace.ghost_src_lin = gs(:);
  k2r = false(Nzc,Ni); fxm = false(Nzc,Ni); phw = false(Nzm,Ni); gdst = []; gsrc = []; gl = [];
  for f=1:Ni
    mn = min(kb(f), kb(f+1));
    if mn>0, k2r(1:mn,f) = true; end
    if kbf(f)>0
      fxm(1:kbf(f),f) = true;
      phw(1:kbf(f)+1,f) = true;
      for k=1:kbf(f), gdst(end+1) = k + (f-1)*Nzc; gsrc(end+1) = kbf(f)+1 + (f-1)*Nzc; end
      gl(end+1) = kbf(f)+1 + (f-1)*Nzc;
    end
  end
  ace.k2_rock_lin = find(k2r); ace.fx_mask = fxm; ace.phiw_mask = phw;
  ace.fxg_dst_lin = gdst(:); ace.fxg_src_lin = gsrc(:); ace.guard_lin = gl(:);
  % ---- PARTIAL STEP geometry (rsol = solid fraction of the partial cell kbot+1 per column; 0 = block) ----
  rs = zeros(1,Ni); if isfield(ace,'rsol') && ~isempty(ace.rsol), rs = ace.rsol(:).'; end
  hf_dz = zeros(1,Ni); rf = zeros(1,Ni);
  for f=1:Ni
    i2 = mod(f,Ni)+1;
    hf_dz(f) = max(kbot(f) + rs(f), kbot(i2) + rs(i2)); rf(f) = hf_dz(f) - kbf(f);
  end
  rf(rf < 1e-12) = 0;
  if ~isempty(rf_hf), rf = rf_hf; hf_dz = kbf + rf; end            % IBSLOPE: the terrain face heights replace the max-of-columns rule
  % PURE IMMERSED BOUNDARY (the only mode): the surface enters ONLY through the psi(h_f)
  % constraint and the Lamb exclusion mask omx -- no finite-volume fractions anywhere.
  Aface = double(Mface); vfrac = ones(Nzc,Ni); vfrac(solid_zc) = 0;
  ak = ones(Nzc,Ni); vk = ones(Nzc,Ni);
  omx = phw;                                                 % Lamb exclusion mask: body rows + the first node above a partial face
  for f = find(rf > 0), if kbf(f)+2 <= Nzm, omx(kbf(f)+2, f) = true; end, end
  if isfield(ace,'ib_noslip') && ace.ib_noslip, for f = find(rf > 0), if kbf(f)+3 <= Nzm, omx(kbf(f)+3, f) = true; end, end, end   % IBNOSLIP: second closure node excluded too
  if isfield(ace,'ib_noslip') && ace.ib_noslip, for f = find(rf == 0 & kbf >= 1), if kbf(f)+2 <= Nzm, omx(kbf(f)+2, f) = true; end, end, end   % block-face no-slip closure node (kbf+2)
  ace.rsol = rs; ace.rface = rf; ace.hface_dz = hf_dz; ace.pface = find(rf > 0);
  ace.pcol = find(rs > 0);
  ace.Aface = Aface; ace.vfrac = vfrac; ace.ak = ak; ace.vk = vk; ace.omx_mask = omx;
  % HORIZONTAL ghost for the Phi_uu stencil: masked (wall/rock) faces used by a
  % fluid cell's up3 stencil take the nearest FLUID face value of their own side (zero-gradient
  % extension into the body, the x-analogue of the F_x copy-from-above), instead of the hard 0.
  % Per level, per masked run [f1..f2] (length >= 2 by construction): f1,f1+1 <- u(f1-1);
  % f2-1,f2 <- u(f2+1); a run-of-3 middle face (second neighbour of both sides) <- mean of both.
  % Consumed only when ace.wall_ghost_u == 1 (default OFF => bit-identical to the hard-zero path).
  ghd = []; ghs1 = []; ghs2 = [];
  for k=1:Nzc
    m = fxm(k,:); if ~any(m), continue; end
    if all(m), continue; end
    % rotate so the run structure is contiguous from a fluid face
    st = find(~m, 1); idx = mod((st-1) + (0:Ni-1), Ni) + 1; mr = m(idx);
    d = diff([0, mr, 0]); rs = find(d==1); re = find(d==-1) - 1;
    for q_=1:numel(rs)
      f1 = idx(rs(q_)); f2 = idx(re(q_)); L = re(q_) - rs(q_) + 1;
      fl = idx(mod(rs(q_)-2, Ni)+1); fr = idx(mod(re(q_), Ni)+1);          % fluid faces just outside the run
      lin = @(f) k + (f-1)*Nzc;
      if L == 1
        ghd(end+1) = lin(f1); ghs1(end+1) = lin(fl); ghs2(end+1) = lin(fr);
      elseif L == 2
        ghd(end+1) = lin(f1); ghs1(end+1) = lin(fl); ghs2(end+1) = lin(fl);
        ghd(end+1) = lin(f2); ghs1(end+1) = lin(fr); ghs2(end+1) = lin(fr);
      elseif L == 3
        fm = idx(rs(q_)+1);
        ghd(end+1) = lin(f1); ghs1(end+1) = lin(fl); ghs2(end+1) = lin(fl);
        ghd(end+1) = lin(fm); ghs1(end+1) = lin(fl); ghs2(end+1) = lin(fr);
        ghd(end+1) = lin(f2); ghs1(end+1) = lin(fr); ghs2(end+1) = lin(fr);
      else
        f1b = idx(rs(q_)+1); f2a = idx(re(q_)-1);
        ghd(end+1) = lin(f1);  ghs1(end+1) = lin(fl); ghs2(end+1) = lin(fl);
        ghd(end+1) = lin(f1b); ghs1(end+1) = lin(fl); ghs2(end+1) = lin(fl);
        ghd(end+1) = lin(f2a); ghs1(end+1) = lin(fr); ghs2(end+1) = lin(fr);
        ghd(end+1) = lin(f2);  ghs1(end+1) = lin(fr); ghs2(end+1) = lin(fr);
      end
    end
  end
  ace.ghu_dst_lin = ghd(:); ace.ghu_src1_lin = ghs1(:); ace.ghu_src2_lin = ghs2(:);
  if ~isfield(ace,'wall_ghost_u'), ace.wall_ghost_u = 0; end
  if ~ace.terrain_on
    ace.rock_if_lin = []; ace.solid_c2_lin = []; ace.ghost_dst_lin = []; ace.ghost_src_lin = [];
    ace.k2_rock_lin = []; ace.fxg_dst_lin = []; ace.fxg_src_lin = []; ace.guard_lin = [];
    ace.ghu_dst_lin = []; ace.ghu_src1_lin = []; ace.ghu_src2_lin = [];
    ace.Mface = ones(Nzc,Ni); ace.fx_mask = false(Nzc,Ni); ace.phiw_mask = false(Nzm,Ni);
    ace.Aface = ones(Nzc,Ni); ace.vfrac = ones(Nzc,Ni); ace.ak = ones(Nzc,Ni); ace.vk = ones(Nzc,Ni); ace.omx_mask = false(Nzm,Ni);
    ace.rsol = zeros(1,Ni); ace.rface = zeros(1,Ni); ace.hface_dz = zeros(1,Ni); ace.pface = []; ace.pcol = [];
    W = true(Nzm,Ni); W(1,:) = false; rs = sum(W .* ace.Ai(:).', 2); rs(rs==0) = 1; ace.wfree = W ./ rs;
    ace.gw = [];                                        % flat: plain mean gauge (verbatim)
  end
end

function ace = BUILD_V024_CAP(ace)
  % Mixed-basis capacitance (ONLINE variant): C1 rows = every rock
  % interface (one K1 source per rock cell), C3 rows = wall cells (one K2 vortex sheet each).
  % The response matrix R (Nb x Nzm*Ni) is built TRANSIENTLY from the truncated kernel tables
  % (a unit source's response IS its kernel column scattered over +-NT entities), used for the
  % capacitance C, the field Gram G = R R' (min-norm KKT) and the redundancy analysis, then
  % DISCARDED: online the stamps are recomputed by K1/K2 applies (CAP_STAMP), eta by ETA_OF.
  Ni = ace.Ni; Nzm = ace.Nzm; Nzc = Nzm-1; kbot = ace.kbot;
  cap = struct('Nb',0,'Nc1',0,'Nc3',0);
  if ~ace.terrain_on, ace.cap = cap; return; end
  kb = @(i) kbot( mod(i-1,Ni)+1 );
  tcols = find(kbot>0);
  c1_col = []; c1_j = []; c1_srcell = [];
  for i = tcols
    for k = 1:kbot(i), c1_col(end+1) = i; c1_j(end+1) = k+1; c1_srcell(end+1) = k; end
  end
  c1_col = c1_col(:); c1_j = c1_j(:); c1_srcell = c1_srcell(:); c1_lin = c1_j + (c1_col-1)*Nzm;
  c3_f = []; c3_k = [];
  for f=1:Ni
    lo = min(kb(f),kb(f+1)); hi = max(kb(f),kb(f+1));
    for k=lo+1:hi, c3_f(end+1) = f; c3_k(end+1) = k; end
  end
  c3_f = c3_f(:); c3_k = c3_k(:); c3_lin = c3_k + (c3_f-1)*Nzc;
  Nc1 = numel(c1_lin); Nc3 = numel(c3_lin); Nb = Nc1 + Nc3;
  assert(all(ace.lay_of_cell(c1_srcell) <= sum(diff(ace.edges)==100)), 'rock cells must lie in the 100-m forcing layers (crest + 400 m <= z_split)');
  region_id = zeros(1,Ni); rid = 0;
  for i=1:Ni
    if kbot(i)>0
      if i>1 && kbot(i-1)>0, region_id(i) = region_id(i-1); else, rid = rid+1; region_id(i) = rid; end
    end
  end
  if Ni>1 && kbot(1)>0 && kbot(Ni)>0 && region_id(1)~=region_id(Ni), region_id(region_id==region_id(Ni)) = region_id(1); end
  nreg = numel(unique(region_id(region_id>0)));
  % source descriptors (for the online stamps)
  src_col = [c1_col; c3_f]; src_lay = [ace.lay_of_cell(c1_srcell); ace.lay_of_cell(c3_k)];
  if isfield(ace,'topo_solver') && any(strcmp(ace.topo_solver,{'psi','cap'}))
    % PSI/CAP mode: only the C1 (rock K1 source) sub-system is needed (tendency-level rock correction) (tendency-level rock correction);
    % walls are handled by the elliptic solve. c3 lists kept for diagnostics.
    % a FULLY blocked level (every column has a rock interface at row j -- the buffer's ground row) carries one
    % redundant constraint (kernel c-rule: every response AND the free tendency are level-sum-free): drop ONE
    % (constraint, source) pair per such level (column Ni); the dropped MF = 0 then holds by the zero level sum and is
    % checked by the rock|MF| diagnostics over c1_lin_all (round-off only).
    c1_lin_all = c1_lin; keep1 = true(Nc1,1);
    for j = unique(c1_j(:)).'
      if sum(c1_j == j) == Ni, keep1(find(c1_j == j & c1_col == Ni, 1)) = false; end
    end
    ndrop1 = nnz(~keep1);
    c1_lin = c1_lin(keep1); c1_col = c1_col(keep1); c1_j = c1_j(keep1); c1_srcell = c1_srcell(keep1); Nc1 = numel(c1_lin);
    src_col = [c1_col; c3_f]; src_lay = [ace.lay_of_cell(c1_srcell); ace.lay_of_cell(c3_k)];
    C11 = zeros(Nc1, Nc1); Rs = zeros(Nzm, Ni);
    for a_=1:Nc1
      Rs(:) = 0; lay = src_lay(a_); c = src_col(a_);
      cols = mod((c-1) + (ace.w1_di-1), Ni) + 1; Rs(:, cols) = squeeze(ace.PMBt(:,:,lay)).';
      C11(:,a_) = Rs(c1_lin);
    end
    cs1 = max(abs(C11),[],1); cs1(cs1==0) = 1; C11s = C11 ./ cs1;
    cond11 = cond(C11s); assert(cond11 < 1e12, 'C11 ill-conditioned');
    [L11, U11, p11] = lu(C11s, 'vector');
    cap.Nb = Nc1; cap.Nc1 = Nc1; cap.Nc3 = 0; cap.c1_lin = c1_lin(:); cap.c1_col = c1_col(:);
    cap.c1_lin_all = c1_lin_all(:); cap.ndrop1 = ndrop1;                 % all rock interfaces (diagnostics) / dropped redundant pairs
    cap.c3_lin = c3_lin(:); cap.c3_f = c3_f(:); cap.c3_k = c3_k(:); cap.Nc3diag = Nc3;
    cap.src_col = src_col(1:Nc1); cap.src_lay = src_lay(1:Nc1);
    cap.scat1 = mod((c1_col(:)-1) + (ace.w1_di(:).'-1), Ni) + 1;
    cap.cs1 = cs1(:).'; cap.L11 = L11; cap.U11 = U11; cap.p11 = p11(:); cap.cond11 = cond11;
    % FAST: rock-source stamp as ONE layer-restricted tap-loop K1 apply (source field scattered on (column, layer))
    cap.lays1 = unique(src_lay(1:Nc1)); cap.nl1 = numel(cap.lays1); [~, li_] = ismember(src_lay(1:Nc1), cap.lays1);
    cap.src_sub1 = sub2ind([Ni, cap.nl1], c1_col(:), li_(:)); assert(numel(unique(cap.src_sub1)) == Nc1, 'c1 sources must be unique per (column, layer)');
    cap.Nb = Nc1; cap.Nc1 = Nc1; cap.Nc3 = 0; cap.src_lay = src_lay(1:Nc1);
    rs_ = rng; rng(4); qg = randn(Nc1,1); rng(rs_); ace_ = ace; ace_.cap = cap; cap.fast1 = false; ace_.cap.fast1 = false;
    dL = CAP_STAMP(qg, ace_, 'c1'); ace_.cap.fast1 = true; dF = CAP_STAMP(qg, ace_, 'c1');
    cap.fast1 = true; cap.fast1_gate = max(abs(dF(:) - dL(:))) / max(abs(dL(:)));
    assert(cap.fast1_gate < 1e-12, sprintf('CAP_STAMP FAST insurance failed: %.2e', cap.fast1_gate));
    fprintf('BUILD_V024_CAP FAST: c1 stamp = K1 apply on %d layers ; vs scatter loop %.2e\n', cap.nl1, cap.fast1_gate);
    cap.solver = 'psi'; cap.wall_basis = 'none'; cap.rk = Nc1; cap.nnull = 0; cap.condC = cond11; cap.condC_raw = cond11; cap.condSm = NaN; cap.nreg = nreg;
    ace.cap = cap;
    fprintf('BUILD_V024_CAP (psi mode): C1-only, Nc1=%d rock sources (%d redundant pairs of fully blocked levels dropped), cond(C11)=%.3e ; walls (%d cells) -> elliptic solve\n', Nc1, ndrop1, cond11, Nc3);
    return;
  end
end

function cl = C1ALL_OF(cap)
  % all rock interfaces incl. the dropped redundant ones (diagnostics); falls back to the solved list.
  cl = cap.c1_lin; if isfield(cap,'c1_lin_all'), cl = cap.c1_lin_all; end
end

function [dMF, deta] = CAP_STAMP(q, ace, which)
  % ONLINE application of the constraint sources: dMF = sum_s q_s * (kernel column of
  % source s scattered over its +-NT entities) -- identical to q'*R and to K1/K2 applies of the
  % source field, at ~Nb*ntaps*Nzm flops (no GEMM). eta increment by ETA_OF(dMF).
  % which = 'c1' uses the K1 rock sources only (tendency-level correction), 'all' both.
  cap = ace.cap; Ni = ace.Ni; Nzm = ace.Nzm;
  if isfield(cap,'fast1') && cap.fast1
    S = zeros(Ni, cap.nl1); S(cap.src_sub1) = q(1:cap.Nc1);              % FAST: layer-restricted tap-loop K1 apply
    dMF = K1_APPLY_LAYERS_SUB(S, ace, cap.lays1);
  else
    dMF = zeros(Nzm, Ni);
    for a_ = 1:cap.Nc1
      if q(a_) ~= 0
        cols = cap.scat1(a_,:);
        dMF(:, cols) = dMF(:, cols) + q(a_) * squeeze(ace.PMBt(:,:,cap.src_lay(a_))).';
      end
    end
  end
  if strcmp(which,'all') && cap.Nc3 > 0
    for b_ = 1:cap.Nc3
      qb = q(cap.Nc1+b_);
      if qb ~= 0
        cols = cap.scat2(b_,:);
        dMF(:, cols) = dMF(:, cols) - qb * squeeze(ace.K2t(:,:,cap.src_lay(cap.Nc1+b_))).';
      end
    end
  end
  if nargout > 1, deta = ETA_OF(dMF, ace); end
end

function MW_G13(aceMW, X0mw, Nzm, Ni)
  % G13: vorticity-flux (Lamb) vs flux form on a FLAT smooth field. Pointwise (kernel-free) checks first:
  %   F_x^flux == F_x^L - rho0 dx(K)  and  F_z^flux == F_z^L - rho0 dz(K)  (to truncation);
  % then the K1/K2-mapped tendencies (whose difference = how the truncated kernels treat the
  % gradient term, which has zero Boussinesq curl analytically).
  aceFl = TERRAIN_MASKS(aceMW, zeros(1,Ni), false); aceFl = BUILD_V024_CAP(aceFl); aceFl.ubar_tau = 0; aceFl.t = 0;
  dz = aceFl.dz; dx = aceFl.dx; Nzc = Nzm-1; rho_zc = aceFl.rho_zc(1:end-1);
  Xs = X0mw; kz = (1:Nzm)'; xi = (1:Ni);
  MFs = 0.5*(aceFl.rho_zi(:)/aceFl.rho_zi(1)) .* sin(pi*(kz-1)/(Nzm-1)*3) .* cos(2*pi*(xi-0.5)/Ni*2);   % smooth mode, w ~ 0.4 m/s at ALL heights (rho0-scaled), zero level sums
  MFs(1,:) = 0; MFs(end-aceFl.ndead+1:end,:) = 0;
  Xs(:,3,:) = reshape(MFs,[Nzm,1,Ni]);
  es = ETA_IC_DIAGNOSE(Xs, aceFl); Xs(:,6,:) = permute(es,[1,3,2]); Xs(1,6,:) = 0; Xs(Nzm,6,:) = 0; Xs(:,7,:) = 0;
  [dTHs,dQts,rho0Bs,aceFl] = microrad(Xs(:,1:2,:),aceFl.p_zc,aceFl.rho_zc,aceFl.Tv_zc,aceFl.theta_e_diag,aceFl);
  for ub = [0 15]
    aF = aceFl; aF.lamb = 0; aF.ubar_zc = ub*ones(size(aF.ubar_zc)); aF.ubar_on = ub~=0;
    aL = aF; aL.lamb = 1;
    aF.diag.k2 = struct('on',1); aF.diag.expf = struct('on',1); [dF, k2F, aF] = expFun_split(Xs,dTHs,dQts,rho0Bs,aF); DF = aF.diag.expf; KF = aF.diag.k2;
    aL.diag.lamb = struct('on',1); aL.diag.expf = struct('on',1); [dL, k2L, aL] = expFun_split(Xs,dTHs,dQts,rho0Bs,aL); DL = aL.diag.expf; LL = aL.diag.lamb;
    % gradient term at cells / faces from the flux-form u_tot (same u for both forms)
    rho0u_tot = KF.rho0u_tot; u_face = rho0u_tot ./ rho_zc; u_c = 0.5*(u_face + circshift(u_face,1,2));
    wiF = squeeze(Xs(:,3,:)) ./ aceFl.rho_zi(:); w_c = 0.5*(wiF(1:Nzc,:) + wiF(2:Nzm,:));
    Kc = 0.5*(u_c.^2 + w_c.^2);
    gradKx = ( circshift(Kc,-1,2) - Kc )/dx;                                    % faces, zc rows
    Kzm = 0.5*(Kc(1:Nzc-1,:) + Kc(2:Nzc,:)); gradKz = zeros(Nzc,Ni); gradKz(2:Nzc-1,:) = (Kzm(2:end,:) - Kzm(1:end-1,:))/dz;   % cells, dz(K) (interior rows)
    in = 3:find(aceFl.zm >= 25e3,1);                                            % interior rows: above the ground rows, below 25 km (sane rho0)
    FxF = KF.Fx; FxL = LL.FxL; FzF = DF.F - DF.FH_eps; FzL = LL.FzL;
    scx = max([max(abs(FxF(in,:)),[],'all'), max(abs(FxL(in,:)),[],'all'), max(abs(rho_zc(in).*gradKx(in,:)),[],'all')]);
    scz = max([max(abs(FzF(in,:)),[],'all'), max(abs(FzL(in,:)),[],'all'), max(abs(rho_zc(in).*gradKz(in,:)),[],'all')]);
    ex = max(abs(FxF(in,:) - (FxL(in,:) - rho_zc(in).*gradKx(in,:))),[],'all') / scx;
    ez = max(abs(FzF(in,:) - (FzL(in,:) - rho_zc(in).*gradKz(in,:))),[],'all') / scz;
    exL = max(abs(FxF(in,:) - FxL(in,:)),[],'all') / max(abs(FxF(in,:)),[],'all');   % how big the gradient part is
    g13 = max(abs(dL(:,3,:)-dF(:,3,:)),[],'all') / max(abs(dF(:,3,:)),[],'all');
    g13k2 = max(abs(k2L(:)-k2F(:))) / max(abs(k2F(:)));
    g13k1 = max(abs(DL.dMF_K1(:)-DF.dMF_K1(:))) / max(abs(DF.dMF_K1(:)));
    fprintf('GATE G13 Lamb vs flux (flat smooth mode, ubar=%g): POINTWISE (z<25 km, / largest term) Fx: |Fx_flux-(FxL-rho dxK)|=%.3e (gradient share %.3e) ; Fz: %.3e | MAPPED (informational: truncated-kernel treatment of the gradient term): rel|dMF diff|=%.3e (K1 part %.3e, K2 part %.3e)\n', ub, ex, exL, ez, g13, g13k1, g13k2);
    [~,iu] = max(abs(u_face(:))); [ru,cu] = ind2sub(size(u_face),iu);
    Adz = aceFl.Ai' .* (MFs(2:end,:) - MFs(1:end-1,:))/dz; iof = GAUGE_IO(cumsum(Adz,2), aceFl);
    fprintf('  G13 field: max|MFs|=%.3e max|dzMF*Ai|=%.3e max|ioflow|=%.3e (row %d) ; max|u_face|=%.3e at row %d col %d ; |u_face| rows 3,50,100,150,190,194 = %s ; max|rho0u_used|=%.3e\n', ...
            max(abs(MFs(:))), max(abs(Adz(:))), max(abs(iof(:))), find(max(abs(iof),[],2)==max(abs(iof(:))),1), max(abs(u_face(:))), ru, cu, mat2str(max(abs(u_face([3 50 100 150 190 194],:)),[],2).',3), max(abs(DF.rho0u_used(:))));
    [~,imz] = max(abs(FzL(in,:)),[],'all','linear'); [rz,cz] = ind2sub(size(FzL(in,:)),imz);
    [~,imx] = max(abs(FxF(in,:)),[],'all','linear'); [rx,cx] = ind2sub(size(FxF(in,:)),imx);
    band = 10:150;
    fprintf('  G13 where: max|FzL| at interior row %d col %d ; max|Fx_flux| at row %d col %d ; max|u_face(in)|=%.3e max|om(in)|=%.3e ; band rows 10-150: |FxF|=%.3e |FxL|=%.3e |FzF|=%.3e |FzL|=%.3e |rho dzK|=%.3e\n', ...
            in(rz), cz, in(rx), cx, max(abs(u_face(in,:)),[],'all'), max(abs(LL.om(in,:)),[],'all'), max(abs(FxF(band,:)),[],'all'), max(abs(FxL(band,:)),[],'all'), max(abs(FzF(band,:)),[],'all'), max(abs(FzL(band,:)),[],'all'), max(abs(rho_zc(band).*gradKz(band,:)),[],'all'));
    fprintf('  G13 scales: max|Fx_flux|=%.3e max|FxL|=%.3e max|S|=%.3e ; max|Fz_flux|=%.3e max|FzL|=%.3e ; max|dMF_flux|=%.3e max|dMF_lamb|=%.3e\n', max(abs(FxF(in,:)),[],'all'), max(abs(FxL(in,:)),[],'all'), max(abs(LL.S(:))), max(abs(FzF(in,:)),[],'all'), max(abs(FzL(in,:)),[],'all'), max(abs(dF(:,3,:)),[],'all'), max(abs(dL(:,3,:)),[],'all'));
    fprintf('  G13 (upwind vorticity-flux form): pointwise F_x/F_z check not applicable; invariants on this state: sum psi.J = %.3e (rel to sum|psi.J| %.3e) ; sum omega.J = %.3e\n', ...
            -sum(sum(LL.PSI .* LL.etadot)), abs(sum(sum(LL.PSI .* LL.etadot)))/max(sum(sum(abs(LL.PSI .* LL.etadot))),1e-300), sum(sum(LL.om .* LL.etadot)));
  end
end

function [kbot, h] = KBOT_BELL(Ni, dx, dz, H, a, xc_face)
  % Witch-of-Agnesi bell h(x) = H / (1 + ((x-xc)/a)^2), centre at FACE xc_face (x = xc_face*dx,
  % between columns xc_face and xc_face+1 => Pm-symmetric for even Ni), quantized to whole cells
  % by INT (floor; WA11 convention). Returns kbot (1 x Ni) in cells.
  xi = ((1:Ni) - 0.5) * dx; xc = xc_face * dx;
  h = H ./ (1 + ((xi - xc)/a).^2);
  kbot = floor(h/dz + 1e-9);
end

function [kbot, rsol] = PARTIAL_SPLIT(h, kbot, dz, vmin, smin)
  % partial step: cell kbot(i)+1 is the PARTIAL cell of column i, rsol(i) = its SOLID fraction
  % h/dz - kbot in [0,1). Two-sided threshold (Chien-Wu style, no merging): fluid fraction 1 - rsol < vmin
  % => the cell counts as solid (kbot+1, rsol = 0); solid fraction rsol < smin => flat (rsol = 0; the bell's
  % tail is a few metres high over most of the domain). rsol == 0 everywhere is exactly the block geometry.
  if nargin < 5, smin = 1e-9; end
  rsol = h/dz - kbot; rsol(rsol < max(smin,1e-9)) = 0;
  full = (1 - rsol) < vmin; kbot(full) = kbot(full) + 1; rsol(full) = 0;
end

function snd = IDEAL_SOUNDING(z, zm, mw)
  % Idealized DRY two-layer sounding: N^2(z) = N1^2 + (N2^2-N1^2)*(1+tanh((z-ztr)/wtr))/2,
  % theta(z) = Ts*exp(int N^2/g dz) (theta_s = T_s requires p_s = 1000 hPa), Exner
  % pi(z) = 1 - int g/(cp*theta) dz (exact hydrostatic), T = theta*pi, p = ps*pi^(cp/R).
  % Integrated on a 1-m grid, interpolated to z (cell centres) and zm (interfaces). Trace qv0.
  IMPORT_CONSTANTS_NOGLOBAL                          % g, RD, CPD (authoritative; no hard-coding)
  assert(abs(mw.ps - 1e5) < 1e-6, 'IDEAL_SOUNDING assumes p_s = 1000 hPa so that theta_s = T_s');
  zf = (floor(min([z;zm;0])):1:ceil(max([z;zm])))';    % extends BELOW z = 0 for the rock buffer rows
  i0 = find(zf == 0, 1);
  N2z = mw.N1^2 + (mw.N2^2 - mw.N1^2) * 0.5*(1 + tanh((zf - mw.ztr)/mw.wtr));
  I1 = cumtrapz(zf, N2z/g); theta_f = mw.Ts * exp(I1 - I1(i0));               % theta(0) = Ts
  I2 = cumtrapz(zf, g./(CPD*theta_f)); pi_f = 1 - (I2 - I2(i0));               % pi(0) = 1 (p_s = 1000 hPa)
  assert(min(pi_f) > 0.01, 'IDEAL_SOUNDING: Exner function collapses before the model top');
  T_f = theta_f .* pi_f; p_f = mw.ps * pi_f.^(CPD/RD);
  snd.T_zc = interp1(zf, T_f, z); snd.p_zc = interp1(zf, p_f, z); snd.theta_zc = interp1(zf, theta_f, z); snd.N2_zc = interp1(zf, N2z, z);
  snd.T_zm = interp1(zf, T_f, zm); snd.p_zm = interp1(zf, p_f, zm); snd.theta_zm = interp1(zf, theta_f, zm); snd.N2_zm = interp1(zf, N2z, zm);
  % trace vapour capped at 5% of (liquid) saturation so the cold tropopause (T ~ 180 K, qsat ~ 4e-7)
  % is never supersaturated (a uniform 1e-5 was: spurious ice + precip-sink drift of theta_e).
  snd.q_zc = min(mw.qv0, 0.05*eval_qsat2(snd.T_zc, snd.p_zc)); snd.q_zm = min(mw.qv0, 0.05*eval_qsat2(snd.T_zm, snd.p_zm));
  snd.Tv_zc = eval_Tv(snd.T_zc, snd.q_zc, 0); snd.Tv_zm = eval_Tv(snd.T_zm, snd.q_zm, 0);
  snd.rho_zc = snd.p_zc ./ snd.Tv_zc / RD; snd.rho_zm = snd.p_zm ./ snd.Tv_zm / RD;
  snd.theta_e_zc = eval_theta_e(snd.T_zc, snd.q_zc, 0, 0, snd.p_zc);
  snd.theta_e_zm = eval_theta_e(snd.T_zm, snd.q_zm, 0, 0, snd.p_zm);
  snd.mw = mw;
end

function [aceMW, X0, snd] = SETUP_MW(ace, mw, H, z, zm, dz, dt, eps_sl)
  % Case assembly: idealized sounding on both grids (sponge damp recomputed), UNIFORM ubar
  % with the C1 time ramp (starts from 0 => compatible IC: walls have u_tot = 0 at t = 0),
  % bell kbot (height H), terrain masks + mixed-basis capacitance, base-state IC at rest.
  Ni = ace.Ni; Nzm = ace.Nzm;
  if isfield(mw,'snd') && strcmp(mw.snd,'arm'), snd = mw.arm; snd.mw = mw; else, snd = IDEAL_SOUNDING(z, zm, mw); end   % case preset SND
  aceMW = ace;
  aceMW.turn_on_K2 = 1;
  aceMW.p_zc = snd.p_zc; aceMW.rho_zc = snd.rho_zc; aceMW.Tv_zc = snd.Tv_zc; aceMW.rho_zi = snd.rho_zm;
  aceMW.theta_e_zc = snd.theta_e_zc; aceMW.qt_zc = snd.q_zc;
  aceMW.damp = dt*(eps_sl./[snd.rho_zc, snd.rho_zc, snd.rho_zm]);
  aceMW.ubar_on = 1;
  if isfield(mw,'ubar') && strcmp(mw.ubar,'profile')                % case preset UBAR='profile': C1 shear
    aceMW.ubar_zc = UBAR_PROFILE(z, mw.U0, mw.z_ramp, mw.zd0, mw.zd1); aceMW.ubar_zm = UBAR_PROFILE(zm, mw.U0, mw.z_ramp, mw.zd0, mw.zd1);
  else
    aceMW.ubar_zc = mw.U0*ones(size(z)); aceMW.ubar_zm = mw.U0*ones(size(zm));
  end
  aceMW.ubar_zc(1:ace.nbuf) = 0; aceMW.ubar_zm(1:ace.nbuf) = 0;    % no base flow inside the rock buffer (PsiBar(ground) = 0)
  aceMW.ubar_tau = mw.tau; aceMW.t = 0; aceMW.gauge = mw.gauge;
  if isfield(mw,'wall_ghost_u'), aceMW.wall_ghost_u = mw.wall_ghost_u; end   % before TERRAIN_MASKS (default 0)
  if isfield(mw,'h_override') && ~isempty(mw.h_override)
    hcol = mw.h_override(:).'; kb = floor(hcol/dz + 1e-9); rs = zeros(1,Ni);   % continuous h given directly (CW16 EXP2 slope test)
    if isfield(mw,'partial') && mw.partial, [kb, rs] = PARTIAL_SPLIT(hcol, kb, dz, mw.vmin, mw.smin); end
  elseif isfield(mw,'kbot_override') && ~isempty(mw.kbot_override)
    kb = mw.kbot_override; hcol = kb*dz; rs = zeros(1,Ni);   % diagnostic geometries (e.g. single step / plateau): block
  else
    [kb, hcol] = KBOT_BELL(Ni, ace.dx, dz, H, mw.a, mw.xc_face); rs = zeros(1,Ni);
    if isfield(mw,'partial') && mw.partial, [kb, rs] = PARTIAL_SPLIT(hcol, kb, dz, mw.vmin, mw.smin); end
  end
  kb = kb + ace.nbuf;                                                    % EVERYWHERE IB: every column has >= nbuf rock rows (buffer); hcol stays PHYSICAL
  if isfield(mw,'ib_slope') && mw.ib_slope && isfield(mw,'ib') && mw.ib                % IBSLOPE: surface point of face f at the terrain height h(x_f)
    xf = (1:Ni)*ace.dx;
    if isfield(mw,'h_fun') && ~isempty(mw.h_fun), aceMW.hface = mw.h_fun(xf);
    elseif (isfield(mw,'h_override') && ~isempty(mw.h_override)) || (isfield(mw,'kbot_override') && ~isempty(mw.kbot_override))
      aceMW.hface = 0.5*(hcol + hcol([2:Ni 1]));                                  % tabulated terrain: mean of the two neighbouring column heights
    else, aceMW.hface = H ./ (1 + ((xf - mw.xc_face*ace.dx)/mw.a).^2); end
    aceMW.hface_vmin = mw.vmin; aceMW.hface_smin = mw.smin;
  end
  aceMW.ib_noslip = double(isfield(mw,'ib_noslip') && mw.ib_noslip && isfield(mw,'ib') && mw.ib);
  aceMW.visc_nu = 0; if isfield(mw,'visc_nu'), aceMW.visc_nu = mw.visc_nu; end
  aceMW.visc_wall = 1; if isfield(mw,'visc_wall'), aceMW.visc_wall = mw.visc_wall; end
  aceMW.mean_u = 0; if isfield(mw,'mean_u'), aceMW.mean_u = mw.mean_u; end
  aceMW.sgs_ml = 0; if isfield(mw,'sgs_ml'), aceMW.sgs_ml = mw.sgs_ml; end
  aceMW.ll_z0 = 0.1; if isfield(mw,'ll_z0'), aceMW.ll_z0 = mw.ll_z0; end
  aceMW.ll_zn = 3000; if isfield(mw,'ll_zn'), aceMW.ll_zn = mw.ll_zn; end
  aceMW.ll_taun = 600; if isfield(mw,'ll_taun'), aceMW.ll_taun = mw.ll_taun; end
  aceMW.ll_nudge = 0; if isfield(mw,'ll_nudge'), aceMW.ll_nudge = mw.ll_nudge; end
  aceMW.mean_u_sponge = 1; if isfield(mw,'mean_u_sponge'), aceMW.mean_u_sponge = mw.mean_u_sponge; end
  aceMW.rsol = rs; aceMW.hcol = hcol;   % partial-cell solid fractions / continuous h (m); read by TERRAIN_MASKS
  aceMW.topo_solver = 'cap'; if isfield(mw,'topo_solver'), aceMW.topo_solver = mw.topo_solver; end   % 'cap' = production ; 'psi' = the gate twin
  aceMW = TERRAIN_MASKS(aceMW, kb, true);
  % MEANU geometry: per column the signed height span of the surface segment [h_L, h_R] inside each level (physical heights;
  % state cell row = physical cell + nbuf) -> sparse weights wseg (Nzc x Ni); the first fluid cell per column (linear index)
  hL_ = 0.5*(hcol + circshift(hcol, 1)); hR_ = 0.5*(hcol + circshift(hcol, -1)); Nzc_ = Nzm - 1; wi_ = []; wj_ = []; wv_ = [];
  for i = 1:Ni
    lo_ = min(hL_(i), hR_(i)); hi_ = max(hL_(i), hR_(i)); sg_ = sign(hR_(i) - hL_(i)); if hi_ - lo_ < 1e-9, continue; end
    for k = floor(lo_/dz):min(floor(hi_/dz), Nzc_ - ace.nbuf - 1)
      seg_ = max(0, min(hi_, (k+1)*dz) - max(lo_, k*dz));
      if seg_ > 0, wi_(end+1) = k + 1 + ace.nbuf; wj_(end+1) = i; wv_(end+1) = sg_*seg_; end %#ok<AGROW>
    end
  end
  aceMW.wseg = sparse(wi_, wj_, wv_, Nzc_, Ni); aceMW.kfirst_lin = (kb(:).' + 1) + ((1:Ni) - 1)*Nzc_;
  if any(rs > 0)
    dh = hcol - circshift(hcol,1);
    heff = (kb - ace.nbuf + rs)*dz;
    fprintf('PARTIAL STEP: %d partial columns (min fluid fraction %.2f, vmin %.2f, smin %.2f), %d partial faces ; max effective riser %.0f m (block: %g m) ; max |dh| per column %.1f m ; crest h_eff %.0f m (h %.0f m)\n', ...
            nnz(rs>0), min(1-rs(rs>0)), mw.vmin, mw.smin, numel(aceMW.pface), max(abs(diff([heff heff(1)]))), dz, max(abs(dh)), max(heff), max(hcol));
  end
  aceMW = BUILD_V024_CAP(aceMW);
  if strcmp(aceMW.topo_solver,'psi')
    aceMW = BUILD_PSI(aceMW);                       % u' from continuity with the psi gauge; eta is a diagnostic
    aceMW.cref_io = zeros(aceMW.Nzm-1,1);
  elseif strcmp(aceMW.topo_solver,'cap')
    aceMW = BUILD_SOFT(aceMW);                      % body nodes, masks, body-mean gauge, FFT constants
    aceMW.cap_mode = 'taper'; if isfield(mw,'cap_mode'), aceMW.cap_mode = mw.cap_mode; end
    aceMW.cref_io = zeros(aceMW.Nzm-1,1);
    aceMW = BUILD_CAPB(aceMW);
  end
  X0 = repmat(reshape([snd.theta_e_zc, snd.q_zc, zeros(Nzm,5)], [Nzm,7,1]), [1,1,Ni]);
  if isfield(mw,'ic') && strcmp(mw.ic,'coldblock')
    % case preset IC='coldblock': saturated cold block with an ABSOLUTE condensate ic_dqc on columns ic_cols,
    % physical cell rows ic_BL (state rows + nbuf); thermodynamics from the zm-grid sounding rows.
    T0_ = 273.15; BLc = mw.ic_BL(:) + ace.nbuf; Tb = snd.T_zm(BLc) + mw.ic_dT;
    qsat3 = eval_qsat2(Tb, snd.p_zm(BLc)); qbc = qsat3 + mw.ic_dqc;
    tbc = eval_theta_e(Tb, qsat3, mw.ic_dqc*(Tb >= T0_), mw.ic_dqc*(Tb < T0_), snd.p_zm(BLc));
    for bc = mw.ic_cols, X0(BLc,2,bc) = qbc; X0(BLc,1,bc) = tbc; end
    fprintf('IC coldblock: cols %d:%d, physical cell rows %d:%d, dT=%g K, condensate %g g/kg\n', mw.ic_cols(1), mw.ic_cols(end), mw.ic_BL(1), mw.ic_BL(end), mw.ic_dT, 1e3*mw.ic_dqc);
  end
end

function MW_GATES(ace, aceMW, X0mw, mw, z, zm, dz, dt, eps_sl) %#ok<INUSD>
  % Gate battery: G9 flat+ubar(t) rest (exact), G10 wall u_tot identity with the ramped
  % ubar (+rock, closure, fluid gauge, two-rep), G11 ubar-reversed mirror twin, G12 gauge
  % reachability (fluid vs all differ with ubar) and coincidence (ubar=0, to the two-rep floor).
  Ni = ace.Ni; Nzm = ace.Nzm; s = ace.Ai(1)/ace.dx;
  fprintf('=== V024 T2b MOUNTAIN-WAVE GATES ===\n');
  MW_G13(aceMW, X0mw, Nzm, Ni);
  % --- G9: x-uniform ramped flow over FLAT ground from rest must stay exactly at rest
  aceF = aceMW; aceF.ubar_tau = 60;
  aceF = TERRAIN_MASKS(aceF, zeros(1,Ni), false); aceF = BUILD_V024_CAP(aceF);
  aceF.inv.reset = 1; y = X0mw; for st=1:20, aceF.t = (st-1)*dt; [y, aceF] = MARCH1(y, aceF); end
  g9 = max([max(abs(y(:,3,:)),[],'all'), max(abs(y(:,6,:)),[],'all'), max(abs(y(1,7,:)),[],'all')]);
  % breakdown (diagnostic): which slot carries the dust, its x-non-uniform part, the base-state
  % inversion residual rho0B (x-uniform => killed by K1 level sums + WBAR), one raw tendency.
  MF9 = squeeze(y(:,3,:)); [dTH9,dQt9,rho0B9,aceF] = microrad(X0mw(:,1:2,:),aceF.p_zc,aceF.rho_zc,aceF.Tv_zc,aceF.theta_e_diag,aceF);
  aceF.t = 0; [d9, aceF] = expFun(X0mw,dTH9,dQt9,rho0B9,aceF);
  fprintf('  G9 breakdown: max|MF|=%.2e (x-nonuniform %.2e) max|eta|=%.2e max|U_p|=%.2e max|theta_e-base|=%.2e ; base rho0B max=%.2e (x-nonuniform %.2e) ; raw dMF(X0) max=%.2e\n', ...
          max(abs(MF9(:))), max(abs(MF9 - mean(MF9,2)),[],'all'), max(abs(y(:,6,:)),[],'all'), max(abs(y(1,7,:)),[],'all'), max(abs(y(:,1,:)-X0mw(:,1,:)),[],'all'), ...
          max(abs(rho0B9(:))), max(abs(rho0B9 - mean(rho0B9,2)),[],'all'), max(abs(d9(:,3,:)),[],'all'));
  % The absolute rest level is set by the base-state inversion round-trip residual (rho0B ~ 2e-4,
  % x-uniform) times the K1 level-sum floor, accumulated over the steps -- NOT by ubar. The gate
  % proper is therefore the TWIN: the same flat march with ubar OFF must agree to the dust level.
  aceF0 = aceF; aceF0.ubar_on = 0;
  aceF0.inv.reset = 1; y0 = X0mw; for st=1:20, aceF0.t = (st-1)*dt; [y0, aceF0] = MARCH1(y0, aceF0); end
  g9t = max(abs(y - y0),[],'all');
  % (the twin is not exact either: ubar acts on the MF dust through Phi_uw = rho*ubar*w -- a
  %  legitimate term -- so it differs at O(ubar x dust x growth) ~ 1e-13; signal is O(1).)
  fprintf('GATE G9 flat + ubar(t) from rest (20 steps, tau=60 s): absolute max|MF,eta,U_p|=%.2e (dust; <= 1e-15) ; ubar-ON vs ubar-OFF twin max|diff|=%.2e (<= 1e-11)\n', g9, g9t);
  assert(g9 <= 1e-15 && g9t <= 1e-11, 'G9: uniform flow over flat ground is not quiet / ubar terms do not cancel');
  % --- G10: wall u_tot identity etc. with ubar ramped to U0 (tau=60 s, 30 steps = 180 s)
  aceQ = aceMW; aceQ.ubar_tau = 60;
  aceQ.rec.topo = struct('n',0,'maxr',0,'maxq',0,'maxdE',0,'sumdE',0,'tworep',0);
  aceQ.inv.reset = 1; y = X0mw; for st=1:30, aceQ.t = (st-1)*dt; [y, aceQ] = MARCH1(y, aceQ); end
  aceQ.t = 30*dt; ubc = UBAR_NOW(aceQ); aceQ = PSI_CREF(aceQ, y);
  MF = squeeze(y(:,3,:)); io = IOFLOW_OF(MF, aceQ);
  b = aceQ.rho_zc(aceQ.cap.c3_k).*ubc(aceQ.cap.c3_k)*s;
  wall = abs(io(aceQ.cap.c3_lin) - b); wall_enf = wall; unenf = 0; if isfield(aceQ.cap,'repl'), wall_enf(aceQ.cap.repl - aceQ.cap.Nc1) = 0; unenf = max(wall(aceQ.cap.repl - aceQ.cap.Nc1)); end
  usc = max(abs(io(:))); MFsc = max(abs(MF(:)));
  c1m = max(abs(MF(aceQ.cap.c1_lin))); rkm = max([abs(MF(aceQ.rock_if_lin));0]);
  clo = max(abs(sum(aceQ.Ai' .* ((MF(2:end,:)-MF(1:end-1,:))/dz), 2)));
  gfl = max(abs(sum(io.*aceQ.gw, 2)));
  fprintf('GATE G10 wall u_tot identity (30 steps, ubar=U0): max|io-b| enforced=%.3e (rel %.3e) unenforced=%.3e ; top|MF|=%.3e rock|MF|=%.3e (max|MF|=%.3e, max|io|=%.3e) ; G8 closure=%.3e ; fluid-gauge=%.3e ; two-rep=%.3e ; TOPO_REC max|q|=%.3e max|dE|=%.3e\n', ...
          max(wall_enf), max(wall_enf)/(usc+eps), unenf, c1m, rkm, MFsc, usc, clo, gfl, aceQ.rec.topo.tworep, aceQ.rec.topo.maxq, aceQ.rec.topo.maxdE);
  assert(max(wall_enf)/(usc+eps) <= 1e-10 && c1m/(MFsc+eps) <= 1e-10 && rkm/(MFsc+eps) <= 1e-10, 'G10: wall/rock identity broken');
  assert(clo <= 1e-12*max(MFsc,1), 'G8(mw): periodic closure broken');
  if ~any(strcmp(aceQ.topo_solver,{'psi','cap'})), assert(gfl <= 1e-12*max(usc,1), 'G10: fluid gauge not satisfied'); end
  % two-rep floor: KKT cond(Sm) ~ 1e7 x eps per stage solve, stressed here by the violent tau=60 s
  % ramp (max|q| ~ 60 vs ~3 under the production ramp tau = 4a/U, which is ~90x gentler).
  fprintf('  G10 scales: max|eta|=%.3e ; two-rep/max|eta|=%.3e\n', max(abs(y(:,6,:)),[],'all'), aceQ.rec.topo.tworep/max(abs(y(:,6,:)),[],'all'));
  if ~any(strcmp(aceQ.topo_solver,{'psi','cap'})), assert(aceQ.rec.topo.tworep <= 2e-8*max(1,max(abs(y(:,6,:)),[],'all')), 'two-representation identity broken (mw)'); end   % psi/soft: eta slot is diagnostic
  % --- G11: ubar-reversed mirror twin (Pm-symmetric bell): MF/tracers even, eta/U_p odd
  aceP = aceMW; aceP.ubar_tau = 60; aceM = aceP; aceM.ubar_zc = -aceP.ubar_zc; aceM.ubar_zm = -aceP.ubar_zm;
  Pm = (Ni+1) - (1:Ni); Pf = mod(Ni-(1:Ni)-1,Ni)+1;
  assert(isequal(aceP.kbot, aceP.kbot(Pm)), 'G11: bell kbot is not Pm-symmetric');
  assert(max(abs(aceP.rsol - aceP.rsol(Pm))) <= 1e-12, 'G11: partial fractions are not Pm-symmetric');
  % K2_CHANNEL parity diagnostic on the exact-mirror REST state with ubar = +/-U0 (no ramp):
  % every intermediate must be even (cells: Pm) or odd (faces: Pf) to round-off.
  aceDp = aceP; aceDp.ubar_tau = 0; aceDp.t = 0; aceDm = aceM; aceDm.ubar_tau = 0; aceDm.t = 0;
  [dTHd,dQtd,rho0Bd,aceDp] = microrad(X0mw(:,1:2,:),aceDp.p_zc,aceDp.rho_zc,aceDp.Tv_zc,aceDp.theta_e_diag,aceDp);
  if isfield(aceDp,'lamb') && aceDp.lamb
    aceDp.diag.lamb = struct('on',1); [~, aceDp] = expFun(X0mw,dTHd,dQtd,rho0Bd,aceDp); Dp = aceDp.diag.lamb;
    aceDm.diag.lamb = struct('on',1); [~, aceDm] = expFun(X0mw,dTHd,dQtd,rho0Bd,aceDm); Dm = aceDm.diag.lamb;
    flds = {'om','f',-1; 'FxL','f',-1; 'S','f',-1; 'dzFx','f',-1; 'FzL','c',+1};   % omega odd (u odd, w even), F_x odd, F_z even
  else
    aceDp.diag.k2 = struct('on',1); [~, aceDp] = expFun(X0mw,dTHd,dQtd,rho0Bd,aceDp); Dp = aceDp.diag.k2;
    aceDm.diag.k2 = struct('on',1); [~, aceDm] = expFun(X0mw,dTHd,dQtd,rho0Bd,aceDm); Dm = aceDm.diag.k2;
    flds = {'rho0u_in','f',-1; 'rho0u_tot','f',-1; 'u_ctr','c',-1; 'Phi_uu','c',+1; 'Fx_uu','f',-1; 'rho0u_zm','f',-1; 'Phi_uw','f',-1; 'Fx_uw','f',-1; 'Fx','f',-1; 'Fx_face','f',-1; 'dzFx','f',-1; 'K2resp','c',+1};
  end
  for q_ = 1:size(flds,1)
    A = Dp.(flds{q_,1}); Bm = Dm.(flds{q_,1});
    if strcmp(flds{q_,2},'f'), Bm = Bm(:,Pf); else, Bm = Bm(:,Pm); end
    err = max(abs(A - flds{q_,3}*Bm),[],'all'); sc = max(abs(A),[],'all');
    [~,im] = max(abs(A(:) - flds{q_,3}*Bm(:))); [rr,cc] = ind2sub(size(A), im);
    parn = {'even','odd'};
    fprintf('  K2 parity %-10s (%s, %s): max|err|=%.3e (scale %.3e, rel %.3e) at row %d col %d\n', flds{q_,1}, flds{q_,2}, parn{1+(flds{q_,3}<0)}, err, sc, err/(sc+eps), rr, cc);
  end
  aceP.inv.reset = 1; yp = X0mw; for st=1:20, aceP.t = (st-1)*dt; [yp, aceP] = MARCH1(yp, aceP); end
  aceM.inv.reset = 1; ym = X0mw; for st=1:20, aceM.t = (st-1)*dt; [ym, aceM] = MARCH1(ym, aceM); end
  symTQ = max(abs(yp(:,1:2,:)-ym(:,1:2,Pm)),[],'all')/max(max(abs(yp(:,1:2,:)-X0mw(:,1:2,:)),[],'all'),eps);
  symMF = max(abs(yp(:,3,:)-ym(:,3,Pm)),[],'all')/(max(abs(yp(:,3,:)),[],'all')+eps);
  etaP = squeeze(yp(:,6,:)); etaM = squeeze(ym(:,6,:)); oddEta = max(abs(etaP + etaM(:,Pf)),[],'all')/(max(abs(etaP),[],'all')+eps);
  fprintf('GATE G11 ubar-reversed mirror twin (20 steps): sym(theta_e,qt anomaly)=%.3e sym(MF)=%.3e odd(eta)=%.3e ; max|MF|=%.3e\n', symTQ, symMF, oddEta, max(abs(yp(:,3,:)),[],'all'));
  % tracer metric: closure floor (1e-9 in MF) divided by a tiny 20-step theta_e anomaly (200-m steps) ->
  % relative value inflated; MF/eta carry the real test (1e-7), tracers 1e-5.
  assert(symTQ < 1e-5 && symMF < 1e-7 && oddEta < 1e-7, 'G11: ubar-reversed mirror twin broken');
  % --- G14c (cap mode): hard closure identities + exact-vs-trunc twin on a perturbed state ---
  if strcmp(aceMW.topo_solver,'cap')
    aceG = aceMW; aceG.ubar_tau = 0; aceG.t = 0;
    Xg = X0mw; rng(11); Xg(:,3,:) = Xg(:,3,:) + 0.3*(aceG.rho_zi(:)/aceG.rho_zi(1)).*randn(Nzm,1,Ni); Xg(1,3,:) = 0; Xg(end-aceG.ndead+1:end,3,:) = 0;
    Xg(:,3,:) = Xg(:,3,:) - mean(Xg(:,3,:),3);
    if isfield(aceG.capb,'mu2') && aceG.capb.mu2
      % MEANU=1: the closure owns k~=0 only; the gate state must respect the march invariant MF = 0 on rock interfaces / top
      % faces (tendency-level cap), otherwise a fully blocked row carries a k = 0 residual no k~=0 response can meet.
      MFg = squeeze(Xg(:,3,:)); MFg(aceG.soft.mfm) = 0; MFg = WBAR_REMOVE(MFg, aceG); Xg(:,3,:) = reshape(MFg, [Nzm,1,Ni]);
    end
    Xg(1:Nzm-1,7,1) = 0; [Xh, aceG] = CAPB_STAGE(Xg, aceG); aceH = PSI_CREF(aceG, Xh); MFh = squeeze(Xh(:,3,:)); ioh = IOFLOW_OF(MFh, aceH); rho0uh = -ioh/s; ubc = UBAR_NOW(aceG);
    ut = rho0uh./aceG.rho_zc(1:Nzm-1) + ubc(1:Nzm-1);
    rockMF = max(abs(MFh(aceG.soft.mfm))); wallu = max(abs(ut(aceG.soft.ufm)));
    psih = PSI_OF_STATE(MFh, rho0uh, aceH); PsiTm = repmat([0; cumsum(aceG.rho_zc(1:Nzm-1).*aceG.ubar_zc(1:Nzm-1))*aceG.dz],1,Ni); tgt = max(abs(psih(aceG.soft.body_lin) - PsiTm(aceG.soft.body_lin)));
    lsum = max(abs(sum(MFh .* aceG.Ai(:).', 2)));
    pres = 0;
    if isfield(aceG.capb,'Np') && aceG.capb.Np > 0                          % extrapolated psi(h_f) = PsiBar(h_f) on partial faces
      cbG = aceG.capb; rubG = aceG.rho_zc(1:Nzm-1).*aceG.ubar_zc(1:Nzm-1);
      tgtG = PsiTm(1:Nzm,1); tgtG = tgtG(cbG.cons_k) + rubG(cbG.cons_cell).*cbG.cons_frac;
      if isfield(cbG,'noslip') && cbG.noslip, islG = cbG.cons_type == 1; tgtG(islG) = rubG(cbG.cons_cell(islG)); end   % no-slip rows: slope target (R = 1 here)
      resG = cbG.W * psih(:) - tgtG; pres = max(abs(resG(cbG.Nb0+1:end)));
      fprintf('  G14c (partial step): %d partial faces ; extrapolated psi(h_f) residual %.2e (rel %.2e) ; min A_f %.2f min v_i %.2f ; cond(C_b) %.2e\n', ...
              cbG.Np, pres, pres/max(abs(tgtG)), min(aceG.Aface(aceG.Aface>0)), min(aceG.vfrac(aceG.vfrac>0)), cbG.condCb);
    end
    % exact twin: the same state closed with the exact responses must equal the psi-Dirichlet solve
    aceE = aceG; aceE.cap_mode = 'exact'; aceE = BUILD_CAPB(aceE); [Xe, aceE] = CAPB_STAGE(Xg, aceE);
    dcref = max(abs(Xe(1:Nzm-1,7,1) - 0));   % informational
    aceP = aceG; aceP.topo_solver = 'psi'; aceP = BUILD_PSI(aceP); aceP.cref_io = zeros(Nzm-1,1); [Xp, aceP] = PSI_STAGE(Xg, aceP);
    dEP = max(abs(Xe(:,3,:) - Xp(:,3,:)),[],'all') / max(abs(Xp(:,3,:)),[],'all');
    dTE = max(abs(Xh(:,3,:) - Xe(:,3,:)),[],'all') / max(abs(Xe(:,3,:)),[],'all');
    fprintf('GATE G14c cap closure: rock|MF|=%.2e wall|u_tot|=%.2e ; psi = PsiBar on body nodes to %.2e ; level sums %.2e | exact-cap vs psi-Dirichlet rel %.2e (must be ~1e-12) | trunc(+-%d) vs exact rel %.2e (truncation tail) ; cond(C_b)=%.2e\n', ...
            rockMF, wallu, tgt, lsum, dEP, aceG.NT, dTE, aceG.capb.condCb);
    if isfield(aceG.capb,'noslip') && aceG.capb.noslip
      fprintf('  G14c (no-slip): psi-Dirichlet twin not applicable (the twin solver has no slope constraint; rel %.2e informational) -- identities checked via W rows\n', dEP); dEP = 0;
    end
    if isfield(aceG.capb,'mu2') && aceG.capb.mu2
      fprintf('  G14c (MEANU=1): psi-Dirichlet twin not applicable (the twin carries the k = 0 part the closure no longer owns; rel %.2e informational) -- identities checked via W rows\n', dEP); dEP = 0;
    end
    assert(rockMF <= 1e-12 && wallu <= 1e-10 && lsum <= 1e-12 && dEP <= 1e-9 && pres <= 1e-9*max(1,max(abs(PsiTm(:)))), 'G14c: cap closure identities broken');
  end
  % --- G14 (psi mode): elliptic-closure identities on a perturbed state ---
  if strcmp(aceMW.topo_solver,'psi')
    aceG = aceMW; aceG.ubar_tau = 0; aceG.t = 0;                       % R = 1
    Xg = X0mw; rng(11); Xg(:,3,:) = Xg(:,3,:) + 0.3*randn(Nzm,1,Ni); Xg(1,3,:) = 0; Xg(end-aceG.ndead+1:end,3,:) = 0;
    Xg(:,3,:) = Xg(:,3,:) - mean(Xg(:,3,:),3);                          % level-mean-free
    Xg(1:Nzm-1,7,1) = 0;                                                % reference gauge = 0 before the solve
    aceG.diag.psi = struct('on',1); [Xh, aceG] = PSI_STAGE(Xg, aceG); D = aceG.diag.psi;
    MFh = squeeze(Xh(:,3,:)); aceH = PSI_CREF(aceG, Xh); ioh = IOFLOW_OF(MFh, aceH); ubc = UBAR_NOW(aceG);
    ut = (-ioh/s)./aceG.rho_zc(1:Nzm-1) + ubc(1:Nzm-1);                 % u_tot from the march's own ioflow + psi gauge
    wallu = max(abs(ut(aceG.cap.c3_lin))); rocku = max(abs(ut(aceG.k2_rock_lin)));
    cl_ = aceG.cap.c1_lin; if isfield(aceG.cap,'c1_lin_all'), cl_ = aceG.cap.c1_lin_all; end
    rockMF = max(abs(MFh(cl_)));
    [etah, ~] = ETA_OF(MFh, aceH); etah_SI = zeros(size(etah));          % ETA_OF is in mixed units; recompute SI interior eta
    rho0uh = -ioh/s; dxMFh = (circshift(MFh,-1,2)-MFh)/aceG.dx; etah_SI(2:Nzm-1,:) = (rho0uh(2:end,:)-rho0uh(1:end-1,:))/aceG.dz - dxMFh(2:Nzm-1,:);
    li = aceG.psi.lin_int; deta_int = max(abs(etah_SI(li) - D.eta_in(li))) / max(abs(D.eta_in(li)));
    lsum = max(abs(sum(MFh .* aceG.Ai(:).', 2)));
    gaug = max(abs(ioh(:) + s*D.rho0u_psi(:)));                          % io == -s rho0u_psi everywhere?
    fprintf('GATE G14 psi closure identities: rock|MF|=%.2e ; wall|u_tot|=%.2e rock|u_tot|=%.2e (max|u|=%.2f) ; interior eta preserved rel %.2e ; level sums %.2e ; psi-gauge consistency %.2e ; max|dMF stamp|=%.3f ; Chol %.1f s\n', ...
            rockMF, wallu, rocku, max(abs(ut(:))), deta_int, lsum, gaug, max(abs(D.MF_out(:)-D.MF_in(:))), aceG.psi.tfact);
    assert(rockMF <= 1e-13 && wallu <= 1e-10 && rocku <= 1e-10 && deta_int <= 1e-9 && lsum <= 1e-12 && gaug <= 1e-12, 'G14: psi closure identities broken');
  end
  % --- G12 (gauge reachability) does not apply to the cap/psi gauge: the level constant comes from the
  % closure, not from a face-mean rule. The battery ends here.
  fprintf('GATE G12 skipped (%s gauge)\n', aceMW.topo_solver);
  fprintf('=== ALL T2b GATES PASS ===\n');
end

function RUN_MW(tag, mw, aceMW, X0, snd, dt, progress_file)
  % One mountain-wave march: rest IC, ubar ramped by sin^2 over mw.tau, guarded/checkpointed
  % integration, per-frame ioflow/u_tot diagnostics, config-tagged save.
  aceMW.meanu.dmfdt_prev = []; aceMW.rec.meanu = struct('n',0,'D_last',0,'D_sum',0,'D_max',0);   % MEANU pressure-drag diagnostic
  Nzm = aceMW.Nzm; Ni = aceMW.Ni; Nzc = Nzm-1; s = aceMW.Ai(1)/aceMW.dx;
  tspan = 0:mw.dtout:mw.T; Nt = numel(tspan);
  aceMW.rec.topo = struct('n',0,'maxr',0,'maxq',0,'maxdE',0,'sumdE',0,'tworep',0,'leak_MF',0,'leak_u',0,'leak_mass',0);
  aceMW.rec.lamb = struct('n',0,'WL_last',0,'WL_max',0,'WL_sum',0,'WL_abs_sum',0,'KE_last',0,'ens_last',0,'circ_last',0);
  out_matfile = OUTP([tag '.mat'], aceMW.run.outdir); ckpt_file = OUTP([tag '_ckpt.mat'], aceMW.run.outdir);
  fprintf('%s: bell H=%g m (crest %g m) a=%g km U0=%g m/s N1=%g N2=%g ramp tau=%g s ; 0..%g s (%d outputs) ; Nb=%d gauge=%s\n', ...
          tag, mw.H, (max(aceMW.kbot)-aceMW.nbuf)*aceMW.dz, mw.a/1e3, mw.U0, mw.N1, mw.N2, mw.tau, mw.T, Nt, aceMW.cap.Nb, aceMW.gauge);
  pf = fopen(progress_file,'a'); fprintf(pf,'[%s] %s START\n', datestr(now,'HH:MM:SS'), tag); fclose(pf);
  aceMW.inv.reset = 1;
  if ~isempty(aceMW.run.resume) && aceMW.run.resume && exist(ckpt_file,'file')
    % RESUME from the checkpoint: continue from the last saved frame, keep the preceding frames
    ck = load(ckpt_file); copyfile(ckpt_file, OUTP([tag '_ckpt0.mat'], aceMW.run.outdir));
    i0 = numel(ck.tspan_ckpt); assert(abs(ck.tspan_ckpt(end) - tspan(i0)) < 1e-9, 'resume: checkpoint times do not match tspan');
    fprintf('%s RESUME from checkpoint: %d frames saved, continuing from t=%g s\n', tag, i0, tspan(i0));
    pf = fopen(progress_file,'a'); fprintf(pf,'[%s] %s RESUME from t=%g s\n', datestr(now,'HH:MM:SS'), tag, tspan(i0)); fclose(pf);
    tic; [Xr, blew_up, bstep, aceMW] = timeint_ckpt(@ssprk93_topo, tspan(i0:end), ck.Xckpt(:,:,:,end), dt, aceMW, 2, ckpt_file, progress_file, tag); Tcost = toc;
    X = cat(4, ck.Xckpt(:,:,:,1:end-1), Xr); bstep = bstep + i0 - 1;
  else
    tic; [X, blew_up, bstep, aceMW] = timeint_ckpt(@ssprk93_topo, tspan, X0, dt, aceMW, 2, ckpt_file, progress_file, tag); Tcost = toc;   % checkpoint every 2 outputs
  end
  fprintf('%s solver time = %.1f s (%.2f s/output) ; blew_up=%d bstep=%d\n', tag, Tcost, Tcost/max(Nt-1,1), blew_up, bstep);
  fprintf('%s TOPO_REC: stages=%d max|r|=%.3e max|q|=%.3e max|dE|=%.3e sum dE=%.3e ; two-rep max|eta-ETA_OF(MF)|=%.3e\n', ...
          tag, aceMW.rec.topo.n, aceMW.rec.topo.maxr, aceMW.rec.topo.maxq, aceMW.rec.topo.maxdE, aceMW.rec.topo.sumdE, aceMW.rec.topo.tworep);
  if ~isempty(aceMW.rec.lamb) && aceMW.rec.lamb.n > 0
    fprintf('%s VORTICITY-FLUX WORK: %d evaluations ; max|W_L|=%.3e W ; sum W_L=%.3e ; sum|W_L|=%.3e ; last W_L=%.3e vs KE=%.3e J (W_L*dt/KE last = %.3e)\n', tag, aceMW.rec.lamb.n, aceMW.rec.lamb.WL_max, aceMW.rec.lamb.WL_sum, aceMW.rec.lamb.WL_abs_sum, aceMW.rec.lamb.WL_last, aceMW.rec.lamb.KE_last, aceMW.rec.lamb.WL_last*dt/max(aceMW.rec.lamb.KE_last,1e-30));
  end
  if ~isempty(aceMW.rec.meanu) && aceMW.rec.meanu.n > 0, fprintf('%s MEANU pressure drag: %d stages ; mean D=%.3e max|D|=%.3e last D=%.3e (N per unit y, force on the mountain)\n', tag, aceMW.rec.meanu.n, aceMW.rec.meanu.D_sum/aceMW.rec.meanu.n, aceMW.rec.meanu.D_max, aceMW.rec.meanu.D_last); end
  POST_MW(tag, mw, aceMW, snd, X, tspan, blew_up, bstep, Tcost, dt, progress_file);
  if exist(ckpt_file,'file'), delete(ckpt_file); end
  pf = fopen(progress_file,'a'); fprintf(pf,'[%s] %s DONE blew_up=%d bstep=%d\n', datestr(now,'HH:MM:SS'), tag, blew_up, bstep); fclose(pf);
end

function POST_MW(tag, mw, aceMW, snd, X, tspan, blew_up, bstep, Tcost, dt, progress_file) %#ok<INUSD>
  % Post-processing + config-tagged save of a mountain-wave trajectory (also reachable from a
  % checkpoint via RUN_MODE='mwpost' when the march finished but the save did not).
  Nzm = aceMW.Nzm; Ni = aceMW.Ni; Nzc = Nzm-1; s = aceMW.Ai(1)/aceMW.dx; Nt = numel(tspan);
  out_matfile = OUTP([tag '.mat'], aceMW.run.outdir);
  lastok = Nt; for it=1:Nt, if any(~isfinite(X(:,:,:,it)),'all'), lastok = it-1; break; end, end
  lastok = max(lastok,1);
  Xok = X(:,:,:,1:lastok); tspan_save = tspan(1:lastok);
  mfmax = squeeze(max(abs(Xok(:,3,:,:)),[],[1 3]));
  fprintf('%s max|MF| per output (every 6th): %s\n', tag, mat2str(mfmax(1:6:end).', 4));
  % per-frame ioflow (gauge) and total u on faces (SI); rock interior u_tot = 0
  ioflow = zeros(Nzc, Ni, lastok); u_tot = zeros(Nzc, Ni, lastok); Rt = zeros(1, lastok);
  for it=1:lastok
    aceMW = PSI_CREF(aceMW, Xok(:,:,:,it));
    aceMW.t = tspan_save(it); ubc = UBAR_NOW(aceMW); Rt(it) = ubc(aceMW.nbuf+1)/max(mw.U0,eps);   % first PHYSICAL cell (the buffer row has ubar = 0)   % time FIRST: the soft/hybrid gauge target b(t) depends on it
    MFi = squeeze(Xok(:,3,:,it)); io = IOFLOW_OF(MFi, aceMW); ioflow(:,:,it) = io;
    ut = ( (-io/s)./aceMW.rho_zc(1:end-1) + ubc(1:end-1) )./aceMW.ak; ut(aceMW.k2_rock_lin) = 0;   % true velocity on partial faces = TOTAL areal flux / open fraction (io/s + rho0 ubar is the total; the gauge constant is the far-field rho0 ubar)
    u_tot(:,:,it) = ut;
  end
  MFl = squeeze(Xok(:,3,:,end)); iol = ioflow(:,:,end); aceMW.t = tspan_save(end); ubc = UBAR_NOW(aceMW);
  b = aceMW.rho_zc(aceMW.cap.c3_k).*ubc(aceMW.cap.c3_k)*s;      % wall target (both solvers keep the c3 lists)
  fprintf('%s last frame: max|MF top faces|=%.3e max|MF rock|=%.3e max|io-b walls|=%.3e (max|io|=%.3e) ; max|w|=%.3f m/s max u_tot=%.2f min u_tot=%.2f m/s\n', tag, ...
          max(abs(MFl(C1ALL_OF(aceMW.cap)))), max([abs(MFl(aceMW.rock_if_lin));0]), max(abs(iol(aceMW.cap.c3_lin)-b)), max(abs(iol(:))), ...
          max(abs(MFl./aceMW.rho_zi),[],'all'), max(u_tot(:,:,end),[],'all'), min(u_tot(:,:,end),[],'all'));
  [theta_e,qt,mf,theta,RH,B,qsat,qv,qc,ql,qi,Tv,T,~,~,eta] = POST_PROCESS(Xok, aceMW); %#ok<ASGLU>
  th_anom = theta - repmat(snd.theta_zc(1:size(theta,1)),[1,size(theta,2),size(theta,3)]);
  fprintf('%s: max|mf|=%.4g max|theta anom|=%.3g K max|eta|=%.3e ; ramp R(end)=%.3f\n', tag, max(abs(mf(:))), max(abs(th_anom(:))), max(abs(eta(:))), Rt(end));
  Xlast = Xok(:,:,:,end); kbot_sv = aceMW.kbot; zm = aceMW.zm; dz = aceMW.dz; dx = aceMW.dx; rho_zc = aceMW.rho_zc; rho_zi = aceMW.rho_zi; %#ok<NASGU>
  theta_e_zc = aceMW.theta_e_zc; qt_zc = aceMW.qt_zc; Tv_zc = aceMW.Tv_zc; p_zc = aceMW.p_zc; ubar_zc = aceMW.ubar_zc; gauge = aceMW.gauge; %#ok<NASGU>
  cap_c1_lin = aceMW.cap.c1_lin; cap_c3_lin = aceMW.cap.c3_lin; cap_c3_k = aceMW.cap.c3_k; cap_c3_f = aceMW.cap.c3_f; cap_repl = []; if isfield(aceMW.cap,'repl'), cap_repl = aceMW.cap.repl; end %#ok<NASGU>
  Mface = aceMW.Mface; solid_zc = aceMW.solid_zc; %#ok<NASGU>
  h_sv = aceMW.hcol; rsol_sv = aceMW.rsol; nbuf_sv = aceMW.nbuf; Aface = aceMW.Aface; vfrac = aceMW.vfrac; partial_on_sv = double(any(aceMW.rsol > 0)); %#ok<NASGU>
  if isempty(aceMW.rec.topo), aceMW.rec.topo = struct('n',0,'maxr',0,'maxq',0,'maxdE',0,'sumdE',0,'tworep',0); end
  info = struct('blew_up',blew_up,'bstep',bstep,'Tcost',Tcost,'mfmax',mfmax,'rec',aceMW.rec.topo,'Nb',aceMW.cap.Nb,'rank',aceMW.cap.rk,'condC',aceMW.cap.condC,'condSm',aceMW.cap.condSm); %#ok<NASGU>
  save(out_matfile,'Xlast','tspan_save','theta_e','qt','mf','theta','B','Tv','T','eta','ioflow','u_tot','Rt','kbot_sv','mw','snd', ...
       'theta_e_zc','qt_zc','Tv_zc','p_zc','rho_zc','rho_zi','ubar_zc','gauge','zm','Ni','dz','dx','dt','Tcost','blew_up','bstep','info', ...
       'cap_c1_lin','cap_c3_lin','cap_c3_k','cap_c3_f','cap_repl','Mface','solid_zc','h_sv','rsol_sv','Aface','vfrac','partial_on_sv','nbuf_sv','-v7.3');
  d = dir(out_matfile); fprintf('saved %s (%.0f MB)\n', out_matfile, d.bytes/1e6);
  pf = fopen(progress_file,'a'); fprintf(pf,'[%s] %s POST saved\n', datestr(now,'HH:MM:SS'), tag); fclose(pf);
end


