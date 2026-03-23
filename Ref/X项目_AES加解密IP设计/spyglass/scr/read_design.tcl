
set top_design aes_top
new_project $top_design -force

##Data Import Section
read_file -type verilog [list       \
../rtl/aes_top.v 		            \
../rtl/aes_cfg.v 		            \
../rtl/aes_flow_ctrl.v 	            \
../rtl/aes_axir.v 		            \
../rtl/aes_axiw.v 		            \
../rtl/aes_core.v 		            \
../rtl/aes_sbox_lut.v 		        \
../rtl/aes_key_mem.v 	    	    \
../rtl/aes_encipher_block.v 		\
../rtl/aes_decipher_block_fast.v    \
../rtl/aes_inv_sbox_fast.v          \
../rtl/reg_file_wbe_generic.v 		\
]

read_file -type awl  ./scr/message_waive.awl

#--- write SDC for spyglass
read_file -type sgdc ./scr/design.sgdc

##Common Options Section
set_option language_mode mixed
set_option designread_enable_synthesis no
set_option designread_disable_flatten no
# set_option incdir {../rtl/include}

#set_option define {_SHA_STAND_ALGORITHM_}
set_option top $top_design

