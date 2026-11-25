import json
from pathlib import Path
import re
import sys
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.append(str(Path(__file__).resolve().parent.parent))
from resolve_compat import convert, PROFILES, select_profile


def inspect(source, target=None):
    source = Path(source).expanduser().resolve()
    if source.suffix.lower() not in ('.dra', '.drp'):
        raise ValueError('请选择 .dra 归档文件夹或 .drp 工程文件。')
    archive = source / 'project.drp' if source.is_dir() else source
    with zipfile.ZipFile(archive) as z:
        if z.testzip():
            raise ValueError('工程文件校验失败，无法转换。')
        s = z.read('project.xml')
        version = re.search(rb'<ProjectVersion>(\d+)</ProjectVersion>', s)
        app = re.search(rb'DbAppVer="([^"]+)"', s)
        name = re.search(rb'<ProjectName>(.*?)</ProjectName>', s, re.S)
        if not version:
            raise ValueError('未找到工程版本字段。')
        profile = select_profile(version.group(1), target) if version.group(1) in PROFILES else None
        return {'target_major': profile['target_major'] if profile else None, 'target_schema': profile['target_schema'].decode() if profile else None, 'experimental': profile['experimental'] if profile else False, 'ok': True, 'version': version.group(1).decode(), 'app': app.group(1).decode() if app else '未知', 'name': name.group(1).decode('utf-8') if name else source.stem, 'members': len(z.namelist()), 'size': archive.stat().st_size, 'supported': profile is not None, 'media': str(source / 'MediaFiles') if source.is_dir() else ''}

try:
    if sys.argv[1] == 'inspect':
        result = inspect(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != 'auto' else None)
    else:
        source = sys.argv[2]
        target = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != 'auto' else None
        inspect(source, target)
        result = {'ok': True, 'output': str(convert(source, sys.argv[3], target))}
    print(json.dumps(result, ensure_ascii=False))
except Exception as error:
    print(json.dumps({'ok': False, 'error': str(error)}, ensure_ascii=False))
    sys.exit(1)
