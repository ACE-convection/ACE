function [cin, cinidz, cape, capeidz] = cin_cape_calc(B, z)
  % Identify CIN layer
  ccn = bwconncomp(B<0);
  if ccn.NumObjects==0 % CIN layer doesn't exist
    cin = 0;
    cinidz = [];
  else
    cinidz = ccn.PixelIdxList{1};
    idzt = max(cinidz); % CIN layer top
    idzb = min(cinidz); % Bottom
    % Evaluate dz
    idzu = cinidz+1;
    if idzt==length(z)
      idzu(end) = idzt; % Correction for top boundary
    end
    idzd = cinidz-1;
    if idzb==1
      idzd(1) = idzb; % Correction for bottom
    end
    dz = ( z(idzu)-z(idzd) )/2;
    cin = sum( B(cinidz).*dz );
  end%CIN
  % Identify CAPE layer
  ccp = bwconncomp(B>0);
  if ccp.NumObjects==0 % CAPE layer doesn't exist
    cape = 0;
    capeidz = [];
  else
    capeidz = ccp.PixelIdxList{1};
    if ~isempty(cinidz) && max(capeidz)<idzb && ccp.NumObjects>1
      capeidz = ccp.PixelIdxList{2};
    end
    idzt = max(capeidz); % CAPE layer top
    idzb = min(capeidz); % Bottom
    % Evaluate dz
    idzu = capeidz+1;
    if idzt==length(z)
      idzu(end) = idzt; % Correction for top boundary
    end
    idzd = capeidz-1;
    if idzb==1
      idzd(1) = idzb; % Correction for bottom
    end
    dz = ( z(idzu)-z(idzd) )/2;
    cape = sum( B(capeidz).*dz );
  end
end