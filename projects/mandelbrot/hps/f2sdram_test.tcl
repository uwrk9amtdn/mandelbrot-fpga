# Access HPS memory through the f2sdram bridge, with the GHRD's JTAG master
# (subsys_debug|hps_f2sdram; its span extender passes addresses through unchanged, and f2sdram
# addresses are HPS physical addresses, RAM starting at 0x80000000).
#
#   system-console --script=f2sdram_test.tcl <sof> read <addr> [words]   read 32-bit words (harmless)
#   system-console --script=f2sdram_test.tcl <sof> fill <addr> <bytes>   write memtool's test pattern
#
# <sof> is the bitstream running on the board (the GHRD's output_files/golden_top_hps.sof). System
# Console needs it to name the three JTAG masters; without it they are only phy_0..phy_2.
#
# After a fill, on the board: memtool check <addr> <bytes>
# Only fill memory that Linux does not use (removed with mem=).

lassign $argv sof mode addr count
if {$addr eq "" || ($mode ne "read" && $mode ne "fill") || ($mode eq "fill" && $count eq "")} {
    puts "usage: system-console --script=f2sdram_test.tcl <sof> read|fill <addr> <words|bytes>"
    exit 2
}

design_load $sof
refresh_connections
after 5000 ;# the masters appear a few seconds after the connection is made
set masters [get_service_paths master]
set m [lsearch -inline $masters *f2sdram*]
if {$m eq ""} {
    puts "no f2sdram master found among:\n  [join $masters "\n  "]"
    exit 1
}
open_service master $m

if {$mode eq "read"} {
    if {$count eq ""} {set count 8}
    puts "[format %#x $addr]: [master_read_32 $m $addr $count]"
} else {
    # 1024 words per JTAG transaction.
    for {set off 0} {$off < $count} {incr off 4096} {
        set words {}
        for {set i 0} {$i < 4096 && $off + $i < $count} {incr i 4} {
            lappend words [expr {($addr + $off + $i) & 0xffffffff}]
        }
        master_write_32 $m [expr {$addr + $off}] $words
    }
    puts "wrote $count bytes at [format %#x $addr]"
    puts "first words read back over f2sdram: [master_read_32 $m $addr 4]"
}
close_service master $m
