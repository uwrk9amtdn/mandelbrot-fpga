onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group top /tb/top/clk_p
add wave -noupdate -expand -group top /tb/top/clk_n
add wave -noupdate -expand -group top /tb/top/sda
add wave -noupdate -expand -group top /tb/top/scl
add wave -noupdate -expand -group top /tb/top/pixel_clk
add wave -noupdate -expand -group top /tb/top/r
add wave -noupdate -expand -group top /tb/top/g
add wave -noupdate -expand -group top /tb/top/b
add wave -noupdate -expand -group top /tb/top/hsync
add wave -noupdate -expand -group top /tb/top/vsync
add wave -noupdate -expand -group top /tb/top/de
add wave -noupdate -expand -group top /tb/top/ddr3_dq
add wave -noupdate -expand -group top /tb/top/ddr3_dqs_n
add wave -noupdate -expand -group top /tb/top/ddr3_dqs_p
add wave -noupdate -expand -group top /tb/top/ddr3_addr
add wave -noupdate -expand -group top /tb/top/ddr3_ba
add wave -noupdate -expand -group top /tb/top/ddr3_ras_n
add wave -noupdate -expand -group top /tb/top/ddr3_cas_n
add wave -noupdate -expand -group top /tb/top/ddr3_we_n
add wave -noupdate -expand -group top /tb/top/ddr3_reset_n
add wave -noupdate -expand -group top /tb/top/ddr3_ck_p
add wave -noupdate -expand -group top /tb/top/ddr3_ck_n
add wave -noupdate -expand -group top /tb/top/ddr3_cke
add wave -noupdate -expand -group top /tb/top/ddr3_cs_n
add wave -noupdate -expand -group top /tb/top/ddr3_dm
add wave -noupdate -expand -group top /tb/top/ddr3_odt
add wave -noupdate -expand -group top /tb/top/sysclk
add wave -noupdate -expand -group top /tb/top/ddr3_clk
add wave -noupdate -expand -group top /tb/top/ddr3_clk_90
add wave -noupdate -expand -group top /tb/top/ddr3_ctrl_clk
add wave -noupdate -expand -group top /tb/top/ddr3_ctrl_rst
add wave -noupdate -expand -group top /tb/top/ddr3_ref_clk
add wave -noupdate -expand -group top /tb/top/clk
add wave -noupdate -expand -group top /tb/top/rst
add wave -noupdate -expand -group top /tb/top/vio_rst
add wave -noupdate -expand -group top /tb/top/ddr3_calib_complete
add wave -noupdate -expand -group top /tb/top/max_it
add wave -noupdate -expand -group top /tb/top/center_x
add wave -noupdate -expand -group top /tb/top/center_y
add wave -noupdate -expand -group top /tb/top/xy_step
add wave -noupdate -expand -group top /tb/top/start
add wave -noupdate -expand -group top /tb/top/adv7511_setup_error
add wave -noupdate -expand -group top /tb/top/adv7511_setup_done
add wave -noupdate -expand -group top /tb/top/cc_start_index
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/ADDR_WIDTH
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/araddr
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arburst
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arcache
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arid
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arlen
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arlock
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arprot
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arqos
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arready
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arsize
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/arvalid
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awaddr
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awburst
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awcache
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awid
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awlen
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awlock
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awprot
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awqos
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awready
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awsize
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/awvalid
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/bid
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/bready
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/bresp
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/bvalid
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/DATA_WIDTH
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/ID_WIDTH
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/rdata
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/rid
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/rlast
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/rready
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/rresp
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/rvalid
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/wdata
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/wlast
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/wready
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/wstrb
add wave -noupdate -group ddr3_axi /tb/top/ddr3_block/ddr3_axi/wvalid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awaddr
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awlen
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awsize
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awburst
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awlock
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awcache
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awprot
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awqos
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awvalid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/awready
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/wdata
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/wstrb
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/wlast
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/wvalid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/wready
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/bid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/bresp
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/bvalid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/bready
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/araddr
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arlen
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arsize
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arburst
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arlock
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arcache
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arprot
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arqos
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arvalid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/arready
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/rid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/rdata
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/rresp
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/rlast
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/rvalid
add wave -noupdate -group ddr3_axi_64 /tb/top/ddr3_axi_64/rready
add wave -noupdate -group memw_s_addr /tb/top/wrapper_block/memw/s_addr/ready
add wave -noupdate -group memw_s_addr /tb/top/wrapper_block/memw/s_addr/valid
add wave -noupdate -group memw_s_addr /tb/top/wrapper_block/memw/s_addr/data
add wave -noupdate -group memw_s_addr /tb/top/wrapper_block/memw/s_addr/last
add wave -noupdate -group memw_s_data /tb/top/wrapper_block/memw/s_data/ready
add wave -noupdate -group memw_s_data /tb/top/wrapper_block/memw/s_data/valid
add wave -noupdate -group memw_s_data /tb/top/wrapper_block/memw/s_data/data
add wave -noupdate -group memw_s_data /tb/top/wrapper_block/memw/s_data/last
add wave -noupdate -group data_fifo_m /tb/top/wrapper_block/data_fifo_m/ready
add wave -noupdate -group data_fifo_m /tb/top/wrapper_block/data_fifo_m/valid
add wave -noupdate -group data_fifo_m /tb/top/wrapper_block/data_fifo_m/data
add wave -noupdate -group data_fifo_m /tb/top/wrapper_block/data_fifo_m/last
add wave -noupdate -group data_fifo_s /tb/top/wrapper_block/data_fifo_s/ready
add wave -noupdate -group data_fifo_s /tb/top/wrapper_block/data_fifo_s/valid
add wave -noupdate -group data_fifo_s /tb/top/wrapper_block/data_fifo_s/data
add wave -noupdate -group data_fifo_s /tb/top/wrapper_block/data_fifo_s/last
add wave -noupdate -group addr_fifo_m /tb/top/wrapper_block/addr_fifo_m/ready
add wave -noupdate -group addr_fifo_m /tb/top/wrapper_block/addr_fifo_m/valid
add wave -noupdate -group addr_fifo_m -radix unsigned /tb/top/wrapper_block/addr_fifo_m/data
add wave -noupdate -group addr_fifo_m /tb/top/wrapper_block/addr_fifo_m/last
add wave -noupdate -expand -group wrapper_wc_s /tb/top/wrapper_block/wrapper/master_block/wc_s/ready
add wave -noupdate -expand -group wrapper_wc_s /tb/top/wrapper_block/wrapper/master_block/wc_s/valid
add wave -noupdate -expand -group wrapper_wc_s /tb/top/wrapper_block/wrapper/master_block/wc_s/data
add wave -noupdate -expand -group wrapper_wc_s /tb/top/wrapper_block/wrapper/master_block/wc_s/last
add wave -noupdate -expand -group wrapper_m_addr /tb/top/wrapper_block/wrapper/m_addr/ready
add wave -noupdate -expand -group wrapper_m_addr /tb/top/wrapper_block/wrapper/m_addr/valid
add wave -noupdate -expand -group wrapper_m_addr /tb/top/wrapper_block/wrapper/m_addr/data
add wave -noupdate -expand -group wrapper_m_addr /tb/top/wrapper_block/wrapper/m_addr/last
add wave -noupdate /tb/top/wrapper_block/wrapper/master_block/state
add wave -noupdate /tb/top/clk
add wave -noupdate -expand -group at_m /tb/top/wrapper_block/wrapper/at_m/ready
add wave -noupdate -expand -group at_m /tb/top/wrapper_block/wrapper/at_m/valid
add wave -noupdate -expand -group at_m /tb/top/wrapper_block/wrapper/at_m/data
add wave -noupdate -expand -group at_m /tb/top/wrapper_block/wrapper/at_m/last
add wave -noupdate -expand -group core_wrapper_0 {/tb/top/wrapper_block/wrapper/slave_block/core_gen[0]/core/sstate}
add wave -noupdate -expand -group core_wrapper_0 {/tb/top/wrapper_block/wrapper/slave_block/core_gen[0]/core/mstate}
add wave -noupdate -expand -group core_wrapper_0 {/tb/top/wrapper_block/wrapper/slave_block/core_gen[0]/core/ptr}
add wave -noupdate -expand -group core_wrapper_0 {/tb/top/wrapper_block/wrapper/slave_block/core_gen[0]/core/data}
add wave -noupdate -expand -group core_m {/tb/top/wrapper_block/wrapper/slave_block/core_gen[0]/core/m/ready}
add wave -noupdate -expand -group core_m {/tb/top/wrapper_block/wrapper/slave_block/core_gen[0]/core/m/valid}
add wave -noupdate -expand -group core_m {/tb/top/wrapper_block/wrapper/slave_block/core_gen[0]/core/m/data}
add wave -noupdate -expand -group core_m {/tb/top/wrapper_block/wrapper/slave_block/core_gen[0]/core/m/last}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {116665000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 423
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {116350785 ps} {116979215 ps}
