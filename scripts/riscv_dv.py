#!/usr/bin/env python3
"""RISCV-DV flow for HORNET: pygen, GCC, Spike, Verilator, trace CSVs, comparison.

  riscv_dv.py --sim build/sim/core-rv32imf/Vhornet_tb --isa rv32imf [-j 8]
              [--tests riscv_rand_instr_test,...] [--iterations N] [--seed S]
              [--directed verif/dv/directed] [--no-random] [--loop [--max-runs N]]
              [--mem-stall 30] [--out build/rv32imf/riscv-dv] [--from-run <earlier out dir>]

This is the flow of "Creating Verification Environment Using RISCV-DV With
Open and Closed Source Tools" (ISMSIT 2025, Fig. 1) with open-source tools
only: RISCV-DV's Python generator (pygen) instead of the SystemVerilog
generator, Verilator instead of Xcelium. For every test iteration:

  1. pygen writes a random assembly program (verif/dv/testlist.yaml, core
     setting verif/dv/riscv_core_setting.py for --isa)
  2. GCC builds it with RISCV-DV's linker script (0x8000_0000, the memory of
     tb/hornet_tb.sv)
  3. Spike runs it (-l --log-commits, the same 4 MB of memory as the testbench)
  4. the core testbench runs it and writes the tracer log (RVFI)
  5. both logs become CSV files (scripts/dv/trace_csv.py) that are compared
     row by row: PC, instruction, x/f register write, fflags, memory address
     and store data -> PASS, PASS with warnings or FAIL
  6. the same logs also go through RISCV-DV's own converter and comparator
     (spike_log_to_trace_csv.py, instr_trace_compare.py: integer and float
     register writes)

Custom tests (--directed, default verif/dv/directed/*.S) skip step 1: the
paper notes that the Python flow cannot run hand-written tests, this one can.
--from-run runs the programs of an earlier run again (another core build,
other wait states) without generating them.
--loop keeps generating new programs (new seeds) until one fails, as the
paper's main script did to find rare bugs.

Every iteration gets <out>/<test>_<n>/ with the program, logs and CSVs; the
summary goes to <out>/summary.txt and <out>/results.csv.
"""
import argparse
import csv
import os
import re
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
DV = os.path.join(ROOT, "verif", "riscv-dv")
TARGET = os.path.join(ROOT, "verif", "dv")
sys.path.insert(0, os.path.join(DV, "scripts"))

from run_tests import SPIKE_ARGS, BASE, MEM_SIZE, march, prepare, spike_isa, ISAS  # noqa: E402

CC = "riscv32-unknown-elf-gcc"
GEN_RETRIES = 5


def run(cmd, timeout=None, **kw):
    t0 = time.time()
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout, **kw)
        return r.returncode, r.stdout, time.time() - t0
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        return -1, out + "\nTIMEOUT after %d s" % timeout, time.time() - t0


def gen_opts(text):
    """riscv-dv "+name=value" options to pygen's "--name=value"."""
    return ["--" + o[1:] for o in (text or "").split() if o.startswith("+")]


def load_tests(path, isa, only):
    with open(path) as f:
        tests = yaml.safe_load(f)
    ext = isa[len("rv32i"):]
    out = []
    for t in tests:
        if only and t["test"] not in only:
            continue
        need = [e for e in str(t.get("requires", "")).split(",") if e.strip()]
        if any(e.strip() not in ext for e in need):
            continue
        out.append(t)
    return out


def requires_of(src):
    with open(src) as f:
        m = re.search(r"^#\s*requires:\s*(.*)$", f.read(), re.M)
    return [e.strip() for e in m.group(1).split(",")] if m else []


class Job:
    def __init__(self, name, test, idx, seed, src=None):
        self.name, self.test, self.idx, self.seed, self.src = name, test, idx, seed, src


