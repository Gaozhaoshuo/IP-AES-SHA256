#----- compile fix setup violation ------#
puts "#--------------------------#"
puts "#  compile stage: $stage   #"
puts "#--------------------------#"

current_design  $top

set_max_area 0.0

set compile_log_file  [format "%s%s%s%s%s"  $compile_log_name  _  $stage _  compile.log]

##set compile_sequential_area_recovery  true

if {$en_clk_gating == 1} {
	redirect -append $compile_log_file  {     \
		compile -map_effort  high   \
                -area_effort high   \
	            -incremental        \
			    -gate_clock}
} else {
	redirect -append $compile_log_file  {     \
		compile -map_effort  high   \
                -area_effort high   \
	            -incremental}
}

