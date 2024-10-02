function v_weno = reconstruction_weno(k,v)
% ~10% slower than reconstruction_weno.m but more readible, so kept as backup.
% Reconstruction using Eq. (2.52) in Shu (1998):
% 
% 	V(i+1/2) ≈ ∑_{r=0}^{k-1} wr Vr(i+1/2),
% 
% Redundancy: length(v) = 2k-1 is the order of accuracy.
% Note that v = V(i-k+1:i+k-1).
  wr = reconstruction_wr(k,v);
  v_weno = zeros(1,size(v,2));
  for r=0:k-1
% % %     v_weno = v_weno + ...
% % %              wr(r+1,:) .* dot(repmat(reconstruction_cij(k,r),[1,size(v,2)]),...
% % %                               v(k-r:end-r,:));
     v_weno = v_weno + ...
             wr(r+1,:) .* sum(reconstruction_cij(k,r).*v(k-r:end-r,:));
  end
% %   v_weno = wr(1,:) .* dot(repmat([1/3;5/6;-1/6],[1,size(v,2)]), v(k:end,:)) +...
% %            wr(2,:) .* dot(repmat([-1/6;5/6;1/3],[1,size(v,2)]), v(k-1:end-1,:)) +...
% %            wr(3,:) .* dot(repmat([1/3;-7/6;11/6],[1,size(v,2)]), v(k-2:end-2,:));
end
