# HORNET verification image.
#
#   Verilator      5.046, built from source
#   RISC-V GCC     xPack riscv-none-elf-gcc 15.2.0-1 (multilibs rv32i, rv32im, rv32imf)
#   Spike          riscv-isa-sim, pinned commit (co-simulation reference)
#   TestFloat 3e   with SoftFloat 3e (FPU reference vectors)
#   OSS CAD Suite  Yosys, SymbiYosys, SMT solvers (riscv-formal); last in PATH
#   Python 3       packages in requirements.txt (also RISCV-DV pygen and Sphinx)
#   LaTeX          for the PDF manual (make docs)
#
# Vivado is not in the image; it runs on the host.
#
# Stages:
#   tools  compiles Verilator, Spike and TestFloat, unpacks GCC (build only)
#   ci     the simulation tools without formal and LaTeX (GitHub Actions:
#          docker build --target ci; simulation, tests, coverage, RISCV-DV)
#   dev    everything (the default: make docker-build, VS Code Dev Container)

FROM ubuntu:24.04 AS tools

ARG DEBIAN_FRONTEND=noninteractive
ARG JOBS=6
ARG VERILATOR_VERSION=5.046
ARG XPACK_GCC_VERSION=15.2.0-1
ARG SPIKE_COMMIT=fdc1ffa05152707a00ca22a9cf50c59a1b487875

RUN apt-get update && apt-get install -y --no-install-recommends \
        autoconf bison build-essential ca-certificates curl \
        device-tree-compiler flex git help2man libboost-regex-dev \
        libboost-system-dev libfl-dev libfl2 make perl python3 \
        xz-utils zlib1g zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/verilator/verilator/archive/refs/tags/v${VERILATOR_VERSION}.tar.gz \
        | tar -xz -C /tmp \
    && cd /tmp/verilator-${VERILATOR_VERSION} \
    && autoconf && ./configure --prefix=/opt/verilator \
    && make -j${JOBS} && make install \
    && rm -rf /tmp/verilator-${VERILATOR_VERSION}

# only the multilibs of the three HORNET configurations are kept (about 1 GB less)
RUN curl -fsSL https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v${XPACK_GCC_VERSION}/xpack-riscv-none-elf-gcc-${XPACK_GCC_VERSION}-linux-x64.tar.gz \
        | tar -xz -C /opt \
    && mv /opt/xpack-riscv-none-elf-gcc-${XPACK_GCC_VERSION} /opt/riscv \
    && for d in /opt/riscv/riscv-none-elf/lib/rv* /opt/riscv/lib/gcc/riscv-none-elf/*/rv*; do \
        case "${d##*/}" in rv32i|rv32im|rv32imf_zicsr) ;; *) rm -rf "$d" ;; esac; \
    done \
    && cd /opt/riscv/bin \
    && for t in riscv-none-elf-*; do ln -s "$t" "riscv32-unknown-elf-${t#riscv-none-elf-}"; done

# only the stripped executables: Spike is linked statically, lib/ and include/
# are for building extensions (about 1.7 GB less)
RUN git clone https://github.com/riscv-software-src/riscv-isa-sim.git /tmp/spike \
    && cd /tmp/spike && git checkout ${SPIKE_COMMIT} \
    && mkdir build && cd build && ../configure --prefix=/opt/spike \
    && make -j${JOBS} && make install \
    && rm -rf /tmp/spike /opt/spike/lib /opt/spike/include \
    && strip /opt/spike/bin/*

# testfloat's Makefile expects SoftFloat next to it
RUN git clone --depth 1 https://github.com/ucb-bar/berkeley-softfloat-3.git /tmp/tf/berkeley-softfloat-3 \
    && git clone --depth 1 https://github.com/ucb-bar/berkeley-testfloat-3.git /tmp/tf/berkeley-testfloat-3 \
    && make -C /tmp/tf/berkeley-softfloat-3/build/Linux-x86_64-GCC -j${JOBS} SPECIALIZE_TYPE=RISCV \
    && make -C /tmp/tf/berkeley-testfloat-3/build/Linux-x86_64-GCC -j${JOBS} SPECIALIZE_TYPE=RISCV \
    && install -D -m755 -t /opt/testfloat/bin \
        /tmp/tf/berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen \
        /tmp/tf/berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_ver \
    && rm -rf /tmp/tf


FROM ubuntu:24.04 AS ci

ARG DEBIAN_FRONTEND=noninteractive

# Verilator compiles its models with g++ and zlib (FST traces); Spike calls dtc
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates device-tree-compiler git make perl \
        python3 python3-venv zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=tools /opt/verilator /opt/verilator
COPY --from=tools /opt/riscv /opt/riscv
COPY --from=tools /opt/spike /opt/spike
COPY --from=tools /opt/testfloat /opt/testfloat

COPY requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# RISCV-DV pygen (Python instruction generator)
COPY requirements-dv.txt /tmp/
RUN /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements-dv.txt \
    && rm /tmp/requirements-dv.txt

ENV PATH=/opt/venv/bin:/opt/riscv/bin:/opt/verilator/bin:/opt/spike/bin:/opt/testfloat/bin:${PATH} \
    HORNET_CONTAINER=1

WORKDIR /work
CMD ["bash"]


FROM ci AS dev

ARG DEBIAN_FRONTEND=noninteractive
ARG OSS_CAD_SUITE_DATE=2026-09-20

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_DATE}/oss-cad-suite-linux-x64-$(echo ${OSS_CAD_SUITE_DATE} | tr -d -).tgz \
        | tar -xz -C /opt

# the documentation tools
COPY requirements-docs.txt /tmp/
RUN /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements-docs.txt \
    && rm /tmp/requirements-docs.txt

RUN apt-get update && apt-get install -y --no-install-recommends \
        latexmk texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended \
        tex-gyre fonts-freefont-otf texlive-xetex \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=${PATH}:/opt/oss-cad-suite/bin
