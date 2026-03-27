# Vivado: Basys3 RISC-V — run from Vivado Tcl Console:
#   cd <repo>/vivado
#   source create_project.tcl
# Or: vivado -mode batch -source create_project.tcl

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]
set proj_name  basys3_riscv
set proj_dir   [file join $script_dir project]
set src_dir    [file join $repo_root src]
set constr_dir [file join $repo_root constraints]

file mkdir $proj_dir

create_project -force $proj_name $proj_dir -part xc7a35tcpg236-1

set design_sources [list \
  [file join $src_dir basys3_riscv_top.sv] \
  [file join $src_dir riscv_cpu_top.sv] \
  [file join $src_dir program_counter.sv] \
  [file join $src_dir simple_memory.sv] \
  [file join $src_dir pipeline_if_id.sv] \
  [file join $src_dir pipeline_id_ex.sv] \
  [file join $src_dir pipeline_ex_mem.sv] \
  [file join $src_dir pipeline_mem_wb.sv] \
  [file join $src_dir control_unit.sv] \
  [file join $src_dir register_file.sv] \
  [file join $src_dir immediate_generator.sv] \
  [file join $src_dir forwarding_unit.sv] \
  [file join $src_dir riscv_alu.sv] \
  [file join $src_dir branch_unit.sv] \
  [file join $src_dir load_store_unit.sv] \
]

set mem_init [file join $src_dir imem_program.hex]

add_files -fileset sources_1 $design_sources
add_files -fileset sources_1 $mem_init

add_files -fileset constrs_1 [file join $constr_dir basys3_riscv.xdc]

set_property top basys3_riscv_top [current_fileset]
update_compile_order -fileset sources_1

puts "Project created: $proj_dir"
puts "Top: basys3_riscv_top"
puts "Next: launch_runs synth_1 impl_1 -to_step write_bitstream -jobs 4"
puts "  Or use GUI: Open project, Run Synthesis, Implementation, Generate Bitstream."
