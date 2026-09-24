% Assuming Nx, Ny = 2^n; 512x512x256 ~ 1.25G
Nx = 880;

Lx = 880; % km

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

Z = [0:0.2:40]'; % dz=200m~4dx/2pi
Nz = length(Z);

for bidx=2:201
  disp(['bidx=' num2str(bidx)])
  if bidx>1 && bidx<=Nz
    zL = Z(bidx-1);
    zH = Z(bidx);
    zi = [zL;zH];
    Bi = [0,1];
  end

%   root = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
  root = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\2D_delta_v\';
%   root = 'D:\Mog\WKB_Reconstruct\COLD_TOP_FE_STEP_BASIS\';
%   root = '/home/yhkuo/Desktop/COLD_TOP_FE_STEP_BASIS/';%'/media/yhkuo/BUOY_CALC/Mog/WKB_Reconstruct/WKB_3D_Reconstruct_WtUt/PRECOMPUTED_VERTICAL_MODES/';
  fn = ['PRECOMPUTED_VERTICAL_MODES_MCStepDHvat' num2str(zL,'%04.1f') '-' num2str(zH,'%04.1f') 'KM.mat'];

  computed = zeros(size(nsq));
  storedx = zeros(size(nsq));
%   A = zeros([length(Z),size(nsq)]); % (z,kx)
  ADV = zeros([length(Z),size(nsq)]); % (z,kx)
  tcost = zeros(length(nx),1);
  for idx=1:length(nx)
    tic;
    disp(['idx = ' num2str(idx) '/' num2str(Nx)])
    factor = 0;
    n2 = nsq(idx);
    if n2~=0 % U=0 if n2==0
      if ~computed(idx)
        while ~computed(idx)
%           lastwarn('','') 
%           a = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idx),Z,zL,zH,16*factor); %defult d=0: no symbolic computation for speed
%           [warnMsg, warnId] = lastwarn();
%           if ~isempty(warnMsg)
%             factor = factor+1 + (factor==0); %factor=0-->2-->3-->4...
%             disp(['Updating: (idx,factor) = (' num2str(idx) ',' num2str(factor) ')'])
%           else
%             A(:,idx) = a;
%             n2 = nsq(idx);
%             computed(nsq==n2) = 1;
%             storedx(nsq==n2) = idx;
%             %disp(['(' num2str(idx) ',' num2str(idy) ',' num2str(factor) ')'])
%           end
          ADV(:,idx) = VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idx),Z,zL,zH);
          n2 = nsq(idx);
          computed(nsq==n2) = 1;
          storedx(nsq==n2) = idx;
        end
      else
%         A(:,idx) = A(:,storedx(idx));
        ADV(:,idx) = ADV(:,storedx(idx));
      end
    end
    tcost(idx) = toc;
%     disp(['Elapsed time is ' num2str(tcost(idx)) ' seconds.'])
  end
  disp(['TOTAL elapsed time is ' num2str(sum(tcost)) ' seconds.'])

  % Fix possible overflow
%   A(~isfinite(A)) = 0;
  ADV(~isfinite(ADV)) = 0;

  save([root fn],'Nx','Lx','kx','Z','zL','zH','Bi','ADV','-v7.3')

