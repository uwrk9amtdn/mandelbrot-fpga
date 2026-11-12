set part xc7a200tfbg676-2

create_project UberDDR3_test . -part $part -force

set design_files {
    ../top.sv
    ../../../sv/axi/axi_intf.sv
    ../../../sv/memory_controllers/ddr3_intf.sv
    ../../../sv/memory_controllers/uberddr3_wrapper_axi.sv
    ../../../sv/misc/clock_gen_7_series_pll.sv
    ../../../third_party/UberDDR3/rtl/ddr3_top.v
    ../../../third_party/UberDDR3/rtl/ddr3_phy.v
    ../../../third_party/UberDDR3/rtl/ddr3_controller.v
    ../../../third_party/UberDDR3/rtl/axi/axi_addr.v
    ../../../third_party/UberDDR3/rtl/axi/axim2wbsp.v
    ../../../third_party/UberDDR3/rtl/axi/aximrd2wbsp.v
    ../../../third_party/UberDDR3/rtl/axi/aximwr2wbsp.v
    ../../../third_party/UberDDR3/rtl/axi/ddr3_top_axi.v
    ../../../third_party/UberDDR3/rtl/axi/sfifo.v
    ../../../third_party/UberDDR3/rtl/axi/skidbuffer.v
    ../../../third_party/UberDDR3/rtl/axi/wbarbiter.v
}

set sim_files {
    ../tb.sv
    ../../../sv/memory_controllers/ddr3_sim_model/ddr3_model.sv
}

set constraint_files {
    ac701.xdc
}

add_files $design_files
add_files -fileset sim_1 $sim_files
add_files -fileset constrs_1 $constraint_files

set_property top top [current_fileset]
update_compile_order -fileset sources_1
