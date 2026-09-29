%% Compute when multiple pre-computed files (Cylindrical Buoyancy)
wkb_basis_dir = 'C:\Users\r9822\Dropbox\JULIACE\data\basis\';
wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_2D.mat';

% For anelastic basis
load([wkb_basis_dir wkb_basis_fn])
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

pmb = squeeze(mean(reshape(ABH,length(Z),5,length(x)/5,length(Z)-1),2)); 
pmb = pmb(:,1:length(D),:); % pmbe below=pmb above (up to permute)
pmb = permute(pmb,[1,3,2]); %(Z,D,Bi)-->(Z,Bi,D)
pmbe = cat(3,pmb,pmb(:,:,length(D)-1:-1:2)); % Ensure pmbe symmetric w.r.t. x=0

pmdv = squeeze(mean(reshape(ADHv,length(Z),5,length(x)/5,length(Z)-1),2)); 
pmdv = pmdv(:,1:length(D),:); % pmdve below=pmdv above (up to permute)
pmdv = permute(pmdv,[1,3,2]); %(Z,D,Bi)-->(Z,Bi,D)
pmdve = cat(3,pmdv,pmdv(:,:,length(D)-1:-1:2)); % Ensure pmdve symmetric w.r.t. x=0

%% TBD(2025/3/13): Need to rewrite pmd subsequent terms for PMD
pmd = squeeze(mean(reshape(ADH,length(Z),5,length(x)/5,length(Z)-1),2));
pmd = pmd(:,1:length(D),:);
pmd = permute(pmd,[1,3,2]); %(Z,D,DHi)-->(Z,DHi,D)
pmde = cat(3,pmd,-pmd(:,:,length(D)-1:-1:2)); % Ensure pmbe an odd function w.r.t. x=0
pmde(:,:,1) = 0; % a(DH)=0 within forcing column (for odd functions)
De = [D,D(length(D)-1:-1:2)];
xe = x(3:5:end-2);
xe = xe(1:length(D));
xe = [xe,5-xe(length(D)-1:-1:2)];

% Expectd by ACE-driver: PMB, PMDv & PMD(201,200,forcing-region,response-region)
pmbig = nan(length(Z),length(Z)-1,length(De),length(De)); 
pmdvig = nan(length(Z),length(Z)-1,length(De),length(De)); 
pmdig = nan(length(Z),length(Z)-1,length(De),length(De)); 
for id=1:length(De)
  pmbig(:,:,:,id) = circshift(pmbe,id-1,3); % PMBig(201,200,forcing-region,response-region)
  pmdvig(:,:,:,id) = circshift(pmdve,id-1,3); % PMDvig(201,200,forcing-region,response-region)
  pmdig(:,:,:,id) = circshift(pmde,id-1,3); % PMDig(201,200,forcing-region,response-region)
end%id

% figure
% pmbplot = squeeze(sum(pmbig(:,10:40,30,:),2));
% contourf(xe,Z/1e3,pmbplot,[-0.3:0.01:0.5],'LineStyle','none')
% colormap(flipud(spectral))
% colorbar

pmbig = pmbig(:,:,:,1:length(De)/2);
pmdvig = pmdvig(:,:,:,1:length(De)/2);
pmdig = pmdig(:,:,:,1:length(De)/2);

% figure
% pmbplot = squeeze(sum(pmbig(:,10:40,30,:),2));
% contourf(pmbplot,[-0.3:0.01:0.5],'LineStyle','none')
% colormap(flipud(spectral))
% colorbar

PMB = pmbig(:,:,1:length(De)/2,:) + pmbig(:,:,end:-1:length(De)/2+1,:);
PMDv = pmdvig(:,:,1:length(De)/2,:) + pmdvig(:,:,end:-1:length(De)/2+1,:);
PMD = pmdig(:,:,1:length(De)/2,:) + pmdig(:,:,end:-1:length(De)/2+1,:); %<--It's plus here!!!

% figure
% pmbplot = squeeze(sum(PMB(:,10:40,20,:),2));
% contourf(pmbplot,[-0.3:0.01:0.5],'LineStyle','none')
% colormap(flipud(spectral))
% colorbar

Description = {'PMB(Z,Bi,forcing-region,response-region); 2D domain assumed symmetric w.r.t. x=0';
               'PMDv(Z,DHvi,forcing-region,response-region); 2D domain assumed symmetric w.r.t. x=0';
               'PMD(Z,DHi,forcing-region,response-region); 2D domain assumed symmetric w.r.t. x=0'};
L = Lx;
N = Nx/5;
x = xe;

save([wkb_basis_dir 'COMPOSITE_ACE_BASIS_2D.mat'],"PMB","PMDv","PMD","Z","L","N","x",'-v7.3')

