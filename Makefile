# HORNET top-level Makefile.
#
# Every tool except Vivado runs inside the Docker image (make docker-build).
# On the host the commands are wrapped in `docker run`; inside the container
# (make shell, devcontainer, CI) they run directly.

IMAGE   ?= hornet-dev:latest
DOCKER  ?= docker
# limits for a laptop: parallel jobs and container memory
JOBS    ?= 4
MEMLIM  ?= 8g

ifdef HORNET_CONTAINER
DOCKER_RUN  =
else
DOCKER_RUN  = $(DOCKER) run --rm -t --memory=$(MEMLIM) -u $(shell id -u):$(shell id -g) \
              -v $(CURDIR):/work -w /work $(IMAGE)
endif

BUILD   ?= build

CORE_SRCS = rtl/core/hornet_core.v rtl/core/if_stage.v rtl/core/id_stage.v rtl/core/ex_stage.v \
            rtl/core/mem_stage.v rtl/core/wb_stage.v rtl/core/hazard_unit.v rtl/core/csr_unit.v \
            rtl/core/regfile.v rtl/core/control_unit.v rtl/core/imm_decoder.v rtl/core/ALU.v \
            rtl/core/mul.v rtl/core/div.v
FPU_SRCS  = rtl/fpu/fpu_top.v rtl/fpu/fpu_fma.v rtl/fpu/fpu_divsqrt.v rtl/fpu/fpu_cvt.v rtl/fpu/fpu_round.v \
            rtl/fpu/fpu_decoder.v rtl/fpu/fpu_sign_inj.v rtl/fpu/fpu_min_max.v rtl/fpu/fpu_compare.v \
            rtl/fpu/fpu_classifier.v
SOC_SRCS  = rtl/soc/hornet_soc.v rtl/soc/imem.v rtl/soc/dmem.v rtl/soc/data_router.v rtl/soc/obi_axil_bridge.v \
            rtl/soc/axil_xbar.v rtl/soc/axil_timer.v rtl/soc/axil_uart.v rtl/soc/axil_gpio.v rtl/soc/sync_fifo.v \
            rtl/soc/axil_sysctl.v
RTL_SRCS  = $(CORE_SRCS) $(FPU_SRCS)
RTL_INC   = -Irtl/core -Irtl/fpu

SIM        = $(BUILD)/sim/core/Vhornet_tb
SIM_FPU    = $(BUILD)/sim/fpu/Vfpu_tb
SIM_SOC    = $(BUILD)/sim/soc/Vsoc_tb
VERILATOR_FLAGS = --binary --timing -j $(JOBS) -Wno-fatal -Wno-lint -Wno-style +1364-2005ext+v \
                  --trace-fst --timescale 1ns/1ps $(RTL_INC)

RISCV_TESTS  = verif/riscv-tests/isa/rv32ui/Makefrag
RISCV_FORMAL = verif/riscv-formal/checks/genchecks.py

SUITES    ?= ui,um,uf,mi
TEST_ARGS ?=
MEM_STALL ?= 30
RANDOM    ?= 200
SEED      ?= 1

# riscv-formal: parallel checks, timeout per check in seconds, optional subset
FORMAL_JOBS    ?= 6
FORMAL_TIMEOUT ?= 900
FORMAL_CHECKS  ?=

.PHONY: help docker-build shell tool-versions lint sim test cosim cosim-stall random fpu-test formal soc-sim sw-tests regress clean

help:
	@echo "make docker-build   Build the $(IMAGE) image"
	@echo "make shell          Interactive shell in the image"
	@echo "make lint           Verilator lint of the RTL (Verilog-2005)"
	@echo "make sim            Build the core testbench"
	@echo "make test           riscv-tests ($(SUITES)) on the core"
	@echo "make cosim          The same, compared with Spike"
	@echo "make cosim-stall    cosim with random memory wait states (MEM_STALL=$(MEM_STALL))"
	@echo "make fpu-test       FPU alone against TestFloat vectors (all rounding modes)"
	@echo "make random         RANDOM=$(RANDOM) random programs vs. Spike, plain and with wait states"
	@echo "make formal         riscv-formal on the RVFI port (FORMAL_JOBS=$(FORMAL_JOBS), FORMAL_CHECKS=\"reg_ch0 ...\")"
	@echo "make soc-sim HEX=<path/prog>  Run <prog>.imem.hex/.dmem.hex on the SoC testbench"
	@echo "make sw-tests       Build and run the SoC test programs in sw/tests"
	@echo "make regress        Everything above plus formal"
	@echo "make clean          Remove $(BUILD)/"

docker-build:
	$(DOCKER) build --build-arg JOBS=$(JOBS) -t $(IMAGE) docker

