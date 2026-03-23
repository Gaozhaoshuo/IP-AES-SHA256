##------------------------------##
# setup the library for compile  #
##------------------------------##

set designer          "yuxiang"
set company           "study"

## set search_path       [list		\
##                 /home/yuxiang/proj/libs/TSMC_013/synopsys           \
##                 /home/yuxiang/eda_tools/dc_2015/libraries/syn       \
##                 /home/yuxiang/eda_tools/dc_2015/dw/sim_ver          \
## 			]

set search_path [list		\
                /home/yyx/proj/libs/TSMC_013/synopsys               \
                /eda/dc/syn/O-2018.06-SP1/libraries/syn             \
                /eda/dc/syn/O-2018.06-SP1/dw/sim_ver                \
                ]

set worst_lib           [list slow.db]
set tech_lib            [list slow]

set synthetic_library   [list dw_foundation.sldb]
set link_library        [list "*" $worst_lib $synthetic_library]
set target_library      $worst_lib

set_min_library	slow.db	-min_version	fast.db
#---- List all the Hard Macros used ----#


#don't use the cells for scan insertion
set_dont_use          slow/SEDFF*
set_dont_use          slow/SDFF*

#don't use latch
#set_dont_use          slow/TLAT*
#don't use regfile in lib
set_dont_use          slow/RF2R*
set_dont_use          slow/RF1R1*
#don't use low driven strength cells
#set_dont_use          slow/*X1
set_dont_use          slow/*XL
#don't use cells with a lot of  pins
set_dont_use          slow/MDFF*
set_dont_use          slow/SMDFF*

set dont_use_cell     [list slow/TBUF* slow/DLY* slow/*DF*SR*]
set_dont_use $dont_use_cell
#use these tie high and tie low cell for better ESD
##remove_attribute slow/TIEHI dont_use
##remove_attribute slow/TIELO dont_use
set_attribute [get_lib_cells slow/TIELO] "dont_touch" 	"false"
set_attribute [get_lib_cells slow/TIELO] "dont_use" 	"false"

set_attribute [get_lib_cells slow/TIEHI] "dont_touch" 	"false"
set_attribute [get_lib_cells slow/TIEHI] "dont_use" 	"false"
##set_lib_attribute "slow/TIELO" "dont_use" "false"
##set_lib_attribute "slow/TIEHI" "dont_use" "false"
     
