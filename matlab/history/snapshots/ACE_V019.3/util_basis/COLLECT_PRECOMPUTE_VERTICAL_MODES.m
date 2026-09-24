%% Collect when only one pre-computed file is needed
list = dir('PRECOMPUTED_VERTICAL_MODES_MCStepBUOYat*KM.mat');

fidx = 1;
fn = list(fidx).name;
load(fn,'kx','ky','Lx','Ly','Nx','Ny','Z');

a = nan(length(Z),length(kx),length(ky),length(Z)-1);
zh = nan(length(Z)-1,1);
zl = nan(length(Z)-1,1);

for fidx=1:length(list)
  disp([num2str(fidx) '/' num2str(length(list))])
  fn = list(fidx).name;
  load(fn,'A','zH','zL')
  a(:,:,:,fidx) = A;
  zh(fidx) = zH;
  zl(fidx) = zL;
end
A = a;
zH = zh;
zL = zl;
Description = 'A(z,kx,ky,B)=rho_0(z)*fft(a) (kx,ky) with rho_0(z)*B(z)=1 for zL<=z<=zH and zero elsewhere; length in km.';

save('PRECOMPUTED_VERTICAL_MODES_MCStepBASIS.mat',"Description","zL","zH","A",'kx','ky','Lx','Ly','Nx','Ny','Z','-v7.3');

plot(zH,zL,'x')
sum(~isfinite(A(:)))
sum(~isfinite(zL))
sum(~isfinite(zH))
figure
plot(A(:,30,25,50),Z)

%% Collect for 2D domain when only one pre-computed file is needed
list = dir('PRECOMPUTED_VERTICAL_MODES_MCStepBUOYat*KM.mat');

fidx = 1;
fn = list(fidx).name;
load(fn,'kx','Lx','Nx','Z');

a = nan(length(Z),length(kx),length(Z)-1);
adx = nan(length(Z),length(kx),length(Z)-1);
zh = nan(length(Z)-1,1);
zl = nan(length(Z)-1,1);

for fidx=1:length(list)
  disp([num2str(fidx) '/' num2str(length(list))])
  fn = list(fidx).name;
  load(fn,'A','ADX','zH','zL')
  a(:,:,fidx) = A;
  adx(:,:,fidx) = ADX;
  zh(fidx) = zH;
  zl(fidx) = zL;
end
A = a;
ADX = adx;
ADX(:,Nx/2+1,:) = 0; % Modification for kx=Nx/2 mode (for aliasing)
zH = zh;
zL = zl;
Description = {'A(z,kx,B)=rho_0(z)*fft(a) (kx) with rho_0(z)*B(z)=1 for zL<=z<=zH and zero elsewhere; length in km.';
               'ADX(z,kx,DH)=-i*rho_0(z)*fft(a) (kx) with x-component of D_H=1 for zL<=z<=zH and zero elsewhere; length in km.'};

save('PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_2D.mat',"Description","zL","zH","A",'ADX','kx','Lx','Nx','Z','-v7.3');

plot(zH,zL,'x')
sum(~isfinite(A(:)))
sum(~isfinite(ADX(:)))
sum(~isfinite(zL))
sum(~isfinite(zH))
figure
subplot(1,2,1)
plot(squeeze(A(:,25,:)),Z)
subplot(1,2,2)
plot(squeeze(ADX(:,25,:)),Z)

%% Collect when multiple pre-computed files
list = dir('PRECOMPUTED_VERTICAL_MODES_MCStepBUOYat*KM.mat');

fidx = 1;
fn = list(fidx).name;
load(fn,'kx','ky','Lx','Ly','Nx','Ny','Z');

a = nan(length(Z),length(kx),length(ky),100);
zh = nan(100,1);
zl = nan(100,1);

for fidx=101:200%length(list)
  disp([num2str(fidx) '/' num2str(length(list))])
  fn = list(fidx).name;
  load(fn,'A','zH','zL')
  a(:,:,:,fidx-100) = A;
  zh(fidx-100) = zH;
  zl(fidx-100) = zL;
end
A = a;
zH = zh;
zL = zl;
Description = 'A(z,kx,ky,B)=rho_0(z)*fft(a) (kx,ky) with rho_0(z)*B(z)=1 for zL<=z<=zH and zero elsewhere; length in km.';

save('PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_20-40KM.mat',"Description","zL","zH","A",'kx','ky','Lx','Ly','Nx','Ny','Z','-v7.3');

plot(1:length(zH),zH,'x')
% plot(zH,zL,'x')
% sum(~isfinite(A(:)))
% sum(~isfinite(zL))
% sum(~isfinite(zH))
% plot(A(:,30,25,50),Z)