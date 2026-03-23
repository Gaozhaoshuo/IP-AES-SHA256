sh date
##if {[file exists work]} {exec rm -rf work}

echo "----------------------------------------------"
echo "--- Welcome to Boring, Smart and Stupid DC ---"
echo "--- I'm so smart than you can image, and I'm -"
echo "--- also more stupid than your can dream. ----"
echo "--- Keep this in mind, then you can success. -"
echo "----------------------------------------------"

echo "-------------------------------------------------"
echo "--- Begin read in all the RTL code             --"
echo "-------------------------------------------------"

set top             "sha256"
set SCANSYN         0
set en_clk_gating   1
set stage           pre

source ./scr/syn_parameter.tcl
source ./scr/lib_tsmc130.tcl

source ./scr/tsmc_rule_apply.tcl

#------------------------------#
#---- read in all RTL code     #
#------------------------------#
source ./scr/read_design.tcl
source ./scr/initial_pre.tcl

#------------------------------#
#---- desing parameter seting -#
#------------------------------#

current_design $top

##---- use compile_ultra
set     speed_high              1
set  	en_last_optimization 	0

set  	en_auto_wire_model_sel  0
##set  	fixed_wire_load_model  	"tsmc13_wl10"
##set  	fixed_wire_load_model  	"tsmc13_wl20"
set  	fixed_wire_load_model  	"ForQA"
set     wire_load_lib           slow

if {$en_auto_wire_model_sel == 0} {
    set auto_wire_load_selection false
}

#------------------------------#
#---- constrain the design  ---#
#------------------------------#

set    stage         p0

echo "-------------------------------------------------"
echo "--- Run stage: $stage on design: $top . ---"
echo "-------------------------------------------------"

current_design   $top
source ./scr/clocks.tcl

##---- insert clock gating
if {$en_clk_gating == 1} {
 	source ./scr/clk_gating_exclude.tcl > ./log/clk_gating_exclude.log
	source ./scr/power.tcl
}

source ./scr/initial.tcl
source ./scr/core_const.tcl

##-------------------------------------------------------------------------------------##
##---- set to no boundary optimization for these big cells for RTL VS gate purpose ----##
##---- assume this will not influence the timing and area much.                    ----##
##-------------------------------------------------------------------------------------##
set  no_boundary_op_cells [get_cells ""]
foreach_in_collection  sig_cell $no_boundary_op_cells {
  	set_boundary_optimization $sig_cell "false"
}


#------------------------------#
#---- compile the design  -----#
#------------------------------#
set stage       p1
set dont_touch_cells    ""
foreach sig_cell $dont_touch_cells {
    set_dont_touch  [get_designs $dont_touch_cells] true
}

echo "-------------------------------------------------"
echo "--- Run stage: $stage on design: $top . ---"
echo "-------------------------------------------------"

if {$SCANSYN == 1} {
    source ./scr/scan_cfg.tcl
}

if {$speed_high == 1} {
   source ./scr/compile_pass1_speed.tcl
} else {
   source ./scr/compile_pass1.tcl
}

if {$SCANSYN == 1} {
    create_test_protocol -infer_asynch -infer_clock  \
    -capture_procedure single_clock

    insert_dft
    dft_drc     -verbose  -coverage_estimate  > ./rpt/dft_drc.rpt
}


foreach sig_cell $dont_touch_cells {
    set_dont_touch  [get_designs $dont_touch_cells] false
}

##change_names -verbose -hierarchy -rule TSMC_VERILOG_RULE
source ./scr/write_result.tcl
source ./scr/report.tcl

#normal mode second compile to save area
set stage p2
current_design $top

echo "-------------------------------------------------"
echo "--- Run stage: $stage on design: $top . ---"
echo "-------------------------------------------------"

if {$speed_high == 1} {
  source ./scr/compile_pass2_speed.tcl
} else {
  source ./scr/compile_pass2.tcl
}


##change_names -verbose -hierarchy -rule TSMC_VERILOG_RULE
source ./scr/write_result.tcl

##-- don't fix hold at synthesis --##
##--set stage p3
##--source ./scr/compile_pass3.tcl
##--source ./scr/write_result.tcl
##--source ./scr/report.tcl

set stage p2_before_naming
source ./scr/write_result.tcl

set stage p2_naming
change_names -verbose -hierarchy -rule TSMC_VERILOG_RULE
#change_names -verbose -hierarchy -rule verilog
source ./scr/write_result_all.tcl
source ./scr/report.tcl


if {$en_last_optimization != 0} {
 	##----- Additional timing optimization stage ----##
 	set stage last_opt_p0 	


 	echo "-------------------------------------------------"
 	echo "--- Run stage: $stage on design: $top . ---"
 	echo "-------------------------------------------------"
}


echo "-------------------------------------------------"
echo "--- Congratulations, My Lord. All you commands --"
echo "--- have been done. But I don't whether there  --"
echo "--- is any eror and whether the results match  --"
echo "--- your requirement or not. Because I'm stupid. "
echo "--- If not, Pleae wait for next DC version and --"
echo "--- don't forget to prepare enough \$.          --"
echo "-------------------------------------------------"

echo "----------------------------------------------"
echo "--- Please keep your manner and keep tring, --"
echo "--- because I'm stupid. Thanks. ^_^ ^_^   ----"
echo "----------------------------------------------"
sh date

#quit
  
