function [T, q, ql, qi, ws] = inv_T_batch_warm(theta_e, qt, p, Tseed, QLseed, QIseed, n0)
%INV_T_BATCH_WARM warm-jump batched inversion.
%
% STEP 0 (branch jump): each cell enters ITS OWN branch's Newton directly,
% seeded by the previous time step's (T, ql, qi):
%     ql<=0 & qi<=0 -> unsaturated F-Newton (warm T seed)
%     ql>0  & qi<=0 -> liquid-only G-Newton (warm T seed; SKIPS step 1)
%     qi>0  & ql<=0 -> ice-only    H-Newton (warm T seed; SKIPS step 1)
%     ql>0  & qi>0  -> coexist: straight to fallback (rare; closed-form there)
% Each warm Newton runs at most n0 (default 3) FIXED sweeps, then
% a per-cell convergence + branch-validity check:
%     unsaturated: |dT|<=tol, real, and qt <= qsat(T)
%     liquid:      |dT|<=tol, real, T > T0, ql = qt - qs  >= 0
%     ice:         |dT|<=tol, real, T < T0, qi = qt - qsi >= 0
% Cells failing ANY check fall back PER-CELL to the plain certified batch
% routine inv_T_batch (exact mirror of util_thermodynamics/inv_T_from_theta_e,
% carries the V024 fail-fast cap + nonconv flags). Empty Tseed => pure
% fallback (= cold start; use for the first step of a march).
%
% Newton bodies below are copied VERBATIM (formulas and constants) from
% inv_T_from_theta_e.m; only the seeding, sweep cap, masking, and validity
% checks are new. Outputs are REAL doubles in the input's linear order
% (matching INV_THETA_E semantics).
%
% ws: .fallback_frac .n_fallback .n_unsat .n_liq .n_ice .n_coex
%     .sweeps (=n0) .nonconv (struct from the fallback inv_T_batch; all-zero
%     struct when no cell fell back).

if nargin < 7 || isempty(n0), n0 = 3; end   % patience knob (tol unchanged)
N = numel(theta_e);
theta_e = theta_e(:); qt = qt(:); p = p(:);

ws = struct('fallback_frac',1,'n_fallback',N,'n_unsat',0,'n_liq',0,'n_ice',0, ...
            'n_coex',0,'sweeps',n0,'nonconv',struct('any',false,'count',0));

if nargin < 4 || isempty(Tseed)                    % cold start = plain batch
  [T, q, ql, qi, nc] = inv_T_batch(theta_e, qt, p);
  T = real(T); q = real(q); ql = real(ql); qi = real(qi);
  ws.nonconv = nc;
  return
end
Tseed = real(Tseed(:)); QLs = real(QLseed(:)); QIs = real(QIseed(:));

ABS_TOL = 1e-3;
T0v = 273.1636783445389;

mU = QLs <= 0 & QIs <= 0;
mL = QLs >  0 & QIs <= 0;
mI = QIs >  0 & QLs <= 0;
mC = QLs >  0 & QIs >  0;                          % coexist -> fallback

T = zeros(N,1); q = zeros(N,1); ql = zeros(N,1); qi = zeros(N,1);
ok = false(N,1);

% per-cell thermodynamic constants (verbatim from the scalar routine)
CPL = 1005.7 + 3184.3*qt;
RE  = 287.04*(1-qt);
chi = RE./CPL;

iu = find(mU);
if ~isempty(iu)
  [Tu, oku, qu] = warm_unsat(theta_e(iu), qt(iu), p(iu), Tseed(iu), n0, ABS_TOL, T0v, ...
                             CPL(iu), RE(iu), chi(iu));
  T(iu) = real(Tu); q(iu) = real(qu); ok(iu) = oku;   % ql=qi=0 already
end
il = find(mL);
if ~isempty(il)
  [Tl, okl, qsl] = warm_liq(theta_e(il), qt(il), p(il), Tseed(il), n0, ABS_TOL, T0v, ...
                            CPL(il), RE(il), chi(il));
  T(il) = real(Tl); q(il) = real(qsl); ql(il) = real(complex(qt(il)) - qsl); ok(il) = okl;
end
ii = find(mI);
if ~isempty(ii)
  [Ti, oki, qsi_] = warm_ice(theta_e(ii), qt(ii), p(ii), Tseed(ii), n0, ABS_TOL, T0v, ...
                             CPL(ii), RE(ii), chi(ii));
  T(ii) = real(Ti); q(ii) = real(qsi_); qi(ii) = real(complex(qt(ii)) - qsi_); ok(ii) = oki;
end

ifb = find(~ok);                                   % includes all mC cells
if ~isempty(ifb)
  [Tf, qf, qlf, qif, nc] = inv_T_batch(theta_e(ifb), qt(ifb), p(ifb));
  T(ifb) = real(Tf); q(ifb) = real(qf); ql(ifb) = real(qlf); qi(ifb) = real(qif);
  ws.nonconv = nc;
end
ql(ql < 0) = 0; qi(qi < 0) = 0;                    % scalar routine's clamp semantics

ws.fallback_frac = numel(ifb)/N;  ws.n_fallback = numel(ifb);
ws.n_unsat = numel(iu); ws.n_liq = numel(il); ws.n_ice = numel(ii); ws.n_coex = sum(mC);
end

