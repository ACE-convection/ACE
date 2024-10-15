function up3 = reconstruction_up3(c)
  % Following Eq. (C.1) of Lemarie et al. (2015).
  % Assuming 3-D c(z,var==c,ACE-i), size(c,2)=1, c(z==0)=0
  % c is vertical mass flux and to be interpolated onto z+dz/2
  up3 = 7*( c+circshift(c,-1) )-circshift(c,1)-circshift(c,-2); % 12 x CD4-estimate for flow direction (divided by 12 next line)
  up3 = ( up3 + sign(up3).*( 3*( c-circshift(c,-1) )+circshift(c,-2)-circshift(c,1) ) )/12; % c(z+dz/2,var==c,ACE-i)
  % Surface BC modification (odd extension below surface)
  up3(1,:,:) = 8*c(2,:,:)-c(3,:,:);
  up3(1,:,:) = ( up3(1,:,:) + sign(up3(1,:,:)).*( c(3,:,:)-2*c(2,:,:) ) )/12;
end