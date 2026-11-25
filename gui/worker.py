import json
import os
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

ENGLISH_ERRORS = {
    '请选择 .dra 归档文件夹或 .drp 工程文件。': 'Choose a .dra archive folder or a .drp project file.',
    '工程文件校验失败，无法转换。': 'Project integrity check failed.',
    '未找到工程版本字段。': 'The project version field is missing.',
    '只支持 Resolve 21 或 20 保存的工程。': 'Choose a project saved in Resolve 21 or 20.',
    '目标版本必须比源工程低；Resolve 20 工程请选择 19。': 'The target must be older than the source. Choose 19 for a Resolve 20 project.',
    '输出文件已存在，请换一个文件名；工具不会覆盖文件。': 'The output file already exists. Choose a different location or filename.',
    '不能覆盖原工程': 'The original project cannot be overwritten.',
    '原工程 ZIP 校验失败': 'The source project archive failed its integrity check.',
    '检查期间工程版本发生变化，请重新选择文件。': 'The project version changed during the check. Select the file again.',
    '工程版本字段不唯一': 'The archive contains more than one project version field.',
    '输出 ZIP 校验失败': 'The output archive failed its integrity check.',
    '只支持 Resolve 21 → 20（17 → 15）和 20 → 19（15 → 14）；其他版本不修改。': 'Choose a supported Resolve 21 or 20 project.',
}

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
    message = str(error)
    if os.environ.get('RESOLVE_COMPAT_LANGUAGE') == 'en':
        message = ENGLISH_ERRORS.get(message, message)
    print(json.dumps({'ok': False, 'error': message}, ensure_ascii=False))
    sys.exit(1)