shell:
	$(DOCKER) run --rm -it --memory=$(MEMLIM) -u $(shell id -u):$(shell id -g) -v $(CURDIR):/work -w /work $(IMAGE) bash

tool-versions:
	$(DOCKER_RUN) sh -c 'verilator --version; riscv32-unknown-elf-gcc --version | head -1; spike --help 2>&1 | head -1; yosys -V; python3 --version'

$(RISCV_TESTS):
	git submodule update --init verif/riscv-tests
	git -C verif/riscv-tests submodule update --init env

$(RISCV_FORMAL):
	git submodule update --init verif/riscv-formal

lint:
	$(DOCKER_RUN) verilator --lint-only -Wall --language 1364-2005 $(RTL_INC) --top-module hornet_core \
	    rtl/lint.vlt $(RTL_SRCS)
	$(DOCKER_RUN) verilator --lint-only -Wall --language 1364-2005 $(RTL_INC) --top-module hornet_soc \
	    rtl/lint.vlt $(RTL_SRCS) $(SOC_SRCS)

sim: $(SIM)

$(SIM): $(RTL_SRCS) tb/hornet_tb.sv
	@mkdir -p $(@D)
	$(DOCKER_RUN) verilator $(VERILATOR_FLAGS) --top-module hornet_tb --Mdir $(@D) -o $(@F) \
	    $(RTL_SRCS) tb/hornet_tb.sv > $(@D).log
	@echo "Built $@"

$(SIM_FPU): $(FPU_SRCS) tb/fpu_tb.sv
	@mkdir -p $(@D)
	$(DOCKER_RUN) verilator $(VERILATOR_FLAGS) --top-module fpu_tb --Mdir $(@D) -o $(@F) \
	    $(FPU_SRCS) tb/fpu_tb.sv > $(@D).log
	@echo "Built $@"

$(BUILD)/fpu/vectors.txt: scripts/fpu_vectors.py
	@mkdir -p $(@D)
	$(DOCKER_RUN) python3 scripts/fpu_vectors.py --out $@

fpu-test: $(SIM_FPU) $(BUILD)/fpu/vectors.txt
	$(DOCKER_RUN) sh -c '$(SIM_FPU) +vectors=$(BUILD)/fpu/vectors.txt | tee $(BUILD)/fpu/fpu_test.log | grep -v "^- "'
	@grep -q "^PASS" $(BUILD)/fpu/fpu_test.log

IMEM_SIZE ?= 65536
DMEM_SIZE ?= 65536
$(SIM_SOC): $(RTL_SRCS) $(SOC_SRCS) tb/soc_tb.sv
	@mkdir -p $(@D)
	$(DOCKER_RUN) verilator $(VERILATOR_FLAGS) --top-module soc_tb --Mdir $(@D) -o $(@F) \
	    -GIMEM_SIZE=$$(($(IMEM_SIZE))) -GDMEM_SIZE=$$(($(DMEM_SIZE))) $(RTL_SRCS) $(SOC_SRCS) tb/soc_tb.sv > $(@D).log
	@echo "Built $@"

SOC_ARGS ?=
soc-sim: $(SIM_SOC)
	$(DOCKER_RUN) sh -c '$(SIM_SOC) +imem=$(HEX).imem.hex +dmem=$(HEX).dmem.hex +uart_log=$(HEX).uart.log $(SOC_ARGS) | grep -v "^- "'

sw-tests: $(SIM_SOC)
	$(DOCKER_RUN) python3 scripts/run_sw_tests.py --sim $(SIM_SOC) -j $(JOBS)

test: $(SIM) $(RISCV_TESTS)
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --suites $(SUITES) -j $(JOBS) $(TEST_ARGS)

cosim: $(SIM) $(RISCV_TESTS)
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --suites $(SUITES) --spike -j $(JOBS) $(TEST_ARGS)

cosim-stall: $(SIM) $(RISCV_TESTS)
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --suites $(SUITES) --spike -j $(JOBS) \
	    --mem-stall $(MEM_STALL) --workdir $(BUILD)/tests-stall $(TEST_ARGS)

random: $(SIM)
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --spike -j $(JOBS) --random $(RANDOM) \
	    --seed $(SEED) --workdir $(BUILD)/random
	$(DOCKER_RUN) python3 scripts/run_tests.py --sim $(SIM) --spike -j $(JOBS) --random $(RANDOM) \
	    --seed $(SEED) --mem-stall $(MEM_STALL) --workdir $(BUILD)/random-stall

formal: $(RISCV_FORMAL)
	$(DOCKER_RUN) env FORMAL_TIMEOUT=$(FORMAL_TIMEOUT) scripts/run_formal.sh $(BUILD) $(FORMAL_JOBS) $(FORMAL_CHECKS)

regress: lint fpu-test cosim cosim-stall random formal

clean:
	rm -rf $(BUILD)
