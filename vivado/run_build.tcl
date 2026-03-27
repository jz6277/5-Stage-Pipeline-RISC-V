# Batch: synthesis, implementation, bitstream (after create_project.tcl)
#   vivado -mode batch -source run_build.tcl

set script_dir [file dirname [file normalize [info script]]]
set xpr [file join $script_dir project basys3_riscv.xpr]

if {![file exists $xpr]} {
  puts "ERROR: Missing $xpr — run create_project.tcl first."
  exit 1
}

open_project $xpr
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set bit [file join $script_dir project basys3_riscv.runs impl_1 basys3_riscv_top.bit]
if {[file exists $bit]} {
  puts "Done. Bitstream: $bit"
} else {
  puts "Check impl_1 run — expected: $bit"
}
