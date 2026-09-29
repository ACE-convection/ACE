function [T,q,ql,qi,nonconv,iters] = inv_T_batch(theta_e, qt, p, T_guess, maxit)
%{
  Batched Newton inversion of (T, q, ql, qi) from (theta_e, qt, p), mirroring the
  certified SCALAR routine util_thermodynamics/inv_T_from_theta_e.m EXACTLY: same
  formulas, same branch logic, same per-point stopping criteria, applied to an
  N-vector via mask-and-freeze (a point leaves the active Newton mask the instant
  its own scalar-equivalent while-guard would have exited; frozen points keep
  their last (T,dT), which reproduces the scalar loop's final iterate bit-for-bit
  in exact arithmetic). NO algorithmic change relative to the scalar reference.

  The Newton-iterate body below follows the scalar reference routine step by step.
  Added on top of the reference version (inv_T infinite-loop
  lesson -- fail loud, never hang):
    - hard iteration cap (default 200, same value as
      INVT_MAX_ITER in the scalar routine) on EVERY masked Newton stage (step-1 unsaturated,
      step-2 liquid-only, step-2 ice-only); exceeding the cap does NOT silently
      return residual garbage -- the offending points are flagged via `nonconv`
      and their outputs are set to NaN (mirrors the scalar fail-fast: NaN out,
      let the caller's blew_up detection stop the integration).
    - `nonconv`: struct with per-stage and total non-convergence point counts and
      logical masks (over the length-N input order), so a caller can diagnose
      exactly which points and which Newton stage failed to converge within maxit.
    - `iters`: struct with the number of masked-Newton sweeps actually executed by
      each stage (scalars), and a per-point iteration-count vector `iters.perpoint`
      recording how many sweeps each point's stage ran before freezing/cap.
    - optional warm-start input `T_guess` (N x 1, real or []): when non-empty, used
      as the step-1 initial T instead of the cold-start branch seed (T=400 if
      F0>=FT0 else T=T0). Step-2 (condensate) initial guesses are UNCHANGED (still
      the closed-form Tetens/T0 seeds) because warm-starting step-2 is out of scope
      for this delivery and the specification only asks for a step-1 warm-start hook;
      T_guess is ignored (as if []) for any point that reaches step 2, i.e. the
      step-2 seed logic is identical to the cold-start path regardless of T_guess.
    - optional `maxit` input (default 200) to allow a caller to override the cap
      without editing this file.
  Backward-compatible: [T,q,ql,qi] = inv_T_batch(theta_e,qt,p) still works (T_guess
  and maxit default to cold-start / 200; nonconv/iters simply not requested).

  Args:
    theta_e (double, N-vector or array): equivalent potential temperature in K.
    qt      (double, N-vector or array): total specific water content in kg/kg.
    p       (double, N-vector or array): air pressure in Pa. Must be broadcastable
            to the same shape as theta_e/qt (e.g. same size, or a size that numel()
            expands correctly once linearized -- caller is responsible for
            replicating p to full N x 1 if it varies only along one dimension).
    T_guess (double, N-vector, or []): optional warm-start seed for step-1 T.
            [] (default) => cold start identical to the scalar routine's seed.
    maxit   (double scalar, optional): Newton iteration cap per stage (default 200).

  Returns:
    T, q, ql, qi (double, N x 1): temperature (K) and specific humidities (kg/kg),
        reshaped-flat in the same linear order as theta_e(:).
    nonconv (struct): .any (logical scalar), .count (double scalar, total points
        that hit the cap in ANY stage), .mask (N x 1 logical, true where THIS
        point's governing stage did not converge within maxit),
        .step1 / .liquid / .ice (per-stage counts, scalars).
    iters (struct): .step1 / .liquid / .ice (scalar: number of masked-Newton
        sweeps executed by that stage, i.e. loop-count until all-frozen or cap),
        .perpoint (N x 1 double: sweeps run by the stage that determined each
        point's final (T,q,ql,qi); unsaturated points get their step-1 count).
%}

if nargin<4, T_guess = []; end
if nargin<5 || isempty(maxit), maxit = 200; end

sz = size(theta_e);
N  = numel(theta_e);
ABS_TOL = 1e-3;
T0 = 273.1636783445389;

theta_e = complex(theta_e(:)); qt = complex(qt(:));
p = complex(p(:));
if numel(p)==1, p = p*ones(N,1); end % allow scalar p to broadcast

CPL = 1005.7 + 3184.3*qt;
RE  = 287.04*(1-qt);
chi = RE./CPL;

R = RE + 461.5*qt;
gamma = 461.5*qt./CPL;
e = p.*qt./(0.621971830985916+0.378028169014084*qt);
F0  = theta_e .* (p.*RE./R/1e5).^chi .* e.^gamma;
FT0 = T0 * 611.3902114165171.^gamma .* exp(qt./CPL*9155.566660243245);

water = F0>=FT0;                            % branch mask (Step 1)
T  = complex(zeros(N,1));
if ~isempty(T_guess)
  T_guess = T_guess(:);
  if numel(T_guess)~=N
    error('inv_T_batch: T_guess must have N=%d elements (got %d).', N, numel(T_guess));
  end
  T = complex(T_guess);
else
  T(water)  = 400;
  T(~water) = T0;
end
dT = complex(9999*ones(N,1));

% Step-1 masked Newton (active-per-point stopping mirrors scalar while-guard):
%   a point leaves the mask precisely when the scalar while-guard exits:
%   abs(dT)<=ABS_TOL | imag(dT)~=0 | isnan(T). Frozen points keep their last (T,dT).
active = true(N,1);
iters_step1 = 0;
perpoint = zeros(N,1);
nonconv_step1_mask = false(N,1);
for it = 1:maxit
  iters_step1 = it;
  if ~any(active), break; end
  a = active;
  Ta = T(a); qta = qt(a); CPLa = CPL(a); gammaa = gamma(a);
  wa = water(a); F0a = F0(a);
  F = complex(zeros(nnz(a),1)); dFdT = complex(zeros(nnz(a),1));
  % water sub-branch
  iw = wa;
  if any(iw)
    Tw = Ta(iw);
    F(iw)    = Tw .* eval_es(Tw).^gammaa(iw) .* exp(qta(iw)./CPLa(iw).*lv(Tw)./Tw);
    dFdT(iw) = (1-2320*qta(iw)./CPLa(iw))./Tw;
  end
  % ice sub-branch
  ii = ~wa;
  if any(ii)
    Ti = Ta(ii);
    F(ii)    = Ti .* eval_esi(Ti).^gammaa(ii) .* exp(qta(ii)./CPLa(ii).*lv(Ti)./Ti);
    dFdT(ii) = ( 1-300708*qta(ii)./CPLa(ii)./Ti )./Ti;
  end
  dFdT = dFdT.*F;
  dTa  = -(F-F0a)./dFdT;
  Ta   = Ta + dTa;
  T(a)  = Ta;  dT(a) = dTa;
  aidx = find(a);
  perpoint(aidx) = perpoint(aidx) + 1;
  % update active mask EXACTLY as the scalar while-guard:
  %   stay active iff abs(dT)>ABS_TOL && imag(dT)==0 && ~isnan(T)
  stay = abs(dTa)>ABS_TOL & imag(dTa)==0 & ~isnan(Ta);
  active(aidx) = stay;
end
if any(active)
  % FAIL-FAST: step-1 hit the cap without converging for these
  % points. Mirror the scalar routine's fail-fast: NaN out, flag, never hang.
  nonconv_step1_mask(active) = true;
  fprintf('inv_T_batch FAIL-FAST: step-1 (no-condensate) Newton exceeded %d iters for %d/%d pts; theta_e [%.6g, %.6g] qt [%.6g, %.6g]\n', ...
          maxit, nnz(active), N, min(real(theta_e(active))), max(real(theta_e(active))), ...
          min(real(qt(active))), max(real(qt(active))));
  T(active) = complex(NaN);
end

q  = qt;
ql = complex(zeros(N,1));
qi = complex(zeros(N,1));

% consistency check (bsmeter) -- identical logic, vectorized.
qsat = complex(zeros(N,1));
hot = real(T)>=T0;                          % T>=T0 test (real part; T real here)
% NaN'd (non-converged step-1) points: keep them out of both eval_qs/eval_qsi
% calls (hot/~hot on NaN gives false for hot, i.e. they fall to eval_qsi; that is
% harmless since bsmeter below will already be forced true by isnan(T)).
if any(hot),  qsat(hot)  = eval_qs (T(hot),  p(hot),  qt(hot));  end
if any(~hot), qsat(~hot) = eval_qsi(T(~hot), p(~hot), qt(~hot)); end
bsmeter = imag(dT)~=0 | isnan(T) | (real(q)>real(qsat));

iters_liq = 0; iters_ice = 0;
nonconv_liq_mask = false(N,1);
nonconv_ice_mask = false(N,1);

if any(bsmeter)
  b = bsmeter;
  G0  = theta_e(b) .* (p(b).*RE(b)/1e5).^chi(b);
  dC  = 2083.900148084866;
  qsi = eval_qsi(T0,p(b),qt(b));
  HT0 = T0 .* (RE(b)+461.5*qsi).^chi(b) .* exp( (qsi*2.500968266240670e+06-0.3337e6*(qt(b)-qsi))./CPL(b)/T0 );
  qsB = eval_qs(T0,p(b),qt(b));
  GT0 = T0 .* (RE(b)+461.5*qsB).^chi(b) .* exp(qsB.*9155.566660243245./CPL(b));

  % regime masks (same comparisons as scalar)
  liqM = G0>GT0 & G0>HT0;
  iceM = G0<GT0 & G0<HT0;
  coexM = ~liqM & ~iceM;

  bidx = find(b);
  Tb = T(b); qb = q(b); qlb = ql(b); qib = qi(b);
  peb = theta_e(b); pb = p(b); qtb = qt(b);
  REb = RE(b); CPLb = CPL(b); chib = chi(b);

  % --- liquid-only subset: masked batch Newton on G ---
  if any(liqM)
    m = liqM;
    LOG = log(pb(m).*qtb(m)) - 5.939876353793538;
    Tm = 237.3*LOG./(17.27-LOG) + 273.15;
    dTm = complex(9999*ones(nnz(m),1)); act = true(nnz(m),1);
    m_global = bidx(m); % map subset index -> global point index (for perpoint/nonconv)
    for it=1:maxit
      iters_liq = it;
      if ~any(act), break; end
      aa=act;
      Tc=Tm(aa); pc=pb(m); pc=pc(aa); qtc=qtb(m); qtc=qtc(aa);
      REc=REb(m); REc=REc(aa); CPLc=CPLb(m); CPLc=CPLc(aa); chic=chib(m); chic=chic(aa);
      G0c=G0(m); G0c=G0c(aa);
      qsc = eval_qs(Tc,pc,qtc);
      Rc = REc + 461.5*qsc; LVoT = lv(Tc)./Tc;
      G = Tc .* Rc.^chic .* exp(qsc.*LVoT./CPLc);
      dGdT = 1./Tc + ( (461.5*REc./Rc+LVoT).*eval_dTqs(Tc,pc,qtc) - 1867292.*qsc./Tc.^2 )./CPLc;
      dGdT = dGdT.*G;
      dd = -(G-G0c)./dGdT; Tc = Tc + dd;
      idxa=find(aa); Tm(idxa)=Tc; dTm(idxa)=dd;
      perpoint(m_global(idxa)) = perpoint(m_global(idxa)) + 1;
      act(idxa) = abs(dd)>ABS_TOL;    % scalar's  while max(abs(dT))>ABS_TOL  == per-point
    end
    if any(act)
      nonconv_liq_mask(m_global(act)) = true;
      fprintf('inv_T_batch FAIL-FAST: liquid-only Newton exceeded %d iters for %d/%d pts (subset); theta_e [%.6g, %.6g] qt [%.6g, %.6g]\n', ...
              maxit, nnz(act), nnz(m), min(real(peb(m))), max(real(peb(m))), min(real(qtb(m))), max(real(qtb(m))));
      Tm(act) = complex(NaN);
    end
    qtm = qtb(m);                            % qt restricted to this subset
    qf  = eval_qs(Tm,pb(m),qtm);             % q = eval_qs(T)
    qlf = qtm-qf;                            % ql = qt-q
    qif = complex(zeros(nnz(m),1));          % qi = 0
    neg = real(qlf)<0;                       % if ql<0 -> q=qt, ql=0
    qf(neg)=qtm(neg); qlf(neg)=0;
    qf(act) = complex(NaN); qlf(act) = complex(NaN); qif(act) = complex(NaN);
    Tb(m)=Tm; qb(m)=qf; qlb(m)=qlf; qib(m)=qif;
  end

  % --- ice-only subset: masked batch Newton on H ---
  if any(iceM)
    m = iceM;
    LOG = log(pb(m).*qtb(m)) - 5.939876353793538;
    Tm = 265.5*LOG./(21.875-LOG) + 273.16;
    dTm = complex(9999*ones(nnz(m),1)); act = true(nnz(m),1);
    m_global = bidx(m);
    for it=1:maxit
      iters_ice = it;
      if ~any(act), break; end
      aa=act;
      Tc=Tm(aa); pc=pb(m); pc=pc(aa); qtc=qtb(m); qtc=qtc(aa);
      REc=REb(m); REc=REc(aa); CPLc=CPLb(m); CPLc=CPLc(aa); chic=chib(m); chic=chic(aa);
      G0c=G0(m); G0c=G0c(aa);
      qsic = eval_qsi(Tc,pc,qtc); qic2 = qtc-qsic;
      dTqsic = eval_dTqsi(Tc,pc,qtc); LVoT = lv(Tc)./Tc;
      Rc = REc + 461.5*qsic;
      H = Tc .* Rc.^chic .* (T0./Tc).^(dC*qic2./CPLc) .* exp((qsic.*LVoT - 0.3337e6/T0*qic2)./CPLc);
      dHdT = 1./Tc + ( ( 461.5*REc./Rc + LVoT + dC*log(Tc/T0) + 1221.611899584641 ).*dTqsic ...
                      - ( (1867292./Tc-dC).*qsic + dC*qtc )./Tc )./CPLc;
      dHdT = dHdT.*H;
      dd = -(H-G0c)./dHdT; Tc = Tc + dd;
      idxa=find(aa); Tm(idxa)=Tc; dTm(idxa)=dd;
      perpoint(m_global(idxa)) = perpoint(m_global(idxa)) + 1;
      act(idxa) = abs(dd)>ABS_TOL;
    end
    if any(act)
      nonconv_ice_mask(m_global(act)) = true;
      fprintf('inv_T_batch FAIL-FAST: ice-only Newton exceeded %d iters for %d/%d pts (subset); theta_e [%.6g, %.6g] qt [%.6g, %.6g]\n', ...
              maxit, nnz(act), nnz(m), min(real(peb(m))), max(real(peb(m))), min(real(qtb(m))), max(real(qtb(m))));
      Tm(act) = complex(NaN);
    end
    qtm = qtb(m);                            % qt restricted to this subset
    qsf = eval_qsi(Tm,pb(m),qtm);
    qif = qtm-qsf; qlf = complex(zeros(nnz(m),1));
    neg = real(qif)<0; qf = qsf; qf(neg)=qtm(neg); qif(neg)=0;
    qf(act) = complex(NaN); qlf(act) = complex(NaN); qif(act) = complex(NaN);
    Tb(m)=Tm; qb(m)=qf; qlb(m)=qlf; qib(m)=qif;
  end

  % --- coexisting subset: closed-form partition (no Newton) ---
  if any(coexM)
    m = coexM;
    qtm = qtb(m); pbm = pb(m); REbm = REb(m); CPLbm = CPLb(m); chibm = chib(m); pebm = peb(m);
    Tm = complex(T0*ones(nnz(m),1));
    qs_ = eval_qs(Tm,pbm,qtm); qsi_ = eval_qsi(Tm,pbm,qtm);
    qm = 0.5*(qs_+qsi_);
    Rc = REbm + 461.5*qm;
    PIc = (pbm.*REbm./Rc/1e5).^chibm;
    qc = qtm-qm;
    qim = ( lv(T0)*qm - T0*CPLbm.*log(pebm.*PIc/T0) )/0.3337e6;
    qlm = qc-qim;
    % branch fixups (qc<0 / ql<0 / qi<0), vectorized in scalar precedence order
    c1 = real(qc)<0;                 % discrepancy -> all vapor
    c2 = ~c1 & (real(qlm)<0);        % liquid-free
    c3 = ~c1 & ~c2 & (real(qim)<0);  % ice-free
    qmf = qm; qlmf = qlm; qimf = qim;
    qmf(c1)=qtm(c1); qlmf(c1)=0; qimf(c1)=0;
    qlmf(c2)=0; qimf(c2)=qc(c2);
    qimf(c3)=0; qlmf(c3)=qc(c3);
    Tb(m)=Tm; qb(m)=qmf; qlb(m)=qlmf; qib(m)=qimf;
  end

  T(b)=Tb; q(b)=qb; ql(b)=qlb; qi(b)=qib;
end

T=real(T); q=real(q); ql=real(ql); qi=real(qi);
T   = reshape(T,   sz);
q   = reshape(q,   sz);
ql  = reshape(ql,  sz);
qi  = reshape(qi,  sz);

nonconv_mask = nonconv_step1_mask | nonconv_liq_mask | nonconv_ice_mask;
nonconv = struct( ...
  'any',    any(nonconv_mask), ...
  'count',  nnz(nonconv_mask), ...
  'mask',   reshape(nonconv_mask, sz), ...
  'step1',  nnz(nonconv_step1_mask), ...
  'liquid', nnz(nonconv_liq_mask), ...
  'ice',    nnz(nonconv_ice_mask) );
iters = struct( ...
  'step1',    iters_step1, ...
  'liquid',   iters_liq, ...
  'ice',      iters_ice, ...
  'perpoint', reshape(perpoint, sz) );
end
