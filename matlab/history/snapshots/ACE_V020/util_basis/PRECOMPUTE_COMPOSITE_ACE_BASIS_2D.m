% wkb_basis_dir ='D:\MATCHING_STEP_BASIS\KHN26\';
wkb_basis_dir = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\KHN26\';
% wkb_basis_dir = '/home/yhkuo/Dropbox/JULIACE/ACE_NOGLOBAL/util_basis/';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_2D.mat';

load([wkb_basis_dir wkb_basis_fn])

%% Cut model top at 30 km
% zL = zL(1:150);
% zH = zH(1:150);
% Z = Z(1:151);
% ADX = ADX(1:151,:,1:150);
% ADV = ADV(1:151,:,1:150);
% A = A(1:151,:,1:150);

% For anelastic basis
Z = Z*1e3; % km-->m

x = [-Lx/2+Lx/Nx/2:Lx/Nx:Lx/2-Lx/Nx/2];
D = [0:440/5]*5; % Distance from forcing column to response column

% Horizontal buoyancy configuration
BH = [ones(1,5),zeros(1,Nx-5)];
fftBH = fft(BH);
ABH = real(ifft(A.*fftBH,length(BH),2)); %(Z,x,Bi)

% Horizontal DHv configuration (for rho0*delta_v)
BH = [ones(1,5),zeros(1,Nx-5)];
fftBH = fft(BH);
ADHv = real(ifft(ADV.*fftBH,length(BH),2)); %(Z,x,Bi)

% DH configuration
DH = [ones(1,5),zeros(1,Nx-5)];
fftDH = 1i*fft(DH);
ADH = real(ifft(ADX.*fftDH,length(DH),2)); %(Z,x,DHi)

pmb = squeeze(mean(reshape(ABH,length(Z),5,length(x)/5,length(Z)-1),2)); % pmbe two lines below=pmb here (up to permute)
pmb = [pmb(:,1,:),(pmb(:,2:end,:)+pmb(:,end:-1:2,:))/2]; % Ensure pmbe symmetric w.r.t. x=0
pmbe = permute(pmb,[1,3,2]); %(Z,D,Bi)-->(Z,Bi,D)

pmdv = squeeze(mean(reshape(ADHv,length(Z),5,length(x)/5,length(Z)-1),2)); % pmdve two lines below=pmdv here (up to permute)
pmdv = [pmdv(:,1,:),(pmdv(:,2:end,:)+pmdv(:,end:-1:2,:))/2]; % Ensure pmdve symmetric w.r.t. x=0
pmdve = permute(pmdv,[1,3,2]); %(Z,D,Bi)-->(Z,Bi,D)

%% TBD(2025/3/13): Need to rewrite pmd subsequent terms for PMD
pmd = squeeze(mean(reshape(ADH,length(Z),5,length(x)/5,length(Z)-1),2));
pmd = [pmd(:,1,:),(pmd(:,2:end,:)-pmd(:,end:-1:2,:))/2]; % Ensure pmde an odd function w.r.t. x=0
pmd(:,1,:) = 0; % a(DH)=0 within forcing column (for odd functions)
pmde = permute(pmd,[1,3,2]); %(Z,D,DHi)-->(Z,DHi,D)

De = [D,D(length(D)-1:-1:2)];
xe = x(3:5:end-2);
xe = xe(1:length(D));
xe = [xe,5-xe(length(D)-1:-1:2)];

% Expectd by ACE-driver: PMB, PMDv & PMD(201,200,forcing-region,response-region)
pmbig = nan(length(Z),length(Z)-1,length(De),length(De)); 
pmdvig = nan(length(Z),length(Z)-1,length(De),length(De)); 
pmdig = nan(length(Z),length(Z)-1,length(De),length(De)); 
for id=1:length(De)
  pmbig(:,:,id,:) = circshift(pmbe,id-1,3); % PMBig(201,200,forcing-region,response-region)
  pmdvig(:,:,id,:) = circshift(pmdve,id-1,3); % PMDvig(201,200,forcing-region,response-region)
  pmdig(:,:,id,:) = circshift(pmde,id-1,3); % PMDig(201,200,forcing-region,response-region)
end%id

% figure
% idx = 30;%176-30+1;
% tiledlayout(1,3)
% nexttile
% pmbplot = squeeze(sum(pmbig(:,10:40,idx,:),2));
% imagesc(xe,Z/1e3,pmbplot)
% set(gca,'YDir','normal')
% clim([-0.3 0.5])
% ylim([0 15])
% colormap(flipud(spectral))
% colorbar
% title('PMB')
% nexttile
% pmbplot = squeeze(sum(pmdvig(:,10:40,idx,:),2));
% imagesc(xe,Z/1e3,pmbplot)
% set(gca,'YDir','normal')
% clim([-350 180])
% ylim([0 15])
% colormap(flipud(spectral))
% colorbar
% title('PMDv')
% nexttile
% pmbplot = squeeze(sum(pmdig(:,10:40,idx,:),2));
% imagesc(xe,Z/1e3,pmbplot)
% set(gca,'YDir','normal')
% clim([-0.055 0.055])
% ylim([0 15])
% colormap(flipud(spectral))
% colorbar
% title('PMD')
% 
% rand(2)+rand(3)

% figure
% idx = 30;%176-30+1;
% tiledlayout(2,1)
%  nexttile
% pmbplot = squeeze(sum(pmdig(:,10:40,idx,:),2));
% imagesc(xe,Z/1e3,pmbplot)
% set(gca,'YDir','normal')
% clim([-0.055 0.055])
% ylim([0 15])
% colormap(flipud(spectral))
% colorbar
% title('PMD')
% nexttile
% pmbplot = squeeze(sum(pmdig(:,10:40,idx,:),2));
% imagesc(xe,Z/1e3,fliplr(pmbplot))
% set(gca,'YDir','normal')
% clim([-0.055 0.055])
% ylim([0 15])
% colormap(flipud(spectral))
% colorbar
% title('PMD')

pmbig = pmbig(:,:,:,1:length(De)/2);
pmdvig = pmdvig(:,:,:,1:length(De)/2);
pmdig = pmdig(:,:,:,1:length(De)/2);

PMB = pmbig(:,:,1:length(De)/2,:) + pmbig(:,:,end:-1:length(De)/2+1,:);
PMDv = pmdvig(:,:,1:length(De)/2,:) + pmdvig(:,:,end:-1:length(De)/2+1,:);
PMD = pmdig(:,:,1:length(De)/2,:) + pmdig(:,:,end:-1:length(De)/2+1,:); %<--It's plus here!!!

Description = {'PMB(Z,Bi,forcing-region,response-region); 2D domain assumed symmetric w.r.t. x=0';
               'PMDv(Z,DHvi,forcing-region,response-region); 2D domain assumed symmetric w.r.t. x=0';
               'PMD(Z,DHi,forcing-region,response-region); 2D domain assumed symmetric w.r.t. x=0'};
L = Lx;
N = Nx/5;
x = xe;

save([wkb_basis_dir 'COMPOSITE_ACE_BASIS_2D.mat'],"PMB","PMDv","PMD","Z","L","N","x",'-v7.3')