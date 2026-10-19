#!/usr/bin/env python3
"""Draws Alim's launcher icon: an emerald tile, a gold ring, a crescent and a
sparkle. Pure stdlib — zlib and struct write the PNG, the shapes are rasterised
with a 3x supersample so the edges come out smooth."""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

BG_TOP = (10, 56, 42)
BG_BOTTOM = (14, 82, 62)
GOLD = (201, 162, 39)
SS = 3


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def rounded_rect_inside(x, y, n, radius):
    cx = min(max(x, radius), n - radius)
    cy = min(max(y, radius), n - radius)
    dx = x - cx
    dy = y - cy
    return dx * dx + dy * dy <= radius * radius


def crescent(x, y, n):
    ox, oy, orr = 0.48 * n, 0.50 * n, 0.300 * n
    ix, iy, irr = 0.575 * n, 0.435 * n, 0.260 * n
    d_out = (x - ox) ** 2 + (y - oy) ** 2
    d_in = (x - ix) ** 2 + (y - iy) ** 2
    return d_out <= orr * orr and d_in >= irr * irr


def sparkle(x, y, n):
    import math

    cx, cy = 0.665 * n, 0.335 * n
    r_out, r_in = 0.085 * n, 0.030 * n
    dx, dy = x - cx, y - cy
    dist = math.hypot(dx, dy)
    if dist > r_out:
        return False
    ang = math.atan2(dy, dx)
    # A four-pointed star: r(θ) dips to r_in on the diagonals.
    k = abs(math.cos(2 * ang))
    limit = r_in + (r_out - r_in) * (k ** 1.6)
    return dist <= limit


def render(n):
    big = n * SS
    rows = []
    for py in range(big):
        y = py + 0.5
        row = bytearray()
        for px in range(big):
            x = px + 0.5
            if not rounded_rect_inside(x, y, big, 0.225 * big):
                row += b"\x00\x00\x00\x00"
                continue
            t = y / big
            r, g, b = lerp(BG_TOP, BG_BOTTOM, t)
            # gold ring
            dcen = ((x - big / 2) ** 2 + (y - big / 2) ** 2) ** 0.5
            if abs(dcen - 0.462 * big) <= 0.011 * big:
                r, g, b = GOLD
            elif sparkle(x, y, big):
                r, g, b = GOLD
            elif crescent(x, y, big):
                r, g, b = GOLD
            row += bytes((r, g, b, 255))
        rows.append(row)

    out = bytearray()
    for oy in range(n):
        row = bytearray(b"\x00")
        for ox in range(n):
            rr = gg = bb = aa = 0
            for sy in range(SS):
                src = rows[oy * SS + sy]
                for sx in range(SS):
                    i = (ox * SS + sx) * 4
                    rr += src[i]
                    gg += src[i + 1]
                    bb += src[i + 2]
                    aa += src[i + 3]
            k = SS * SS
            row += bytes((rr // k, gg // k, bb // k, aa // k))
        out += row
    return bytes(out)


def write_png(path, width, height, pixels):
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    body = zlib.compress(pixels, 9)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", header))
        fh.write(chunk(b"IDAT", body))
        fh.write(chunk(b"IEND", b""))


def main():
    for folder, size in SIZES.items():
        target_dir = os.path.join(RES, folder)
        os.makedirs(target_dir, exist_ok=True)
        pixels = render(size)
        write_png(os.path.join(target_dir, "ic_launcher.png"), size, size, pixels)
        print(f"{folder}: {size}x{size}")


if __name__ == "__main__":
    main()
