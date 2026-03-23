#----- compile fix setup violation ------#
puts "#--------------------------#"
puts "#  compile stage: $stage   #"
puts "#--------------------------#"

current_design  $top

set_max_area 0.0

if {$SCANSYN == 1} {
    set scan_option "-scan  "
} else {
    set scan_option ""
}

set compile_log_file  [format "%s%s%s%s%s"  $compile_log_name  _  $stage _  compile.log]

##set compile_sequential_area_recovery  true

##compile_ultra
##              [-incremental]
##              [-scan]
##              [-exact_map]
##              [-no_autoungroup]
##              [-no_seq_output_inversion]
##              [-no_boundary_optimization]
##              [-no_design_rule | -only_design_rule]
##              [-timing_high_effort_script | -area_high_effort_script]
##              [-top]
##              [-retime]
##              [-gate_clock]
##              [-check_only]
##              [-num_cpus n]
##              [-congestion]

if {$en_clk_gating == 1} {
	redirect  $compile_log_file "           \
	    compile_ultra -no_autoungroup       \
        	    -no_seq_output_inversion    \
                -timing_high_effort_script  \
                -gate_clock		            \
                $scan_option                \
	"
} else {
	redirect $compile_log_file "            \
	    compile_ultra -no_autoungroup       \
                -timing_high_effort_script  \
                -no_seq_output_inversion    \
                $scan_option                \
         "
}

##-- redirect -append $compile_log_file {      \
##-- 	 compile  -boundary_optimization   \
##--                  -map_effort  high        \
##--                  -area_effort high        \
##--                  -incremental	          \
##--         }


