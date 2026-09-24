%% Compute when only one pre-computed file is needed
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS.mat';
DCASES = [1 3 5 10 15 20 25]';

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% D = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2:Lx/Nx:Lx/2-Lx/Nx];
y = [-Ly/2:Ly/Ny:Ly/2-Ly/Ny]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt(X.^2 + Y.^2);

for id=1:length(DCASES)
  D = DCASES(id);
  disp(D)
  
  BH = erfc((R-D/2)/sig)/2; % max(BH) = 1 (SI units)
  fft2BH = fft2(BH);
  ABH = real(ifft2(permute(A,[2,3,1,4]).*fft2BH));
  ABH = reshape(ABH,[],size(A,1),size(A,4));
  PMB = squeeze(mean(ABH(R<=D/2,:,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  clear BH fft2BH ABH
  
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_D=' num2str(D) 'KM.mat'], "PMB","D","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
end

%% Compute when multiple pre-computed files (Cylindrical Buoyancy)
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_0-20KM.mat';
DCASES = [1 3 5 10 15 20 25]';

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% D = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2:Lx/Nx:Lx/2-Lx/Nx];
y = [-Ly/2:Ly/Ny:Ly/2-Ly/Ny]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt(X.^2 + Y.^2);

for id=1:length(DCASES)
  D = DCASES(id);
  disp(D)
  
  PMB = nan(size(A,1),size(A,4));
  BH = erfc((R-D/2)/sig)/2; % max(BH) = 1 (SI units)
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz) = squeeze(mean(ABH(R<=D/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  end
  clear BH fft2BH ABH
  
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_D=' num2str(D) 'KM_0-20KM.mat'], "PMB","D","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
end

wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_20-40KM.mat';
DCASES = [1 3 5 10 15 20 25]';

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% D = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2:Lx/Nx:Lx/2-Lx/Nx];
y = [-Ly/2:Ly/Ny:Ly/2-Ly/Ny]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt(X.^2 + Y.^2);

for id=1:length(DCASES)
  D = DCASES(id);
  disp(D)
  
  PMB = nan(size(A,1),size(A,4));
  BH = erfc((R-D/2)/sig)/2; % max(BH) = 1 (SI units)
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz) = squeeze(mean(ABH(R<=D/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  end
  clear BH fft2BH ABH
  
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_D=' num2str(D) 'KM_20-40KM.mat'], "PMB","D","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
end

wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
DCASES = [1 3 5 10 15 20 25]';

for id=1:length(DCASES)
  D = DCASES(id);
  disp(D)

  wkb_basis_fn = ['PRECOMPUTED_MATCHING_STEP_BASIS_D=' num2str(D) 'KM_0-20KM.mat'];
  load([wkb_basis_dir wkb_basis_fn])
  pmb = PMB;
  
  wkb_basis_fn = ['PRECOMPUTED_MATCHING_STEP_BASIS_D=' num2str(D) 'KM_20-40KM.mat'];
  load([wkb_basis_dir wkb_basis_fn])
  PMB = [pmb, PMB];
  
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_D=' num2str(D) 'KM.mat'], "PMB","D","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')

  figure
  plot(PMB,Z)
end

%% Compute when multiple pre-computed files (Non-cylindrical Buoyancy)
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_0-20KM.mat';
DCASES = [3 5 10 15]';%

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% D = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2:Lx/Nx:Lx/2-Lx/Nx];
y = [-Ly/2:Ly/Ny:Ly/2-Ly/Ny]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt(X.^2 + Y.^2);

for id=1:length(DCASES)
  D = DCASES(id);
  disp(D)
  
  PMB = nan(size(A,1),size(A,4));
  load([wkb_basis_dir 'BH_ASYMM_L=64KM_N=512_D~' num2str(D) 'KM.mat'],'BH','BB'); % mean(BH(BH~=0)) = 1 (SI units)
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz) = squeeze(mean(ABH(BB==1,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  end
  clear fft2BH ABH
  
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_D~' num2str(D) 'KM_0-20KM.mat'],'BH','BB',"PMB","D","Z","Lx","Ly","Nx","Ny",'-v7.3')
end

wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_20-40KM.mat';
DCASES = [3 5 10 15]';

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% D = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2:Lx/Nx:Lx/2-Lx/Nx];
y = [-Ly/2:Ly/Ny:Ly/2-Ly/Ny]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt(X.^2 + Y.^2);

for id=1:length(DCASES)
  D = DCASES(id);
  disp(D)
  
  PMB = nan(size(A,1),size(A,4));
  load([wkb_basis_dir 'BH_ASYMM_L=64KM_N=512_D~' num2str(D) 'KM.mat'],'BH','BB'); % mean(BH(BH~=0)) = 1 (SI units)
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz) = squeeze(mean(ABH(BB==1,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  end
  clear fft2BH ABH
  
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_D~' num2str(D) 'KM_20-40KM.mat'],'BH','BB',"PMB","D","Z","Lx","Ly","Nx","Ny",'-v7.3')
end

wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
DCASES = [3 5 10 15]';

for id=1:length(DCASES)
  D = DCASES(id);
  disp(D)

  wkb_basis_fn = ['PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_D~' num2str(D) 'KM_0-20KM.mat'];
  load([wkb_basis_dir wkb_basis_fn])
  pmb = PMB;
  
  wkb_basis_fn = ['PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_D~' num2str(D) 'KM_20-40KM.mat'];
  load([wkb_basis_dir wkb_basis_fn])
  PMB = [pmb, PMB];
  
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_D~' num2str(D) 'KM.mat'],'BH','BB',"PMB","D","Z","Lx","Ly","Nx","Ny",'-v7.3')

  figure
  plot(PMB,Z)
end