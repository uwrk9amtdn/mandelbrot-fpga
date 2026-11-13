# DE25-Nano (Agilex 5) build. Needs Quartus Prime Pro (tested flow: 25.1) on PATH, sbt, and the
# Terasic DE25-Nano resource package (for the LPDDR4 EMIF system and the pin assignments).
#
#   make            generate Verilog, IP, project and compile -> build/output_files/mandelbrot.sof
#   make program    load the .sof over the USB-Blaster III
#   make verilog    only regenerate build/sp_De25NanoTop.v
#   make clean
#
# HPS design (De25NanoHpsTop, ROADMAP.md phase 1), in build_hps/:
#   make hps           compile -> build_hps/output_files/mandelbrot_hps_spl.sof (with the HPS boot loader)
#   make program-hps   load it over JTAG. This restarts the HPS, so Linux reboots.
#
# Options (make VAR=value): CORE_MHZ, NCORES, FRAC_WIDTH, SI_LATENCY, DE25_DIR

DE25_DIR   ?= $(HOME)/Desktop/fpga/de25nano/DE25-Nano_revB_v.1.0.0_ResourcePackage
CORE_MHZ   ?= 198
NCORES     ?= 60
# 16 -> 19x19 multipliers, one per DSP block: the device has 188, so at most 62 cores (3 per core).
# 15 -> 18x18, two per DSP block.
FRAC_WIDTH ?= 16
# Iteration pipeline depth (multiplier latency = SI_LATENCY - 2). Lower = fewer registers per core,
# higher = easier timing.
SI_LATENCY ?= 8

