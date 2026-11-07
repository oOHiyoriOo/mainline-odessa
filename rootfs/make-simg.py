#!/usr/bin/env python3
"""Convert a raw ext4 image to an Android sparse image (sparse v1).

Usage: make-simg.py <raw.img> <out.simg> [block-size]
Chunk types raw (0xCAC1), fill (0xCAC2) and skip (0xCAC3) are sufficient for
fastboot and simg2img.
"""
import os
import struct
import sys

BLK = int(sys.argv[3]) if len(sys.argv) > 3 else 4096
src, dst = sys.argv[1], sys.argv[2]
total = os.path.getsize(src) // BLK
chunks = []
with open(src, "rb") as f:
    i = 0
    while i < total:
        f.seek(i * BLK)
        d = f.read(BLK)
        zero = d.count(0) == len(d)
        j = i
        while j < total:
            f.seek(j * BLK)
            e = f.read(BLK)
            if (e.count(0) == len(e)) != zero:
                break
            j += 1
        if zero:
            chunks.append((0xCAC3, j - i, b""))
        else:
            f.seek(i * BLK)
            chunks.append((0xCAC1, j - i, f.read((j - i) * BLK)))
        i = j
with open(dst, "wb") as f:
    f.write(struct.pack("<IHHHHIIII", 0xED26FF3A, 1, 0, 28, 12, BLK,
                        total, len(chunks), 0))
    for t, n, p in chunks:
        f.write(struct.pack("<HHII", t, 0, n, 12 + len(p)))
        f.write(p)
print(f"{dst}: {os.path.getsize(dst)} bytes, {len(chunks)} chunks, "
      f"{total} blocks")
