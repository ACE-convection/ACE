function out=Precomputed(s,fixed)
% One BLAS contraction; reduction order differs and is explicitly measured.
rho=s.rho0B;
if s.zero_ref_buoyancy
    rho=rho-sum(rho.*fixed.area_weights,2);
end
b=mean(reshape(rho(1:end-1,:)+s.F(1:end-1,:),s.coarse_z,[],s.Ni));
v=mean(reshape(s.dz2FH,s.coarse_z,[],s.Ni));
h=mean(reshape(s.DHh(1:end-1,:),s.coarse_z,[],s.Ni));
coeff=reshape(cat(1,b,v,h),[],1);
edge=reshape(fixed.matrix*coeff,numel(s.Z),s.Ni);
% makima slopes depend on current values: interpolation is never precomputed.
out=interp1(s.Z,edge,s.zm,'makima');
end
