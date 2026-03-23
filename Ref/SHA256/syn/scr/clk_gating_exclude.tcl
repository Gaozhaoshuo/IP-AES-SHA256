##--- DFFs dirven by clock gating latch with enable pin with cross clock domain source. 
set clk_exclude_cell_list ""

set clk_gating_exclude_cells ""

foreach sig_cell $clk_exclude_cell_list {
  	set clk_gating_exclude_cells [add_to_collection -unique $clk_gating_exclude_cells [get_cells $sig_cell] ]
} 

set_clock_gating_registers -exclude_instances $clk_gating_exclude_cells

unset  clk_gating_exclude_cells
unset  clk_exclude_cell_list

