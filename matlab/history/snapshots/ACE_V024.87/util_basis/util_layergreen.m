function L = util_layergreen(k, z, a, b, Lz)
%UTIL_LAYERGREEN slab layer Green L_k(z; a, b) = int_a^b G_k(z, z') dz'
%   Dirichlet at z = 0 and z = Lz; three-piece closed
%   form, implemented in scaled-exponential form (all exponents <= 0) so the
%   sinh/cosh ratios stay finite at large k*Lz. k scalar > 0; z any shape.
den = 1 - exp(-2*k*Lz);
L = zeros(size(z));
i1 = z <= a;  i3 = z >= b;  i2 = ~i1 & ~i3;
z1 = z(i1);
L(i1) = -(1/(2*k^2)) * (1-exp(-2*k*z1)) .* ...
    ( exp(-k*(a-z1)).*(1+exp(-2*k*(Lz-a))) - exp(-k*(b-z1)).*(1+exp(-2*k*(Lz-b))) ) / den;
z3 = z(i3);
L(i3) = -(1/(2*k^2)) * (1-exp(-2*k*(Lz-z3))) .* ...
    ( exp(-k*(z3-b)).*(1+exp(-2*k*b)) - exp(-k*(z3-a)).*(1+exp(-2*k*a)) ) / den;
z2 = z(i2);
t_a = 0.5*(1-exp(-2*k*(Lz-z2))).*(1+exp(-2*k*a)).*exp(-k*(z2-a)) / den;
t_b = 0.5*(1-exp(-2*k*z2)).*(1+exp(-2*k*(Lz-b))).*exp(-k*(b-z2)) / den;
L(i2) = -(1/k^2) * (1 - t_a - t_b);
end
