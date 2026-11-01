# References

The specifications HORNET implements, the tools and test suites it is
verified with, the vendor documents of the FPGA flow, and books that explain
the background. The chapters cite them by the label in brackets.

## RISC-V specifications

- **[RV-UNPRIV]** RISC-V International, *The RISC-V Instruction Set Manual,
  Volume I: Unprivileged ISA*, document version 20191213. RV32I, M, F, Zicsr,
  Zifencei. <https://github.com/riscv/riscv-isa-manual/releases>
- **[RV-PRIV]** RISC-V International, *The RISC-V Instruction Set Manual,
  Volume II: Privileged Architecture*, document version 20211203 (machine
  ISA version 1.12). Machine mode, CSRs, traps, interrupts.
  <https://github.com/riscv/riscv-isa-manual/releases>
- **[RV-ABI]** RISC-V International, *RISC-V ELF psABI Specification*. The
  `ilp32` and `ilp32f` calling conventions.
  <https://github.com/riscv-non-isa/riscv-elf-psabi-doc>
- **[ACLINT]** RISC-V International, *RISC-V Advanced Core Local
  Interruptor Specification*. The machine timer and software interrupt
  devices, compatible with the SiFive CLINT layout that HORNET's timer uses.
  <https://github.com/riscv/riscv-aclint>
- **[CLINT]** SiFive, *SiFive FU540-C000 Manual*, chapter *Core-Local
  Interruptor (CLINT)*. The register offsets of `msip`, `mtimecmp` and
  `mtime`. <https://www.sifive.com/documentation>
- **[RVFI]** YosysHQ, *RISC-V Formal Interface (RVFI)*, in riscv-formal,
  `docs/rvfi.md`. <https://github.com/YosysHQ/riscv-formal>

## Bus and peripheral standards

- **[OBI]** OpenHW Group, *OBI (Open Bus Interface) Specification*. The
  request/grant/response-valid handshake of HORNET's instruction and data
  ports follows OBI's address and response phases (without its optional
  signals). <https://github.com/openhwgroup/obi>
- **[AXI]** Arm, *AMBA AXI Protocol Specification*, ARM IHI 0022. The
  AXI4-Lite interface of the peripherals, the bridge, the interconnect and the
  external `m_axi` port. <https://developer.arm.com/documentation/ihi0022/latest>
- **[UART]** Texas Instruments, *PC16550D Universal Asynchronous
  Receiver/Transmitter with FIFOs*, datasheet SNLS378. A widely used
  description of asynchronous serial framing (start bit, data bits LSB
  first, stop bit) and receiver sampling; HORNET's register map is its own,
  not 16550-compatible. <https://www.ti.com/product/PC16550D>

## Arithmetic

- **[IEEE754]** IEEE, *IEEE Standard for Floating-Point Arithmetic*,
  IEEE Std 754-2008 (revised as IEEE Std 754-2019). The binary32 format,
  rounding, exceptions and fused multiply-add that the F extension refers to.
- **[TESTFLOAT]** J. R. Hauser, *Berkeley TestFloat* (release 3e) and
  *Berkeley SoftFloat* (release 3e). The reference results for the FPU
  vectors. <http://www.jhauser.us/arithmetic/TestFloat.html>
- **[MULLER]** J.-M. Muller et al., *Handbook of Floating-Point Arithmetic*,
  2nd edition, Birkhäuser, 2018. Rounding, fused multiply-add, division and
  square root in hardware.
- **[GOLDBERG]** D. Goldberg, "What Every Computer Scientist Should Know
  About Floating-Point Arithmetic", *ACM Computing Surveys* 23(1), 1991.
- **[PARHAMI]** B. Parhami, *Computer Arithmetic: Algorithms and Hardware
  Designs*, 2nd edition, Oxford University Press, 2010. Restoring division
  and digit-recurrence square root.

## Hardware description languages

