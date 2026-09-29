%% Collect when only one pre-computed file is needed
list = dir('PRECOMPUTED_VERTICAL_MODES_MCStepDHat*KM.mat');

fidx = 1;
fn = list(fidx).name;
load(fn,'kx','ky','Lx','Ly','Nx','Ny','Z');

% a = nan(length(Z),length(kx),length(ky),length(Z)-1);
% zh = nan(length(Z)-1,1);
% zl = nan(length(Z)-1,1);
ADH = nan(length(Z),length(kx),length(ky),(length(Z)-1)/2);
zH = nan((length(Z)-1)/2,1);
zL = nan((length(Z)-1)/2,1);

for fidx=1:length(list)/2
  disp([num2str(fidx) '/' num2str(length(list))])
  fn = list(fidx).name;
  adx = load(fn,'ADX','zH','zL');
  ADH(:,:,:,fidx) = adx.('ADX');
  zH(fidx) = adx.('zH');
  zL(fidx) = adx.('zL');
end
% ADX = a; % (z,ky,kx,DH)
% zH = zh;
% zL = zl;
ADH(:,:,Nx/2+1,:) = 0; % Modification for kx=Nx/2 mode (for aliasing)
ADH(~isfinite(ADH)) = 0;
Description = 'ADH(z,ky,kx,DH)=rho_0(z)*fft(a) (ky,kx) solving Poisson equation with DH=1 for zL<=z<=zH and zero elsewhere; length in km.';

save('PRECOMPUTED_VERTICAL_MODES_DHStepBASIS_0-20KM.mat',"Description","zL","zH","ADH",'kx','ky','Lx','Ly','Nx','Ny','Z','-v7.3');

plot(zH,zL,'x')
sum(~isfinite(ADH(:)))
sum(~isfinite(zL))
sum(~isfinite(zH))
figure
plot(ADH(:,6,Nx/2+1,5),Z)
hold on
plot(ADH(:,Nx/2+1,6,5),Z)
plot(ADH(:,6,6,5),Z)
plot(ADH(:,6,end-7,5),Z)

%%
clear ADH
ADH = nan(length(Z),length(kx),length(ky),(length(Z)-1)/2);
zH = nan((length(Z)-1)/2,1);
zL = nan((length(Z)-1)/2,1);

for fidx=length(list)/2+1:length(list)
  disp([num2str(fidx) '/' num2str(length(list))])
  fn = list(fidx).name;
  adx = load(fn,'ADX','zH','zL');
  ADH(:,:,:,fidx-length(list)/2) = adx.('ADX');
  zH(fidx-length(list)/2) = adx.('zH');
  zL(fidx-length(list)/2) = adx.('zL');
end
% ADX = a; % (z,ky,kx,DH)
% zH = zh;
% zL = zl;
ADH(:,:,Nx/2+1,:) = 0; % Modification for kx=Nx/2 mode (for aliasing)
ADH(~isfinite(ADH)) = 0;
Description = 'ADH(z,ky,kx,DH)=rho_0(z)*fft(a) (ky,kx) solving Poisson equation with DH=1 for zL<=z<=zH and zero elsewhere; length in km.';

save('PRECOMPUTED_VERTICAL_MODES_DHStepBASIS_20-40KM.mat',"Description","zL","zH","ADH",'kx','ky','Lx','Ly','Nx','Ny','Z','-v7.3');


%%
%%
%% Collect when only one pre-computed file is needed
list = dir('PRECOMPUTED_VERTICAL_MODES_MCStepDHat*KM.mat');

fidx = 1;
fn = list(fidx).name;
load(fn,'kx','ky','Lx','Ly','Nx','Ny','Z');

% a = nan(length(Z),length(kx),length(ky),length(Z)-1);
% zh = nan(length(Z)-1,1);
% zl = nan(length(Z)-1,1);
ADZ = nan(length(Z),length(kx),length(ky),(length(Z)-1)/2);
zH = nan((length(Z)-1)/2,1);
zL = nan((length(Z)-1)/2,1);

for fidx=1:length(list)/2
  disp([num2str(fidx) '/' num2str(length(list))])
  fn = list(fidx).name;
  adz = load(fn,'ADZ','zH','zL');
  ADZ(:,:,:,fidx) = adz.('ADZ');
  zH(fidx) = adz.('zH');
  zL(fidx) = adz.('zL');
end
% ADZ = a; % (z,ky,kx,DH)
% zH = zh;
% zL = zl;
% ADZ(:,:,Nx/2+1,:) = 0; % Modification for kx=Nx/2 mode (for aliasing)
Description = 'ADZ(z,ky,kx,DH)=rho_0(z)*fft(a) (ky,kx) with x-component of D_H=1 for zL<=z<=zH and zero elsewhere; length in km.';

save('PRECOMPUTED_VERTICAL_MODES_ADZStepBASIS_0-20KM.mat',"Description","zL","zH","ADZ",'kx','ky','Lx','Ly','Nx','Ny','Z','-v7.3');

plot(zH,zL,'x')
sum(~isfinite(ADZ(:)))
sum(~isfinite(zL))
sum(~isfinite(zH))
figure
plot(ADZ(:,6,Nx/2+1,5),Z)
hold on
plot(ADZ(:,Nx/2+1,6,5),Z)
plot(ADZ(:,6,6,5),Z)
plot(ADZ(:,6,end-7,5),Z)

%%
ADZ = nan(length(Z),length(kx),length(ky),(length(Z)-1)/2);
zH = nan((length(Z)-1)/2,1);
zL = nan((length(Z)-1)/2,1);

for fidx=length(list)/2+1:length(list)
  disp([num2str(fidx) '/' num2str(length(list))])
  fn = list(fidx).name;
  adz = load(fn,'ADZ','zH','zL');
  ADZ(:,:,:,fidx-length(list)/2) = adz.('ADZ');
  zH(fidx-length(list)/2) = adz.('zH');
  zL(fidx-length(list)/2) = adz.('zL');
end
% ADZ = a; % (z,ky,kx,DH)
% zH = zh;
% zL = zl;
% ADZ(:,:,Nx/2+1,:) = 0; % Modification for kx=Nx/2 mode (for aliasing)
Description = 'ADZ(z,ky,kx,DH)=rho_0(z)*fft(a) (ky,kx) with x-component of D_H=1 for zL<=z<=zH and zero elsewhere; length in km.';

save('PRECOMPUTED_VERTICAL_MODES_ADZStepBASIS_20-40KM.mat',"Description","zL","zH","ADZ",'kx','ky','Lx','Ly','Nx','Ny','Z','-v7.3');
