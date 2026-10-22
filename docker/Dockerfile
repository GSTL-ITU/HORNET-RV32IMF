# HORNET verification image.
#
#   Verilator      5.046, built from source
#   RISC-V GCC     xPack riscv-none-elf-gcc 15.2.0-1 (rv32imf multilib)
#   Spike          riscv-isa-sim, pinned commit (co-simulation reference)
#   TestFloat 3e   with SoftFloat 3e (FPU reference vectors)
#   OSS CAD Suite  Yosys, SymbiYosys, SMT solvers (riscv-formal); last in PATH
#   Python 3       packages in requirements.txt
#
# Vivado is not in the image; it runs on the host.

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG JOBS=6
ARG VERILATOR_VERSION=5.046
ARG XPACK_GCC_VERSION=15.2.0-1
ARG SPIKE_COMMIT=fdc1ffa05152707a00ca22a9cf50c59a1b487875
ARG OSS_CAD_SUITE_DATE=2026-09-20

RUN apt-get update && apt-get install -y --no-install-recommends \
        autoconf bison build-essential ca-certificates curl \
        device-tree-compiler flex git help2man libboost-regex-dev \
        libboost-system-dev libfl-dev libfl2 make perl python3 python3-pip \
        python3-venv unzip xz-utils zlib1g zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/verilator/verilator/archive/refs/tags/v${VERILATOR_VERSION}.tar.gz \
        | tar -xz -C /tmp \
    && cd /tmp/verilator-${VERILATOR_VERSION} \
    && autoconf && ./configure --prefix=/opt/verilator \
    && make -j${JOBS} && make install \
    && rm -rf /tmp/verilator-${VERILATOR_VERSION}

RUN curl -fsSL https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v${XPACK_GCC_VERSION}/xpack-riscv-none-elf-gcc-${XPACK_GCC_VERSION}-linux-x64.tar.gz \
        | tar -xz -C /opt \
    && mv /opt/xpack-riscv-none-elf-gcc-${XPACK_GCC_VERSION} /opt/riscv \
    && cd /opt/riscv/bin \
    && for t in riscv-none-elf-*; do ln -s "$t" "riscv32-unknown-elf-${t#riscv-none-elf-}"; done

RUN git clone https://github.com/riscv-software-src/riscv-isa-sim.git /tmp/spike \
    && cd /tmp/spike && git checkout ${SPIKE_COMMIT} \
    && mkdir build && cd build && ../configure --prefix=/opt/spike \
    && make -j${JOBS} && make install \
    && rm -rf /tmp/spike

# testfloat's Makefile expects SoftFloat next to it
RUN git clone --depth 1 https://github.com/ucb-bar/berkeley-softfloat-3.git /tmp/tf/berkeley-softfloat-3 \
    && git clone --depth 1 https://github.com/ucb-bar/berkeley-testfloat-3.git /tmp/tf/berkeley-testfloat-3 \
    && make -C /tmp/tf/berkeley-softfloat-3/build/Linux-x86_64-GCC -j${JOBS} SPECIALIZE_TYPE=RISCV \
    && make -C /tmp/tf/berkeley-testfloat-3/build/Linux-x86_64-GCC -j${JOBS} SPECIALIZE_TYPE=RISCV \
    && install -D -m755 -t /opt/testfloat/bin \
        /tmp/tf/berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen \
        /tmp/tf/berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_ver \
    && rm -rf /tmp/tf

RUN curl -fsSL https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_DATE}/oss-cad-suite-linux-x64-$(echo ${OSS_CAD_SUITE_DATE} | tr -d -).tgz \
        | tar -xz -C /opt

COPY requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

ENV PATH=/opt/venv/bin:/opt/riscv/bin:/opt/verilator/bin:/opt/spike/bin:/opt/testfloat/bin:${PATH}:/opt/oss-cad-suite/bin \
    HORNET_CONTAINER=1

WORKDIR /work
CMD ["bash"]
