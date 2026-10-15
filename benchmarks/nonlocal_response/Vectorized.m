function out=Vectorized(s,P)
% Same arithmetic grouping, explicit small coefficients and reusable temporary.
rho=s.rho0B;
if s.zero_ref_buoyancy
    rho=rho-sum(rho.*(s.Ai'/sum(s.Ai)),2);
end
b=mean(reshape(rho(1:end-1,:)+s.F(1:end-1,:),s.coarse_z,[],s.Ni));
v=mean(reshape(s.dz2FH,s.coarse_z,[],s.Ni));
h=mean(reshape(s.DHh(1:end-1,:),s.coarse_z,[],s.Ni));
terms=P{1}.*b;
terms=terms+P{2}.*v;
terms=terms+P{3}.*h;
edge=squeeze(sum(sum(terms,2),3));
out=interp1(s.Z,edge,s.zm,'makima');
end
