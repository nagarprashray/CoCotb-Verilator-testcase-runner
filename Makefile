SIM ?= verilator
TOPLEVEL_LANG = verilog
EXAMPLE ?= counter
MODE ?= both
RESULT_DIR ?= results/$(EXAMPLE)

ifneq ($(CASE_DIR),)
DUT_SOURCES = $(sort $(wildcard $(CASE_DIR)/rtl/*.v) $(wildcard $(CASE_DIR)/rtl/*.sv))
SV_TB_SOURCES = $(sort $(wildcard $(CASE_DIR)/tb/*.v) $(wildcard $(CASE_DIR)/tb/*.sv))
DUT_TOPLEVEL ?= $(CASE_DUT_TOP)
SV_TOPLEVEL ?= $(CASE_SV_TOP)
COCOTB_TEST_MODULES ?= $(CASE_PY_MODULES)
PYTHON_TEST_PATH ?= $(CASE_DIR)/tb:$(CASE_DIR)/tests:$(CASE_DIR)/python_tb
else
ifeq ($(EXAMPLE),fifo)
DUT_SOURCES = $(CURDIR)/input/fifo/dut/sync_fifo.sv
SV_TB_SOURCES = $(CURDIR)/input/fifo/sv_tb/tb_sync_fifo.sv
DUT_TOPLEVEL = sync_fifo
SV_TOPLEVEL = tb_sync_fifo
COCOTB_TEST_MODULES = test_sync_fifo
else
DUT_SOURCES = $(CURDIR)/input/counter/dut/counter.sv
SV_TB_SOURCES = $(CURDIR)/input/counter/sv_tb/tb_counter.sv
DUT_TOPLEVEL = counter
SV_TOPLEVEL = tb_counter
COCOTB_TEST_MODULES = test_counter
endif
PYTHON_TEST_PATH = $(CURDIR)/input/$(EXAMPLE)/python_tb
endif

ifeq ($(MODE),python)
VERILOG_SOURCES = $(DUT_SOURCES)
TOPLEVEL = $(DUT_TOPLEVEL)
else
VERILOG_SOURCES = $(DUT_SOURCES) $(SV_TB_SOURCES)
TOPLEVEL = $(SV_TOPLEVEL)
endif

COCOTB_RESULTS_FILE = $(RESULT_DIR)/results.xml
COMPILE_ARGS += --timing

export PYTHONPATH := $(PYTHON_TEST_PATH):$(PYTHONPATH)

empty :=
space := $(empty) $(empty)
cocotb_makefiles := $(subst $(space),\$(space),$(shell cocotb-config --makefiles))
include $(cocotb_makefiles)/Makefile.sim

.PHONY: sv-only
sv-only:
	mkdir -p sim_build
	verilator --binary --timing --timescale 1ns/1ps -DSV_ONLY --top-module $(SV_TOPLEVEL) \
		-Mdir sim_build -o Vsv $(DUT_SOURCES) $(SV_TB_SOURCES)
	./sim_build/Vsv
