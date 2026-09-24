% dcases = [2:2:10]';
dcases = [0.5:1:9.5]';

%% Compute when multiple pre-computed files (Cylindrical Buoyancy)
wkb_basis_dir = 'D:\L=25.6km_dx=50m_dz=50m\';
list = dir([wkb_basis_dir 'PRECOMPUTED_VERTICAL_MODES_hireStepBASIS_*.mat']);

for idf=2:length(list)
  tic;
  disp(idf)
wkb_basis_fn = list(idf).name;

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
% PMD = nan(size(A,1),size(A,4),length(dcases)+1,length(dcases)+1); 

checkerboard = 1;%mod(round(X+1),2).*mod(round(Y+1),2);

id = 1;
d = dcases(id);
disp(num2str(d))

BH = double(R<=d/2);%erfc((R-d/2)/sig)/2; % max(BH) = 1 (SI units)
BH = BH.*checkerboard;
BH = BH./mean(BH(R<=d/2));
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
clear BH ABH fft2BH
% fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
% fft2DH(fft2Kx==0&fft2Ky==0) = 0;
% for idz=1:size(A,4)
%   ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
%   ADH = reshape(ADH,[],size(A,1));
%   PMD(:,idz,id,1) = squeeze(mean(ADH(R<=dcases(1)/2,:))); % Mass-flux Basis = PMB(Z,Bi)*rho_0(Z)
%   for od=2:length(dcases)
%     PMD(:,idz,id,od) = squeeze(mean(ADH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
%   end
%   PMD(:,idz,id,end) = squeeze(mean(ADH(R>dcases(end)/2,:)));
% end
% clear fft2BH ADH

for id=2:length(dcases)
  di = dcases(id-1);
  do = dcases(id);
  disp(num2str(do))

  BH = double(R<=do/2)-double(R<=di/2);%erfc((R-do/2)/sig)/2 - erfc((R-di/2)/sig)/2;
  BH = BH.*checkerboard;
  BH = BH./mean(BH(R<=do/2&R>di/2));
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
  clear BH ABH fft2BH
  % fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
  % fft2DH(fft2Kx==0&fft2Ky==0) = 0;
  % for idz=1:size(A,4)
  %   ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
  %   ADH = reshape(ADH,[],size(A,1));
  %   PMD(:,idz,id,1) = squeeze(mean(ADH(R<=dcases(1)/2,:)));
  %   for od=2:length(dcases)
  %     PMD(:,idz,id,od) = squeeze(mean(ADH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
  %   end
  %   PMD(:,idz,id,end) = squeeze(mean(ADH(R>dcases(end)/2,:)));
  % end
  % clear fft2BH ADH
end


id = length(dcases)+1;
disp(['>' num2str(dcases(end))])

BH = 1-double(R<=dcases(end)/2);%1 - erfc((R-dcases(end)/2)/sig)/2;
BH = BH.*checkerboard;
BH = BH./mean(BH(R>dcases(end)/2));
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
clear BH ABH fft2BH
% fft2DH = -fft2BH./(fft2Kx.^2+fft2Ky.^2);
% fft2DH(fft2Kx==0&fft2Ky==0) = 0;
% for idz=1:size(A,4)
%   ADH = real(ifft2(permute(A(:,:,:,idz),[2,3,1]).*fft2DH));
%   ADH = reshape(ADH,[],size(A,1));
%   PMD(:,idz,id,1) = squeeze(mean(ADH(R<=dcases(1)/2,:)));
%   for od=2:length(dcases)
%     PMD(:,idz,id,od) = squeeze(mean(ADH(R>dcases(od-1)/2&R<=dcases(od)/2,:)));
%   end
%   PMD(:,idz,id,end) = squeeze(mean(ADH(R>dcases(end)/2,:)));
% end

% save([wkb_basis_dir 'COMPOSITE_ACE_BASIS_hires_' num2str(idf,'%02.0f') '.mat'],"PMB","dcases","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
% pmb = PMB;
% pmd = PMD;
% zl = zL;
% zh = zH;
save(['./hires-temp/COMPOSITE_ACE_BASIS_hires_' num2str(idf,'%02.0f') '.mat'],"PMB","dcases","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')
clear A PMB
toc

end%idf

clear
idf = 1;
load(['./hires-temp/COMPOSITE_ACE_BASIS_hires_' num2str(idf,'%02.0f') '.mat'])
for idf=2:10
  mat = load(['./hires-temp/COMPOSITE_ACE_BASIS_hires_' num2str(idf,'%02.0f') '.mat'],'PMB');
  PMB = [PMB,mat.('PMB')];
end
save('./hires-temp/COMPOSITE_ACE_BASIS_hires.mat',"PMB","dcases","Z","sig","Lx","Ly","Nx","Ny",'-v7.3')

figure
plot(PMB(:,1:10:end,1,1),Z/1e3)
xlim([0 0.1])