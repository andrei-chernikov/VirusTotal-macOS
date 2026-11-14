#!/usr/bin/env python3
"""Write Finder metadata directly, so the DMG does not depend on UI timing.

Requires the pinned tools in requirements-packaging.txt.
"""
from pathlib import Path
import sys

from ds_store import DSStore
from mac_alias import Alias

volume = Path(sys.argv[1])
background = volume / ".background" / "background.png"
with DSStore.open(str(volume / ".DS_Store"), "w+") as store:
    store["."]["bwsp"] = {
        "ShowStatusBar": False, "ShowToolbar": False, "ShowPathbar": False,
        "ShowSidebar": False, "ShowTabView": False,
        "ContainerShowSidebar": False, "WindowBounds": "{{100, 100}, {768, 544}}",
    }
    store["."]["icvp"] = {
        "viewOptionsVersion": 1, "backgroundType": 2,
        "backgroundColorRed": 1.0, "backgroundColorGreen": 1.0, "backgroundColorBlue": 1.0,
        "backgroundImageAlias": Alias.for_file(str(background)).to_bytes(),
        "iconSize": 112.0, "textSize": 14.0, "labelOnBottom": True,
        "showItemInfo": False, "showIconPreview": True, "arrangeBy": "none",
        "gridOffsetX": 0.0, "gridOffsetY": 0.0, "gridSpacing": 100.0,
        "scrollPositionX": 0.0, "scrollPositionY": 0.0,
    }
    store["."]["vSrn"] = ("long", 1)
    store["VirusTotal.app"]["Iloc"] = (222, 222)
    store["Applications"]["Iloc"] = (548, 222)
