#!/usr/bin/env python3
"""Post-process the Godot Web export.

Godot's default shell is a bare canvas. This script adds the arcade bridge, the
portrait framing CSS, a mobile viewport and the game's own title, and copies the
drop-in arcade client next to the build.

    python3 Tools/patch_web.py
"""

from __future__ import annotations

import pathlib
import re
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLAY = ROOT / "web" / "play"
CLIENT = ROOT / "web" / "arcade-client.js"
MANIFEST = ROOT / "web" / "manifest.webmanifest"

HEAD_INJECT = """\t<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover" />
\t<meta name="theme-color" content="#05080f" />
\t<meta name="apple-mobile-web-app-capable" content="yes" />
\t<meta name="mobile-web-app-capable" content="yes" />
\t<meta name="description" content="Wonderguard 3D — a portrait-first 3D toybox tower defense with 1,000 levels, 20 kingdoms and 26 towers. A Little Joy Arcade original." />
\t<link rel="stylesheet" href="./frame.css" />
\t<link rel="manifest" href="./manifest.webmanifest" />
\t<script src="./arcade-bridge.js"></script>
\t<script src="./arcade-client.js" data-game-id="wonderguard-3d"></script>
"""


def main() -> int:
    index = PLAY / "index.html"
    if not index.exists():
        print("web/play/index.html is missing — run the Godot Web export first.")
        return 1

    html = index.read_text(encoding="utf-8")
    html = re.sub(r"<title>.*?</title>", "<title>Wonderguard 3D</title>", html, flags=re.S)
    # Godot ships an older viewport tag; drop it so the one below is the only
    # one and viewport-fit=cover survives the safe-area insets.
    html = re.sub(r"\s*<meta name=\"viewport\"[^>]*>", "", html)
    if "arcade-bridge.js" not in html:
        html = html.replace("</head>", HEAD_INJECT + "</head>")
    index.write_text(html, encoding="utf-8")

    if CLIENT.exists():
        shutil.copyfile(CLIENT, PLAY / "arcade-client.js")
        text = CLIENT.read_text(encoding="utf-8")
        if "__LJA_ANON_KEY__" in text:
            print("warning: arcade-client.js still has the anon-key placeholder")
    else:
        print("warning: arcade client not found at", CLIENT)

    if MANIFEST.exists():
        shutil.copyfile(MANIFEST, PLAY / "manifest.webmanifest")
    else:
        print("warning: web manifest not found at", MANIFEST)

    (PLAY / ".nojekyll").write_text("", encoding="utf-8")
    # The export directory lives inside the Godot project. Without this marker
    # the editor imports the build's own PNGs and starts packing them back into
    # the next .pck.
    (PLAY / ".gdignore").write_text("", encoding="utf-8")
    print("patched", index.relative_to(ROOT))
    for path in sorted(PLAY.iterdir()):
        print(f"  {path.name:30s} {path.stat().st_size/1024/1024:6.2f} MiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
