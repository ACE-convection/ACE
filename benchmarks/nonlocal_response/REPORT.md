# NONLOCAL_RESPONSE actual-input benchmark results

All changes are confined to this benchmark directory. Production source hashes match the pre-test manifest. Integration requires developer approval.

## Kernel comparison

Three timeit estimates per version; median reported. Errors are maxima over all nine captured real SSPRK stages, after makima.

| Version | Time (ms) | Speedup | Max Error | Relative L2 |
|---|---:|---:|---:|---:|
| Original | 531.372 | 1.000x | 0 | 0 |
| Vectorized | 563.437 | 0.943x | 0 | 0 |
| Loop-based | 5466.989 | 0.097x | 0 | 0 |
| Precomputed | 201.652 | 2.635x | 9.801e-17 | 5.849e-14 |

## Three main findings

1. The large 201x200x88x88 element-wise products and reductions dominate Original. The original profiler spent 5.146 seconds across nine calls, versus 0.024 seconds inside interp1 and 0.010 seconds inside mean. Component timeit: reshape 0.0010 ms, mean 0.0830 ms, each product 230–244 ms, vertical sum 135.7 ms, forcing sum 0.150 ms, makima 0.887 ms. Separate component timings materialize different temporaries and cannot be added to predict compound performance.

2. Precomputed is fastest in this actual-input test. A fixed interleaved three-operator matrix avoids runtime basis-sized element-wise temporary arrays; one BLAS matrix-vector product is followed by the original makima. Kernel speedup is 2.64x. Maximum error 9.80e-17 and relative L2 5.85e-14 pass the declared screening limits. Vectorized/Loop-based remain exact on these inputs but are slower.

3. Actual complete-step replays confirm a speedup: Original 3.9068 s versus Precomputed 1.9685 s (medians of two independent processes per method), 1.985x observed. Maximum MF/theta_e/qt differences are 5.00e-16 / 5.68e-14 / 2.17e-19. Both variants pack before the timer to match setup memory footprint; initialization and packing are excluded.

## Costs and limits

- One-time packing in the kernel benchmark: 6.389 s. Packed matrix storage is 7.471 GB (6.96 GiB); this experiment retains the original basis too, increasing memory usage. Packing is not included in runtime timings.
- Only the current coarse_z=2, actual native t=600 s state and its nine SSPRK stages are covered. Zero-reference buoyancy is enabled. No claim is made for other configurations.
- Floating-point summation changes in Precomputed. No physical algorithm or makima formula is replaced. One-step screening does not establish long-trajectory scientific equivalence.
- Previously authorized background validation competes for CPU/memory. timeit order is reversed in the middle round; sample counts remain limited. No guaranteed production long-run speedup is claimed.

## One next optimization recommendation

After developer approval, compare Original and Precomputed over the same native ten-minute trajectory, including water bookkeeping and full diagnostics, before considering production integration. Keep the pending original one-hour validation and eight-hour decision separate.

See README.md for fixture details, scripts, scope and replay commands. Raw outputs: results/results.json, results/profile.json, fullsteps/results.json; provenance: manifest.json.
