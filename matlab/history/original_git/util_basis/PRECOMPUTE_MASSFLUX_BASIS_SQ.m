%% Compute when only one pre-computed file is needed
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_dx=0.8km.mat';
dcases = [3.2]'; % squared region of width d

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% D = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2+Lx/Nx/2:Lx/Nx:Lx/2-Lx/Nx/2];
y = [-Ly/2+Ly/Ny/2:Ly/Ny:Ly/2-Ly/Ny/2]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
% sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
% R = sqrt(X.^2 + Y.^2);

[fft2Kx,fft2Ky] = meshgrid((2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1],...
                           (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]); % (ky,kx)                   

for id=1:length(dcases)
  d = dcases(id);
  disp(d)
  
  %BH = erfc((R-d/2)/sig)/2; % max(BH) = 1 (SI units)
  BH = (abs(X)<d/2).*(abs(Y)<d/2);
  fft2BH = fft2(BH);
  ABH = real(ifft2(permute(A,[2,3,1,4]).*fft2BH));
  ABH = reshape(ABH,[],size(A,1),size(A,4));
  PMB = squeeze(mean(ABH(BH>0,:,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_SQ=3.2km_dx=0.8km.mat'], "PMB","d","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
  clear ABH PMB %BH 
  
  fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
  fft2DH(fft2Kx==0&fft2Ky==0) = 0;
  ADH = real(ifft2(permute(A,[2,3,1,4]).*fft2DH));
  ADH = reshape(ADH,[],size(A,1),size(A,4));
  PMD = squeeze(mean(ADH(BH>0,:,:))); % Mass-flux Basis for D-term = PMD(Z,Di)*rho_0(Z)
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_SQ=3.2km_dx=0.8km.mat'],"PMD",'-append')
  clear fft2BH fft2DH ADH PMD
end