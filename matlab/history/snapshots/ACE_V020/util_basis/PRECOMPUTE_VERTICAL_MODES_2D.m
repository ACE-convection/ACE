% Assuming Nx, Ny = 2^n; 512x512x256 ~ 1.25G
basis_dir = 'D:\MATCHING_STEP_BASIS\KHN26\';
Lx = 880; % km
Nx = 880; % Must be an integer
Z = [0:0.2:40]'; % km; Vertical grid; recommend dz=200m~4dx/2pi

%%
if mod(Nx,2)==0
  nx = [0:Nx/2-1 Nx/2 -Nx/2+1:-1]';
  kx = (2*pi/Lx)*nx;
  nsq = nx.^2; % (kx)
  L = Lx./sqrt(nsq);
else
  nx = [0:(Nx-1)/2 -(Nx-1)/2:-1]';
  kx = (2*pi/Lx)*nx;
  nsq = nx.^2; % (kx)
  L = Lx./sqrt(nsq);
end

Nz = length(Z);

for bidx=2:length(Z)
  disp(['bidx=' num2str(bidx)])
  if bidx>1 && bidx<=Nz
    zL = Z(bidx-1);
    zH = Z(bidx);
    zi = [zL;zH];
    Bi = [0,1];
  end
  
  fn = ['PRECOMPUTED_VERTICAL_MODES_2Dat' num2str(zL,'%04.1f') '-' num2str(zH,'%04.1f') 'KM.mat'];

  computed = zeros(size(nsq));
  storedx = zeros(size(nsq));
  A = zeros([length(Z),size(nsq)]); % (z,kx)
  ADV = zeros([length(Z),size(nsq)]); % (z,kx)
  ADX = zeros([length(Z),size(nsq)]); % (z,kx)
  tcost = zeros(length(nx),1);
  for idx=1:length(nx)
    tic;
    disp(['idx = ' num2str(idx) '/' num2str(Nx)])
    factor = 0;
    n2 = nsq(idx);
    if n2~=0 % U=0 if n2==0
      if ~computed(idx)
        while ~computed(idx)
          A(:,idx) = vertical_solutions_reconstruct_util(L(idx),Z,zL,zH,'N_ij');
          ADV(:,idx) = vertical_solutions_reconstruct_util(L(idx),Z,zL,zH,'N_ij^h');
          ADX(:,idx) = vertical_solutions_reconstruct_util(L(idx),Z,zL,zH,'N_ij(d/dz)');
          n2 = nsq(idx);
          computed(nsq==n2) = 1;
          storedx(nsq==n2) = idx;
        end
      else
        A(:,idx) = A(:,storedx(idx));
        ADV(:,idx) = ADV(:,storedx(idx));
        ADX(:,idx) = sign(kx(idx))*ADX(:,storedx(idx));
      end
    end
    tcost(idx) = toc;
  end
  disp(['TOTAL elapsed time is ' num2str(sum(tcost)) ' seconds.'])

  % Fix possible overflow
  A(~isfinite(A)) = 0;
  ADV(~isfinite(ADV)) = 0;
  ADX(~isfinite(ADX)) = 0;

  save([basis_dir fn],'Nx','Lx','kx','Z','zL','zH','Bi','A','ADV','ADX','-v7.3')

  plot(1:length(nx),tcost)
  ylabel('T cost (min)')
  title(['T cost = ' num2str(sum(tcost)/60) ' (s)'])
  set(gca,'FontSize',15)
  grid on
  box on
end