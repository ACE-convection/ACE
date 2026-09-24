% Assuming Nx, Ny = 2^n; 512x512x256 ~ 1.25G
Nx = 256;
Ny = 256;

Lx = 12.8; % km
Ly = 12.8;

[fft2Kx,fft2Ky] = meshgrid((2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1],...
                           (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]); % (ky,kx)
                         
nx = [0:Nx/2-1 Nx/2 -Nx/2+1:-1];
ny = [0:Ny/2-1 Ny/2 -Ny/2+1:-1]';
nsq = nx.^2 + ny.^2; % (ky,kx)
L = Lx./sqrt(nsq); % Assuming Lx=Ly
kx = (2*pi/Lx)*[0:Nx/2-1 Nx/2 -Nx/2+1:-1]';
ky = (2*pi/Ly)*[0:Ny/2-1 Ny/2 -Ny/2+1:-1]';

% For mimicing Finite-Difference horizontal discretization
dx = Lx/Nx; %in km
dy = Ly/Ny;
effKsq = 2*( (1-cos(fft2Kx*dx))/dx^2 + (1-cos(fft2Ky*dy))/dy^2 )/(4*pi^2); % CD2 for 2nd derivative
effL = 1./sqrt(effKsq);

Z = [0:0.2:10]'; % dz=200m~4dx/2pi
Nz = length(Z);

for bidx=30:30 %2:Nz
  disp(['bidx=' num2str(bidx)])
  if bidx>1 && bidx<=Nz
    zL = Z(bidx-1);
    zH = Z(bidx);
    zi = [zL;zH];
    Bi = [0,1];
  end
  
%   root = ['C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\dx=' num2str(dx*1e3) 'm\'];
  root = ['/home/yhkuo/KKHW24_BASIS/'];
  fn = ['PRECOMPUTED_VERTICAL_MODES_MCStepBUOYat' num2str(zL,'%04.1f') '-' num2str(zH,'%04.1f') 'KM.mat'];

  computed = zeros(size(nsq));
  storedx = zeros(size(nsq));
  storedy = zeros(size(nsq));
  A = zeros([length(Z),size(nsq)]); % (z,ky,kx)
  tcost = zeros(length(nx),1);
  for idx=1:length(nx)
    tic;
    disp(['idx = ' num2str(idx) '/' num2str(Nx)])
    for idy=1:length(ny)
      n2 = nsq(idy,idx);
      if n2~=0 % U=0 if n2==0
        if ~computed(idy,idx)
          try
            a = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idy,idx),Z,zL,zH,1024); %defult d=64
          catch
            disp('!')
            a = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idy,idx),Z,zL,zH,1024*3); %defult d=64
          end
% % %           try
% % %             a = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(effL(idy,idx),Z,zL,zH,1024); %defult d=64
% % %           catch
% % %             disp('!')
% % %             a = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(effL(idy,idx),Z,zL,zH,1024*3); %defult d=64
% % %           end
          A(:,idy,idx) = a;
          n2 = nsq(idy,idx);
          computed(nsq==n2) = 1;
          storedx(nsq==n2) = idx;
          storedy(nsq==n2) = idy;
        else
          A(:,idy,idx) = A(:,storedy(idy,idx),storedx(idy,idx));
        end
      end
    end
    tcost(idx) = toc;
    disp(['Elapsed time is ' num2str(tcost(idx)) ' seconds.'])
  end

  % Fix possible overflow
  A(~isfinite(A)) = 0;

  save([root fn],'Nx','Ny','Lx','Ly','kx','ky','Z','zL','zH','Bi','A','-v7.3')
  
  disp(['Elapsed time for 1 layer is ' num2str(sum(tcost)) ' seconds.'])

%   plot(1:length(nx),tcost)
%   ylabel('T cost (s)')
%   title(['T cost = ' num2str(sum(tcost)) ' (s)'])
%   set(gca,'FontSize',15)
%   grid on
%   box on
end