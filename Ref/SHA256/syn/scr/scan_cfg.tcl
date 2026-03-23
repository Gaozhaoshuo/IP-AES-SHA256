set_dft_signal  -view   spec        -type   ScanClock       \
                -port   clk

set_dft_signal  -view   spec        -type   Reset           \
                -port   rstn

set port_num    [sizeof_collection [get_ports test_mode -quiet]]

if {$port_num == 1} {
    set_dft_signal  -view   spec        -type   TestMode    \
                    -port   test_mode

    set_false_path -from [get_ports test_mode]
}

set port_num    [sizeof_collection [get_ports scan_en -quiet]]

if {$port_num == 1} {
    set_dft_signal  -view   spec        -type   ScanEnable  \
                    -port   scan_en

    set_ideal_network	[get_ports  scan_en]
}

set_dft_signal  -view   spec        -type   ScanDataIn      \
                -port   [get_ports din\[?\]]

set_dft_signal  -view   spec        -type   ScanDataOut     \
                -port   [get_ports sad\[?\]]

set_scan_configuration  -chain_count 10