% % % Assuming Nx, Ny = 2^n; 512x512x256 ~ 1.25G
% % Nx = 880;
% % 
% % Lx = 880; % km
% % 
% % if mod(Nx,2)==0
% %   nx = [0:Nx/2-1 Nx/2 -Nx/2+1:-1]';
% %   kx = (2*pi/Lx)*nx;
% %   nsq = nx.^2; % (kx)
% %   L = Lx./sqrt(nsq);
% % else
% %   nx = [0:(Nx-1)/2 -(Nx-1)/2:-1]';
% %   kx = (2*pi/Lx)*nx;
% %   nsq = nx.^2; % (kx)
% %   L = Lx./sqrt(nsq);
% % end
% % 
% % Z = [0:0.2:40]'; % dz=200m~4dx/2pi
% % Nz = length(Z);
% % 
% % for bidx=2:201
% %   disp(['bidx=' num2str(bidx)])
% %   if bidx>1 && bidx<=Nz
% %     zL = Z(bidx-1);
% %     zH = Z(bidx);
% %     zi = [zL;zH];
% %     Bi = [0,1];
% %   end
% % 
% % %   root = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
% %   root = 'C:\Users\yhkuo\MATCHING_STEP_BASIS\2D_DOMAIN\';
% % %   root = 'D:\Mog\WKB_Reconstruct\COLD_TOP_FE_STEP_BASIS\';
% % %   root = '/home/yhkuo/Desktop/COLD_TOP_FE_STEP_BASIS/';%'/media/yhkuo/BUOY_CALC/Mog/WKB_Reconstruct/WKB_3D_Reconstruct_WtUt/PRECOMPUTED_VERTICAL_MODES/';
% %   fn = ['PRECOMPUTED_VERTICAL_MODES_MCStepBUOYat' num2str(zL,'%04.1f') '-' num2str(zH,'%04.1f') 'KM.mat'];
% % 
% %   computed = zeros(size(nsq));
% %   storedx = zeros(size(nsq));
% %   A = zeros([length(Z),size(nsq)]); % (z,kx)
% %   ADX = zeros([length(Z),size(nsq)]); % (z,kx)
% %   tcost = zeros(length(nx),1);
% %   for idx=1:length(nx)
% %     tic;
% %     disp(['idx = ' num2str(idx) '/' num2str(Nx)])
% %     factor = 0;
% %     n2 = nsq(idx);
% %     if n2~=0 % U=0 if n2==0
% %       if ~computed(idx)
% %         while ~computed(idx)
% %           lastwarn('','') 
% %           a = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idx),Z,zL,zH,16*factor); %defult d=0: no symbolic computation for speed
% %           [warnMsg, warnId] = lastwarn();
% %           if ~isempty(warnMsg)
% %             factor = factor+1 + (factor==0); %factor=0-->2-->3-->4...
% %             disp(['Updating: (idx,factor) = (' num2str(idx) ',' num2str(factor) ')'])
% %           else
% %             A(:,idx) = a;
% %             n2 = nsq(idx);
% %             computed(nsq==n2) = 1;
% %             storedx(nsq==n2) = idx;
% %             %disp(['(' num2str(idx) ',' num2str(idy) ',' num2str(factor) ')'])
% %           end
% %           ADX(:,idx) = DH_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idx),kx(idx),Z,zL,zH);
% %         end
% %       else
% %         A(:,idx) = A(:,storedx(idx));
% %         ADX(:,idx) = sign(kx(idx))*ADX(:,storedx(idx));
% %       end
% %     end
% %     tcost(idx) = toc;
% %     disp(['Elapsed time is ' num2str(tcost(idx)) ' seconds.'])
% %   end
% %   disp(['TOTAL elapsed time is ' num2str(sum(tcost)) ' seconds.'])
% % 
% %   % Fix possible overflow
% %   A(~isfinite(A)) = 0;
% %   ADX(~isfinite(ADX)) = 0;
% % 
% %   save([root fn],'Nx','Lx','kx','Z','zL','zH','Bi','A','ADX','-v7.3')

%   plot(1:length(nx),tcost)
%   ylabel('T cost (min)')
%   title(['T cost = ' num2str(sum(tcost)/60) ' (s)'])
%   set(gca,'FontSize',15)
%   grid on
%   box on
end

