#-------save design --------#
puts "#--------------------------------#"
puts "  save design result of $stage.   "
puts "#--------------------------------#" 

current_design  $top

#force no tran and assign in the netlist#
##-- if {$SCANSYN==0} {
##--   foreach_in_collection design  [get_designs "*"] {
##--     current_design  $design
##--     set_fix_multiple_port_nets -all  -buffer_constants
##--     }
##--   } else {
##--   set_fix_multiple_port_nets -all -buffer_constants
##--   }

#current_design $top
#set bus_naming_style  {%s[%d]}
#define_name_rules  MY_NAMING -first_restricted "0-9_\\[]" \
#                             -allowed {A-Za-zO-9_}        \
#                             -map {{{"\\"}, {"p"}}}       \
#                             -remove_chars
#define_name_rules  MY_NAMING                             \ 
#                            -first_restricted {0-9_\[]} \
#                            -max_length 30              \
#                            -case_insensitive           \
#                            -remove_irregular_net_bus   \
#                            -flatten_multi_dimension_busses
#                            #  -target_bus_naming_style "%s_%d_" \
#                            #-allowed {A-Za-zO-9_}       \

#change_name  -rules MY_NAMING   -verbose  -hierarchy
#change_name  -rules verilog -hierarchy
#change_name  -rules vhdl    -hierarchy

#source ./scr/tsmc_rule_apply.tcl

write  -hierarchy  -format  verilog  -output \
    [format "%s%s%s%s" $result_name _ $stage .vnet]
write  -hierarchy  -format  ddc       -output \
    [format "%s%s%s%s" $db_name _ $stage .ddc]