- **[VERILOG]** IEEE, *IEEE Standard for Verilog Hardware Description
  Language*, IEEE Std 1364-2005. The language of the RTL.
- **[SV]** IEEE, *IEEE Standard for SystemVerilog*, IEEE Std 1800-2017.
  The language of the testbenches.

## Verification tools and suites

- **[SPIKE]** RISC-V International, *Spike, the RISC-V ISA Simulator*.
  <https://github.com/riscv-software-src/riscv-isa-sim>
- **[RV-TESTS]** RISC-V International, *riscv-tests*.
  <https://github.com/riscv-software-src/riscv-tests>
- **[RISCV-DV]** CHIPS Alliance, *RISCV-DV: an instruction generator for
  RISC-V processor verification*. <https://github.com/chipsalliance/riscv-dv>
- **[RV-FORMAL]** YosysHQ, *riscv-formal: RISC-V Formal Verification
  Framework*. <https://github.com/YosysHQ/riscv-formal>
- **[VERILATOR]** W. Snyder et al., *Verilator*. <https://verilator.org>
- **[YOSYS]** YosysHQ, *Yosys*, *SymbiYosys* and the OSS CAD Suite.
  <https://github.com/YosysHQ/oss-cad-suite-build>
- **[NEWLIB]** *Newlib C library*. <https://sourceware.org/newlib/>

## FPGA and boards

- **[UG472]** AMD Xilinx, *7 Series FPGAs Clocking Resources User Guide*,
  UG472. The MMCM of the board top.
- **[UG473]** AMD Xilinx, *7 Series FPGAs Memory Resources User Guide*,
  UG473. The block RAMs of IMEM and DMEM.
- **[UG479]** AMD Xilinx, *7 Series DSP48E1 Slice User Guide*, UG479. The
  multiplier and the FMA significand product.
- **[UG994]** AMD Xilinx, *Vivado Design Suite User Guide: Designing IP
  Subsystems Using IP Integrator*, UG994. Block designs.
- **[UG1118]** AMD Xilinx, *Vivado Design Suite User Guide: Creating and
  Packaging Custom IP*, UG1118. HORNET as a Vivado IP.
- **[PG144]** AMD Xilinx, *AXI GPIO LogiCORE IP Product Guide*, PG144. The
  block-design demo.
- **[PG247]** AMD Xilinx, *SmartConnect LogiCORE IP Product Guide*, PG247.
  Several AXI4-Lite slaves on the `m_axi` port.
- **[NEXYS4DDR]** Digilent, *Nexys 4 DDR Reference Manual*.
  <https://digilent.com/reference/programmable-logic/nexys-4-ddr/reference-manual>
- **[NEXYSVIDEO]** Digilent, *Nexys Video Reference Manual*.
  <https://digilent.com/reference/programmable-logic/nexys-video/reference-manual>

The AMD Xilinx documents are at <https://docs.amd.com>.

## Books

- **[PH]** D. A. Patterson and J. L. Hennessy, *Computer Organization and
  Design RISC-V Edition: The Hardware/Software Interface*, 2nd edition,
  Morgan Kaufmann, 2020. The five-stage pipeline, hazards and forwarding.
- **[HH]** S. L. Harris and D. Harris, *Digital Design and Computer
  Architecture, RISC-V Edition*, Morgan Kaufmann, 2021.

## HORNET publications

- **[ELECO21]** Y. S. Tozlu, Y. Yılmaz, B. Örs, "Design and Implementation
  of a 32-Bit RISC-V Core", *12th International Conference on Electrical and
  Electronics Engineering (ELECO)*, 2021. Version 1 of the core.
- **[ISMSIT25]** D. Z. Eroğlu, M. K. Özden, B. Örs, "Creating Verification
  Environment Using RISCV-DV With Open and Closed Source Tools", *9th
  International Symposium on Multidisciplinary Studies and Innovative
  Technologies (ISMSIT)*, 2025. The RISCV-DV environment of version 1 and
  the FPU bugs it found.