def run_job(a, job):
    d = os.path.join(a.out, job.name)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    res = {"test": job.test["test"] if job.test else job.name.rsplit("_", 1)[0], "name": job.name, "seed": job.seed,
           "gen_seed": job.seed, "gen_retries": 0,
           "status": "", "instr": 0, "gen_s": 0.0, "spike_s": 0.0, "rtl_s": 0.0, "detail": ""}
    env = dict(os.environ, HORNET_ISA=a.isa)

    # 1. generation
    if job.src is None:
        asm = os.path.join(d, "test")
        cmd = [sys.executable, os.path.join(ROOT, "scripts", "dv", "pygen_run.py"), DV, TARGET,
               "riscv_instr_base_test", "--num_of_tests=1", "--start_idx=0", "--asm_file_name=" + asm,
               "--log_file_name=" + os.path.join(d, "gen.log"), "--gen_test=riscv_instr_base_test",
               "--seed=%d" % job.seed, "--disable_compressed_instr=1", "--boot_mode=m"] + gen_opts(job.test.get("gen_opts"))
        # pygen sometimes cannot solve a constraint (riscv_loop_instr picks an
        # instruction without an immediate for the loop counter init and exits):
        # retry with derived seeds, the seed that was used is recorded
        src = asm + "_0.S"
        for attempt in range(GEN_RETRIES):
            seed = job.seed + attempt * 1000003
            cmd[cmd.index([c for c in cmd if c.startswith("--seed=")][0])] = "--seed=%d" % seed
            rc, out, t = run(cmd, timeout=a.gen_timeout, env=env)
            res["gen_s"] += t
            with open(os.path.join(d, "gen.out"), "a") as f:
                f.write(" ".join(cmd) + "\n" + out + "\n")
            if rc == 0 and os.path.exists(src):
                break
        res["gen_seed"] = seed
        res["gen_retries"] = attempt
        if rc or not os.path.exists(src):
            crit = [l for l in out.splitlines() if "CRITICAL" in l or "Error" in l]
            res.update(status="GEN", detail=(crit or out.strip().splitlines()[-1:] or ["pygen failed"])[-1])
            return res
        inc = ["-I" + os.path.join(DV, "user_extension")]
    else:
        src = os.path.join(d, os.path.basename(job.src))
        shutil.copy(job.src, src)
        inc = ["-I" + os.path.dirname(os.path.abspath(job.src)), "-I" + os.path.join(DV, "user_extension"),
               "-I" + os.path.join(TARGET, "directed")]

    # 2. GCC
    elf = os.path.join(d, "test.elf")
    rc, out, _ = run([CC, "-march=" + march(a.isa), "-mabi=ilp32", "-static", "-mcmodel=medany",
                      "-fvisibility=hidden", "-nostdlib", "-nostartfiles"] + inc +
                     ["-T", os.path.join(DV, "scripts", "link.ld"), src, "-o", elf])
    if rc:
        res.update(status="GCC", detail=out.strip()[-300:])
        return res
    try:
        tohost = prepare(elf)
    except Exception as e:  # image larger than the testbench memory, ...
        res.update(status="ERROR", detail=str(e))
        return res
    base = elf[:-4]

    # 3. Spike, with the testbench's memory
    spike_log = os.path.join(d, "spike.log")
    with open(spike_log, "w") as f:
        t0 = time.time()
        try:
            subprocess.run(["spike", "--isa=" + spike_isa(a.isa)] + SPIKE_ARGS +
                           ["-m0x%x:0x%x" % (BASE, MEM_SIZE), "-l", "--log-commits", elf],
                           stdout=subprocess.DEVNULL, stderr=f, timeout=a.timeout_s)
        except subprocess.TimeoutExpired:
            res.update(status="SPIKE", detail="Spike timeout")
            return res
        res["spike_s"] = time.time() - t0

    # 4. RTL
    rtl_log = os.path.join(d, "hornet.log")
    cmd = [a.sim, "+hex=" + base + ".hex", "+trace=" + rtl_log, "+tohost=%x" % tohost,
           "+mem_stall=%d" % a.mem_stall, "+seed=%d" % job.seed, "+timeout=%d" % a.timeout]
    rc, out, t = run(cmd, timeout=a.timeout_s)
    res["rtl_s"] = t
    with open(os.path.join(d, "sim.log"), "w") as f:
        f.write(" ".join(cmd) + "\n" + out)
    end = [l for l in out.splitlines() if re.match(r"(PASS|FAIL|TIMEOUT|HANG)", l)]
    rvfi = [l for l in out.splitlines() if "RVFI ERROR" in l]
    if not end or not end[0].startswith("PASS") or rvfi:
        res.update(status="RTL", detail=(rvfi or end or [out.strip()[-200:]])[0])
        return res

    # 5. CSVs and the comparison
    tc = os.path.join(ROOT, "scripts", "dv", "trace_csv.py")
    dump = base + ".dump"
    h_csv, s_csv = os.path.join(d, "hornet.csv"), os.path.join(d, "spike.csv")
    th = "0x%x" % tohost
    run([sys.executable, tc, "convert", "--format", "hornet", "--log", rtl_log, "--csv", h_csv, "--dump", dump,
         "--riscv-dv", os.path.join(d, "hornet.riscv-dv.csv"), "--tohost", th])
    run([sys.executable, tc, "convert", "--format", "spike", "--log", spike_log, "--csv", s_csv, "--dump", dump,
         "--tohost", th])
    rc, out, _ = run([sys.executable, tc, "compare", h_csv, s_csv, "--log", os.path.join(d, "compare.log")])
    result = out.strip().splitlines()[-1].replace("RESULT: ", "") if out.strip() else "FAIL"
    with open(h_csv) as f:
        res["instr"] = max(0, sum(1 for _ in f) - 1)

    # 6. RISCV-DV's own converter and comparator
    reg_first = os.path.join(d, "spike.reg-first.log")
    run([sys.executable, tc, "spike-reg-first", spike_log, reg_first])
    run([sys.executable, os.path.join(DV, "scripts", "spike_log_to_trace_csv.py"), "--log", reg_first,
         "--csv", os.path.join(d, "spike.riscv-dv.csv")])
    dv_log = os.path.join(d, "compare.riscv-dv.log")
    if os.path.exists(dv_log):
        os.remove(dv_log)
    run([sys.executable, os.path.join(DV, "scripts", "instr_trace_compare.py"),
         "--csv_file_1", os.path.join(d, "hornet.riscv-dv.csv"), "--csv_file_2", os.path.join(d, "spike.riscv-dv.csv"),
         "--csv_name_1", "hornet", "--csv_name_2", "spike", "--log", dv_log])
    with open(dv_log) as f:
        dv_text = f.read()
    dv_ok = "[PASSED]" in dv_text

    if result == "FAIL":
        bad = [l for l in out.splitlines() if l.startswith("ERROR")]
        res.update(status="FAIL", detail=bad[0] if bad else "compare failed")
    elif not dv_ok:
        res.update(status="FAIL", detail="riscv-dv compare: " + (dv_text.strip().splitlines() or ["?"])[-1])
    else:
        res.update(status="PASS" if result == "PASS" else "PASS*", detail=result)
    if res["status"].startswith("PASS") and not a.keep:
        for f in os.listdir(d):  # keep the program, the CSVs and the results
            if f.endswith((".hex", ".log")) and not f.startswith("compare"):
                os.remove(os.path.join(d, f))
    return res


