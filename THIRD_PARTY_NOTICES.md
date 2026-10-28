# Third-party notices

Notchest includes SwiftTerm, a terminal emulator library by Miguel de Icaza and contributors, licensed under the MIT License.

- Upstream: https://github.com/migueldeicaza/SwiftTerm
- Vendored source: `Vendor/SwiftTerm/`
- License: `Vendor/SwiftTerm/LICENSE`
- Distribution copy: `Resources/SwiftTerm-LICENSE.txt`, also copied into the built app bundle by `build.sh`
- Source version metadata: `Vendor/SwiftTerm/SwiftTermBuildInfo.swift`

The vendored build uses the Core Graphics renderer. The Metal shader is excluded from compilation so this project can build using Apple Command Line Tools without the Metal shader compiler.

This notice does not assign a license to Notchest's original source code.

## Installer build tools

The DMG packaging workflow uses the following tools in an isolated build environment. Their code is not included in the Notchest app or distributed installer.

- [dmgbuild](https://github.com/dmgbuild/dmgbuild), version 1.6.5 — MIT License.
- [ds_store](https://github.com/dmgbuild/ds_store), version 1.3.1 — MIT License.
- [mac_alias](https://github.com/dmgbuild/mac_alias), version 2.2.2 — MIT License.

Their installed distributions include their respective license files.
