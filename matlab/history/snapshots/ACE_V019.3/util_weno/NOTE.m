%{
Utility functions using WENO approach.
Notations follow Shu (1998).

reconstruction_weno.m is a self-contained script runnning ~10% faster than reconstruction_weno-bak.m
---the latter and other utility scripts are kept for readibility.

Reference:
  Shu, C. W., 1998: Essentially non-oscillatory and weighted essentially
      non-oscillatory schemes for hyperbolic conservation laws. In Advanced
      numerical approximation of nonlinear hyperbolic equations (pp. 325-432).
      Springer, Berlin, Heidelberg.
  Jiang, G. S., & C. W. Shu, 1996: Efficient implementation of weighted ENO
      schemes. Journal of computational physics, 126(1), 202-228.
  Balsara, D. S., & C. W. Shu, 2000: Monotonicity preserving weighted
      essentially non-oscillatory schemes with increasingly high order of
      accuracy. Journal of Computational Physics, 160(2), 405-452.
%}
