# Third-party notices

This repository's original source code and artwork are copyright © 2026 J.zero and licensed under MIT. The licenses of redistributed third-party software remain applicable to those components.

- **Python Build Standalone / CPython**: macOS distributions bundle a pinned Python 3.12.16 runtime from [Astral's Python Build Standalone](https://github.com/astral-sh/python-build-standalone/releases/tag/20261026). The runtime archive is not stored in this repository. Builds verify its SHA256 before extracting it. Runtime license files are retained inside the application, including `Contents/Resources/runtime/lib/python3.12/LICENSE.txt` and `runtime/share/`. See [upstream licensing](https://github.com/astral-sh/python-build-standalone/blob/main/docs/distributions.md).
- **dmgbuild, ds_store, mac_alias**: development/build dependencies used to construct disk images. They are not embedded in the application. Their license metadata is supplied by their respective Python packages.
- **Method reference**: [xax/resolve-project-version](https://github.com/xax/resolve-project-version) describes patching project version metadata. This tool is an independent implementation; that repository's source is not vendored here.

DaVinci Resolve and Blackmagic Design are trademarks of their respective owners. This is an unofficial community utility and is not affiliated with or endorsed by Blackmagic Design. Its three-color icon is original artwork for this utility, not an official product logo.
