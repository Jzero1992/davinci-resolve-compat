#!/usr/bin/env python3
"""Experimental Resolve 21 -> 20 / 20 -> 19 version-gate patch. No schema migration."""
import argparse
import copy
import errno
import shutil
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import zipfile


PROFILES = {
    b'17': {'source_major': 21, 'target_major': 20, 'target_schema': b'15', 'target_app': b'20.3.3.0010'},
    b'15': {'source_major': 20, 'target_major': 19, 'target_schema': b'14', 'target_app': b'19.1.4.0011'},
}


def select_profile(schema, target=None):
    if schema not in PROFILES:
        raise ValueError('只支持 Resolve 21 或 20 保存的工程。')
    profile = dict(PROFILES[schema])
    if target is not None:
        target = int(target)
        if target not in (19, 20) or target >= profile['source_major']:
            raise ValueError('目标版本必须比源工程低；Resolve 20 工程请选择 19。')
        profile.update(target_major=target, target_schema=b'14' if target == 19 else b'15',
                       target_app=b'19.1.4.0011' if target == 19 else b'20.3.3.0010')
    profile['experimental'] = profile['source_major'] == 21 and profile['target_major'] == 19
    return profile


def convert(source, destination=None, target=None):
    source = Path(source).expanduser().resolve()
    archive = source if source.suffix.lower() == '.drp' else source / 'project.drp'
    with zipfile.ZipFile(archive) as probe:
        version_match = re.search(rb'<ProjectVersion>(\d+)</ProjectVersion>', probe.read('project.xml'))
        schema = version_match.group(1) if version_match else None
        if schema not in PROFILES:
            raise ValueError('只支持 Resolve 21 → 20（17 → 15）和 20 → 19（15 → 14）；其他版本不修改。')
        profile = select_profile(schema, target)
    destination = Path(destination).expanduser().resolve() if destination else source.with_name((source.stem if source.is_dir() else archive.stem) + f'_Resolve{profile["target_major"]}_实验兼容.drp')
    if destination.exists():
        raise ValueError('输出文件已存在，请换一个文件名；工具不会覆盖文件。')
    if destination == archive:
        raise ValueError('不能覆盖原工程')
    changes = []
    original_hash = hashlib.sha256(archive.read_bytes()).hexdigest()
    with zipfile.ZipFile(archive) as zin:
        if zin.testzip():
            raise ValueError('原工程 ZIP 校验失败')
        project = zin.read('project.xml')
        version = re.search(rb'<ProjectVersion>(\d+)</ProjectVersion>', project)
        if not version or version.group(1) != schema:
            raise ValueError('检查期间工程版本发生变化，请重新选择文件。')
        destination.parent.mkdir(parents=True, exist_ok=True)
        fd, temp = tempfile.mkstemp(dir=destination.parent, suffix='.drp.tmp')
        os.close(fd)
        try:
            with zipfile.ZipFile(temp, 'w') as zout:
                zout.comment = zin.comment
                for info in zin.infolist():
                    data = zin.read(info)
                    before = data
                    if info.filename.endswith('.xml'):
                        data = data.replace(b'DbPrjVer="' + schema + b'"', b'DbPrjVer="' + profile['target_schema'] + b'"')
                        data = re.sub(rb'DbAppVer="' + str(profile['source_major']).encode() + rb'\.[0-9.]+"', b'DbAppVer="' + profile['target_app'] + b'"', data)
                        if info.filename == 'project.xml':
                            data, count = re.subn(b'<ProjectVersion>' + schema + b'</ProjectVersion>', b'<ProjectVersion>' + profile['target_schema'] + b'</ProjectVersion>', data)
                            if count != 1:
                                raise ValueError('工程版本字段不唯一')
                    zout.writestr(copy.copy(info), data)
                    if data != before:
                        changes.append(info.filename)
            with zipfile.ZipFile(temp) as check:
                if check.testzip():
                    raise ValueError('输出 ZIP 校验失败')
                assert check.namelist() == zin.namelist()
                for name in zin.namelist():
                    if name not in changes:
                        assert check.read(name) == zin.read(name)
            # Exclusive creation, even if another process creates destination meanwhile.
            try:
                os.link(temp, destination)
            except OSError as error:
                if error.errno not in (errno.EPERM, errno.EXDEV, errno.ENOTSUP, errno.EOPNOTSUPP):
                    raise
                # Some mounted volumes do not support hard links. Still never overwrite.
                created = False
                try:
                    with open(destination, 'xb') as output, open(temp, 'rb') as input_file:
                        created = True
                        shutil.copyfileobj(input_file, output)
                        output.flush()
                        os.fsync(output.fileno())
                except Exception:
                    if created:
                        destination.unlink()
                    raise
        finally:
            os.unlink(temp)
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == original_hash
    report = {'source': str(archive), 'source_sha256': original_hash, 'output': str(destination), 'output_sha256': hashlib.sha256(destination.read_bytes()).hexdigest(), 'changed_members': changes, 'method': f'Version metadata patch only: {schema.decode()} -> {profile["target_schema"].decode()}; no schema migration', 'source_resolve': profile['source_major'], 'target_resolve': profile['target_major'], 'experimental_cross_major': profile['experimental'], 'verified_in_resolve': False, 'media_directory': str(source / 'MediaFiles') if source.is_dir() else None}
    destination.with_suffix('.report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    return destination


def main():
    parser = argparse.ArgumentParser(description='Resolve 21 → 20 / 20 → 19 实验兼容补丁；原文件不变。并非完整格式转换。')
    parser.add_argument('source', nargs='?', help='.dra 文件夹或 .drp 文件')
    parser.add_argument('-o', '--output')
    parser.add_argument('--target', type=int, choices=[19, 20], help='默认自动降一级；21→19为实验选项')
    args = parser.parse_args()
    if not args.source:
        args.source = input('拖入 .dra 文件夹或 .drp 文件，按回车：\n').strip().strip("'\"").replace('\\ ', ' ')
    try:
        result = convert(args.source, args.output, args.target)
        print(f'已生成：{result}\n在对应目标版本的 Resolve 项目管理器中导入此 DRP。\n若媒体离线，请重新链接原 DRA/MediaFiles。\n此工具只修改版本标记，新版专属功能仍需逐项检查。')
    except (ValueError, OSError, zipfile.BadZipFile, KeyError) as error:
        parser.exit(1, f'未完成：{error}\n')


if __name__ == '__main__':
    main()
