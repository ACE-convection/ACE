# v0.21.87 exact input distribution

Developer policy update: basis payloads for v0.21 onward are local-only,
including the shared NetCDF operators and all their parts. Do not add them to
Git or upload them through LFS. The instructions below describe reconstruction
from separately supplied local files, not files promised by a fresh clone.
The developer authorized removing new basis/operator pointers from the release
history after v0.20.87. Earlier historical inputs are preserved.

The supplied basis MAT and raw sounding NC, plus the validated shared-case NC,
were split into <=1 GiB local byte parts. No values or file encodings are
changed. `manifest.json` records each ordered part and full-file size/SHA-256.

After cloning:

```sh
# Obtain the matching local parts separately first.
python3 tools/input/materialize_v02187_inputs.py
```

This reconstructs the original runtime paths under `data/basis`,
`data/soundings` and `data/input`. Existing matching files are verified;
differing existing files are preserved and reported as an error. Partial
reconstruction uses a temporary file and is installed atomically only after
all part/full hashes match. Run `--verify-only` to check materialized inputs.

The shared input is 5,667,681,931 bytes, above GitHub's maximum per-file LFS
limit. All 12 parts fit within 1 GiB. A local fresh-path reconstruction and
existing-file preservation check passed before the release commit. LFS content
for any remaining non-basis files is separate from this local materialization.
Basis and shared-operator payloads must never be uploaded for v0.21 onward.
