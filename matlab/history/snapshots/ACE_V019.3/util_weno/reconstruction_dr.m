function dr = reconstruction_dr(k)
% dr as used in Eq. (2.54) in Shu (1998):
% 
% 	v(i+1/2) ≈ ∑_{r=0}^{k-1} dr vr(i+1/2),
% 
% or Crk in Jiang & Shu (1996) and C^r_k in Balsara & Shu (2000).
% Notations: (k, r) here is (r, k) in Crk.
% Notations: r starts with 1 because of Julia/Matlab's index.
  if k==2
    dr = [2/3; 1/3];
  elseif k==3
    dr = [3/10; 3/5; 1/10];
  elseif k==4
    dr = [1/35; 12/35; 18/35; 4/35];
  elseif k==5
    dr = [1/126; 10/63; 10/21; 20/63; 5/126];
  elseif k==6
    dr = [1/462; 5/77; 25/77; 100/231; 25/154; 1/77];
  elseif k==1
  	dr = 1;
  end
end
