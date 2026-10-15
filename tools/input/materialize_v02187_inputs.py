#!/usr/bin/env python3
"""Verify or reconstruct the byte-identical v0.21.87 runtime inputs from LFS parts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        while block := stream.read(8 * 1024 * 1024):
            h.update(block)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-only', action='store_true', help='Verify existing runtime inputs only')
    parser.add_argument('--destination', type=Path, default=ROOT, help='Root for the original data/ paths')
    args = parser.parse_args()
    directory = ROOT / 'data/distribution/v02187'
    manifest = json.loads((directory / 'manifest.json').read_text())
    for item in manifest['files']:
        relative = Path(item['path'])
        assert not relative.is_absolute() and '..' not in relative.parts
        target = args.destination.resolve() / relative
        if target.exists():
            if target.stat().st_size != item['bytes'] or digest(target) != item['sha256']:
                raise ValueError(f'Existing input differs; preserved without overwriting: {target}')
            print(f'Verified {target}', flush=True)
            continue
        if args.verify_only:
            raise FileNotFoundError(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=target.parent, prefix=target.name+'.materialize-', delete=False) as out:
                temporary = Path(out.name)
                total = hashlib.sha256()
                written = 0
                for part in item['parts']:
                    name = part['name']
                    assert Path(name).name == name
                    part_hash = hashlib.sha256()
                    count = 0
                    with (directory / name).open('rb') as stream:
                        while block := stream.read(8 * 1024 * 1024):
                            out.write(block);total.update(block);part_hash.update(block)
                            count += len(block);written += len(block)
                    if count != part['bytes'] or part_hash.hexdigest() != part['sha256']:
                        raise ValueError(f'Incomplete/corrupt LFS part: {name}; run git lfs pull')
                assert written == item['bytes'] and total.hexdigest() == item['sha256']
                out.flush();os.fsync(out.fileno())
            # Atomic install without replacing a file created concurrently.
            os.link(temporary, target)
            print(f'Reconstructed {target}', flush=True)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
