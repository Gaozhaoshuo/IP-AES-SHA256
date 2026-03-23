#------ add multiport fix -----#


#set_attribute $top mux_no_boundary_opt  true  -type  boolean

#if {$SCANSYN==0} {
#  foreach_in_collection design  [get_designs "*"] {
#    current_design  $design
#    set_fix_multiple_port_nets -all  -buffer_constants
#    }
#  } else {
#  set_fix_multiple_port_nets -all -buffer_constants
#  }

current_design  $top  
set  check_design_file  [format "%s%s%s%s%s"  $report_name  _  $stage _  check_design.rpt]
set  check_timing_file  [format "%s%s%s%s%s"  $report_name  _  $stage _  check_timing.rpt]

redirect $check_design_file {check_design}
redirect $check_timing_file {check_timing}
    
