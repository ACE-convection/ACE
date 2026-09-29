%% Adopted from WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UNITSTEP.m       ||
% Turned into a utility function for 3D Buoyancy Inversion via WKB. ||
%====================================================================|
% For inversion dw/dt (d = partial derivative) from bouyancy, a set of
%  solutions have been derived via WKB approach (verified in
%  WKB_VERTICAL_SOLUTIONS_VERIFICATION.m).
% This script reconstructs dw/dt from a given buoyancy profile B 
%  by approximatingmatching B with piecewise polynomials of degree<=2, 
%  solving with piecewise solutions and matching 0th and 1st derivatives.
% This script is modified from an earlier version for isentropic density;
%  the current computation assumes an exponentailly decay density
%  exp(-z/H).

%% Solutions to % u'' - lambda^2 * u = -lambda0^2 * sqrt(rho_0) * B
%   s = z/H; ()'=d/ds; rho_0(z)=exp(-z/H);
%   lambda0=2*pi*H/L; lambda^2=lambda0^2+1/4;
% % Homogeneous solutions
%   up = exp(lambda*s);
%   un = exp(-lambda*s);
%   up' = lambda.*up;
%   un' = -lambda.*un;
% % Inhomogeneous solution (for B=constant in zL<z<zH & vanishing elsewhere)
%   uin = exp(-s/2);
%   uin' = -uin/2;
% Iterative approximation valid for more general B provide computation stable.
% And recall: rho_0 ~ exp(-z/H) & A = rho_0*dw/dt = exp(0.5*z/H) * U

