
set top_design sha256
new_project $top_design -force

##Data Import Section
read_file -type verilog [list       \
../rtl/sha256.v             \
../rtl/sha256_cfg.v         \
../rtl/sha256_axir.v        \
../rtl/sha256_flow_ctl.v    \
../rtl/sha256_core.v        \
../rtl/sha256_k_lut.v       \
../rtl/sha256_w_reg.v       \
../rtl/sha256_loop.v        \
../rtl/sync_fifo.v          \
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

