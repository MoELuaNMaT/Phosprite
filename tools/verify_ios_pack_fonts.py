#!/usr/bin/env python3
"""Require both Latin and CJK imported font payloads in an exported Godot PCK.

A byte-string search is not enough: a font path can survive in a .remap even
if its imported fontdata is missing. Parse the complete Godot 4 pack directory
and require actual non-empty font resource entries before distributing an IPA.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

FONT_SIZES = {
    "Roboto-Regular.ttf-": 50_000,
    "NotoSansCJKsc-Regular.otf-": 1_000_000,
}


def read_manifest(data: bytes) -> dict[str, tuple[int, int]]:
    if len(data) < 116 or data[:4] != b"GDPC":
        raise ValueError("Invalid Godot PCK header")
    base = struct.unpack_from("<Q", data, 24)[0]
    offset = struct.unpack_from("<Q", data, 32)[0]
    if base != 112 or offset >= len(data):
        raise ValueError("Unexpected PCK directory header")
    count = struct.unpack_from("<I", data, offset)[0]
    if not 1 <= count <= 100_000:
        raise ValueError("Unexpected PCK entry count")
    offset += 4
    files: dict[str, tuple[int, int]] = {}
    for _ in range(count):
        path_size = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        if not 1 <= path_size <= 4096 or offset + path_size > len(data):
            raise ValueError("Invalid PCK path entry")
        path = data[offset : offset + path_size].rstrip(b"\x00").decode("utf-8")
        offset += path_size
        file_offset, size = struct.unpack_from("<QQ", data, offset)
        offset += 16 + 16 + 4  # data offsets, MD5, flags
        if file_offset + base + size > len(data):
            raise ValueError(f"Out-of-range packed file: {path}")
        files[path] = file_offset + base, size
    if offset != len(data):
        raise ValueError("Unexpected PCK directory trailer")
    return files


def verify(pack_path: Path) -> None:
    data = pack_path.read_bytes()
    entries = read_manifest(data)
    for needle, min_size in FONT_SIZES.items():
        matched = [
            (name, size)
            for name, (_, size) in entries.items()
            if name.startswith(".godot/imported/")
            and needle in name
            and name.endswith(".fontdata")
        ]
        if len(matched) != 1 or matched[0][1] < min_size:
            raise ValueError(f"Missing/undersized imported font: {needle} ({matched})")
        print(f"[PHOSPRITE-FONT-PACK] {matched[0][0]} {matched[0][1]} bytes")
    print("[PHOSPRITE-FONT-PACK] PASS: IPA embeds Roboto and Noto Sans CJK")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: verify_ios_pack_fonts.py path/to/Phosprite.pck")
    try:
        verify(Path(sys.argv[1]))
    except (OSError, ValueError, struct.error, UnicodeDecodeError) as exc:
        raise SystemExit(f"[PHOSPRITE-FONT-PACK] FAIL: {exc}") from exc
