# Precomputed NONLOCAL_RESPONSE candidate

Status: benchmark-only candidate, not integrated into production. All timings
below use pure MATLAB with 32 computation threads and current `coarse_z=2`.

## Original operation

The three basis arrays use `[edge, coarse level, forcing ACE, response ACE]`
layout, each `[201,200,88,88]` double. After the unchanged zero-reference
buoyancy correction, reshape/mean produces three `[1,200,88]` coefficients:
buoyancy plus local forcing `b`, vertical momentum `v`, horizontal momentum `h`.
The original forms `(PMB.*b + PMDv.*v) + PMD.*h`, reduces coarse levels then
forcing ACEs, and interpolates the resulting `[201,88]` field with `makima`.
The large products and intermediate arrays dominate its measured runtime.

## Fixed setup outside the repeated kernel

Let `nr=201*88` and `nc=200*88`. Permuting each basis with `[1,4,2,3]`
places edge/response in the matrix rows and coarse/forcing in the columns.
Interleave the operators into one fixed `nr` by `3*nc` matrix:

```matlab
fixed.matrix = zeros(nr,3*nc);
fixed.matrix(:,1:3:end) = reshape(permute(PMB, [1,4,2,3]),nr,nc);
fixed.matrix(:,2:3:end) = reshape(permute(PMDv,[1,4,2,3]),nr,nc);
fixed.matrix(:,3:3:end) = reshape(permute(PMD, [1,4,2,3]),nr,nc);
fixed.area_weights = Ai'/sum(Ai);
```

This fixed matrix occupies 7,471,411,200 bytes (7.47 GB, 6.96 GiB). Keeping the
original operators too, as the benchmark does, requires additional memory.
The setup must be rebuilt if basis values, geometry/ordering, or area weights
change. It must not be repeated within an SSPRK stage.

## Runtime operation

`Precomputed.m` retains the original buoyancy correction and reshape/mean.
It interleaves the current coefficients in the same operator/coarse/forcing
ordering, evaluates one matrix-vector multiplication, then retains `makima`:

```matlab
coeff = reshape(cat(1,b,v,h),[],1);
edge = reshape(fixed.matrix*coeff,numel(s.Z),s.Ni);
out = interp1(s.Z,edge,s.zm,'makima');
```

The basis-sized element-wise products are avoided. `makima` is not replaced
or precomputed: its slopes depend on the current edge values.

## Numerical behavior and measured results

The mathematical contraction is unchanged, but BLAS changes floating-point
accumulation grouping. Bitwise equality is not claimed. Actual inputs were
captured from all nine SSPRK stages of a replay starting from the completed
native t=600 s state. All errors below include `makima`.

- Kernel median of three `timeit` estimates: Original 531.37 ms; Precomputed
  201.65 ms, observed 2.64x speedup.
- Maximum absolute error over nine stages: 9.8012e-17; maximum relative L2:
  5.8494e-14. Predeclared screening limits: 1e-9 and 1e-10 respectively.
- Full native 6 s timestep, two independent processes per implementation:
  Original median 3.90675 s; Precomputed median 1.9685 s, observed 1.98x.
- Full-step MF/theta_e/qt maximum differences: 4.9960e-16 / 5.6843e-14 /
  2.1684e-19. All checked states were finite and qt nonnegative.
- Kernel benchmark setup took 6.389 s; separate complete-step setup timings
  varied. Setup/loading are excluded from the repeated-kernel/ODE timings.

These observations include competition from the authorized background model
run. Only current geometry, switches and captured states are covered; no
long-trajectory scientific equivalence or guaranteed long-run speedup is
claimed. The current implementation is an experiment, not a general public API.

## Integration decision

The developer decides whether to integrate. Before adoption, compare complete
Original/Precomputed native ten-minute trajectories, per-step water inventory,
and diagnostics under the same execution conditions. Preserve the original
baseline and explicitly document changed floating-point grouping. The pending
eight-hour production decision remains separate.

See [REPORT.md](REPORT.md), [Precomputed.m](Precomputed.m),
[run_benchmark.m](run_benchmark.m), and [full-step results](fullsteps/results.json).
