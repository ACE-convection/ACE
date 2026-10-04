function a = VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L,Z,zL,zH,operator)
switch operator
  case 'N_ij' % Current notation: PMB
    %% For primary effective acceleration (i.e., N_ij for Poisson with \nabla_h^2)
    k = 2*pi/L;
    uh = 2*sinh(k*zH/2)^2*exp(-k*Z);
    uh(Z<zH) = 1-exp(-k*Z(Z<zH))-exp(-k*zH)*sinh(k*Z(Z<zH));
    ul = 2*sinh(k*zL/2)^2*exp(-k*Z);
    ul(Z<zL) = 1-exp(-k*Z(Z<zL))-exp(-k*zL)*sinh(k*Z(Z<zL));
    a = uh-ul;
  case 'N_ij^h' % Current notation: PMDv
    %% For Poisson equation solutions (for N_ij^h; also for N_ij^v but not including d^2/dz^2)
    k = 2*pi/L;
    uh = ( (1-0.5*exp(-k*zH))*exp(-k*Z)+0.5*exp(-k*zH)*exp(k*Z)-1 );
    uh(Z>=zH) = exp(-k*Z(Z>=zH))*(1-sinh(k*zH));
    if zL>0
      ul = ( (1-0.5*exp(-k*zL))*exp(-k*Z)+0.5*exp(-k*zL)*exp(k*Z)-1 );
      ul(Z>=zL) = exp(-k*Z(Z>=zL))*(1-sinh(k*zL));
      a = (uh-ul)/k^2;
    else
      a = uh/k^2;
    end
  case 'N_ij(d/dz)' % Current notation: PMD
    %% For Nij(Fu) (i.e., N_ij but includes (d/dz) in Fu)
    k = 2*pi/L;
    uh = sinh(k*zH)*exp(-k*Z);
    uh(Z<zH) = exp(-k*zH)*sinh(k*Z(Z<zH));
    ul = sinh(k*zL)*exp(-k*Z);
    ul(Z<zL) = exp(-k*zL)*sinh(k*Z(Z<zL));
    a = -k*(uh-ul);
  otherwise
    disp('Undefined operator...')
end