#!/usr/bin/env python3
"""Repack a `docker save` image tar into a form RouterOS containers can import.

Modern Docker (BuildKit / containerd image store) writes `docker save` archives
in OCI layout with **gzip-compressed** layer blobs. RouterOS 7's container import
reads `manifest.json` and the image config fine, but cannot read compressed layer
blobs, so import fails with:

    *** error getting layer file
    import error: failed to load next entry

This script reads the layer paths listed in `manifest.json` and rewrites any
gzip-compressed layer as a plain (uncompressed) tar, copying everything else
through unchanged. Already-uncompressed (legacy) archives pass through untouched.

Usage: pack-for-routeros.py <src.tar> <dst.tar>
"""
import gzip
import io
import json
import sys
import tarfile

GZIP_MAGIC = b"\x1f\x8b"


def main(src_path, dst_path):
    with tarfile.open(src_path, "r") as src:
        manifest = json.load(src.extractfile("manifest.json"))
        layer_paths = set()
        for entry in manifest:
            layer_paths.update(entry.get("Layers", []))

        decompressed = 0
        with tarfile.open(dst_path, "w") as out:
            for m in src.getmembers():
                if not m.isfile():
                    out.addfile(m)
                    continue
                data = src.extractfile(m).read()
                if m.name in layer_paths and data[:2] == GZIP_MAGIC:
                    data = gzip.decompress(data)
                    decompressed += 1
                ti = tarfile.TarInfo(m.name)
                ti.size = len(data)
                ti.mode = m.mode
                ti.mtime = m.mtime
                ti.type = m.type
                out.addfile(ti, io.BytesIO(data))

    print(f"Repacked {src_path} -> {dst_path} "
          f"({decompressed} layer(s) decompressed for RouterOS)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1], sys.argv[2])
