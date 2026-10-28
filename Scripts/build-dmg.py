#!/usr/bin/env python3
"""Build the branded disk image without controlling Finder or requiring Automation access."""
import argparse
from pathlib import Path

import dmgbuild


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    app, output = args.app.resolve(), args.output.resolve()
    if not (app / "Contents/MacOS/Notchest").is_file():
        parser.error(f"Notchest app bundle not found: {app}")
    output.parent.mkdir(parents=True, exist_ok=True)
    dmgbuild.build_dmg(
        str(output), "Notchest", settings_file=str(root / "Scripts/dmg-settings.py"),
        defines={"project": str(root), "app": str(app)},
    )
    print(f"Built branded installer: {output}")


if __name__ == "__main__":
    main()
