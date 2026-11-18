#!/usr/bin/env python3
"""Flatten simulator PNGs to opaque RGB and check App Store pixel sizes.

The App Store rejects a screenshot that still has an alpha channel. The medium
iPhone slot is 1206x2622, the 6.9-inch slot is 1320x2868, and the 13-inch iPad
slot is 2064x2752.
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path


EXPECTED = {
    "iphone": (1206, 2622),
    "iphone69": (1320, 2868),
    "ipad": (2064, 2752),
}


def read_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path} is not a PNG")
    pos = 8
    width = height = None
    color_type = None
    bit_depth = None
    interlace = None
    idat = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _comp, _filter, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
        elif kind == b"IDAT":
            idat += chunk
        elif kind == b"IEND":
            break
    if width is None or color_type is None or interlace is None:
        raise SystemExit(f"{path} is missing an image header")
    if bit_depth != 8 or interlace != 0 or color_type not in (2, 6):
        raise SystemExit(f"{path} is not an 8-bit RGB or RGBA PNG ({color_type=}, {bit_depth=})")
    channels = 4 if color_type == 6 else 3
    raw = zlib.decompress(idat)
    stride = width * channels
    rows = []
    i = 0
    previous = bytearray(stride)
    for _y in range(height):
        filter_type = raw[i]
        i += 1
        scan = bytearray(raw[i : i + stride])
        i += stride
        if filter_type == 0:
            current = scan
        elif filter_type == 1:
            current = bytearray(stride)
            for x, value in enumerate(scan):
                left = current[x - channels] if x >= channels else 0
                current[x] = (value + left) & 255
        elif filter_type == 2:
            current = bytearray((scan[x] + previous[x]) & 255 for x in range(stride))
        elif filter_type == 3:
            current = bytearray(stride)
            for x, value in enumerate(scan):
                left = current[x - channels] if x >= channels else 0
                current[x] = (value + ((left + previous[x]) // 2)) & 255
        elif filter_type == 4:
            current = bytearray(stride)
            for x, value in enumerate(scan):
                left = current[x - channels] if x >= channels else 0
                up = previous[x]
                up_left = previous[x - channels] if x >= channels else 0
                current[x] = (value + _paeth(left, up, up_left)) & 255
        else:
            raise SystemExit(f"{path} uses an unknown PNG filter {filter_type}")
        rows.append(bytes(current))
        previous = current
    if color_type == 2:
        rgb = b"".join(rows)
    else:
        out = bytearray()
        for row in rows:
            for x in range(0, len(row), 4):
                r, g, b, a = row[x : x + 4]
                if a == 255:
                    out.extend((r, g, b))
                else:
                    # Composite on white. Simulator captures are normally opaque.
                    out.append((r * a + 255 * (255 - a)) // 255)
                    out.append((g * a + 255 * (255 - a)) // 255)
                    out.append((b * a + 255 * (255 - a)) // 255)
        rgb = bytes(out)
    return width, height, rgb


def _paeth(left: int, up: int, up_left: int) -> int:
    estimate = left + up - up_left
    distances = (abs(estimate - left), abs(estimate - up), abs(estimate - up_left))
    return (left, up, up_left)[distances.index(min(distances))]


def write_rgb_png(path: Path, width: int, height: int, rgb: bytes) -> None:
    stride = width * 3

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(rgb[y * stride : (y + 1) * stride])
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def prepare(directory: Path) -> None:
    files = sorted(directory.glob("*.png"))
    if not files:
        raise SystemExit(f"no screenshots in {directory}")
    for path in files:
        prefix = path.name.split("-", 1)[0]
        expected = EXPECTED.get(prefix)
        if expected is None:
            raise SystemExit(f"{path.name} does not start with iphone-, iphone69-, or ipad-")
        width, height, rgb = read_png(path)
        if (width, height) != expected:
            raise SystemExit(f"{path.name} is {width}x{height}, expected {expected[0]}x{expected[1]}")
        write_rgb_png(path, width, height, rgb)
        print(f"{path.name} {width}x{height} rgb")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: prepare_screenshots.py DIRECTORY")
    prepare(Path(sys.argv[1]))