PART       := A5EB013BB23BE4SCS
BUILD      := build
SPINAL     := ../spinal
LPDDR4_DEMO = $(DE25_DIR)/Demonstration/FPGA/RTL_LPDDR4_AXI4_Test
SPINAL_SRC := $(wildcard $(SPINAL)/src/main/scala/mandelbrot/*.scala ../../../spinal/src/main/scala/fpgalib/*.scala)

.PHONY: all verilog project compile program clean hps program-hps

all: compile

verilog: $(BUILD)/sp_De25NanoTop.v

$(BUILD)/sp_De25NanoTop.v: $(SPINAL_SRC) Makefile
	mkdir -p $(BUILD)
	cd $(SPINAL) && sbt -batch "runMain mandelbrot.GenerateDe25Nano targetDir=$(abspath $(BUILD)) \
	    coreMHz=$(CORE_MHZ) nCores=$(NCORES) fracWidth=$(FRAC_WIDTH) siLatency=$(SI_LATENCY)"

# Terasic's LPDDR4 EMIF Platform Designer system (both banks; bank A is used) and reset-release IP.
# Copied, not committed: Terasic's license only allows their use with Terasic boards.
$(BUILD)/EMIF_Qsys.qsys:
	@test -d "$(LPDDR4_DEMO)" || { echo "Terasic package not found: set DE25_DIR (now $(DE25_DIR))"; exit 1; }
	mkdir -p $(BUILD)/ip/EMIF_Qsys
	cp $(LPDDR4_DEMO)/EMIF_Qsys.qsys $(LPDDR4_DEMO)/agilex_reset_release.ip $(BUILD)/
	cp $(filter-out %.BAK.ip,$(wildcard $(LPDDR4_DEMO)/ip/EMIF_Qsys/*.ip)) $(BUILD)/ip/EMIF_Qsys/
	# unlocks the board's A5EB013BB23BE4SR1 silicon (the qsf names the SCS part, like Terasic's)
	-cp $(LPDDR4_DEMO)/quartus.ini $(BUILD)/

# Pixel clock 148.5 MHz (outclk_0) and core clock (outclk_1) from CLOCK0_50.
# The old generated files must go, or quartus_ipgenerate keeps using them ("regeneration policy").
$(BUILD)/sys_pll.ip: Makefile
	mkdir -p $(BUILD)
	rm -rf $(BUILD)/sys_pll
	cd $(BUILD) && ip-deploy --family="Agilex 5" --part=$(PART) \
	    --component-name=altera_iopll --output-name=sys_pll --output-directory=. \
	    --component-parameter=gui_reference_clock_frequency=50.0 \
	    --component-parameter=gui_number_of_clocks=2 \
	    --component-parameter=gui_output_clock_frequency0=148.5 \
	    --component-parameter=gui_output_clock_frequency1=$(CORE_MHZ) \
	    --component-parameter=gui_use_locked=true \
	    --component-parameter=gui_operation_mode=normal

$(BUILD)/mandelbrot.qsf: create_project.tcl $(BUILD)/EMIF_Qsys.qsys $(BUILD)/sys_pll.ip
	cd $(BUILD) && quartus_sh -t ../create_project.tcl $(LPDDR4_DEMO)/golden_top.qsf

project: $(BUILD)/mandelbrot.qsf $(BUILD)/sp_De25NanoTop.v

compile: project
	cd $(BUILD) && quartus_ipgenerate --run_default_mode_op mandelbrot
	cd $(BUILD) && quartus_sh --flow compile mandelbrot
	@grep -A3 'Worst-case Slack' $(BUILD)/output_files/mandelbrot.sta.summary 2>/dev/null || true

program:
	cd $(BUILD) && quartus_pgm -m jtag -o "p;output_files/mandelbrot.sof"

clean:
	rm -rf $(BUILD) $(BUILD_HPS)

# ------------------------------------------------------------------------------------ HPS design
BUILD_HPS  := build_hps
GHRD        = $(DE25_DIR)/Demonstration/SoC_FPGA/GHRD
BOARD_INFO  = $(DE25_DIR)/Demonstration/FPGA/Board_Info_RTL

$(BUILD_HPS)/sp_De25NanoHpsTop.v: $(SPINAL_SRC) Makefile
	mkdir -p $(BUILD_HPS)
	cd $(SPINAL) && sbt -batch "runMain mandelbrot.GenerateDe25NanoHps targetDir=$(abspath $(BUILD_HPS)) \
	    nCores=$(NCORES) fracWidth=$(FRAC_WIDTH) siLatency=$(SI_LATENCY)"

# Core clock (outclk_0) from CLOCK1_50.
$(BUILD_HPS)/core_pll.ip: Makefile
	mkdir -p $(BUILD_HPS)
	rm -rf $(BUILD_HPS)/core_pll
	cd $(BUILD_HPS) && ip-deploy --family="Agilex 5" --part=$(PART) \
	    --component-name=altera_iopll --output-name=core_pll --output-directory=. \
	    --component-parameter=gui_reference_clock_frequency=50.0 \
	    --component-parameter=gui_number_of_clocks=1 \
	    --component-parameter=gui_output_clock_frequency0=$(CORE_MHZ) \
	    --component-parameter=gui_use_locked=true \
	    --component-parameter=gui_operation_mode=normal

# Terasic's GHRD (HPS, its LPDDR4 EMIF, JTAG masters) reshaped by hps_qsys.tcl, the boot loader the
# GHRD was built with, and the fan controller. Copied, not committed (Terasic's license).
$(BUILD_HPS)/qsys_top.qsys: hps_qsys.tcl
	@test -d "$(GHRD)" || { echo "Terasic package not found: set DE25_DIR (now $(DE25_DIR))"; exit 1; }
	mkdir -p $(BUILD_HPS)
	cd $(BUILD_HPS) && rm -rf ip hps_subsys jtag_subsys custom_ip board_management_ip qsys_top
	cp -r $(GHRD)/ip $(GHRD)/hps_subsys $(GHRD)/jtag_subsys $(GHRD)/custom_ip $(BUILD_HPS)/
	cp $(GHRD)/jtag.sdc $(GHRD)/software/u-boot/spl/u-boot-spl-dtb.hex $(BUILD_HPS)/
	cp -r $(BOARD_INFO)/board_management_ip $(BUILD_HPS)/
	rm -f $(BUILD_HPS)/ip/qsys_top/ext_hps_f2sdram_master.ip
	cp $(GHRD)/qsys_top.qsys $(BUILD_HPS)/
	cd $(BUILD_HPS) && qsys-script --script=../hps_qsys.tcl --quartus-project=none

$(BUILD_HPS)/mandelbrot_hps.qsf: create_project_hps.tcl $(BUILD_HPS)/qsys_top.qsys $(BUILD_HPS)/core_pll.ip
	cd $(BUILD_HPS) && quartus_sh -t ../create_project_hps.tcl $(GHRD)/golden_top.qsf
	# the GHRD was made with Quartus 25.1
	cd $(BUILD_HPS) && quartus_sh --ip_upgrade -mode all mandelbrot_hps

hps: $(BUILD_HPS)/mandelbrot_hps.qsf $(BUILD_HPS)/sp_De25NanoHpsTop.v
	cd $(BUILD_HPS) && quartus_ipgenerate --run_default_mode_op mandelbrot_hps
	cd $(BUILD_HPS) && quartus_sh --flow compile mandelbrot_hps
	cd $(BUILD_HPS) && quartus_pfg -c output_files/mandelbrot_hps.sof output_files/mandelbrot_hps_spl.sof \
	    -o hps_path=u-boot-spl-dtb.hex
	@grep -A3 'Worst-case Slack' $(BUILD_HPS)/output_files/mandelbrot_hps.sta.summary 2>/dev/null || true

program-hps:
	cd $(BUILD_HPS) && quartus_pgm -m jtag -o "p;output_files/mandelbrot_hps_spl.sof"
