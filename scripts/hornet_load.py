#!/usr/bin/env python3
"""Loads an ELF into HORNET through the UART bootloader (sw/bootloader) and starts it.

  hornet_load.py --port /dev/ttyUSB1 sw/examples/gpio/build/gpio_test.elf [--term]
  hornet_load.py --emit out.bin prog.elf      (the same byte stream, for the SoC testbench)

Press the reset button (CPU_RESET) when asked: the bootloader listens for one
second after reset. With --term the script stays connected and prints what
the program sends.
"""
import argparse
import struct
import sys
import time
import zlib
from elftools.elf.elffile import ELFFile

CHUNK = 1024


def segments(path):
    with open(path, "rb") as f:
        elf = ELFFile(f)
        entry = elf.header["e_entry"]
        segs = [(s["p_paddr"], s.data()) for s in elf.iter_segments()
                if s["p_type"] == "PT_LOAD" and s["p_filesz"] > 0]
    return entry, segs


def commands(entry, segs):
    for addr, data in segs:
        for off in range(0, len(data), CHUNK):
            block = data[off:off + CHUNK]
            yield (b"W" + struct.pack("<II", addr + off, len(block)) + block +
                   struct.pack("<I", zlib.crc32(block) & 0xffffffff)), addr + off
    yield b"G" + struct.pack("<I", entry), entry


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("elf")
    ap.add_argument("--port")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--emit", help="write the byte stream to a file instead of a serial port")
    ap.add_argument("--term", action="store_true", help="print the program's UART output afterwards")
    a = ap.parse_args()
    entry, segs = segments(a.elf)

    if a.emit:
        with open(a.emit, "wb") as f:
            f.write(b"HB")
            for cmd, _ in commands(entry, segs):
                f.write(cmd)
        return

    import serial
    with serial.Serial(a.port, a.baud, timeout=0.05) as ser:
        print("Press the reset button of the board ...")
        t0 = time.time()
        while True:
            ser.write(b"HB")
            if ser.read(1) == b"R":
                break
            if time.time() - t0 > 30:
                sys.exit("no answer from the bootloader")
        ser.timeout = 2
        total = sum(len(d) for _, d in segs)
        for cmd, addr in commands(entry, segs):
            ser.write(cmd)
            r = ser.read(1)
            if r != b"K":
                sys.exit("bootloader answered %r at 0x%08x" % (r, addr))
        print("loaded %d bytes, started at 0x%08x" % (total, entry))
        if a.term:
            ser.timeout = 0.1
            try:
                while True:
                    d = ser.read(256)
                    if d:
                        sys.stdout.write(d.decode(errors="replace"))
                        sys.stdout.flush()
            except KeyboardInterrupt:
                pass


if __name__ == "__main__":
    main()
