onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/top/wrapper_gen/wrapper/rst
add wave -noupdate /tb/top/wrapper_gen/wrapper/clk
add wave -noupdate -group {wrapper s} /tb/top/wrapper_gen/wrapper/s_ready
add wave -noupdate -group {wrapper s} /tb/top/wrapper_gen/wrapper/s_valid
add wave -noupdate -group {wrapper s} /tb/top/wrapper_gen/wrapper/s_max_it
add wave -noupdate -group {wrapper s} /tb/top/wrapper_gen/wrapper/s_center_x
add wave -noupdate -group {wrapper s} /tb/top/wrapper_gen/wrapper/s_center_y
add wave -noupdate -group {wrapper s} /tb/top/wrapper_gen/wrapper/s_xy_step
add wave -noupdate -expand -group {wrapper m_addr} /tb/top/wrapper_gen/wrapper/m_addr/ready
add wave -noupdate -expand -group {wrapper m_addr} /tb/top/wrapper_gen/wrapper/m_addr/valid
add wave -noupdate -expand -group {wrapper m_addr} /tb/top/wrapper_gen/wrapper/m_addr/data
add wave -noupdate -expand -group {wrapper m_addr} /tb/top/wrapper_gen/wrapper/m_addr/last
add wave -noupdate -group {wrapper m_data} /tb/top/wrapper_gen/wrapper/m_data/ready
add wave -noupdate -group {wrapper m_data} /tb/top/wrapper_gen/wrapper/m_data/valid
add wave -noupdate -group {wrapper m_data} /tb/top/wrapper_gen/wrapper/m_data/data
add wave -noupdate -group {wrapper m_data} /tb/top/wrapper_gen/wrapper/m_data/last
add wave -noupdate -expand -group {wrapper wc_s} /tb/top/wrapper_gen/wrapper/master_block/wc_s/ready
add wave -noupdate -expand -group {wrapper wc_s} /tb/top/wrapper_gen/wrapper/master_block/wc_s/valid
add wave -noupdate -expand -group {wrapper wc_s} /tb/top/wrapper_gen/wrapper/master_block/wc_s/data
add wave -noupdate -expand -group {wrapper wc_s} /tb/top/wrapper_gen/wrapper/master_block/wc_s/last
add wave -noupdate -expand -group {wrapper at_m} /tb/top/wrapper_gen/wrapper/at_m/ready
add wave -noupdate -expand -group {wrapper at_m} /tb/top/wrapper_gen/wrapper/at_m/valid
add wave -noupdate -expand -group {wrapper at_m} /tb/top/wrapper_gen/wrapper/at_m/data
add wave -noupdate -expand -group {wrapper at_m} /tb/top/wrapper_gen/wrapper/at_m/last
add wave -noupdate /tb/top/wrapper_gen/wrapper/master_block/state
add wave -noupdate -group {core wrapper 9} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[9]/ready}
add wave -noupdate -group {core wrapper 9} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[9]/valid}
add wave -noupdate -group {core wrapper 9} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[9]/data}
add wave -noupdate -group {core wrapper 9} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[9]/last}
add wave -noupdate -group {core wrapper 8} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[8]/ready}
add wave -noupdate -group {core wrapper 8} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[8]/valid}
add wave -noupdate -group {core wrapper 8} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[8]/data}
add wave -noupdate -group {core wrapper 8} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[8]/last}
add wave -noupdate -group {core wrapper 7} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[7]/ready}
add wave -noupdate -group {core wrapper 7} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[7]/valid}
add wave -noupdate -group {core wrapper 7} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[7]/data}
add wave -noupdate -group {core wrapper 7} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[7]/last}
add wave -noupdate -group {core wrapper 6} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[6]/ready}
add wave -noupdate -group {core wrapper 6} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[6]/valid}
add wave -noupdate -group {core wrapper 6} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[6]/data}
add wave -noupdate -group {core wrapper 6} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[6]/last}
add wave -noupdate -group {core wrapper 5} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[5]/ready}
add wave -noupdate -group {core wrapper 5} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[5]/valid}
add wave -noupdate -group {core wrapper 5} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[5]/data}
add wave -noupdate -group {core wrapper 5} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[5]/last}
add wave -noupdate -group {core wrapper 4} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[4]/ready}
add wave -noupdate -group {core wrapper 4} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[4]/valid}
add wave -noupdate -group {core wrapper 4} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[4]/data}
add wave -noupdate -group {core wrapper 4} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[4]/last}
add wave -noupdate -group {core wrapper 3} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[3]/ready}
add wave -noupdate -group {core wrapper 3} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[3]/valid}
add wave -noupdate -group {core wrapper 3} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[3]/data}
add wave -noupdate -group {core wrapper 3} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[3]/last}
add wave -noupdate -group {core wrapper 2} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[2]/ready}
add wave -noupdate -group {core wrapper 2} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[2]/valid}
add wave -noupdate -group {core wrapper 2} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[2]/data}
add wave -noupdate -group {core wrapper 2} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[2]/last}
add wave -noupdate -group {core wrapper 1} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[1]/ready}
add wave -noupdate -group {core wrapper 1} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[1]/valid}
add wave -noupdate -group {core wrapper 1} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[1]/data}
add wave -noupdate -group {core wrapper 1} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[1]/last}
add wave -noupdate -expand -group {core wrapper 0} {/tb/top/wrapper_gen/wrapper/slave_block/core_gen[0]/core/mstate}
add wave -noupdate -expand -group {core wrapper 0} {/tb/top/wrapper_gen/wrapper/slave_block/core_gen[0]/core/sstate}
add wave -noupdate -expand -group {core wrapper 0} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[0]/ready}
add wave -noupdate -expand -group {core wrapper 0} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[0]/valid}
add wave -noupdate -expand -group {core wrapper 0} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[0]/data}
add wave -noupdate -expand -group {core wrapper 0} {/tb/top/wrapper_gen/wrapper/slave_block/core_m[0]/last}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {116484788 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 542
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
WaveRestoreZoom {116232343 ps} {117267433 ps}
