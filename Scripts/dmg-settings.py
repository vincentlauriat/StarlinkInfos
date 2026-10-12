# dmgbuild settings for the release DMG, read by Scripts/release.sh.
#
# dmgbuild writes the Finder layout (.DS_Store) itself, so the DMG gets its
# background and icon positions without scripting Finder. The Finder AppleScript
# this replaces needs Apple Events, which some shells cannot send (it silently
# shipped two ClaudeCockpit releases without a layout).
#
# Values come in through `-D`: app (the signed .app) and background (the PNG
# made by make-dmg-background.swift, 144 dpi so it fills the window on Retina).
import os

app = defines["app"]  # noqa: F821 — injected by dmgbuild
app_name = os.path.basename(app)

files = [app]
symlinks = {"Applications": "/Applications"}

format = "UDZO"
compression_level = 9
filesystem = "HFS+"

background = defines["background"]  # noqa: F821
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
window_rect = ((200, 100), (540, 380))
default_view = "icon-view"
arrange_by = None
icon_size = 128
icon_locations = {app_name: (140, 200), "Applications": (400, 200)}
