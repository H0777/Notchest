#!/usr/bin/env python3
"""Prepare an isolated capture copy; production Swift sources are never modified."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parents[2]
copy = root / '.build' / 'gallery-source'
copy.mkdir(parents=True, exist_ok=True)
for name in ['Sources', 'Resources', 'Vendor', 'Tests']:
    shutil.copytree(root / name, copy / name, dirs_exist_ok=True)
for name in ['Package.swift', 'build.sh']:
    shutil.copy2(root / name, copy / name)
source = copy / 'Sources' / 'Notchest'
shutil.copy2(Path(__file__).with_name('DemoData.swift'), source / 'GalleryDemo.swift')
p = source / 'NotchestApp.swift'
s = p.read_text().replace('private let model = AppModel()', 'private let model = GalleryDemo.makeModel()')
assert 'GalleryDemo.makeModel()' in s
s = s.replace('        setupHotKey()', '        GalleryDemo.apply(model)')
for line in ['        model.developer.start()\n', '        model.monitor.start()\n', '        model.weather.start()\n', '        model.tools.start()\n']:
    assert line in s
    s = s.replace(line, '')
# Keep the application's normal navigation callbacks intact.
p.write_text(s)
p = source / 'EmbeddedTerminal.swift'
s = p.read_text().replace('args: ["-l"]', 'args: ["-f"]')
s = s.replace('environment["TERM"] = "xterm-256color"', 'environment["TERM"] = "xterm-256color"\n        environment["PS1"] = "notchest % "')
p.write_text(s)
print(copy)
