from pathlib import Path
import sys
root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root/'distribution/build-deps'))
import dmgbuild
from ds_store import DSStore
from mac_alias import Alias
mount = {}
def capture_mount(path, options):
    mount['path'] = Path(path)
def customize(event):
    if event.get('type') == 'operation::finished' and event.get('operation') == 'dsstore::create':
        path = mount['path']
        with DSStore.open(str(path/'.DS_Store'), 'r+') as store:
            settings = store['.']['icvp']
            settings['backgroundType'] = 2
            settings['backgroundImageAlias'] = Alias.for_file(str(path/'达芬奇工程兼容工具.app/Contents/Resources/DMG-background.png')).to_bytes()
            store['.']['icvp'] = settings

out = root/'distribution/releases'
out.mkdir(exist_ok=True)
filename = out/'达芬奇工程兼容工具-1.4.0-Apple芯片-内置运行环境.dmg'
if filename.exists():
    raise SystemExit('DMG already exists; choose a new release filename.')
dmgbuild.build_dmg(str(filename), '达芬奇工程兼容工具 1.4.0', callback=customize, settings={
    'create_hook': capture_mount,
    'format': 'UDZO',
    'files': [str(root/'达芬奇工程兼容工具.app'), str(root/'distribution/首次打开说明.txt'), str(root/'distribution/Getting Started.txt')],
    'symlinks': {'应用程序': '/Applications'},
    'background': '#202020',
    'window_rect': ((180, 150), (820, 560)),
    'icon_size': 64,
    'text_size': 13,
    'icon_locations': {'达芬奇工程兼容工具.app': (220, 220), '应用程序': (600, 220), '首次打开说明.txt': (712, 420), 'Getting Started.txt': (712, 520)},
    'default_view': 'icon-view',
    'include_icon_view_settings': True,
    'include_list_view_settings': False,
    'show_toolbar': False,
    'show_status_bar': False,
})
print(filename)
