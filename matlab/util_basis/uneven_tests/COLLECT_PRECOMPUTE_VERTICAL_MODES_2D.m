%% Collect for 2D domain when only one pre-computed file is needed
basis_dir = 'D:\MATCHING_STEP_BASIS\KHN26\';
basis_fn = 'PRECOMPUTED_VERTICAL_MODES_2D_4UNEVEN_dx=625m.mat';
PLOT4DOUBLECHECK = 1;
DELETE_REDUNDANT_FILES = 1; %<--will delete files created by PRECOMPUTE_VERTICAL_MODES_2D.m

%%
list = dir([basis_dir 'PRECOMPUTED_VERTICAL_MODES_2Dat*KM.mat']);

fidx = 1;
fn = list(fidx).name;
load([basis_dir fn],'kx','Lx','Nx','Z');

a = nan(length(Z),length(kx),length(Z)-1);
adv = nan(length(Z),length(kx),length(Z)-1);
adx = nan(length(Z),length(kx),length(Z)-1);
zh = nan(length(Z)-1,1);
zl = nan(length(Z)-1,1);

for fidx=1:length(list)
  disp([num2str(fidx) '/' num2str(length(list))])
  fn = list(fidx).name;
  load([basis_dir fn],'A','ADV','ADX','zH','zL')
  a(:,:,fidx) = A;
  adv(:,:,fidx) = ADV;
  adx(:,:,fidx) = ADX;
  zh(fidx) = zH;
  zl(fidx) = zL;
end
A = a;
ADV = adv;
ADX = adx;
% ADX(:,Nx/2+1,:) = 0; % Modification for kx=Nx/2 mode (for aliasing)
zH = zh;
zL = zl;
Description = {'A(z,kx,B)=rho_0(z)*fft(a) (kx) with rho_0(z)*B(z)=1 for zL<=z<=zH and zero elsewhere; length in km.';
               'ADX(z,kx,DH)=-i*rho_0(z)*fft(a) (kx) with x-component of D_H=1 for zL<=z<=zH and zero elsewhere; length in km.'};

save([basis_dir basis_fn],"Description","zL","zH","A",'ADV','ADX','kx','Lx','Nx','Z','-v7.3');

disp('Double check all values are finite (hint: 0 is good):')
disp(sum(~isfinite(A(:))))
disp(sum(~isfinite(ADV(:))))
disp(sum(~isfinite(ADX(:))))
disp(sum(~isfinite(zL)))
disp(sum(~isfinite(zH)))

%%
if PLOT4DOUBLECHECK

  figure
  subplot(1,3,1)
  plot(squeeze(A(:,25,:)),Z)
  title('A')
  subplot(1,3,2)
  plot(squeeze(ADV(:,25,:)),Z)
  title('ADV')
  subplot(1,3,3)
  plot(squeeze(ADX(:,25,:)),Z)
  title('ADX')
end

if DELETE_REDUNDANT_FILES
  delete([basis_dir 'PRECOMPUTED_VERTICAL_MODES_2Dat*KM.mat'])
end