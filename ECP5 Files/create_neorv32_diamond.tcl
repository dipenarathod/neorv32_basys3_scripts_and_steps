# =====================================================================
# Create a Lattice Diamond project for NEORV32 on ECP5-EVN
#
# Usage example (batch):
#   /home/dipen/lscc/diamond/3.14/bin/lin64/diamond.sh -t create_neorv32_diamond.tcl
#
# Then open the generated .ldf in the GUI, or extend this script with
# synthesis/PAR run commands as needed.
# =====================================================================

# ---------------- User configuration ---------------------------------

# NEORV32 repo root (relative to this script)
set neorv32_home [file normalize "../../neorv32"]

# Project/implementation names
set board_name "ECP5EVN"
set proj_name  "${board_name}_NEORV32_MinimalBoot"
set impl_name  "impl1"

# Exact ECP5 device (adjust if Diamond uses a slightly different string)
set device "LFE5U5MG-85F-8BG381I"

# Work directory where the Diamond project (.ldf, etc.) will live
set work_dir "work"

# Constraint file (LPF) relative to this script
set lpf_file [file normalize "../../osflow/constraints/ECP5EVN.lpf"]

# Board top-level file (place this VHDL next to this script)
set board_top_src [file normalize "./neorv32_ECP5EVN_BoardTop_MinimalBoot.vhd"]

# Processor template inside NEORV32
set proc_template [file normalize "$neorv32_home/rtl/processor_templates/neorv32_ProcessorTop_MinimalBoot.vhd"]

# NEORV32 file list (SoC setup) as recommended in the docs
set file_list_path [file normalize "$neorv32_home/rtl/file_list_soc.f"]

# ---------------- Prepare work directory ------------------------------

if {![file exists $work_dir]} {
    file mkdir $work_dir
    puts "Created directory $work_dir"
} else {
    set files [glob -nocomplain "$work_dir/*"]
    if {[llength $files] != 0} {
        puts "Cleaning directory $work_dir"
        file delete -force {*}$files
    } else {
        puts "$work_dir is already empty"
    }
}

# Change into work dir so project files end up here
cd $work_dir

# ---------------- Create Diamond project ------------------------------

# Create a new project with the given device and implementation.
# If your Diamond version uses different flags, check 'help prj_project'
# in the Diamond Tcl console and adjust this line accordingly.
prj_project new -name $proj_name -impl $impl_name -dev $device

# ---------------- Add ECP5 components package (EHXPLLL, etc.) ---------

# Path to the ECP5 components VHDL (relative to this script)
set ecp5_comp [file normalize "../../osflow/devices/ecp5/ecp5_components.vhd"]

if {[file exists $ecp5_comp]} {
    puts "Adding ECP5 components package: $ecp5_comp"
    # Compile into VHDL library 'ecp5' to match: library ecp5; use ecp5.components.all;
    prj_src add -work ecp5 $ecp5_comp
} else {
    puts "WARNING: ECP5 components file not found: $ecp5_comp"
}


# Explicitly add core files (ensures neorv32_package is present)
set core_dir "$neorv32_home/rtl/core"
set core_files [glob -nocomplain "$core_dir/*.vhd"]

puts "Adding NEORV32 core files to library 'neorv32'..."
foreach f $core_files {
    if {![file exists $f]} {
        puts "WARNING: core file not found: $f"
        continue
    }
    prj_src add -work neorv32 $f
}

# ---------------- Add NEORV32 core + SoC sources ---------------------

if {![file exists $file_list_path]} {
    puts "ERROR: Cannot find NEORV32 file list: $file_list_path"
    return
}

set fl_fd [open $file_list_path r]
set fl_data [read $fl_fd]
close $fl_fd

# Replace placeholder path with actual rtl directory as described in the docs
set fl_data [string map {"NEORV32_RTL_PATH_PLACEHOLDER" "$neorv32_home/rtl"} $fl_data]

# Collect file paths, ignoring empty lines and comments
set neorv32_files {}
foreach line [split $fl_data "\n"] {
    set trimmed [string trim $line]
    if {$trimmed eq ""} {
        continue
    }
    if {[string match "#*" $trimmed]} {
        continue
    }
    lappend neorv32_files $trimmed
}

puts "Adding NEORV32 RTL files to library 'neorv32'..."
foreach f $neorv32_files {
    if {![file exists $f]} {
        puts "WARNING: NEORV32 file not found: $f"
        continue
    }
    # Add each NEORV32 file into VHDL library 'neorv32'
    prj_src add -work neorv32 $f
}

# Ensure the processor template is present (in case it is not in file_list_soc.f)
if {[file exists $proc_template]} {
    puts "Adding processor template: $proc_template"
    prj_src add -work neorv32 $proc_template
} else {
    puts "WARNING: Processor template not found: $proc_template"
}

# ---------------- Add board-level top entity -------------------------

if {![file exists $board_top_src]} {
    puts "ERROR: Board top-level file not found: $board_top_src"
    return
}

puts "Adding board top-level: $board_top_src"
# Board-level top can be in 'work' (it instantiates the NEORV32 template)
prj_src add -work work $board_top_src
prj_src top $board_top_src

# ---------------- Add constraints (LPF) ------------------------------

if {[file exists $lpf_file]} {
    puts "Adding constraints file: $lpf_file"
    prj_src add $lpf_file
} else {
    puts "WARNING: Constraint file not found: $lpf_file"
}

# ---------------- Save project ---------------------------------------

prj_project save

puts "==================================================================="
puts "NEORV32 Diamond project created:"
puts "  Project:        $proj_name"
puts "  Implementation: $impl_name"
puts "  Device:         $device"
puts "  Location:       [pwd]"
puts "Now open the .ldf in Diamond and run Synthesis / Map / PAR / Bitgen."
puts "==================================================================="