% % % % Assuming Nx, Ny = 2^n; 512x512x256 ~ 1.25G
% % % Nx = 75;
% % % 
% % % Lx = 75; % km
% % % 
% % % if mod(Nx,2)==0
% % %   nx = [0:Nx/2-1 Nx/2 -Nx/2+1:-1]';
% % %   kx = (2*pi/Lx)*nx;
% % %   nsq = nx.^2; % (kx)
% % %   L = Lx./sqrt(nsq);
% % % else
% % %   nx = [0:(Nx-1)/2 -(Nx-1)/2:-1]';
% % %   kx = (2*pi/Lx)*nx;
% % %   nsq = nx.^2; % (kx)
% % %   L = Lx./sqrt(nsq);
% % % end
% % % 
% % % Z = [0:0.2:40]'; % dz=200m~4dx/2pi
% % % Nz = length(Z);
% % % 
% % % for bidx=2:201
% % %   disp(['bidx=' num2str(bidx)])
% % %   if bidx>1 && bidx<=Nz
% % %     zL = Z(bidx-1);
% % %     zH = Z(bidx);
% % %     zi = [zL;zH];
% % %     Bi = [0,1];
% % %   end
% % % 
% % % %   root = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
% % %   root = 'C:\Users\yhkuo\MATCHING_STEP_BASIS\2D_DOMAIN\';
% % % %   root = 'D:\Mog\WKB_Reconstruct\COLD_TOP_FE_STEP_BASIS\';
% % % %   root = '/home/yhkuo/Desktop/COLD_TOP_FE_STEP_BASIS/';%'/media/yhkuo/BUOY_CALC/Mog/WKB_Reconstruct/WKB_3D_Reconstruct_WtUt/PRECOMPUTED_VERTICAL_MODES/';
% % %   fn = ['PRECOMPUTED_VERTICAL_MODES_MCStepBUOYat' num2str(zL,'%04.1f') '-' num2str(zH,'%04.1f') 'KM.mat'];
% % % 
% % %   computed = zeros(size(nsq));
% % %   storedx = zeros(size(nsq));
% % %   A = zeros([length(Z),size(nsq)]); % (z,kx)
% % %   tcost = zeros(length(nx),1);
% % %   for idx=1:length(nx)
% % %     tic;
% % %     disp(['idx = ' num2str(idx) '/' num2str(Nx)])
% % %     factor = 0;
% % %     n2 = nsq(idx);
% % %     if n2~=0 % U=0 if n2==0
% % %       if ~computed(idx)
% % %         while ~computed(idx)
% % %           lastwarn('','') 
% % %           a = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idx),Z,zL,zH,16*factor); %defult d=0: no symbolic computation for speed
% % %           [warnMsg, warnId] = lastwarn();
% % %           if ~isempty(warnMsg)
% % %             factor = factor+1 + (factor==0); %factor=0-->2-->3-->4...
% % %             disp(['Updating: (idx,factor) = (' num2str(idx) ',' num2str(factor) ')'])
% % %           else
% % %             A(:,idx) = a;
% % %             n2 = nsq(idx);
% % %             computed(nsq==n2) = 1;
% % %             storedx(nsq==n2) = idx;
% % %             %disp(['(' num2str(idx) ',' num2str(idy) ',' num2str(factor) ')'])
% % %           end
% % %         end
% % %       else
% % %         A(:,idx) = A(:,storedx(idx));
% % %       end
% % %     end
% % %     tcost(idx) = toc;
% % %     disp(['Elapsed time is ' num2str(tcost(idx)) ' seconds.'])
% % %   end
% % %   disp(['TOTAL elapsed time is ' num2str(sum(tcost)) ' seconds.'])
% % % 
% % %   % Fix possible overflow
% % %   A(~isfinite(A)) = 0;
% % % 
% % %   save([root fn],'Nx','Lx','kx','Z','zL','zH','Bi','A','-v7.3')
% % % 
% % % %   plot(1:length(nx),tcost)
% % % %   ylabel('T cost (min)')
% % % %   title(['T cost = ' num2str(sum(tcost)/60) ' (s)'])
% % % %   set(gca,'FontSize',15)
% % % %   grid on
% % % %   box on
% % % end

