#!/usr/bin/env python3
"""Coverage reports from Verilator coverage data:

  coverage_report.py <coverage.dat> <summary.txt> <coverage.info>

summary.txt counts the line, branch and toggle points of every RTL file.
coverage.info is the lcov file for Codecov: per source line the line count
(DA) and its branch points (BRDA); toggles are not in it.

A point is covered when any instance of its module hit it (a module
instantiated twice, or simulated in two testbenches, is counted once), so
the numbers are code coverage of the source, not of every instance. Toggle
points are single bits, each 0->1 and 1->0. Verilator's own lcov export
(--write-info) is not used: it reports the instances of a line as its
branches and keeps one toggle count per line.
"""
import re
import sys
from collections import defaultdict

TYPES = ("line", "branch", "toggle")


def read(path):
    """{(file, line, column, type, comment): count} summed over all instances."""
    points = defaultdict(int)
    with open(path, encoding="utf-8", errors="replace") as f:
        for text in f:
            m = re.match(r"C '(.*)' (\d+)$", text.rstrip("\n"))
            if not m:
                continue
            fields = dict(kv.split("\x02", 1) for kv in m.group(1).split("\x01") if "\x02" in kv)
            key = (fields.get("f"), int(fields.get("l", 0)), int(fields.get("n", 0)), fields.get("t"), fields.get("o"))
            points[key] += int(m.group(2))
    return points


def pct(hit, total):
    return "%5.1f%% %6d/%-6d" % (100.0 * hit / total, hit, total) if total else "%-20s" % "     -"


def summary(points, path):
    count = defaultdict(lambda: [0, 0])  # (file, type) -> [hit, total]
    for (f, _, _, t, _), n in points.items():
        for k in ((f, t), ("total", t)):
            count[k][1] += 1
            count[k][0] += n > 0
    files = sorted({f for f, _ in count if f != "total"})
    lines = ["%-28s %-20s %-20s %-20s" % ("file", *TYPES)]
    for f in files + ["total"]:
        lines.append("%-28s %s" % (f, " ".join(pct(*count[(f, t)]) for t in TYPES)))
    with open(path, "w") as out:
        out.write("\n".join(lines) + "\n")
    return lines


def lcov(points, path):
    da = defaultdict(lambda: defaultdict(int))     # file -> line -> count
    brda = defaultdict(lambda: defaultdict(list))  # file -> line -> [count of each branch point]
    for (f, l, n, t, o), c in sorted(points.items()):
        if t in ("line", "branch"):
            da[f][l] = max(da[f][l], c)
        if t == "branch":
            brda[f][l].append(c)
    with open(path, "w") as out:
        out.write("TN:hornet\n")
        for f in sorted(da):
            out.write("SF:%s\n" % f)
            for l in sorted(da[f]):
                for i, c in enumerate(brda[f][l]):
                    out.write("BRDA:%d,0,%d,%d\n" % (l, i, c))
                out.write("DA:%d,%d\n" % (l, da[f][l]))
            br = [c for l in brda[f] for c in brda[f][l]]
            out.write("BRF:%d\nBRH:%d\n" % (len(br), sum(c > 0 for c in br)))
            out.write("LF:%d\nLH:%d\n" % (len(da[f]), sum(c > 0 for c in da[f].values())))
            out.write("end_of_record\n")


def main():
    points = read(sys.argv[1])
    lines = summary(points, sys.argv[2])
    lcov(points, sys.argv[3])
    print("\n".join([lines[0], lines[-1]]))


if __name__ == "__main__":
    main()