% function [U,dAdz] = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L,Z,zL,zH)
function U = WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L,Z,zL,zH,d)
%% Reconstruct U=sqrt(rho_0).*dw/dt on grid points Z for horizontal wavelength L
  
  %% Edit "SECTION DEFINING BUOYANCY" for different buoyancy profile

  %% Increase significant digits (using symbolic via vpa) 
  % When N increases, the matching conditions leads to a linear system with
  %  super large condition number.
  if nargin==4
    d = 64; % defult digits unless specified by input
  end
  
  if d>0
    digits(d)
    % Evaluate homogeneous and inhomogeneous solutions with vpa only when
    %  needed for speed.

    % Constants
  %   H = vpa(9.5525); % Units: km
    % L = vpa(3); % Units: km
    lambda0 = 2*pi/L;
    lambdaSq = lambda0^2;

    %% B = piecewise polynomial of degree <= 2
    % Define b0, b1, b2 s.t. B(z)=b0(i)+b1(i)*z+b2(i)*z^2 in I_i=[zi(i-1),zi(i)]
    %==========================================================================
    % BEGIN SECTION DEFINING BUOYANCY
    % B = unit step function
    % disp('Input buoyancy profile...')
    z0 = vpa(0); % zi(0)==z0; zi(1)=z0 is allowed!
    zi = vpa([zL zH]'); % I_i=[zi(i-1),zi(i)], i=1~N; B=0 for z>z_N
    N = length(zi);
    % z, x, and lx for vpa computations
    z = [z0;zi];
    s = z-mean(zi); %s = z;
    lambda = sqrt(lambdaSq);
    % Back to construct B(z)
    b0 = vpa([0 1]); %<--1st 0 between zi(1) and z0 (will be ignored when lowest zi(1)=z0)
    % b1 = vpa(zeros(size(b0)));
    % b2 = vpa(zeros(size(b0)));
    % B(z) = b0(i) + b1(i)*z + b2(i)*z^2 in I_i; size=length(z)*length(zi)
    % Bz = b0 + b1.*z + b2.*z.^2; % <-- Bz ready for plotting now!
    % bconti to be evaluated later for plotting!
    % bconti = ones(size(z)).*(double(z)>=double(zi(1))&double(z)<=double(zi(2)));
    % END SECTION DEFINING BUOYANCY
    %==========================================================================
  else
    lambda0 = 2*pi/L;
    lambdaSq = lambda0^2;
    z0 = 0; % zi(0)==z0; zi(1)=z0 is allowed!
    zi = [zL zH]'; % I_i=[zi(i-1),zi(i)], i=1~N; B=0 for z>z_N
    N = length(zi);
    z = [z0;zi];
    s = z-mean(zi); %s = z;
    lambda = sqrt(lambdaSq);
    b0 = [0 1]; %<--1st 0 between zi(1) and z0 (will be ignored when lowest zi(1)=z0)
  end
  
  %% Construct homogeneous solutions
  % up & un are independent of B
  % disp('Construct homogeneous solutions...')
  up = exp(-lambda*s);
  un = exp(lambda*s);
  % 1st derivative of up & un
  upp = -lambda*up;
  unp = lambda*un;
  
  %% Construct inhomogeneous solutions
%   disp('Construct inhomogeneous solutions...')
  % Note: B(z) = b0(i) + b1(i)*z + b2(i)*z^2 in z-coordinate is equivalent to
  %  B(s) = -lambda0^2 * sqrt(rho_0) * B(z) = -lambda0^2*exp(-s/2)*b0 (for b1=b2=0)
  %  in s-coordinate.
%   Bs = -lambda0^2 * Bz .* exp(-s/2);
  % Solution components in I_i; expecting ui = cpi*upi + cni*uni + uini
  uin = ones(size(s)).*b0;
  % 1st derivative of uin
  uinp = -0*uin/2.*b0;
  % NOTE: B(z,i)'s and uin(z,i)'s vanishing outside I_i=[zi(i-1),zi(i)]; zi(0)==z0.
  
  %% Set up the linear system to solve for cpi's & cni's
  % C = [cp0 cn0 cp1 cn1 cp2]'; M*C = MC; M = sparse(MI,MJ,MV)<--if without vpa
  % First eq at z=0 (i=0)
  % disp('Construct & solve linear system...')
  MI = [1 1];
  MJ = [1 2];
  MV = [up(1) un(1)];
  MC = [-uin(1,1)];
  for i=1:N-1
    MI = horzcat(MI,[(2*i)*ones(1,4),(2*i+1)*ones(1,4)]);
    MJ = horzcat(MJ,[2*i-1:2*i+2 2*i-1:2*i+2]);
    MV = horzcat(MV,[up(i+1) un(i+1) -up(i+1) -un(i+1) ...
                     upp(i+1) unp(i+1) -upp(i+1) -unp(i+1)]);
    MC = vertcat(MC,[-uin(i+1,i)+uin(i+1,i+1) -uinp(i+1,i)+uinp(i+1,i+1)]');
  end
  % Last eq (i=N)
  i = N;
  MI = horzcat(MI,[(2*i)*ones(1,3),(2*i+1)*ones(1,3)]);
  MJ = horzcat(MJ,[2*i-1:2*i+1 2*i-1:2*i+1]);
  MV = horzcat(MV,[up(i+1) un(i+1) -up(i+1) ...
                   upp(i+1) unp(i+1) -upp(i+1)]);
  MC = vertcat(MC,[-uin(i+1,i) -uinp(i+1,i)]');
  % M = sparse(MI,MJ,MV);
  M = vpa(zeros(2*N+1));
  for i=1:length(MI)
    M(MI(i),MJ(i)) = MV(i);
  end
  C = M\MC;
  
  %% Reconstruct solution
  % disp('Recontruct solution...')
  % vpa --> double for evaluation
  
  % Switch to double when able to speed up
  if log10(max(double(abs(C))))<250
%     H = double(H);
%     L = double(L);
%     lambda0 = double(lambda0);
    lambda = double(lambda);
%     z0 = double(z0);
    zi = double(zi);
    b0 = double(b0);
  end
  
  z = Z;%[0:0.01:15]'; % <--z must contain points in [z0;zi] 
  s = z-mean(zi); %s = z;
  
  % Evaluate homogeneous & inhomogeneous solutions in double
  up = exp(-lambda*s);
  un = exp(lambda*s);
%   upp = -lambda*up;
%   unp = lambda*un;
%   Bz = b0 + b1.*z + b2.*z.^2;
  uin = ones(size(s)).*b0;
%   uinp = -uin/2.*b0;
  
  % Recontruct ui = cpi*upi + cni*uni + uini in I_i
  U = zeros(size(z)); % Total solution
  % UP = zeros(size(z)); % Contribution by up
  % UN = zeros(size(z)); % Contribution by un
  % UIN = zeros(size(z)); % Contribution by uin
  U(z<zi(1)) = C(1)*up(z<zi(1)) + C(2)*un(z<zi(1)) + uin(z<zi(1),1);
  % UP(z<zi(1)) = C(1)*up(z<zi(1));
  % UN(z<zi(1)) = C(2)*un(z<zi(1));
  % UIN(z<zi(1)) = uin(z<zi(1),1);
  for i=2:N
    U(z>=zi(i-1)&z<zi(i)) = C(2*i-1)*up(z>=zi(i-1)&z<zi(i)) + C(2*i)*un(z>=zi(i-1)&z<zi(i)) + uin(z>=zi(i-1)&z<zi(i),i);
  %   UP(z>=zi(i-1)&z<zi(i)) = C(2*i-1)*up(z>=zi(i-1)&z<zi(i));
  %   UN(z>=zi(i-1)&z<zi(i)) = C(2*i)*un(z>=zi(i-1)&z<zi(i));
  %   UIN(z>=zi(i-1)&z<zi(i)) = uin(z>=zi(i-1)&z<zi(i),i);
  end
  U(z>=zi(N)) = C(2*N+1)*up(z>=zi(N));
  % UP(z>=zi(N)) = C(2*N+1)*up(z>=zi(N));
  % Recall: rho_0 ~ exp(-z/H) & rho_0*dw/dt = exp(0.5*z/H) * u
  % A = U.*exp(s/2);
  % AP = UP.*exp(s/2);
  % AN = UN.*exp(s/2);
  % AIN = UIN.*exp(s/2);
  % dWdt = U./exp(s/2);
  % dWPdt = UP./exp(s/2);
  % dWNdt = UN./exp(s/2);
  % dWINdt = UIN./exp(s/2);
  
  %% Evaluate dA/dz
%   dUds = zeros(size(z));
%   dUds(z<zi(1)) = C(1)*upp(z<zi(1)) + C(2)*unp(z<zi(1)) + uinp(z<zi(1),1);
%   for i=2:N
%     dUds(z>=zi(i-1)&z<zi(i)) = C(2*i-1)*upp(z>=zi(i-1)&z<zi(i)) + C(2*i)*unp(z>=zi(i-1)&z<zi(i)) + uinp(z>=zi(i-1)&z<zi(i),i);
%   end
%   dUds(z>=zi(N)) = C(2*N+1)*upp(z>=zi(N));
%   dAdz = exp(-s/2).*(dUds - U/2)/H; 
end