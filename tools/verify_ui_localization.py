#!/usr/bin/env python3
"""Check translated UI source messages in Phosprite's core iPad surfaces.

No third-party modules are needed. Run at the repository root.
This deliberately treats developer-facing identifiers, unit labels, and brand
names as non-translatable. Extend SCENE_FILES/SCRIPT_FILES as new screens ship.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SCENE_FILES = (
    "src/UI/ProjectGallery/ProjectGallery.tscn",
    "src/UI/ProjectGallery/NewProjectDialog.tscn",
    "src/UI/Workspace/TimelineHeaderControls.tscn",
    "src/UI/TopMenuContainer/TopMenuContainer.tscn",
    "src/Preferences/PreferencesDialog.tscn",
    "src/UI/GlobalToolOptions/GlobalToolOptions.tscn",
    "src/Tools/DesignTools/Pencil.tscn",
    "src/UI/Timeline/SingleFrameLayerStrip.tscn",
)
SCRIPT_FILES = (
    "src/UI/TopMenuContainer/TopMenuContainer.gd",
    "src/Preferences/PreferencesDialog.gd",
    "src/UI/ProjectGallery/ProjectGallery.gd",
    "src/UI/ProjectGallery/ProjectGalleryCard.gd",
    "src/UI/Workspace/WorkspaceUIProfile3.gd",
    "src/UI/Workspace/TimelineHeaderControls.gd",
    "src/UI/Timeline/SingleFrameLayerStrip.gd",
)
UNTRANSLATED_BY_DESIGN = {
    "Phosprite", "px", "RGBA", "RGBA8", "RGB", "FPS", "UI%d",
    "FFmpeg", "64 × 64 px", "x", "X", "Y", "R", "G", "B", "A",
}
# These new product messages must exist in BOTH Chinese catalogs.
PHOSPRITE_REQUIRED = (
    "Multi-Select", "Exit Multi-Select", "New Project", "Preset size",
    "Custom size", "No projects yet", "Rename Project",
    "Project deleted.", "Loading preview…", "Single frame",
    "Switch to single-frame layer view", "More timeline controls",
    "Project Operations", "Canvas Aids", "Layout Presets",
    "UI Layout", "Canvas Display", "About Phosprite",
    "Palette & Color", "Auto Outline", "Create folder from selection",
    "Shortcut profile:", "New Shortcut Profile",
)
SCENE_PROPERTY = re.compile(
    r'^\\s*(?:text|title|dialog_text|placeholder_text|tooltip_text)'
    r'\\s*=\\s*("(?:\\\\.|[^"\\\\])*")', re.MULTILINE
)
TR_CALL = re.compile(r'\\btr\\(\\s*("(?:\\\\.|[^"\\\\])*")')
PRINTF = re.compile(r'%(?:\\d+\\$)?[sd]|\\{[A-Za-z_][A-Za-z0-9_]*\\}')


def read_catalog(path: Path) -> dict[str, str]:
    messages: dict[str, str] = {}
    for block in re.split(r"\\n\\s*\\n", path.read_text(encoding="utf-8")):
        message_id = ""
        translated = ""
        field = ""
        for line in block.splitlines():
            if line.startswith("msgid "):
                field = "id"
                message_id = json.loads(line[6:])
            elif line.startswith("msgstr "):
                field = "str"
                translated = json.loads(line[7:])
            elif line.startswith('"') and field == "id":
                message_id += json.loads(line)
            elif line.startswith('"') and field == "str":
                translated += json.loads(line)
            elif line.startswith(("msgctxt ", "msgid_plural ", "msgstr[")):
                field = ""
        if message_id:
            messages[message_id] = translated
    return messages


def source_messages(path: Path) -> set[str]:
    contents = path.read_text(encoding="utf-8")
    pattern = SCENE_PROPERTY if path.suffix == ".tscn" else TR_CALL
    return {
        json.loads(match.group(1))
        for match in pattern.finditer(contents)
        if json.loads(match.group(1)) not in UNTRANSLATED_BY_DESIGN
    }


def main() -> int:
    pot = read_catalog(ROOT / "Translations/Translations.pot")
    simplified = read_catalog(ROOT / "Translations/zh_CN.po")
    traditional = read_catalog(ROOT / "Translations/zh_TW.po")
    failures: list[str] = []
    checked = 0
    for relative_path in (*SCENE_FILES, *SCRIPT_FILES):
        path = ROOT / relative_path
        for key in source_messages(path):
            checked += 1
            if key not in pot:
                failures.append(f"{relative_path}: template missing {key!r}")
            if not simplified.get(key):
                failures.append(f"{relative_path}: zh_CN missing {key!r}")
    for key in PHOSPRITE_REQUIRED:
        for name, catalog in (("zh_CN", simplified), ("zh_TW", traditional)):
            translated = catalog.get(key, "")
            if not translated:
                failures.append(f"{name}: missing {key!r}")
            elif sorted(PRINTF.findall(key)) != sorted(PRINTF.findall(translated)):
                failures.append(f"{name}: placeholder mismatch {key!r}")
    for problem in sorted(set(failures)):
        print("ERROR:", problem)
    print(f"Checked {checked} UI source references, {len(PHOSPRITE_REQUIRED)} cross-locale keys.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
