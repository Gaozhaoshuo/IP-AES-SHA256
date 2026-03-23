##------------------------------##
#       globle constraints       #
# 1: set clock and reset         #
# 2: set design rules            #
# 3: set design enviroment       #
# 4: set input/output delay      #
# 5: set case analysis           #
# 6: set timing exception path   #
# 7: set dont_touch              #
# 8: set_dont_touch_network      #
##------------------------------##

#-------- create clocks ------------//


#------- set high fanout net ----------#
set high_fanout_net_threshold  250
set high_fanout_net_pin_capacitance [expr 40*[get_attribute $buf_cell capacitance]]

#------- set design enviroment --------#

set itrans_exclude_ports  [get_port [list clk]]
set itrans_ports    [remove_from_collection [all_inputs] $itrans_exclude_ports]
set otrans_ports    [all_outputs]

#------- set design rule check --------#
#-- Now, all use library default value
#set_max_transition  $design_max_transition [current_design]
#set_max_transition  $port_max_transition   $itrans_ports
#set_max_transition  $port_max_transition   $otrans_ports
set_max_fanout  $design_max_fanout  [current_design]
#set_max_capacitance $design_max_cap [current_design]
#set_max_capacitance $port_max_cap   $otrans_ports


#-------- set default fanout_load -----#
set def_fanout_load  [get_attribute $tech_lib default_fanout_load]
if {$def_fanout_load==0} {
  puts "The fanout load of the library is 0, set to 1.0 ."
  set_attribute $tech_lib default_fanout_load 1.0 -type float
  }

#------ set design librarys -----------#
set_operating_conditions -max  slow              \
                         -max_library slow       \
                         -min  fast              \
                         -min_library fast    

set_wire_load_mode enclosed

if {$en_auto_wire_model_sel == 1} {
	#set_wire_load_selection_group -lib $wire_load_lib   WireAreaLowkCon
	#set auto_wire_load_selection true

    puts "This cell library doesn't support auto wire selection, set to fixed wire load model."
    set_wire_load_model -name  $fixed_wire_load_model \
  				        -lib   $wire_load_lib 
} else {
	set_wire_load_model -name  $fixed_wire_load_model \
  				        -lib   $wire_load_lib 
}

#for IC top ouput
#set_load $output_load_pad  $otrans_ports
#for IP top output
set_load $output_load_pin  $otrans_ports


#--------- set input / output delay -----------#
#--- clk domain ---#
set clk_name    "clk"
set clk_period  [get_attribute [get_clocks $clk_name] period]
set_input_delay  -max -clock [get_clocks $clk_name] [expr 0.5 * $clk_period] $itrans_ports -add_delay
set_input_delay  -min -clock [get_clocks $clk_name] $input_delay_min         $itrans_ports -add_delay

set_output_delay -max -clock [get_clocks $clk_name] [expr 0.5 * $clk_period] $otrans_ports -add_delay
set_output_delay -min -clock [get_clocks $clk_name] $output_delay_min        $otrans_ports -add_delay

set_input_transition 0.15 $itrans_ports

#-------- set timing exception paths --------#
#set_false_path -from -through  -to

#set_clock_groups -asynchronous  -name core_clk_group  \
#	-group  [get_clocks clk]	\
#	-group	[get_clocks clk108]	\
#	-group	[get_clocks clk54]

#when set_multicycle_path on setup check, it will affect the hold check, so you need
#refine the hold check point
#set_multicycle_path 2 -setup -from  -to
#set_multicycle_path 1 -hold  -form  -to

##--- direct in--> out path ---##

#-------- set don't touch and ideal net -----#
#dont touch some cells, such as clock root buffer, gated clock instance
#set_dont_touch [get_cell -hier  "cell_name"]

set_dont_touch [get_cell -hier  [list *u_lib_buf* *u_lib_inv* *u_lib_mux* *u_lib_dff*]]


#--- no reset tree at syn stage
set_ideal_network	    [get_ports [list rstn]]

set_max_area  0.0


