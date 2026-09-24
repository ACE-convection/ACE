% V024p87_CONSTRUCT_KERNELS.m -- builds the precomputed response tables (K1 = inv(Lap) dxx, K2 = inv(Lap) dx) read by
% ACE_V024p87.m. Forcing layers: the three-tier tiling (100 m below 2 km, 200 m from 2 to 18 km, 400 m above; physical
% heights; kernel coordinate z' = z + nbuf dz with nbuf rock buffer rows below the ground); Nx entities of width D = dx;
% dz = 100 m response levels, Dirichlet at the buffer bottom and at the top; truncation to +-NT columns with the c-rule
% (K1 side taps shifted so that the window sum is exactly zero) and closed odd pairs (K2). Output, one composite file:
%   COMPOSITE_ACE_BASIS_2D_V024_dx=<dx>_NT=<NT>.mat   (PMB_trunc [2NT+1 x Nz x Nlay], c_const, K2_trunc [2NT x Nz x Nlay], params)
% with dx written as <n>km when it is a whole number of km and as <n>m otherwise; params.K1 / params.K2 hold the tap
% orders (w1_di / w2_di), the truncation offsets and the box placement of each kernel.
% The tables depend on (D, NT, tiling, nbuf) only; the model applies them to any periodic run with Nx >= 2NT+2. Build every
% resolution directly (a coarse table is not obtainable from a fine one by box averaging).
% Construction: erf-smoothed forcing boxes on a fine grid (R sub-cells per entity), the closed-form slab Green's function
% util_layergreen.m (same folder), FFT over the fine grid (offline), R-point block average. Presets: NX (880), DX (500 m),
% NTP (30), NBUF (1). Run from the model folder; the tables go to its data/basis/ (or to the working directory when that folder does not exist), e.g.
%   addpath('util_basis'); NX=88; DX=5000; NTP=3; V024p87_CONSTRUCT_KERNELS
% Gates: charge norms, K1 evenness, K2 odd pairs, window sums, column zero sums, Dirichlet rows (assert), plus the
% informational truncation-mass report.
addpath(fileparts(mfilename('fullpath')));
t0_all = tic;
fprintf('=== V024p87_CONSTRUCT_KERNELS starting %s ===\n', datestr(now));

%% ---- parameters (presets) ----
Nx = 880;  if exist('NX','var'),   Nx = NX;   end
dx = 500;  if exist('DX','var'),   dx = DX;   end          % entity width (m)
NT = 30;   if exist('NTP','var'),  NT = NTP;  end            % truncation half-width (preset NTP)
nbuf = 1;  if exist('NBUF','var'), nbuf = NBUF; end        % rock buffer rows below the physical ground
dz = 100; ztop_phys = 40e3; Lz = ztop_phys + nbuf*dz; Lx = Nx*dx;
z_r = (0:dz:Lz)'; Nzr = numel(z_r);
tiers = [2000 100; 18000 200; ztop_phys 400];              % [top of tier (physical m), layer thickness (m)]
edges = 0; zlo = 0;
for t_ = 1:size(tiers,1), edges = [edges, (zlo + tiers(t_,2)):tiers(t_,2):tiers(t_,1)]; zlo = tiers(t_,1); end %#ok<AGROW>
edges = (edges + nbuf*dz)'; edges = [0; edges];            % kernel coordinate: buffer layer [0, nbuf*dz] first
assert(abs(edges(end) - Lz) < 1e-9 && all(diff(edges) > 0), 'edges must end at Lz and increase');
Nlay = numel(edges) - 1;
fprintf('three-tier tiling (physical): %s ; Nx=%d dx=%g m ; nbuf=%d ; Nlay=%d ; truncation +-%d\n', mat2str(tiers), Nx, dx, nbuf, Nlay, NT);
R = 64; sigma = dx/32; dxf = dx/R; Nf = R*Nx;
assert(dxf <= sigma/2 + 1e-12, 'fine grid must resolve the erf transition');
if mod(dx, 1000) == 0, dxtag = sprintf('%gkm', dx/1000); else, dxtag = sprintf('%gm', dx); end
fn = sprintf('COMPOSITE_ACE_BASIS_2D_V024_dx=%s_NT=%d.mat', dxtag, NT);
outdir = 'data/basis'; if ~isfolder(outdir), outdir = '.'; end   % tables go to ./data/basis/ when it exists (the model looks there)

kf   = (2*pi/Lx) * [0:Nf/2, -Nf/2+1:-1]';
kpos = (2*pi/Lx) * (1:Nf/2)';
xf = ((0:Nf-1)' + 0.5)*dxf - dx/2;                % fine x (cell-centered)
xc = mod(xf + Lx/2, Lx) - Lx/2;

%% ---- fine forcing boxes ----
b1 = 0.5*(erf((xc + dx/2)/(sqrt(2)*sigma)) - erf((xc - dx/2)/(sqrt(2)*sigma)));   % K1: cell-centered
xface = dx/2;                                     % K2 source at the +dx/2 FACE
b2 = 0.5*(erf((xc - xface + dx/2)/(sqrt(2)*sigma)) - erf((xc - xface - dx/2)/(sqrt(2)*sigma)));
charge_b1 = sum(b1)*dxf/dx; charge_b2 = sum(b2)*dxf/dx;
fprintf('charge norm: K1 %.12f  K2 %.12f (target 1)\n', charge_b1, charge_b2);
b1h = fft(b1); b2h = fft(b2);

%% ---- build kernels, per layer ----
PMBc = zeros(Nx, Nzr, Nlay); K2f = zeros(Nx, Nzr, Nlay);
tic;
for lay = 1:Nlay
  a_ = edges(lay); b_ = edges(lay+1);
  Lmat = zeros(Nf/2, Nzr);
  for m = 1:Nf/2, Lmat(m,:) = util_layergreen(kpos(m), z_r, a_, b_, Lz)'; end
  Lfull = [zeros(1,Nzr); Lmat; Lmat(end-1:-1:1,:)];
  h1 = real(ifft( (-kf.^2) .* b1h .* Lfull, [], 1));   % p1 = -k^2
  h2 = real(ifft( (1i*kf)  .* b2h .* Lfull, [], 1));   % p2 = i*k
  PMBc(:,:,lay) = squeeze(mean(reshape(h1, R, Nx, Nzr), 1));
  K2f (:,:,lay) = squeeze(mean(reshape(h2, R, Nx, Nzr), 1));
  if mod(lay,30)==0, fprintf('  layer %d/%d (%.0f s)\n', lay, Nlay, toc); end
end
build_time_full = toc;
fprintf('kernels built in %.1f s (%d layers x %d modes x %d levels, Nf=%d)\n', build_time_full, Nlay, Nf/2, Nzr, Nf);

%% ---- truncation + gates + save ----
[PMBt, cc, d1, w1_di] = TRUNC_K1(PMBc, NT, Nx);
[K2t, d2, w2_di] = TRUNC_K2(K2f, NT, Nx);
KERNEL_GATES(PMBc, K2f, PMBt, K2t, NT, Nx, d2, w1_di, w2_di, charge_b1, charge_b2);
common = struct('Lz',Lz,'edges',edges,'Nlay',Nlay,'dz_response',dz,'z_resp',z_r,'R',R,'sigma',sigma,'Nf',Nf,'nbuf',nbuf,'tiers',tiers,'tiling','L3 three-tier (100/200/400 m)', ...
                'built',datestr(now),'builder','V024p87_CONSTRUCT_KERNELS.m');
params = common; params.Nx = Nx; params.dx = dx; params.Lx = Lx; params.NT = NT;
params.K1 = struct('w1_di',w1_di,'w1_delta',d1,'center_local',1,'symbol','p1=-k^2','box_center','entity center', ...
                   'note','centre fixed; side taps K1(d)-c with c=(K1(0)+sum sides)/(2*NT); window sum exactly 0');
params.K2 = struct('w2_di',w2_di,'w2_delta',d2,'symbol','p2=i*k','box_center','entity face @ +dx/2','face_offset_x',xface, ...
                   'note',sprintf('%d taps Delta=-(NT-1)..NT, closed odd pairs (d,1-d); pair-sums exactly 0', 2*NT));
PMB_trunc = PMBt; c_const = cc; K2_trunc = K2t;
save(fullfile(outdir, fn), 'PMB_trunc', 'c_const', 'K2_trunc', 'params', '-v7.3');
fprintf('saved %s in %s\n', fn, outdir);

fprintf('build loop %.1f s ; total %.1f s\n', build_time_full, toc(t0_all));
fprintf('=== ALL KERNEL GATES PASS ===\n');

%% ---- local functions ----
function [PMBt, cc, d1, w1_di] = TRUNC_K1(PMBc, NT, Nx)
  % K1: centre + NT taps each side; side taps K1(d) - c with c = (K1(0) + sum sides)/(2 NT) => window sum exactly 0 (c-rule)
  d1 = [0, 1:NT, -(1:NT)]; w1_di = mod(d1, Nx) + 1; Nz = size(PMBc, 2); Nlay = size(PMBc, 3);
  center  = squeeze(PMBc(w1_di(1),:,:)); sideSum = squeeze(sum(PMBc(w1_di(2:end),:,:), 1));
  cc = (center + sideSum) / (2*NT);
  PMBt = zeros(numel(d1), Nz, Nlay); PMBt(1,:,:) = PMBc(w1_di(1),:,:); ccr = reshape(cc, [1, Nz, Nlay]);
  for t = 2:numel(d1), PMBt(t,:,:) = PMBc(w1_di(t),:,:) - ccr; end
  cv = cc(:); fprintf('K1 comp-constant c stats (NT=%d): min=%.3e max=%.3e median=%.3e (max|K1|=%.3e)\n', NT, min(cv), max(cv), median(cv), max(abs(PMBc(:))));
end

function [K2t, d2, w2_di] = TRUNC_K2(K2f, NT, Nx)
  % K2: Delta = -(NT-1)..NT (2 NT taps, closed odd pairs (d, 1-d))
  d2 = -(NT-1):NT; w2_di = mod(d2, Nx) + 1; K2t = K2f(w2_di, :, :);
end

function KERNEL_GATES(PMBc, K2f, PMBt, K2t, NT, Nx, d2, w1_di, w2_di, charge_b1, charge_b2)
  fprintf('\n=== GATES (Nx=%d, NT=%d) ===\n', Nx, NT);
  tol1 = 1e-10; g1a = abs(charge_b1-1); g1b = abs(charge_b2-1);
  fprintf('[Gate 1] charge norms: |K1-1|=%.3e |K2-1|=%.3e\n', g1a, g1b); assert(g1a<=tol1 && g1b<=tol1, 'Gate 1 FAILED');
  maxabsPMB = max(abs(PMBc(:))); tol2 = 1e-12; g2max = 0;
  for dd = 1:NT, d = max(abs(PMBc(mod(dd,Nx)+1,:,:) - PMBc(mod(-dd,Nx)+1,:,:)),[],'all') / maxabsPMB; g2max = max(g2max, d); end
  fprintf('[Gate 2] K1 evenness over %d pairs: max rel = %.3e\n', NT, g2max); assert(g2max <= tol2, 'Gate 2 FAILED: K1 evenness');
  maxabsK2t = max(abs(K2t(:))); tol3 = 1e-12; g3max = 0;
  for dd = 0:NT-1, r1 = find(d2 == -dd); r2 = find(d2 == 1+dd); d = max(abs(K2t(r1,:,:) + K2t(r2,:,:)),[],'all') / maxabsK2t; g3max = max(g3max, d); end
  fprintf('[Gate 3] K2 truncated odd pairs (%d): max rel = %.3e\n', NT, g3max); assert(g3max <= tol3, 'Gate 3 FAILED: K2 odd pairs');
  tol4 = 1e-14; winsum = squeeze(sum(PMBt,1)); g4max = max(abs(winsum(:)));
  fprintf('[Gate 4] K1 truncated window sum: max|sum| = %.3e\n', g4max); assert(g4max <= tol4, 'Gate 4 FAILED');
  tol5 = 1e-10; g5a = max(abs(squeeze(sum(PMBc,1))),[],'all')/maxabsPMB; maxabsK2f = max(abs(K2f(:))); g5b = max(abs(squeeze(sum(K2f,1))),[],'all')/maxabsK2f;
  fprintf('[Gate 5] full-kernel column zero-sum: K1 %.3e K2 %.3e\n', g5a, g5b); assert(g5a<=tol5 && g5b<=tol5, 'Gate 5 FAILED');
  tol6 = 1e-14; g6 = max([max(abs(PMBc(:,1,:)),[],'all'), max(abs(PMBc(:,end,:)),[],'all')])/maxabsPMB; g6b = max([max(abs(K2f(:,1,:)),[],'all'), max(abs(K2f(:,end,:)),[],'all')])/maxabsK2f;
  fprintf('[Gate 6] Dirichlet rows: K1 %.3e K2 %.3e\n', g6, g6b); assert(g6<=tol6 && g6b<=tol6, 'Gate 6 FAILED');
  out1 = PMBc; out1(w1_di,:,:) = 0; out2 = K2f; out2(w2_di,:,:) = 0;
  fr1 = squeeze(sum(abs(out1),1)) ./ max(squeeze(sum(abs(PMBc),1)),1e-300); fr2 = squeeze(sum(abs(out2),1)) ./ max(squeeze(sum(abs(K2f),1)),1e-300);
  fprintf('[Gate 9] truncation: |K| mass OUTSIDE +-%d columns / total -- K1 median %.3e max %.3e ; K2 median %.3e max %.3e (informational)\n', NT, median(fr1(:)), max(fr1(:)), median(fr2(:)), max(fr2(:)));
end
