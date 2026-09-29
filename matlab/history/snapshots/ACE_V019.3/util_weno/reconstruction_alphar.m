function alphar = reconstruction_alphar(k,v,p,epsilon)
% alphar defined by Eq. (2.59) in Shu (1998).
% Redundancy: length(v) = 2k-1.
  if nargin==2
    p = 2;
    epsilon = eps;
  elseif nargin==3
    epsilon = eps;
  end
  alphar = reconstruction_dr(k)./ (epsilon + reconstruction_betar(k,v)).^p;
end