function MF = ImDiffMF(MF,dt)
global rho_mf k dz Nzm eddiffu eddiwin
  % disp(t)
  Xext = [-MF(k:-1:2);MF];
  Nzext = Nzm+k-1; %=length(Xext)/3
  dXextdz = zeros(Nzext,1);

  % Compute MFh(zm+dz/2) from MF(zm) as the mean of up- and down-wind approximations
  LMFh = zeros(Nzm,1); % MFh from more left stencil points
  RMFh = zeros(Nzm,1); % MFh from more right stencil points
  for idz=k+1:Nzext-k+1
    LMFh(idz-k) = reconstruction_weno(k, Xext([idz-k:idz+k-2]) );
    RMFh(idz-k) = reconstruction_weno(k, Xext(flip([idz-k+1:idz+k-1])) );
  end
  MFh = (LMFh + RMFh)/2;
  for idz=k+1:Nzext-k
    % Using WENO-dev
    dXextdz(idz)...
        = ( reconstruction_weno(k, Xext( [idz-k+1:idz+k-1]*(MFh(idz-k+1)>=0)+flip([idz-k+2:idz+k])*(MFh(idz-k+1)<0) ) ) ...
           - reconstruction_weno(k, Xext( [idz-k:idz+k-2]*(MFh(idz-k)>=0)+flip([idz-k+1:idz+k-1])*(MFh(idz-k)<0) ) ) )/dz;
  end
  % First zero at zm=0 (dXdz~=0 but dXdt=0 at the end of computation)
  % zeros(k,1) for domain top<---to be improved!!!!!
  dXdz = [0; dXextdz(k+1:Nzext-k); zeros(k,1)]; %length(dXdz)=Nzm  
  % Eddy Diffusion for Momentum
  ED = abs(dXdz)*( eddiffu*(max(MF./rho_mf)-min(MF./rho_mf))/max(abs(dXdz)+eps)/dz );
  ED = movmax(ED,[1 1]*eddiwin);
  ED = conv(ED,ones(2*eddiwin+1,1)/(2*eddiwin+1),'same')*dt; %length(dXdz)=Nzm
  Mat = sparse(1:Nzm-2,1:Nzm-2,1+2*ED(2:end-1),Nzm-2,Nzm-2) +...
        sparse(1:Nzm-3,2:Nzm-2,-ED(2:end-2),Nzm-2,Nzm-2) +...
        sparse(2:Nzm-2,1:Nzm-3,-ED(3:end-1),Nzm-2,Nzm-2);
  MF(2:end-1) = Mat\MF(2:end-1);
  MF([1,end-10:end]) = 0;
end