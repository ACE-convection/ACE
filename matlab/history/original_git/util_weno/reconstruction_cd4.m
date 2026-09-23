function cd4 = reconstruction_cd4(c)
  % Following Eq. (C.1) of Lemarie et al. (2015).
  % Assuming 3-D c(z,var==c,ACE-i), size(c,2)=1, c(z==0)=0
  % c is vertical mass flux and to be interpolated onto z+dz/2
  cd4 = ( 7*( c+circshift(c,-1) )-circshift(c,1)-circshift(c,-2) )/12; % c(z+dz/2,var==c,ACE-i)
  % Surface BC modification (odd extension below surface)
  cd4(1,:,:) = ( 8*c(2,:,:)-c(3,:,:) )/12;
end