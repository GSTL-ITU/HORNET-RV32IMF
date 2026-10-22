#!/usr/bin/env python3
"""Print signals of a VCD file once per rising clock edge (values before the edge).

  vcdcat.py wave.vcd clk sig1 sig2 ... [--from N] [--count N]

Signal names are matched as suffixes of the full hierarchical name.
"""
import argparse


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vcd")
    ap.add_argument("clock")
    ap.add_argument("signals", nargs="+")
    ap.add_argument("--from", dest="start", type=int, default=0)
    ap.add_argument("--count", type=int, default=40)
    a = ap.parse_args()

    ids, names, scope = {}, {}, []
    with open(a.vcd) as f:
        for line in f:
            t = line.split()
            if not t:
                continue
            if t[0] == "$scope":
                scope.append(t[2])
            elif t[0] == "$upscope":
                scope.pop()
            elif t[0] == "$var":
                names.setdefault(t[3], ".".join(scope + [t[4]]))
            elif t[0] == "$enddefinitions":
                break

        def find(s):
            for code, n in names.items():
                if n == s or n.endswith("." + s):
                    return code
            raise SystemExit("no signal " + s)

        clk = find(a.clock)
        want = [find(s) for s in a.signals]
        val = {}
        cycle = 0
        print("cycle " + " ".join(a.signals))
        for line in f:
            line = line.strip()
            if not line or line[0] == "#":
                continue
            if line[0] in "bB":
                v, code = line[1:].split()
            else:
                v, code = line[0], line[1:]
            if code == clk and v == "1":
                if a.start <= cycle < a.start + a.count:
                    print("%5d " % cycle + " ".join(
                        ("%x" % int(val.get(w, "0"), 2)) if set(val.get(w, "0")) <= {"0", "1"} else val.get(w, "x")
                        for w in want))
                cycle += 1
                if cycle >= a.start + a.count:
                    break
            val[code] = v


if __name__ == "__main__":
    main()
