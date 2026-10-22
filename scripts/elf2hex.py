#!/usr/bin/env python3
"""Write $readmemh images (32-bit words) from an ELF file.

  elf2hex.py prog.elf out.hex --base 0x80000000 --size 0x400000
  elf2hex.py prog.elf imem.hex --base 0x00000000 --size 0x10000 --pad

Only loadable bytes inside [base, base + size) are written. Addresses in the
image are word indices relative to base. --pad writes every word of the region
(Vivado needs a full image for BRAM initialisation).
"""
import argparse
import sys
from elftools.elf.elffile import ELFFile


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("elf")
    ap.add_argument("out")
    ap.add_argument("--base", type=lambda x: int(x, 0), required=True)
    ap.add_argument("--size", type=lambda x: int(x, 0), required=True)
    ap.add_argument("--pad", action="store_true")
    a = ap.parse_args()

    image = {}
    with open(a.elf, "rb") as f:
        elf = ELFFile(f)
        for seg in elf.iter_segments():
            if seg["p_type"] != "PT_LOAD" or seg["p_filesz"] == 0:
                continue
            data = seg.data()
            addr = seg["p_paddr"]
            for i, b in enumerate(data):
                image[addr + i] = b

    used = [x for x in image if a.base <= x < a.base + a.size]
    outside = [x for x in image if not a.base <= x < a.base + a.size]
    words = {}
    for x in used:
        w = (x - a.base) >> 2
        words[w] = words.get(w, 0) | (image[x] << (8 * (x & 3)))

    with open(a.out, "w") as f:
        if a.pad:
            for w in range(a.size // 4):
                f.write("%08x\n" % words.get(w, 0))
        else:
            last = None
            for w in sorted(words):
                if last is None or w != last + 1:
                    f.write("@%x\n" % w)
                f.write("%08x\n" % words[w])
                last = w
    if used and max(used) - a.base >= a.size:
        sys.exit("image does not fit")
    return len(outside)


if __name__ == "__main__":
    main()
