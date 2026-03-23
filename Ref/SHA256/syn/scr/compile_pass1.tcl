#----- initial compile phase ------#

puts "#--------------------------#"
puts "#  compile stage: $stage   #"
puts "#--------------------------#"

current_design  $top

if {$SCANSYN == 1} {
    set scan_option "-scan  \\"
} else {
    set scan_option "\\"
}

##simplify_constants -boundary_optimization

set compile_log_file  [format "%s%s%s%s%s"  $compile_log_name  _  $stage _  compile.log]

##---- No compile_ultra license now ----##

set_datapath_optimization_effort [current_design] high

if {$en_clk_gating == 1} {
  redirect $compile_log_file {  \
    compile -map_effort  high   \
            -gate_clock		    \
            $scan_option
    } 
  } else {
    redirect $compile_log_file {    \
	 compile -map_effort  high      \
             $scan_option
      }         
  }
 
