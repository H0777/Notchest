"""Finder layout for the Notchest disk image (dmgbuild settings)."""
from pathlib import Path

# dmgbuild supplies settings and defines to this module; use an explicit root for any checkout path.
project = Path(defines["project"]).resolve()
application = Path(defines.get("app", project / "dist/Notchest.app")).resolve()
format = "UDZO"
filesystem = "HFS+"
compression_level = 9
files = [
    (str(application), "Notchest.app"),
    # Same bilingual first-open guide that ships inside the ZIP, so both
    # packages explain the one-time Gatekeeper approval by themselves.
    (str(project / "Packaging/READ-ME-FIRST.txt"), "READ-ME-FIRST.txt"),
]
symlinks = {"Applications": "/Applications"}
icon = str(application / "Contents/Resources/Notchest.icns")
background = str(project / "Brand/Installer/background.png")
# Do not set FinderInfo on the signed app bundle to hide its extension.
hide_extensions = []
window_rect = ((180, 180), (760, 532))
icon_locations = {"Notchest.app": (200, 278), "Applications": (560, 278), "READ-ME-FIRST.txt": (380, 430)}
icon_size = 112
text_size = 14
label_pos = "bottom"
arrange_by = None
grid_spacing = 80
scroll_position = (0, 0)
default_view = "icon-view"
include_icon_view_settings = True
show_icon_preview = False
show_item_info = False
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
