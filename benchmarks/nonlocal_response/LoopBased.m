function out=LoopBased(s,P)
% JIT loop over forcing ACE; retain per-level three-term grouping.
rho=s.rho0B;
if s.zero_ref_buoyancy
    rho=rho-sum(rho.*(s.Ai'/sum(s.Ai)),2);
end
b=mean(reshape(rho(1:end-1,:)+s.F(1:end-1,:),s.coarse_z,[],s.Ni));
v=mean(reshape(s.dz2FH,s.coarse_z,[],s.Ni));
h=mean(reshape(s.DHh(1:end-1,:),s.coarse_z,[],s.Ni));
edge=zeros(numel(s.Z),s.Ni);
for j=1:s.Ni
    terms=P{1}(:,:,j,:).*b(1,:,j)+P{2}(:,:,j,:).*v(1,:,j)+P{3}(:,:,j,:).*h(1,:,j);
    edge=edge+reshape(sum(terms,2),numel(s.Z),s.Ni);
end
out=interp1(s.Z,edge,s.zm,'makima');
end
