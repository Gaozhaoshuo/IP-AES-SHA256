##------------------------------##
#       read in designs          #
##------------------------------##


analyze -format verilog -define $syn_define_list -vcs "-f ./flist.f"
elaborate $top

current_design   $top
link
uniquify

