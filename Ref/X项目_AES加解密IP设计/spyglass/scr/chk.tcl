## read design and build hierarchy
current_goal Design_Read -top $top_design
link_design -force

##Goal Setup Section
current_methodology $SPYGLASS_HOME/GuideWare/latest/block/rtl_handoff


#--- RTL lint part
current_goal lint/lint_rtl -top $top_design
run_goal

current_goal lint/lint_turbo_rtl -top $top_design
run_goal

current_goal lint/lint_functional_rtl -top $top_design
run_goal

current_goal lint/lint_abstract -top $top_design
run_goal

current_goal adv_lint/adv_lint_struct -top $top_design
run_goal

current_goal adv_lint/adv_lint_verify -top $top_design
run_goal


#--- CDC part
## current_goal cdc/cdc_setup_check -top $top_design
## run_goal
## 
## current_goal cdc/clock_reset_integrity -top $top_design
## run_goal
## 
## current_goal cdc/cdc_verify_struct -top $top_design
## set_parameter fa_msgmode "all"
## run_goal
## 
## current_goal cdc/cdc_verify -top $top_design
## set_parameter fa_msgmode "all"
## run_goal
## 
## current_goal cdc/cdc_abstract -top $top_design
## run_goal

#--- reset domain cross
## current_goal rdc/rdc_verify_struct -top $top_design
## run_goal


#--- DFT 
## current_goal dft/dft_scan_ready -top $top_design
## run_goal
## 
## current_goal dft/dft_best_practice -top $top_design
## run_goal
## 
## current_goal dft/dft_bist_ready -top $top_design
## run_goal
## 
## current_goal dft/dft_dsm_best_practice -top $top_design
## run_goal
## 
## current_goal dft/dft_dsm_random_resistance -top $top_design
## run_goal
## 
## current_goal dft/dft_abstract -top $top_design
## run_goal
## 
## current_goal connectivity_verify/connectivity_verification -top $top_design
## run_goal


save_project


