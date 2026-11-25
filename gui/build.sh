#!/bin/zsh
set -eu
cd -- "${0:A:h}/.."
app='达芬奇工程兼容工具.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp resolve_compat.py gui/worker.py "$app/Contents/Resources/"
cp gui/assets/AppIcon.icns "$app/Contents/Resources/"
cp distribution/DMG-background.png "$app/Contents/Resources/"
xcrun swiftc -target arm64-apple-macos12.0 gui/main.swift -o "$app/Contents/MacOS/ResolveCompat" -framework AppKit -O
/usr/bin/python3 - <<'PY'
import plistlib
p='达芬奇工程兼容工具.app/Contents/Info.plist'
d={'CFBundleName':'达芬奇工程兼容工具','CFBundleDisplayName':'达芬奇工程兼容工具','CFBundleIdentifier':'local.jzero.resolve-compat','CFBundleIconFile':'AppIcon','CFBundleVersion':'8','CFBundleShortVersionString':'1.3.3','CFBundleExecutable':'ResolveCompat','CFBundlePackageType':'APPL','LSMinimumSystemVersion':'12.0','NSHighResolutionCapable':True,'CFBundleDocumentTypes':[{'CFBundleTypeName':'DaVinci Resolve Project','CFBundleTypeRole':'Viewer','LSHandlerRank':'Alternate','CFBundleTypeExtensions':['drp','dra']}],'NSHumanReadableCopyright':'Copyright © 2026 Jzero. All rights reserved.'}
with open(p,'wb') as f:plistlib.dump(d,f)
PY
/usr/bin/python3 gui/bundle_runtime.py
codesign --force --deep --sign - "$app"
