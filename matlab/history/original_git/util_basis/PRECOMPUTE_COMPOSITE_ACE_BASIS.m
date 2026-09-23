dcases = [5:10:25]';

tic;
%% Compute when multiple pre-computed files (Cylindrical Buoyancy)
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_0-20KM.mat';

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% d = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2:Lx/Nx:Lx/2-Lx/Nx];
y = [-Ly/2:Ly/Ny:Ly/2-Ly/Ny]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt(X.^2 + Y.^2);
[fft2Kx,fft2Ky] = meshgrid((2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1],...
                           (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]); % (ky,kx)

PMB = nan(size(A,1),size(A,4),length(dcases)+1,length(dcases)+1); 
PMD = nan(size(A,1),size(A,4),length(dcases)+1,length(dcases)+1); 

id = 1;
d = dcases(id);
disp(num2str(d))

BH = double(R<=d/2);%erfc((R-d/2)/sig)/2; % max(BH) = 1 (SI units)
fft2BH = fft2(BH);
for idz=1:size(A,4)
  ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
  ABH = reshape(ABH,[],size(A,1));
  PMB(:,idz,id,1) = squeeze(mean(ABH(R<=dcases(1)/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  for od=2:length(dcases)
    PMB(:,idz,id,od) = squeeze(mean(ABH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
  end
  PMB(:,idz,id,end) = squeeze(mean(ABH(R>dcases(end)/2,:)));
end
clear BH ABH %fft2BH
fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
fft2DH(fft2Kx==0&fft2Ky==0) = 0;
for idz=1:size(A,4)
  ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
  ADH = reshape(ADH,[],size(A,1));
  PMD(:,idz,id,1) = squeeze(mean(ADH(R<=dcases(1)/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  for od=2:length(dcases)
    PMD(:,idz,id,od) = squeeze(mean(ADH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
  end
  PMD(:,idz,id,end) = squeeze(mean(ADH(R>dcases(end)/2,:)));
end
clear fft2BH ADH

for id=2:length(dcases)
  di = dcases(id-1);
  do = dcases(id);
  disp(num2str(do))

  BH = double(R<=do/2)-double(R<=di/2);%erfc((R-do/2)/sig)/2 - erfc((R-di/2)/sig)/2;
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz,id,1) = squeeze(mean(ABH(R<=dcases(1)/2,:)));
    for od=2:length(dcases)
      PMB(:,idz,id,od) = squeeze(mean(ABH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
    end
    PMB(:,idz,id,end) = squeeze(mean(ABH(R>dcases(end)/2,:)));
  end
  clear BH ABH %fft2BH
  fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
  fft2DH(fft2Kx==0&fft2Ky==0) = 0;
  for idz=1:size(A,4)
    ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
    ADH = reshape(ADH,[],size(A,1));
    PMD(:,idz,id,1) = squeeze(mean(ADH(R<=dcases(1)/2,:)));
    for od=2:length(dcases)
      PMD(:,idz,id,od) = squeeze(mean(ADH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
    end
    PMD(:,idz,id,end) = squeeze(mean(ADH(R>dcases(end)/2,:)));
  end
  clear fft2BH ADH
end


id = length(dcases)+1;
disp(['>' num2str(dcases(end))])

BH = 1-double(R<=dcases(end)/2);%1 - erfc((R-dcases(end)/2)/sig)/2;
fft2BH = fft2(BH);
for idz=1:size(A,4)
  ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
  ABH = reshape(ABH,[],size(A,1));
  PMB(:,idz,id,1) = squeeze(mean(ABH(R<=dcases(1)/2,:)));
  for od=2:length(dcases)
    PMB(:,idz,id,od) = squeeze(mean(ABH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
  end
  PMB(:,idz,id,end) = squeeze(mean(ABH(R>dcases(end)/2,:)));
end
clear BH ABH %fft2BH
fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
fft2DH(fft2Kx==0&fft2Ky==0) = 0;
for idz=1:size(A,4)
  ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
  ADH = reshape(ADH,[],size(A,1));
  PMD(:,idz,id,1) = squeeze(mean(ADH(R<=dcases(1)/2,:)));
  for od=2:length(dcases)
    PMD(:,idz,id,od) = squeeze(mean(ADH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
  end
  PMD(:,idz,id,end) = squeeze(mean(ADH(R>dcases(end)/2,:)));
end

save([wkb_basis_dir 'COMPOSITE_ACE_BASIS_0-20KM.mat'],"PMB","PMD","dcases","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
pmb = PMB;
pmd = PMD;
zl = zL;
zh = zH;

%%
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_20-40KM.mat';

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
Z = Z*1e3; % km-->m
% d = 1; % km; horizontal diameter of buoyancy
x = [-Lx/2:Lx/Nx:Lx/2-Lx/Nx];
y = [-Ly/2:Ly/Ny:Ly/2-Ly/Ny]';
[X,Y] = meshgrid(x,y);
% Horizontal buoyancy configuration
sig = Lx/Nx; % km; transition in ~3*sig; 45/128~0.35
R = sqrt(X.^2 + Y.^2);
[fft2Kx,fft2Ky] = meshgrid((2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1],...
                           (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]); % (ky,kx)

PMB = nan(size(A,1),size(A,4),length(dcases)+1,length(dcases)+1); 
PMD = nan(size(A,1),size(A,4),length(dcases)+1,length(dcases)+1); 

id = 1;
d = dcases(id);
disp(num2str(d))

BH = double(R<=d/2);%erfc((R-d/2)/sig)/2; % max(BH) = 1 (SI units)
fft2BH = fft2(BH);
for idz=1:size(A,4)
  ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
  ABH = reshape(ABH,[],size(A,1));
  PMB(:,idz,id,1) = squeeze(mean(ABH(R<=dcases(1)/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  for od=2:length(dcases)
    PMB(:,idz,id,od) = squeeze(mean(ABH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
  end
  PMB(:,idz,id,end) = squeeze(mean(ABH(R>dcases(end)/2,:)));
end
clear BH ABH %fft2BH
fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
fft2DH(fft2Kx==0&fft2Ky==0) = 0;
for idz=1:size(A,4)
  ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
  ADH = reshape(ADH,[],size(A,1));
  PMD(:,idz,id,1) = squeeze(mean(ADH(R<=dcases(1)/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
  for od=2:length(dcases)
    PMD(:,idz,id,od) = squeeze(mean(ADH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
  end
  PMD(:,idz,id,end) = squeeze(mean(ADH(R>dcases(end)/2,:)));
end
clear fft2BH ADH

for id=2:length(dcases)
  di = dcases(id-1);
  do = dcases(id);
  disp(num2str(do))

  BH = double(R<=do/2)-double(R<=di/2);%erfc((R-do/2)/sig)/2 - erfc((R-di/2)/sig)/2;
  fft2BH = fft2(BH);
  for idz=1:size(A,4)
    ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
    ABH = reshape(ABH,[],size(A,1));
    PMB(:,idz,id,1) = squeeze(mean(ABH(R<=dcases(1)/2,:)));
    for od=2:length(dcases)
      PMB(:,idz,id,od) = squeeze(mean(ABH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
    end
    PMB(:,idz,id,end) = squeeze(mean(ABH(R>dcases(end)/2,:)));
  end
  clear BH ABH %fft2BH
  fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
  fft2DH(fft2Kx==0&fft2Ky==0) = 0;
  for idz=1:size(A,4)
    ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
    ADH = reshape(ADH,[],size(A,1));
    PMD(:,idz,id,1) = squeeze(mean(ADH(R<=dcases(1)/2,:)));
    for od=2:length(dcases)
      PMD(:,idz,id,od) = squeeze(mean(ADH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
    end
    PMD(:,idz,id,end) = squeeze(mean(ADH(R>dcases(end)/2,:)));
  end
  clear fft2BH ADH
end


id = length(dcases)+1;
disp(['>' num2str(dcases(end))])

BH = 1-double(R<=dcases(end)/2);%1 - erfc((R-dcases(end)/2)/sig)/2;
fft2BH = fft2(BH);
for idz=1:size(A,4)
  ABH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2BH));
  ABH = reshape(ABH,[],size(A,1));
  PMB(:,idz,id,1) = squeeze(mean(ABH(R<=dcases(1)/2,:)));
  for od=2:length(dcases)
    PMB(:,idz,id,od) = squeeze(mean(ABH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
  end
  PMB(:,idz,id,end) = squeeze(mean(ABH(R>dcases(end)/2,:)));
end
clear BH ABH %fft2BH
fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
fft2DH(fft2Kx==0&fft2Ky==0) = 0;
for idz=1:size(A,4)
  ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
  ADH = reshape(ADH,[],size(A,1));
  PMD(:,idz,id,1) = squeeze(mean(ADH(R<=dcases(1)/2,:)));
  for od=2:length(dcases)
    PMD(:,idz,id,od) = squeeze(mean(ADH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
  end
  PMD(:,idz,id,end) = squeeze(mean(ADH(R>dcases(end)/2,:)));
end

save([wkb_basis_dir 'COMPOSITE_ACE_BASIS_20-40KM.mat'],"PMB","PMD","dcases","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')

%% Collect
PMB = [pmb, PMB];
PMD = [pmd, PMD];
zL = [zl;zL];
zH = [zh;zH];
save([wkb_basis_dir 'COMPOSITE_ACE_BASIS_Heaviside_' num2str(length(dcases)+1) 'ACEs.mat'],"PMB","PMD","dcases","Z","zL","zH","sig","Lx","Ly","Nx","Ny",'-v7.3')

toc %~20min