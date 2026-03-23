##-----------------------------##
##---- synthesis defines ------##
##-----------------------------##

set syn_define_list [list ASIC_MACRO ASIC_NETLIST]

##-----------------------------##
##---- timing parameters ------##
##-----------------------------##

#-- set default load cell --#
set  buf_cell              slow/BUFX12/A

#-- set clock cycle time  --#

set  clk_cyc_derate         1.00

set  clk_sys_cyc	        [expr (1000.00 / 250.00) * $clk_cyc_derate]

set  clk_transiton          0.10
set  clk_uncertain_setup    0.20
set  clk_uncertain_hold     0.08

set  clk_gate_setup        0.1
set  clk_gate_hold         0.1

set  input_delay_min       0.2
set  output_delay_min      0.0

#-- set design enviroment value ---#
set  output_load_pad       25.0
set  output_load_pin       0.2

#---- these are all use lib default value ---#
#set  port_max_transition   3.0
#set  port_max_cap          [expr 128.0*[load_of $buf_cell]]
set   design_max_fanout     30
#set  design_max_transition 1.5
#set  design_max_cap        [expr 20.0*[load_of $buf_cell]]

##-----------------------------##
##---- syn directions    ------##
##-----------------------------##

set   db_name           [format  "%s%s" ./db/  $top]
set   sdf_name          [format  "%s%s" ./sdf/ $top]
set   report_name       [format  "%s%s" ./rpt/ $top]
set   result_name       [format  "%s%s" ./result/ $top]
set   compile_log_name  [format  "%s%s" ./log/  $top]
set   sta_name          [format  "%s%s" ./sta/  $top]

##-----------------------------##
##---- DC system variables ----##
##-----------------------------##

### HDL In/Out ###
set hdlin_check_no_latch true

##set hdlout_internal_busses true ; ## old
set hdlout_internal_busses "false" ; ## new

### Verilog out ###
set verilogout_higher_designs_first true
set verilogout_equation false
set verilogout_no_tri true
set verilogout_show_unconnected_pins false
set verilogout_single_bit false

### propagate constant to leaf macro when cal timing ### 
set  case_analysis_with_logic_constants true

### Enable add invert before clock and enable pins of DFFs ###
set compile_automatic_clock_phase_inference "relaxed"

set timing_non_unate_clock_compatibility true

# Define Work Library Location
define_design_lib WORK -path "./work"


set hdlin_preserve_sequential false
##enable async reset/set timing check
set enable_recovery_removal_arcs true

set compile_seqmap_propagate_constants   true
set compile_seqmap_propagate_high_effort true
##set compile_seqmap_propagate_high_effort false

### no auto ugroup DW functions in compile_ultra mode ###
set compile_ultra_ungroup_dw  false

### always keep sub desgin IOs ###
set compile_preserve_subdesign_interfaces  true
set compile_delete_unloaded_sequential_cells true

###-- end disable some compile option for LEC (RTL Vs. Gate) --### 



