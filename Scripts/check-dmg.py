#!/usr/bin/env python3
"""Verify a built installer, including its mounted app, destination and Finder layout."""
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile

from ds_store import DSStore


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def check(image, original):
    subprocess.run(["hdiutil", "verify", "-quiet", str(image)], check=True)
    with tempfile.TemporaryDirectory(prefix="notchest-dmg-check-") as temporary:
        mount = Path(temporary) / "mounted"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-quiet",
                        "-mountpoint", str(mount), str(image)], check=True)
        try:
            visible = {p.name for p in mount.iterdir() if not p.name.startswith(".")}
            require(visible == {"Notchest.app", "Applications"}, f"Unexpected visible items: {visible}")
            require((mount / "Applications").is_symlink(), "Applications must be a symbolic link")
            require(os.readlink(mount / "Applications") == "/Applications", "Wrong installation destination")
            require((mount / ".background.tiff").is_file(), "Missing Retina background")
            require((mount / ".VolumeIcon.icns").is_file(), "Missing volume icon")
            with DSStore.open(str(mount / ".DS_Store"), "r") as store:
                window, view = store["."]["bwsp"], store["."]["icvp"]
                require(window["WindowBounds"].endswith("{760, 532}}"), "Wrong installer window dimensions")
                require(not window["ShowToolbar"] and not window["ShowSidebar"], "Installer chrome is visible")
                require(view["backgroundType"] == 2 and bool(view["backgroundImageAlias"]), "Background is not linked")
                require(view["iconSize"] == 112 and view["arrangeBy"] == "none", "Icon layout would move the targets")
                require(store["Notchest.app"]["Iloc"] == (200, 278), "App is outside its well")
                require(store["Applications"]["Iloc"] == (560, 278), "Applications is outside its well")
            app = mount / "Notchest.app"
            subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
            with (app / "Contents/Info.plist").open("rb") as source:
                info = plistlib.load(source)
            require(info["CFBundleIdentifier"] == "dev.notchest.island", "Unexpected app bundle")
            for name in ["Notchest", "NotchestCommand"]:
                require(os.access(app / "Contents/MacOS" / name, os.X_OK), f"{name} is not executable")
            if original:
                for relative in ["Contents/Info.plist", "Contents/Resources/Notchest.icns",
                                 "Contents/MacOS/Notchest", "Contents/MacOS/NotchestCommand"]:
                    digest = lambda path: hashlib.sha256(path.read_bytes()).digest()
                    require(digest(app / relative) == digest(original / relative), f"Packaged file changed: {relative}")
        finally:
            subprocess.run(["hdiutil", "detach", "-quiet", str(mount)], check=True)
    print("Passed: installer checksum, mounted app signature, executable permissions, Applications link, Retina background and Finder layout.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--app", type=Path)
    args = parser.parse_args()
    check(args.image.resolve(), args.app.resolve() if args.app else None)
