basis_dir = 'E:\Dropbox\JULIACE\data\basis\KHN26\';
basis_fn = 'PRECOMPUTED_VERTICAL_MODES_2D_4UNEVEN_dx=625m.mat';

DX = 5; % km; target coarse grid spacing (must be an integral multiple of dx)

load([basis_dir basis_fn])

%% Cut model top at 30 km
% ztop = 30; % km
% idztop = sum(zH<=ztop);
% zL = zL(1:idztop);
% zH = zH(1:idztop);
% Z = Z(1:idztop+1);
% A = A(1:idztop+1,:,1:idztop);
% % ADX = ADX(1:idztop+1,:,1:idztop);
% % ADV = ADV(1:idztop+1,:,1:idztop);
clear ADV ADX

%% Compute coarse-grained response to idealized unit forcing
dx = Lx/Nx; % km; Native grid spacing
x = [-(Lx-dx)/2:dx:(Lx-dx)/2]; % Note: assuming symmetry w.r.t. x=0
coarse_x = DX/dx; % Note: Lx/(2*coarse_x) must be an integer
ncols = Nx/coarse_x; % Number of total columns in the symmetric domain
D = [0.5,ones(1,ncols/2-1),0.5]*DX; % Width of columns for x>=0 (i.e., after cut in half)

Z = Z*1e3; % km-->m

% Horizontal buoyancy configuration (TBD: Modify BH to prevent Gibbs/aliasing)
BH = [ones(1,coarse_x/2),zeros(1,Nx-coarse_x),ones(1,coarse_x/2)]; % Note: 1st/last column width=Dx/2
fftBH = fft(BH);
ABH0 = real(ifft(A.*fftBH,length(BH),2)); %(Z,x,Bi)
ABH0 = ( ABH0 + fliplr(ABH0) )/2; % (Alrady within eps, but symmetrize w.r.t. x=0 anyway)

% Truncate horizontal nonlocal
ABH0(:,DX+1:end-DX,:) = 0;

% Allocate
PMB = nan(length(Z),length(D),length(Z)-1,length(D)); %PMB(201,response-col,200,forcing-col)

% 1st forcing column (forcing already symmetric)
ABH = ABH0;
PMB(:,1,:,1) = mean(ABH(:,1:coarse_x/2,:),2); % Response in 1st column
PMB(:,2:end-1,:,1) = squeeze(mean(reshape(ABH(:,coarse_x/2+1:Nx/2-coarse_x/2,:),length(Z),coarse_x,[],length(Z)-1),2));
PMB(:,end,:,1) = mean(ABH(:,Nx/2-coarse_x/2+1:Nx/2,:),2); % Response in last column
% 2nd to 2nd-to-last forcing columns
for idf=2:length(D)-1
  ABH = circshift(ABH0,(idf-1)*coarse_x,2) + circshift(ABH0,-(idf-1)*coarse_x,2);
  PMB(:,1,:,idf) = mean(ABH(:,1:coarse_x/2,:),2); % Response in 1st column
  PMB(:,2:end-1,:,idf) = squeeze(mean(reshape(ABH(:,coarse_x/2+1:Nx/2-coarse_x/2,:),length(Z),coarse_x,[],length(Z)-1),2));
  PMB(:,end,:,idf) = mean(ABH(:,Nx/2-coarse_x/2+1:Nx/2,:),2); % Response in last column
end%idf
% Last forcing column (forcing already symmetric)
ABH = circshift(ABH0,(length(D)-1)*coarse_x,2);
PMB(:,1,:,end) = mean(ABH(:,1:coarse_x/2,:),2); % Response in 1st column
PMB(:,2:end-1,:,end) = squeeze(mean(reshape(ABH(:,coarse_x/2+1:Nx/2-coarse_x/2,:),length(Z),coarse_x,[],length(Z)-1),2));
PMB(:,end,:,end) = mean(ABH(:,Nx/2-coarse_x/2+1:Nx/2,:),2); % Response in last column
% Permute dimension for output
PMB = permute(PMB,[1,3,4,2]); %(201,response-col,200,forcing-col)-->(201,200,forcing-col,response-col)

% Output
Description = {'PMB(Z,Bi,forcing-col,response-col); 2D domain assumed symmetric w.r.t. x=0';
               'PMDv(Z,DHvi,forcing-col,response-col); 2D domain assumed symmetric w.r.t. x=0';
               'PMD(Z,DHi,forcing-col,response-col); 2D domain assumed symmetric w.r.t. x=0'};
L = Lx;
N = length(D);

save([basis_dir 'COMPOSITE_ACE_BASIS_2D_KHN26_4UNEVEN_hNonlocalTruncated.mat'],"PMB","Z","L","N","D",'-v7.3')

clear ABH0 ABH BH fftBH

%% Construct UNEVEN basis
% % % load([basis_dir 'COMPOSITE_ACE_BASIS_2D_KHN26_4UNEVEN_hNonlocalTruncated.mat'])
% % % xb = [0,cumsum(D)]; % Boundary points for columns (before evenization...)
% % % 
% % % % Number of uneven columns
% % % ncols_uneven = (L/2)/(DX*10)*4+1; % 3x5km+1x35km in each 50km cell (note: 2.5km columns at both ends, thus +1)
% % % 
% % % % Allocate for uneven basis
% % % xb_uneven = nan(1,ncols_uneven+1);
% % % pmb_uneven = nan(length(Z),length(Z)-1,length(D),ncols_uneven); %(201,200,forcing-col,response-col)
% % % PMB_UNEVEN = nan(length(Z),length(Z)-1,ncols_uneven,ncols_uneven); %(201,200,forcing-col,response-col)
% % % 
% % % % Coarse-grain response columns
% % % idc = 1;
% % % xb_uneven(1) = xb(1);
% % % for idr=1:ncols_uneven
% % %   if mod(idr,4)~=3
% % %     pmb_uneven(:,:,:,idr) = PMB(:,:,:,idc);
% % % %     disp(num2str(idc))
% % %     idc = idc+1;
% % %     xb_uneven(idr+1) = xb(idc);
% % %   else
% % %     pmb_uneven(:,:,:,idr) = mean(PMB(:,:,:,idc:idc+6),4);
% % % %     disp(num2str(idc:idc+6))
% % %     idc = idc+7;
% % %     xb_uneven(idr+1) = xb(idc);
% % %   end%mod(idr,4)
% % % end%idr
% % % 
% % % % Coarse-grain forcing columns
% % % idc = 1;
% % % for idf=1:ncols_uneven
% % %   if mod(idf,4)~=3
% % %     PMB_UNEVEN(:,:,idf,:) = pmb_uneven(:,:,idc,:);
% % %     idc = idc+1;
% % %   else
% % %     PMB_UNEVEN(:,:,idf,:) = sum(pmb_uneven(:,:,idc:idc+6,:),3);
% % %     idc = idc+7;
% % %   end%mod(idf,4)
% % % end%idf
% % % 
% % % D = xb_uneven(2:end)-xb_uneven(1:end-1);
% % % N = length(D);
% % % 
% % % save([basis_dir 'COMPOSITE_ACE_BASIS_2D_KHN26_UNEVEN_hNonlocalTruncated.mat'],"PMB_UNEVEN","Z","L","N","D",'xb_uneven','-v7.3')