function dMFdt = Original(rho0B, F, dz2FH, DHh, Z, zm, coarse_z, Ni, PMB, PMDv, PMD, Ai, zero_ref_buoyancy)
  if zero_ref_buoyancy
    % Zero out reference buoyancy
    rho0B = rho0B - sum(rho0B.*(Ai'/sum(Ai)),2);
  end
  if coarse_z==1
    dMFdt = squeeze(sum(sum(PMB.*reshape((rho0B(1:end-1,:)+F(1:end-1,:)),coarse_z,[],Ni)...
                            +PMDv.*reshape(dz2FH,coarse_z,[],Ni)...
                            +PMD.*reshape(DHh(1:end-1,:),coarse_z,[],Ni),2),3)); % (zi,ACE-i)
  else
    dMFdt = interp1(Z,squeeze(sum(sum(PMB.*mean(reshape((rho0B(1:end-1,:)+F(1:end-1,:)),coarse_z,[],Ni))...
                                      +PMDv.*mean(reshape(dz2FH,coarse_z,[],Ni))...
                                      +PMD.*mean(reshape(DHh(1:end-1,:),coarse_z,[],Ni)),2),3)),zm,'makima'); % (zi,ACE-i)
  end
end