%% Compute when multiple pre-computed files (Cylindrical Buoyancy)
% wkb_basis_dir = 'C:\Users\yhkuo\MATCHING_STEP_BASIS\2D_DOMAIN\';
% wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_2Dsmall.mat';
% 
% % For anelastic basis
% load([wkb_basis_dir wkb_basis_fn])
% Z = Z*1e3; % km-->m
% 
% % Small 2D domain setup
% Lsmall = Lx;
% Nsmall = Nx;
% xsmall = [-Lsmall/2+Lsmall/Nsmall/2:Lsmall/Nsmall:Lsmall/2-Lsmall/Nsmall/2];
% Dsmall = [0:35/5]*5; % Distance from forcing column to response column
% 
% % Horizontal buoyancy configuration
% BH = [ones(1,5),zeros(1,Nx-5)];
% fftBH = fft(BH);
% ABH = real(ifft(A.*fftBH,length(BH),2)); %(Z,x,Bi)
% 
% % Extend to large 2D domain
% Nx = 880;
% Lx = 880; % km
% x = [-Lx/2+Lx/Nx/2:Lx/Nx:Lx/2-Lx/Nx/2];
% D = [0:440/5]*5; % Distance from forcing column to response column
% 
% ABH = [ABH(:,1:40,:),zeros(length(Z),Nx-Nsmall,length(Z)-1),ABH(:,(Lsmall+5)/2+1:Nsmall,:)];
% 
% pmb = squeeze(mean(reshape(ABH,length(Z),5,length(x)/5,length(Z)-1),2));
% pmb = pmb(:,1:length(D),:);
% pmb = permute(pmb,[1,3,2]); %(Z,D,Bi)-->(Z,Bi,D)
% 
% pmbe = cat(3,pmb,pmb(:,:,length(D)-1:-1:2));
% De = [D,D(length(D)-1:-1:2)];
% xe = x(3:5:end-2);
% xe = xe(1:length(D));
% xe = [xe,5-xe(length(D)-1:-1:2)];
% 
% % Expectd by ACE-driver: PMB(201,200,forcing-region,response-region)
% pmbig = nan(length(Z),length(Z)-1,length(De),length(De)); 
% for id=1:length(De)
%   pmbig(:,:,:,id) = circshift(pmbe,id-1,3); % PMBig(201,200,forcing-region,response-region)
% end%id
% 
% % figure
% % pmbplot = squeeze(sum(pmbig(:,10:40,30,:),2));
% % contourf(xe,Z/1e3,pmbplot,[-0.3:0.01:0.5],'LineStyle','none')
% % colormap(flipud(spectral))
% % colorbar
% 
% pmbig = pmbig(:,:,:,1:length(De)/2);
% 
% % figure
% % pmbplot = squeeze(sum(pmbig(:,10:40,30,:),2));
% % contourf(pmbplot,[-0.3:0.01:0.5],'LineStyle','none')
% % colormap(flipud(spectral))
% % colorbar
% 
% PMB = pmbig(:,:,1:length(De)/2,:) + pmbig(:,:,end:-1:length(De)/2+1,:);
% 
% % figure
% % pmbplot = squeeze(sum(PMB(:,10:40,20,:),2));
% % contourf(pmbplot,[-0.3:0.01:0.5],'LineStyle','none')
% % colormap(flipud(spectral))
% % colorbar
% 
% Description = ['PMB(Z,Bi,forcing-region,response-region) computed using a smaller L=75km periodic 2D domain; ' ...
%                'for a large L=880km periodic 2D domain assumed symmetric w.r.t. x=0'];
% L = Lx;
% N = Nx/5;
% x = xe;
% 
% save([wkb_basis_dir 'COMPOSITE_ACE_BASIS_2Dsmall.mat'],"PMB","Z","L","N","x","xsmall","Nsmall",'-v7.3')

