"""Download and verify the pinned redistributable arm64 Python runtime."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / 'distribution/runtime-source'
NAME = 'cpython-3.12.16+20261026-aarch64-apple-darwin-install_only_stripped.tar.gz'
URL = 'https://github.com/astral-sh/python-build-standalone/releases/download/20261026/' + NAME
SHA256 = '353d5f1b4fd2715e7053f12f068435d5bbad16b91e057006b5d01e0925709a7e'


def prepare():
    CACHE.mkdir(parents=True, exist_ok=True)
    archive = CACHE / 'python-arm64.tar.gz'
    if not archive.exists():
        partial = archive.with_suffix('.part')
        subprocess.run(['curl', '--fail', '--location', '--retry', '3', URL, '-o', str(partial)], check=True)
        if hashlib.sha256(partial.read_bytes()).hexdigest() != SHA256:
            partial.unlink()
            raise RuntimeError('Python runtime SHA256 verification failed')
        partial.replace(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise RuntimeError('Cached Python runtime SHA256 verification failed')
    extracted = CACHE / 'extracted'
    if not (extracted / 'python/bin/python3.12').is_file():
        with tempfile.TemporaryDirectory(dir=CACHE) as tmp:
            subprocess.run(['tar', '-xzf', str(archive), '-C', tmp], check=True)
            if extracted.exists():
                shutil.rmtree(extracted)
            Path(tmp).rename(extracted)
    (CACHE / 'SHA256SUMS').write_text(f'{SHA256}  {NAME}\n', encoding='utf-8')
    (CACHE / 'runtime-provenance.txt').write_text(
        'Python Build Standalone by Astral\n'
        f'{URL}\nSHA256 {SHA256}\n'
        'Runtime licenses are retained inside runtime/lib/python3.12/LICENSE.txt and runtime/share/.\n',
        encoding='utf-8',
    )
    print('Pinned Python runtime ready; SHA256 verified.')


if __name__ == '__main__':
    prepare()
