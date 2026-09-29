%% Collect when only one pre-computed file is needed
list = dir('PRECOMPUTED_VERTICAL_MODES_MCStepDHat*KM.mat');

fidx = 1;
fn = list(fidx).name;
load(fn,'kx','ky','Lx','Ly','Nx','Ny','Z');


figure
for patch=1:10
  A = nan(length(Z),length(kx),length(ky),length(list)/10);
  zH = nan(length(list)/10,1);
  zL = nan(length(list)/10,1);
  
  foffset = (patch-1)*length(list)/10;
  for fidx=1:length(list)/10
    disp([num2str(fidx+foffset) '/' num2str(length(list))])
    fn = list(fidx+foffset).name;
    a = load(fn,'A','zH','zL');
    A(:,:,:,fidx) = a.('A');
    zH(fidx) = a.('zH');
    zL(fidx) = a.('zL');
  end
  Description = 'A(z,ky,kx,Bi)=rho_0(z)*fft(a) (ky,kx) with Bi=1 for zL<=z<=zH and zero elsewhere; length in km.';
  
  save(['PRECOMPUTED_VERTICAL_MODES_hireStepBASIS_' num2str(patch,'%02.0f') '.mat'],...
       "Description","zL","zH","A",'kx','ky','Lx','Ly','Nx','Ny','Z','-v7.3');

  subplot(2,5,patch)
  plot(zH,zL,'x')
  sum(~isfinite(A(:)))
  sum(~isfinite(zL))
  sum(~isfinite(zH))
  clear A
end

figure
plot(A(:,6,Nx/2+1,5),Z)
hold on
plot(A(:,Nx/2+1,6,5),Z)
plot(A(:,6,6,5),Z)
plot(A(:,6,end-7,5),Z)