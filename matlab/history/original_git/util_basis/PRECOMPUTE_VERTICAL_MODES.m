% Assuming Nx, Ny = 2^n; 512x512x256 ~ 1.25G
Nx = 1500;
Ny = 1500;

Lx = 150; % km
Ly = 150;

if mod(Nx,2)==0 % Assuming Nx=Ny
  nx = [0:Nx/2-1 Nx/2 -Nx/2+1:-1];
  ny = [0:Ny/2-1 Ny/2 -Ny/2+1:-1]';
  kx = (2*pi/Lx)*nx;
  ky = (2*pi/Ly)*ny;
  [fft2Kx,fft2Ky] = meshgrid(kx,ky); % (ky,kx)
  nsq = nx.^2 + ny.^2; % (ky,kx)
  L = Lx./sqrt(nsq); % Assuming Lx=Ly
else
  nx = [0:(Nx-1)/2 -(Nx-1)/2:-1];
  ny = [0:(Ny-1)/2 -(Ny-1)/2:-1]';
  kx = (2*pi/Lx)*nx;
  ky = (2*pi/Ly)*ny;
  [fft2Kx,fft2Ky] = meshgrid(kx,ky); % (ky,kx)
  nsq = nx.^2 + ny.^2; % (ky,kx)
  L = Lx./sqrt(nsq); % Assuming Lx=Ly
end

Z = [0:0.2:40]'; % dz=200m~4dx/2pi
Nz = length(Z);

for bidx=201:201%2:201
  disp(['bidx=' num2str(bidx)])
  if bidx>1 && bidx<=Nz
    zL = Z(bidx-1);
    zH = Z(bidx);
    zi = [zL;zH];
    Bi = [0,1];
  end
  
%   root = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
  root = '/home/yhkuo/MATCHING_STEP_BASIS/LARGE_DOMAIN/';
%   root = 'D:\Mog\WKB_Reconstruct\COLD_TOP_FE_STEP_BASIS\';
%   root = '/home/yhkuo/Desktop/COLD_TOP_FE_STEP_BASIS/';%'/media/yhkuo/BUOY_CALC/Mog/WKB_Reconstruct/WKB_3D_Reconstruct_WtUt/PRECOMPUTED_VERTICAL_MODES/';
  fn = ['PRECOMPUTED_VERTICAL_MODES_MCStepBUOYat' num2str(zL,'%04.1f') '-' num2str(zH,'%04.1f') 'KM.mat'];
  
  computed = zeros(size(nsq));
  storedx = zeros(size(nsq));
  storedy = zeros(size(nsq));
  A = zeros([length(Z),size(nsq)]); % (z,ky,kx)
  tcost = zeros(length(nx),1);
  for idx=1:length(nx)
    tic;
    disp(['idx = ' num2str(idx) '/' num2str(Nx)])
    factor = 0;
    for idy=1:length(ny)
      n2 = nsq(idy,idx);
      if n2~=0 % U=0 if n2==0
        if ~computed(idy,idx)
          while ~computed(idy,idx)
            lastwarn('','') 
            a = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idy,idx),Z,zL,zH,16*factor); %defult d=0: no symbolic computation for speed
            [warnMsg, warnId] = lastwarn();
            if ~isempty(warnMsg)
              factor = factor+1 + (factor==0); %factor=0-->2-->3-->4...
              disp(['Updating: (idx,idy,factor) = (' num2str(idx) ',' num2str(idy) ',' num2str(factor) ')'])
            else
              A(:,idy,idx) = a;
              n2 = nsq(idy,idx);
              computed(nsq==n2) = 1;
              storedx(nsq==n2) = idx;
              storedy(nsq==n2) = idy;
              %disp(['(' num2str(idx) ',' num2str(idy) ',' num2str(factor) ')'])
            end
          end
        else
          A(:,idy,idx) = A(:,storedy(idy,idx),storedx(idy,idx));
        end
      end
    end
    tcost(idx) = toc;
    disp(['Elapsed time is ' num2str(tcost(idx)) ' seconds.'])
  end
  disp(['TOTAL elapsed time is ' num2str(sum(tcost)) ' seconds.'])

  % Fix possible overflow
  A(~isfinite(A)) = 0;

  save([root fn],'Nx','Ny','Lx','Ly','kx','ky','Z','zL','zH','Bi','A','-v7.3')

%   plot(1:length(nx),tcost)
%   ylabel('T cost (min)')
%   title(['T cost = ' num2str(sum(tcost)/60) ' (s)'])
%   set(gca,'FontSize',15)
%   grid on
%   box on
end