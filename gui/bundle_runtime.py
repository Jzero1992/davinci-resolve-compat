"""Bundle pinned, checksum-verified Python Build Standalone and sign its Mach-O files."""
from pathlib import Path
import hashlib
import shutil
import subprocess

from prepare_runtime import prepare
prepare()

root = Path(__file__).resolve().parent.parent
cache = root / 'distribution/runtime-source'
name = 'cpython-3.12.16+20261026-aarch64-apple-darwin-install_only_stripped.tar.gz'
expected = next(line.split()[0] for line in (cache/'SHA256SUMS').read_text().splitlines() if line.endswith(name))
assert hashlib.sha256((cache/'python-arm64.tar.gz').read_bytes()).hexdigest() == expected
resources = root/'达芬奇工程兼容工具.app/Contents/Resources'
runtime = resources/'runtime'
if runtime.exists():
    shutil.rmtree(runtime)
shutil.copytree(cache/'extracted/python', runtime, symlinks=True)
shutil.copy2(cache/'runtime-provenance.txt', resources/'Python-runtime-provenance.txt')
magics = [b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca']
count = 0
for path in runtime.rglob('*'):
    if path.is_file() and not path.is_symlink():
        with path.open('rb') as f:
            magic = f.read(4)
        if magic in magics:
            subprocess.run(['codesign', '--force', '--sign', '-', str(path)], check=True, capture_output=True)
            count += 1
print(f'Bundled Python 3.12.16, signed {count} runtime binaries; no system Python dependency.')