% % % Assuming Nx, Ny = 2^n; 512x512x256 ~ 1.25G
% % Nx = 120;
% % 
% % Lx = 120; % km
% % 
% % if mod(Nx,2)==0
% %   nx = [0:Nx/2-1 Nx/2 -Nx/2+1:-1]';
% %   kx = (2*pi/Lx)*nx;
% %   nsq = nx.^2; % (kx)
% %   L = Lx./sqrt(nsq);
% % else
% %   nx = [0:(Nx-1)/2 -(Nx-1)/2:-1]';
% %   kx = (2*pi/Lx)*nx;
% %   nsq = nx.^2; % (kx)
% %   L = Lx./sqrt(nsq);
% % end
% % 
% % Z = [0:0.2:40]'; % dz=200m~4dx/2pi
% % Nz = length(Z);
% % 
% % for bidx=2:201
% %   disp(['bidx=' num2str(bidx)])
% %   if bidx>1 && bidx<=Nz
% %     zL = Z(bidx-1);
% %     zH = Z(bidx);
% %     zi = [zL;zH];
% %     Bi = [0,1];
% %   end
% % 
% % %   root = 'C:\Users\r9822\Documents\MATLAB\MATCHING_STEP_BASIS\';
% %   root = 'C:\Users\yhkuo\MATCHING_STEP_BASIS\2D_DOMAIN\';
% % %   root = 'D:\Mog\WKB_Reconstruct\COLD_TOP_FE_STEP_BASIS\';
% % %   root = '/home/yhkuo/Desktop/COLD_TOP_FE_STEP_BASIS/';%'/media/yhkuo/BUOY_CALC/Mog/WKB_Reconstruct/WKB_3D_Reconstruct_WtUt/PRECOMPUTED_VERTICAL_MODES/';
% %   fn = ['PRECOMPUTED_VERTICAL_MODES_MCStepBUOYat' num2str(zL,'%04.1f') '-' num2str(zH,'%04.1f') 'KM.mat'];
% % 
% %   computed = zeros(size(nsq));
% %   storedx = zeros(size(nsq));
% %   A = zeros([length(Z),size(nsq)]); % (z,kx)
% %   tcost = zeros(length(nx),1);
% %   for idx=1:length(nx)
% %     tic;
% %     disp(['idx = ' num2str(idx) '/' num2str(Nx)])
% %     factor = 0;
% %     n2 = nsq(idx);
% %     if n2~=0 % U=0 if n2==0
% %       if ~computed(idx)
% %         while ~computed(idx)
% %           lastwarn('','') 
% %           a = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L(idx),Z,zL,zH,16*factor); %defult d=0: no symbolic computation for speed
% %           [warnMsg, warnId] = lastwarn();
% %           if ~isempty(warnMsg)
% %             factor = factor+1 + (factor==0); %factor=0-->2-->3-->4...
% %             disp(['Updating: (idx,factor) = (' num2str(idx) ',' num2str(factor) ')'])
% %           else
% %             A(:,idx) = a;
% %             n2 = nsq(idx);
% %             computed(nsq==n2) = 1;
% %             storedx(nsq==n2) = idx;
% %             %disp(['(' num2str(idx) ',' num2str(idy) ',' num2str(factor) ')'])
% %           end
% %         end
% %       else
% %         A(:,idx) = A(:,storedx(idx));
% %       end
% %     end
% %     tcost(idx) = toc;
% %     disp(['Elapsed time is ' num2str(tcost(idx)) ' seconds.'])
% %   end
% %   disp(['TOTAL elapsed time is ' num2str(sum(tcost)) ' seconds.'])
% % 
% %   % Fix possible overflow
% %   A(~isfinite(A)) = 0;
% % 
% %   save([root fn],'Nx','Lx','kx','Z','zL','zH','Bi','A','-v7.3')
% % 
% % %   plot(1:length(nx),tcost)
% % %   ylabel('T cost (min)')
% % %   title(['T cost = ' num2str(sum(tcost)/60) ' (s)'])
% % %   set(gca,'FontSize',15)
% % %   grid on
% % %   box on
% % end