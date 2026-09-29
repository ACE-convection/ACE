%% Compute when only one pre-computed file is needed
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS.mat';
dcases = [1 3 5 10 15 20 25]';

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% D = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2+Lx/Nx/2:Lx/Nx:Lx/2-Lx/Nx/2];
y = [-Ly/2+Ly/Ny/2:Ly/Ny:Ly/2-Ly/Ny/2]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt(X.^2 + Y.^2);

[fft2Kx,fft2Ky] = meshgrid((2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1],...
                           (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]); % (ky,kx)                   

for id=1:length(dcases)
  d = dcases(id);
  disp(d)
  
  BH = erfc((R-d/2)/sig)/2; % max(BH) = 1 (SI units)
  fft2BH = fft2(BH);
  ABH = real(ifft2(permute(A,[2,3,1,4]).*fft2BH));
  ABH = reshape(ABH,[],size(A,1),size(A,4));
  PMB = squeeze(mean(ABH(R<=d/2,:,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_d=' num2str(d) 'KM.mat'], "PMB","d","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
  clear BH ABH PMB
  
  fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
  fft2DH(fft2Kx==0&fft2Ky==0) = 0;
  ADH = real(ifft2(permute(A,[2,3,1,4]).*fft2DH));
  ADH = reshape(ADH,[],size(A,1),size(A,4));
  PMD = squeeze(mean(ADH(R<=d/2,:,:))); % Mass-flux Basis for D-term = PMD(Z,Di)*rho_0(Z)
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_d=' num2str(d) 'KM.mat'],"PMD",'-append')
  clear fft2BH fft2DH ADH PMD
end

%% Compute when multiple pre-computed files (Cylindrical Buoyancy)
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_0-20KM.mat';
dcases = [1 3 5 10 15 20 25]';

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

[fft2Kx,fft2Ky] = meshgrid((2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1],...
                           (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]); % (ky,kx)        

for id=1:length(dcases)
  d = dcases(id);
  disp(d)
  
  PMB = nan(size(A,1),size(A,4));
  BH = double(R<=d/2);%erfc((R-d/2)/sig)/2; % max(BH) = 1 (SI units)
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz) = squeeze(mean(ABH(R<=d/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  end
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_d=' num2str(d) 'KM_0-20KM.mat'], "PMB","d","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
  clear BH ABH PMB

  PMD = nan(size(A,1),size(A,4));
  fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
  fft2DH(fft2Kx==0&fft2Ky==0) = 0;
  for idz=1:size(A,4)
    ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
    ADH = reshape(ADH,[],size(A,1));
    PMD(:,idz) = squeeze(mean(ADH(R<=d/2,:))); % Mass-flux Basis for D-term = PMD(Z,Di)*rho_0(Z)
  end
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_d=' num2str(d) 'KM_0-20KM.mat'],"PMD",'-append')
  clear fft2BH fft2DH ADH PMD
end

wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_20-40KM.mat';
% dcases = [1 3 5 10 15 20 25]';

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

[fft2Kx,fft2Ky] = meshgrid((2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1],...
                           (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]); % (ky,kx)  

for id=1:length(dcases)
  d = dcases(id);
  disp(d)
  
  PMB = nan(size(A,1),size(A,4));
  BH = double(R<=d/2);%erfc((R-d/2)/sig)/2; % max(BH) = 1 (SI units)
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz) = squeeze(mean(ABH(R<=d/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  end
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_d=' num2str(d) 'KM_20-40KM.mat'],"PMB","d","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
  clear BH ABH PMB

  PMD = nan(size(A,1),size(A,4));
  fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
  fft2DH(fft2Kx==0&fft2Ky==0) = 0;
  for idz=1:size(A,4)
    ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
    ADH = reshape(ADH,[],size(A,1));
    PMD(:,idz) = squeeze(mean(ADH(R<=d/2,:))); % Mass-flux Basis for D-term = PMD(Z,Di)*rho_0(Z)
  end
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_d=' num2str(d) 'KM_20-40KM.mat'],"PMD",'-append')
  clear fft2BH fft2DH ADH PMD
end

% Combine 0-20KM and 20-40KM
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
% dcases = [1 3 5 10 15 20 25]';

for id=1:length(dcases)
  d = dcases(id);
  disp(d)

  wkb_basis_fn = ['PRECOMPUTED_MATCHING_STEP_BASIS_d=' num2str(d) 'KM_0-20KM.mat'];
  load([wkb_basis_dir wkb_basis_fn],"PMB","PMD","d","Z","sig","Lx","Ly","Nx","Ny")
  pmb = PMB;
  pmd = PMD;
  
  wkb_basis_fn = ['PRECOMPUTED_MATCHING_STEP_BASIS_d=' num2str(d) 'KM_20-40KM.mat'];
  load([wkb_basis_dir wkb_basis_fn],"PMB","PMD","d","Z","sig","Lx","Ly","Nx","Ny")
  PMB = [pmb, PMB];
  PMD = [pmd, PMD];
  
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_d=' num2str(d) 'KM.mat'],"PMB","PMD","d","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')

  figure
  subplot(1,2,1)
  plot(PMB,Z)
  subplot(1,2,2)
  plot(PMD,Z)
end

%% Compute when multiple pre-computed files (Non-cylindrical Buoyancy)
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_0-20KM.mat';
dcases = [3 5 10 15]';%

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% D = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2:Lx/Nx:Lx/2-Lx/Nx];
y = [-Ly/2:Ly/Ny:Ly/2-Ly/Ny]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt( (X/1.2).^2 + (1.2*Y).^2 );

[fft2Kx,fft2Ky] = meshgrid((2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1],...
                           (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]); % (ky,kx)        

for id=1:length(dcases)
  d = dcases(id);
  disp(d)
  
  PMB = nan(size(A,1),size(A,4));
  BH = erfc((R-d/2)/sig)/2; % max(BH) = 1 (SI units)
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz) = squeeze(mean(ABH(R<=d/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  end
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~' num2str(d) 'KM_0-20KM.mat'], "PMB","d","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
  clear BH ABH PMB

  PMD = nan(size(A,1),size(A,4));
  fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
  fft2DH(fft2Kx==0&fft2Ky==0) = 0;
  for idz=1:size(A,4)
    ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
    ADH = reshape(ADH,[],size(A,1));
    PMD(:,idz) = squeeze(mean(ADH(R<=d/2,:))); % Mass-flux Basis for D-term = PMD(Z,Di)*rho_0(Z)
  end
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~' num2str(d) 'KM_0-20KM.mat'],"PMD",'-append')
  clear fft2BH fft2DH ADH PMD
end

wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_20-40KM.mat';
dcases = [3 5 10 15]';

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% D = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2:Lx/Nx:Lx/2-Lx/Nx];
y = [-Ly/2:Ly/Ny:Ly/2-Ly/Ny]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt( (X/1.2).^2 + (1.2*Y).^2 );

[fft2Kx,fft2Ky] = meshgrid((2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1],...
                           (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]); % (ky,kx)  

for id=1:length(dcases)
  d = dcases(id);
  disp(d)
  
  PMB = nan(size(A,1),size(A,4));
  BH = erfc((R-d/2)/sig)/2; % max(BH) = 1 (SI units)
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz) = squeeze(mean(ABH(R<=d/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  end
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~' num2str(d) 'KM_20-40KM.mat'], "PMB","d","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
  clear BH ABH PMB

  PMD = nan(size(A,1),size(A,4));
  fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
  fft2DH(fft2Kx==0&fft2Ky==0) = 0;
  for idz=1:size(A,4)
    ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
    ADH = reshape(ADH,[],size(A,1));
    PMD(:,idz) = squeeze(mean(ADH(R<=d/2,:))); % Mass-flux Basis for D-term = PMD(Z,Di)*rho_0(Z)
  end
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~' num2str(d) 'KM_20-40KM.mat'],"PMD",'-append')
  clear fft2BH fft2DH ADH PMD
end

% Combine 0-20KM and 20-40KM
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
dcases = [3 5 10 15]';

for id=1:length(dcases)
  d = dcases(id);
  disp(d)

  wkb_basis_fn = ['PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~' num2str(d) 'KM_0-20KM.mat'];
  load([wkb_basis_dir wkb_basis_fn],"PMB","PMD","d","Z","sig","Lx","Ly","Nx","Ny")
  pmb = PMB;
  pmd = PMD;
  
  wkb_basis_fn = ['PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~' num2str(d) 'KM_20-40KM.mat'];
  load([wkb_basis_dir wkb_basis_fn],"PMB","PMD","d","Z","sig","Lx","Ly","Nx","Ny")
  PMB = [pmb, PMB];
  PMD = [pmd, PMD];
  
  save([wkb_basis_dir 'PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~' num2str(d) 'KM.mat'],"PMB","PMD","d","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')

  figure
  subplot(1,2,1)
  plot(PMB,Z)
  subplot(1,2,2)
  plot(PMD,Z)
end