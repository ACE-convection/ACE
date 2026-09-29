% Assuming Nx, Ny = 2^n; 512x512x256 ~ 1.25G
Nx = 512;
Ny = 512;

Lx = 64; % km
Ly = 64;

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

for bidx=152:201%Nz
  disp(['bidx=' num2str(bidx)])
  if bidx>1 && bidx<=Nz
    zL = Z(bidx-1);
    zH = Z(bidx);
    zi = [zL;zH];
    Bi = [0,1];
  end
  
  root = 'C:\Users\yhkuo\Documents\MATLAB\MATCHING_STEP_BASIS\D_H\';
  % root = 'D:\MATCHING_STEP_BASIS\D_H\';
  % root = '/home/yhkuo/MATCHING_STEP_BASIS/LARGE_DOMAIN/'; %Nx=Ny=1500;Lx=Ly=150km
  fn = ['PRECOMPUTED_VERTICAL_MODES_MCStepDHat' num2str(zL,'%04.1f') '-' num2str(zH,'%04.1f') 'KM.mat'];
  
  computed = zeros(size(nsq));
  storedx = zeros(size(nsq));
  storedy = zeros(size(nsq));
  A = zeros([length(Z),size(nsq)]); % (z,ky,kx)
  computed2 = zeros(size(nsq));
  storedx2 = zeros(size(nsq));
  storedy2 = zeros(size(nsq));
  ADZ = zeros([length(Z),size(nsq)]); % (z,ky,kx)
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
            ADZ(:,idy,idx) = DH_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idy,idx),2*pi/L(idy,idx),Z,zL,zH);
            n2 = nsq(idy,idx);
            computed(nsq==n2) = 1;
            storedx(nsq==n2) = idx;
            storedy(nsq==n2) = idy;
          end
        else
          ADZ(:,idy,idx) = ADZ(:,storedy(idy,idx),storedx(idy,idx));
        end
        %%
        % % if ~computed2(idy,idx)
        % %   while ~computed2(idy,idx)
        % %     ADX(:,idy,idx) = DH_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idy,idx),kx(idx),Z,zL,zH);
        % %     computed2(abs(ny)==abs(ny(idy)),abs(nx)==abs(nx(idx))) = 1;
        % %     storedx2(abs(ny)==abs(ny(idy)),abs(nx)==abs(nx(idx))) = idx;
        % %     storedy2(abs(ny)==abs(ny(idy)),abs(nx)==abs(nx(idx))) = idy;
        % %     %disp(['(' num2str(idx) ',' num2str(idy) ',' num2str(factor) ')'])
        % %   end
        % % else
        % %   ADX(:,idy,idx) = sign(kx(idx))*ADX(:,storedy2(idy,idx),storedx2(idy,idx));
        % % end
      end
    end
    tcost(idx) = toc;
    disp(['Elapsed time is ' num2str(tcost(idx)) ' seconds.'])
  end
  disp(['TOTAL elapsed time is ' num2str(sum(tcost)) ' seconds.'])

  % Fix possible overflow
  % % % A(~isfinite(A)) = 0;
  % % % save([root fn],'Nx','Ny','Lx','Ly','kx','ky','Z','zL','zH','Bi','A','-v7.3')
  ADZ(~isfinite(ADZ)) = 0;
  save([root fn],'Nx','Ny','Lx','Ly','kx','ky','Z','zL','zH','Bi','ADZ','-v7.3')

%   plot(1:length(nx),tcost)
%   ylabel('T cost (min)')
%   title(['T cost = ' num2str(sum(tcost)/60) ' (s)'])
%   set(gca,'FontSize',15)
%   grid on
%   box on
end