%% Compute when multiple pre-computed files (Cylindrical Buoyancy)
% % wkb_basis_dir = 'C:\Users\yhkuo\MATCHING_STEP_BASIS\2D_DOMAIN\';
% % wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_2D2scales.mat';
% % 
% % % For anelastic basis
% % load([wkb_basis_dir wkb_basis_fn])
% % Z = Z*1e3; % km-->m
% % 
% % % Small 2D domain setup
% % Lsmall = Lx;
% % Nsmall = Nx;
% % xsmall = [-Lsmall/2+Lsmall/Nsmall/2:Lsmall/Nsmall:Lsmall/2-Lsmall/Nsmall/2];
% % Dsmall = [0:Nsmall/5/2]*5; % Distance from forcing column to response column
% % 
% % % Horizontal buoyancy configuration
% % BH = [ones(1,5),zeros(1,Nsmall-5)];
% % fftBH = fft(BH);
% % ABH = real(ifft(A.*fftBH,length(BH),2)); %(Z,x,Bi)
% % abh24col = squeeze(mean(reshape(ABH,length(Z),5,[],length(Z)-1),2)); %(Z,x,Bi); 5km x 24col
% % 
% % % Extend to large 2D domain
% % Nx = 880;
% % Lx = 880; % km
% % x = [-Lx/2+Lx/Nx/2:Lx/Nx:Lx/2-Lx/Nx/2];
% % D = [0:440/5]*5; % Distance from forcing column to response column
% % 
% % ABH = zeros(length(Z),Nx/5,length(Z)-1,8); %(Z,response-region,Bi,forcing-region)
% % for idf=1:8
% %   ABH(:,1:8,:,idf) = abh24col(:,1:8,:);
% %   ABH(:,9:16,:,idf) = repmat(mean(abh24col(:,9:16,:),2),[1,8,1]);
% %   ABH(:,end-7:end,:,idf) = repmat(mean(abh24col(:,end-7:end,:),2),[1,8,1]);
% %   abh24col = circshift(abh24col,1,2);
% % end
% % pmbig = zeros(length(Z),Nx/5,length(Z)-1,Nx/5); %(Z,response-region,Bi,forcing-region)
% % for idf=1:8
% %   pmbig(:,:,:,(idf-1)*8+[1:8]) = circshift(ABH,(idf-1)*8,2);
% % end
% % % Expectd by ACE-driver: PMB(201,200,forcing-region,response-region)
% % pmbig = permute(pmbig,[1,3,4,2]);
% % 
% % De = [D,D(length(D)-1:-1:2)];
% % xe = x(3:5:end-2);
% % xe = xe(1:length(D));
% % xe = [xe,5-xe(length(D)-1:-1:2)];
% % 
% % pmbig = pmbig(:,:,:,1:length(De)/2);
% % PMB = pmbig(:,:,1:length(De)/2,:) + pmbig(:,:,end:-1:length(De)/2+1,:);
% % 
% % Description = ['PMB(Z,Bi,forcing-region,response-region) computed using a periodic 2D domain consisting of 3 smaller L=40km subdomains; ' ...
% %                'for a large L=880km periodic 2D domain assumed symmetric w.r.t. x=0'];
% % L = Lx;
% % N = Nx/5;
% % x = xe;
% % 
% % save([wkb_basis_dir 'COMPOSITE_ACE_BASIS_2D2scales.mat'],"PMB","Z","L","N","x","xsmall","Nsmall",'-v7.3')

%%
%%
%% 2D temp (forgot to bring sd card with precomputed basis (for 3D)
% % wkb_basis_dir = 'C:\Users\yhkuo\MATCHING_STEP_BASIS\2D_DOMAIN\';
% % wkb_basis_fn = 'PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_2Dtemp.mat';
% % 
% % % For anelastic basis
% % load([wkb_basis_dir wkb_basis_fn])
% % Z = Z*1e3; % km-->m
% % 
% % x = [-Lx/2+Lx/Nx/2:Lx/Nx:Lx/2-Lx/Nx/2];
% % D = [2:2:10]; % Distance from forcing column to response column
% % 
% % PMB = nan(size(A,1),size(A,3),length(D)+1,length(D)+1); % PMB(201,200,forcing-region,response-region)
% % R = abs(x);
% % 
% % % Horizontal buoyancy configuration
% % disp(num2str(D(1)))
% % BH = double(R<D(1)/2);
% % fftBH = fft(BH);
% % ABH = real(ifft(A.*fftBH,length(BH),2)); %(Z,x,Bi)
% % PMB(:,:,1,1) = squeeze(mean(ABH(:,R<D(1)/2,:),2));
% % for o=2:length(D)
% %   PMB(:,:,1,o) = squeeze(mean(ABH(:,R>D(o-1)/2&R<D(o)/2,:),2));
% % end
% % PMB(:,:,1,end) = squeeze(mean(ABH(:,R>D(end)/2,:),2));
% % 
% % for i=2:length(D)
% %   disp(num2str(D(i)))
% %   BH = double(R>D(i-1)/2&R<D(i)/2);
% %   fftBH = fft(BH);
% %   ABH = real(ifft(A.*fftBH,length(BH),2)); %(Z,x,Bi)
% %   PMB(:,:,i,1) = squeeze(mean(ABH(:,R<D(1)/2,:),2));
% %   for o=2:length(D)
% %     PMB(:,:,i,o) = squeeze(mean(ABH(:,R>D(o-1)/2&R<D(o)/2,:),2));
% %   end
% %   PMB(:,:,i,end) = squeeze(mean(ABH(:,R>D(end)/2,:),2));
% % end
% % disp(['>' num2str(D(end))])
% % BH = double(R>D(end)/2);
% % fftBH = fft(BH);
% % ABH = real(ifft(A.*fftBH,length(BH),2)); %(Z,x,Bi)
% % PMB(:,:,end,1) = squeeze(mean(ABH(:,R<D(1)/2,:),2));
% % for o=2:length(D)
% %   PMB(:,:,end,o) = squeeze(mean(ABH(:,R>D(o-1)/2&R<D(o)/2,:),2));
% % end
% % PMB(:,:,end,end) = squeeze(mean(ABH(:,R>D(end)/2,:),2));
% % 
% % save([wkb_basis_dir 'COMPOSITE_ACE_BASIS_2Dtemp.mat'],"PMB","Z","Lx","Nx","x",'-v7.3')