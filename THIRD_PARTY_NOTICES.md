# Third-party notices

Notchest includes SwiftTerm, a terminal emulator library by Miguel de Icaza and contributors, licensed under the MIT License.

- Upstream: https://github.com/migueldeicaza/SwiftTerm
- Vendored source: `Vendor/SwiftTerm/`
- License: `Vendor/SwiftTerm/LICENSE`
- Distribution copy: `Resources/SwiftTerm-LICENSE.txt`, also copied into the built app bundle by `build.sh`
- Source version metadata: `Vendor/SwiftTerm/SwiftTermBuildInfo.swift`

The vendored build uses the Core Graphics renderer. The Metal shader is excluded from compilation so this project can build using Apple Command Line Tools without the Metal shader compiler.

This notice does not assign a license to Notchest's original source code.