def make_jobs(a, tests, directed, first_seed):
    jobs = []
    seed = first_seed
    if a.from_run:
        # the programs of an earlier run (generated test_0.S or a custom test's copy)
        for name in sorted(os.listdir(a.from_run)):
            d = os.path.join(a.from_run, name)
            srcs = [f for f in os.listdir(d) if f.endswith(".S")] if os.path.isdir(d) else []
            if srcs:
                jobs.append(Job(name, None, 0, first_seed, os.path.join(d, srcs[0])))
        return jobs, seed
    if not a.no_random:
        for t in tests:
            for i in range(a.iterations if a.iterations else t.get("iterations", 1)):
                jobs.append(Job("%s_%d" % (t["test"], seed), t, i, seed))
                seed += 1
    for src in directed:
        jobs.append(Job("directed_" + os.path.basename(src)[:-2], None, 0, first_seed, src))
    return jobs, seed


def summarize(a, results, elapsed):
    lines = []
    for r in results:
        lines.append("%-48s %-6s %6d instr  gen %6.1f s  spike %5.1f s  rtl %5.1f s  %s" % (
            r["name"], r["status"], r["instr"], r["gen_s"], r["spike_s"], r["rtl_s"],
            r["detail"] if not r["status"].startswith("PASS") or r["status"] == "PASS*" else ""))
    passed = sum(1 for r in results if r["status"].startswith("PASS"))
    gen = [r for r in results if r["gen_s"] > 0 and r["instr"] > 0]
    lines.append("%d/%d passed (isa=%s, mem_stall=%d%%, %.0f s)" % (passed, len(results), a.isa, a.mem_stall, elapsed))
    if gen:
        t = sum(r["gen_s"] for r in gen) / len(gen)
        n = sum(r["instr"] for r in gen) / len(gen)
        lines.append("pygen: %.2f s per program, %.0f retired instructions per program, %.1f instructions/s" % (
            t, n, n / t if t else 0))
    with open(os.path.join(a.out, "summary.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    with open(os.path.join(a.out, "results.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(results[0].keys()) if results else ["name"])
        w.writeheader()
        for r in results:
            w.writerow(r)
    return lines, passed == len(results)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sim", required=True)
    ap.add_argument("--isa", default="rv32imf", choices=ISAS)
    ap.add_argument("--testlist", default=os.path.join(TARGET, "testlist.yaml"))
    ap.add_argument("--tests", default="", help="comma-separated test names (default: all of the ISA)")
    ap.add_argument("--iterations", type=int, default=0, help="per test (default: the testlist's)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--directed", default=os.path.join(TARGET, "directed"), help="directory of custom tests (*.S)")
    ap.add_argument("--no-directed", action="store_true")
    ap.add_argument("--no-random", action="store_true", help="only the custom tests")
    ap.add_argument("--loop", action="store_true", help="new seeds until a test fails")
    ap.add_argument("--max-runs", type=int, default=0, help="--loop: stop after this many programs")
    ap.add_argument("--mem-stall", type=int, default=0)
    ap.add_argument("--timeout", type=int, default=5000000, help="RTL cycles")
    ap.add_argument("--timeout-s", type=int, default=900)
    ap.add_argument("--gen-timeout", type=int, default=1800)
    ap.add_argument("--keep", action="store_true", help="keep the logs of passing tests")
    ap.add_argument("--from-run", default="", help="run the programs of an earlier run's directory again")
    ap.add_argument("--out", default="")
    ap.add_argument("-j", "--jobs", type=int, default=4)
    a = ap.parse_args()
    a.out = a.out or os.path.join(ROOT, "build", a.isa, "riscv-dv")
    os.makedirs(a.out, exist_ok=True)

    tests = load_tests(a.testlist, a.isa, set(filter(None, a.tests.split(","))))
    directed = []
    if not a.no_directed and os.path.isdir(a.directed):
        for f in sorted(os.listdir(a.directed)):
            src = os.path.join(a.directed, f)
            if f.endswith(".S") and all(e in a.isa[len("rv32i"):] for e in requires_of(src)):
                directed.append(src)

    t0 = time.time()
    results = []
    seed = a.seed
    while True:
        jobs, seed = make_jobs(a, tests, directed, seed)
        if not jobs:
            sys.exit("no tests for %s" % a.isa)
        with ThreadPoolExecutor(max_workers=a.jobs) as pool:
            for r in pool.map(lambda j: run_job(a, j), jobs):
                results.append(r)
                print("%-48s %-6s %6d instr  %s" % (r["name"], r["status"], r["instr"],
                                                   "" if r["status"] == "PASS" else r["detail"]), flush=True)
        failed = [r for r in results if not r["status"].startswith("PASS")]
        if not a.loop or failed or (a.max_runs and len(results) >= a.max_runs):
            break
        directed = []  # once per --loop session
    lines, ok = summarize(a, results, time.time() - t0)
    print("\n".join(lines[-3:]))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
