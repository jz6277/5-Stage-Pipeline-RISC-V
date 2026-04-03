set script_dir [file dirname [file normalize [info script]]]
set bit [file join $script_dir project basys3_riscv.runs impl_1 basys3_riscv_top.bit]

if {![file exists $bit]} {
  puts "ERROR: Missing bitstream $bit"
  exit 1
}

open_hw_manager
connect_hw_server
open_hw_target

set devs [get_hw_devices]
if {[llength $devs] == 0} {
  puts "ERROR: No hardware devices found."
  close_hw_manager
  exit 1
}

current_hw_device [lindex $devs 0]
refresh_hw_device [current_hw_device]
set_property PROGRAM.FILE $bit [current_hw_device]
program_hw_devices [current_hw_device]

puts "Programmed device with $bit"
close_hw_manager
