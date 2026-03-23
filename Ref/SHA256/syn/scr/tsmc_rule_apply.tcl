####################################
# TSMC Verilog Netlist Naming Rule #
####################################

#set_fix_multiple_port_nets -all -buffer_constants -constants  

### Bus manipulation 
set bus_dimension_separator_style {][}
set bus_extraction_style {%s[%d:%d]}
set bus_inference_descending_sort {true}
set bus_naming_style {%s[%d]}
set bus_range_separator_style {:}
set change_names_dont_change_bus_members false
### Internal bus Inference 
### Don't form internal bus
set hdlout_internal_busses {false}
##set hdlout_internal_busses {true}
set bus_inference_style {%s[%d]}
### Verilog Interface
set verilogout_higher_designs_first true
#get rid of tri wires and trans primitives
set verilogout_no_tri true
set verilogout_single_bit false
set verilogout_equation  false
set verilogout_show_unconnected_pins  false

### TSMC naming rules for Verilog netlist
define_name_rules TSMC_VERILOG_RULE -reserved_words {always, and, assign, \
begin, buf, bufif0, bufif1, case, casex, casez, cmos, deassign, default, \
defparam, disable, edge, else, end, endattribute, endcase, endfunction, \
endmodule, endprimitive, endspecify, endtable, endtask, event, for, force, \
forever, fork, function, highz0, highz1, if, initial, inout, input, integer, \
join, large, macromodule, medium, module, nand, negedge, nmos, nor, not, \
notif0, notif1, or, output, parameter, pmos, posedge, primitive, pull0, \
pull1, pullup, pulldown, reg, rcmos, release, repeat, rnmos, rpmos, \
rtran, rtranif0, rtranif1, scalared, small, specify, specparam, strength, \
strong0, strong1, supply0, supply1, table, task, time, tran, tranif0, \
tranif1, tri, tri0, tri1, trinand, trior, trireg, use, vectored, wait, \
wand, weak0, weak1, while, wire, wor, xor, xnor}
define_name_rules TSMC_VERILOG_RULE -allowed "a-zA-Z0-9_/!" \
-first_restricted "0-9[]/!" \
-last_restricted {[/!} \
-max_length 255 \
-replacement_char "_" \
-case_insensitive \
-equal_ports_nets \
-inout_ports_equal_nets 

define_name_rules TSMC_VERILOG_RULE -type port \
-allowed {a-zA-Z0-9_} \
-first_restricted "0-9[]" \
-last_restricted {[} \
-map { {{"\/","_"},{"[?*]?*$", "_"}} } \
-max_length 48 


define_name_rules TSMC_VERILOG_RULE -type cell \
-map { {{"\/","_"}, {"][","_"}} }

define_name_rules TSMC_VERILOG_RULE -type net \
-allowed "a-zA-Z0-9_"   	\
-map { {{"\/","_"}, {"][","_"}} }

