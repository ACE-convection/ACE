function U = DH_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(L,k,Z,zL,zH)
  UH = sinh(k*zH)*exp(-k*Z);
  UH(Z<zH) = exp(-k*zH)*sinh(k*Z(Z<zH));
  UL = sinh(k*zL)*exp(-k*Z);
  UL(Z<zL) = exp(-k*zL)*sinh(k*Z(Z<zL));
  U = -k*(UH-UL);
  %% Below used for 2D-88ACE case
  % % % h = L/2/pi;
  % % % UH = sinh(zH/h)*exp(-Z/h);
  % % % UH(Z<zH) = sinh(Z(Z<zH)/h)*exp(-zH/h);
  % % % UL = sinh(zL/h)*exp(-Z/h);
  % % % UL(Z<zL) = sinh(Z(Z<zL)/h)*exp(-zL/h);
  % % % U = (k*h)*(UH-UL);
end