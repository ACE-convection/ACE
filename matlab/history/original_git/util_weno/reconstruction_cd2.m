function cd2 = reconstruction_cd2(c)
  % Following Eq. (C.1) of Lemarie et al. (2015).
  % Assuming 3-D c(z,var==c,ACE-i), size(c,2)=1, c(z==0)=0
  % c is vertical mass flux and to be interpolated onto z+dz/2
  cd2 = 0.5*( c+circshift(c,-1) ); % c(z+dz/2,var==c,ACE-i)
end