% ============================ warm Newton bodies ============================
function [T, ok, q] = warm_unsat(the, qtr, pr, Ts, n0, tol, T0v, CPL, RE, chi)
  % step-1 F-Newton (verbatim formulas), warm seed, <=n0 sweeps, validity check
  qt = complex(qtr); p = pr;
  R = RE + 461.5*qt; gamma = 461.5*qt./CPL;
  e = p.*qt./(0.621971830985916+0.378028169014084*qt);
  F0  = complex(the) .* (p.*RE./R/1e5).^chi .* e.^gamma;
  FT0 = T0v * 611.3902114165171.^gamma .* exp(qt./CPL*9155.566660243245);
  wa = real(F0) >= real(FT0);                      % es-form vs esi-form branch
  T = complex(Ts); dT = complex(9999*ones(size(Ts)));
  for s = 1:n0
    act = abs(dT) > tol & imag(dT) == 0 & ~isnan(real(T));
    if ~any(act), break; end
    a = act & wa; b = act & ~wa;
    F = complex(zeros(size(T))); dFdT = F;
    if any(a)
      F(a) = T(a).*eval_es(T(a)).^gamma(a).*exp(qt(a)./CPL(a).*lv(T(a))./T(a));
      dFdT(a) = (1-2320*qt(a)./CPL(a))./T(a).*F(a);
    end
    if any(b)
      F(b) = T(b).*eval_esi(T(b)).^gamma(b).*exp(qt(b)./CPL(b).*lv(T(b))./T(b));
      dFdT(b) = (1-300708*qt(b)./CPL(b)./T(b))./T(b).*F(b);
    end
    dT(act) = -(F(act)-F0(act))./dFdT(act);
    T(act) = T(act) + dT(act);
  end
  conv = abs(dT) <= tol & imag(dT) == 0 & ~isnan(real(T));
  qs = complex(nan(size(T)));
  hi = real(T) >= T0v;
  m1 = conv & hi;  m2 = conv & ~hi;
  if any(m1), qs(m1) = eval_qs (T(m1), p(m1), qt(m1)); end
  if any(m2), qs(m2) = eval_qsi(T(m2), p(m2), qt(m2)); end
  ok = conv & (real(qt) <= real(qs));              % no-condensate consistency
  q = qt;
end

function [T, ok, qs] = warm_liq(the, qtr, pr, Ts, n0, tol, T0v, CPL, RE, chi)
  % liquid-only G-Newton (verbatim formulas), warm seed, <=n0 sweeps
  qt = complex(qtr); p = pr;
  G0 = complex(the) .* (p.*RE/1e5).^chi;
  T = complex(Ts); dT = complex(9999*ones(size(Ts)));
  for s = 1:n0
    act = abs(dT) > tol & imag(dT) == 0 & ~isnan(real(T));
    if ~any(act), break; end
    qs_ = complex(zeros(size(T))); G = qs_; dGdT = qs_;
    qs_(act) = eval_qs(T(act), p(act), qt(act));
    R = RE(act) + 461.5*qs_(act);
    LVoT = lv(T(act))./T(act);
    G(act) = T(act) .* R.^chi(act) .* exp(qs_(act).*LVoT./CPL(act));
    dGdT(act) = ( 1./T(act) + ( (461.5*RE(act)./R + LVoT).*eval_dTqs(T(act),p(act),qt(act)) ...
                  - 1867292.*qs_(act)./T(act).^2 )./CPL(act) ) .* G(act);
    dT(act) = -(G(act)-G0(act))./dGdT(act);
    T(act) = T(act) + dT(act);
  end
  conv = abs(dT) <= tol & imag(dT) == 0 & ~isnan(real(T));
  qs = complex(nan(size(T)));
  if any(conv), qs(conv) = eval_qs(T(conv), p(conv), qt(conv)); end
  ok = conv & real(T) > T0v & real(qt - qs) >= 0;
end

function [T, ok, qsi_] = warm_ice(the, qtr, pr, Ts, n0, tol, T0v, CPL, RE, chi)
  % ice-only H-Newton (verbatim formulas), warm seed, <=n0 sweeps
  qt = complex(qtr); p = pr;
  dC = complex(2083.900148084866);
  G0 = complex(the) .* (p.*RE/1e5).^chi;
  T = complex(Ts); dT = complex(9999*ones(size(Ts)));
  for s = 1:n0
    act = abs(dT) > tol & imag(dT) == 0 & ~isnan(real(T));
    if ~any(act), break; end
    qsi_ = complex(zeros(size(T))); H = qsi_; dHdT = qsi_;
    qsi_(act) = eval_qsi(T(act), p(act), qt(act));
    qic = qt(act) - qsi_(act);
    dTqsi = eval_dTqsi(T(act), p(act), qt(act));
    LVoT = lv(T(act))./T(act);
    R = RE(act) + 461.5*qsi_(act);
    H(act) = T(act) .* R.^chi(act) .* (T0v./T(act)).^(dC*qic./CPL(act)) ...
             .* exp((qsi_(act).*LVoT - 0.3337e6/T0v*qic)./CPL(act));
    dHdT(act) = ( 1./T(act) + ( ( 461.5*RE(act)./R + LVoT + dC*log(T(act)/T0v) ...
                 + 1221.611899584641 ).*dTqsi ...
                 - ( (1867292./T(act)-dC).*qsi_(act) + dC*qt(act) )./T(act) )./CPL(act) ) .* H(act);
    dT(act) = -(H(act)-G0(act))./dHdT(act);
    T(act) = T(act) + dT(act);
  end
  conv = abs(dT) <= tol & imag(dT) == 0 & ~isnan(real(T));
  qsi_ = complex(nan(size(T)));
  if any(conv), qsi_(conv) = eval_qsi(T(conv), p(conv), qt(conv)); end
  ok = conv & real(T) < T0v & real(qt - qsi_) >= 0;
end
