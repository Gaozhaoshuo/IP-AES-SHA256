onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider dut_IO
add wave -noupdate /tb/u_apb_ms_model/i
add wave -noupdate /tb/u_apb_ms_model/in_byte_len
add wave -noupdate /tb/u_apb_ms_model/in_data_base
add wave -noupdate /tb/u_sha256/clk
add wave -noupdate /tb/u_sha256/rstn
add wave -noupdate /tb/u_sha256/psel
add wave -noupdate /tb/u_sha256/penable
add wave -noupdate /tb/u_sha256/paddr
add wave -noupdate /tb/u_sha256/pwrite
add wave -noupdate /tb/u_sha256/pwdata
add wave -noupdate /tb/u_sha256/pready
add wave -noupdate /tb/u_sha256/prdata
add wave -noupdate -color Violet /tb/u_sha256/intr
add wave -noupdate /tb/u_sha256/cfg_blk_sof
add wave -noupdate /tb/u_sha256/cfg_blk_base
add wave -noupdate /tb/u_sha256/cfg_blk_len
add wave -noupdate /tb/u_sha256/u_sha256_axir/blk_osd_cmd
add wave -noupdate /tb/u_sha256/arvalid
add wave -noupdate /tb/u_sha256/arready
add wave -noupdate /tb/u_sha256/araddr
add wave -noupdate /tb/u_sha256/arlen
add wave -noupdate /tb/u_sha256/rvalid
add wave -noupdate /tb/u_sha256/rready
add wave -noupdate /tb/u_sha256/rdata
add wave -noupdate /tb/u_sha256/rresp
add wave -noupdate /tb/u_sha256/rlast
add wave -noupdate -divider axir
add wave -noupdate /tb/u_sha256/u_sha256_axir/clk
add wave -noupdate /tb/u_sha256/u_sha256_axir/sta
add wave -noupdate /tb/u_sha256/u_sha256_axir/cross_4kb_w
add wave -noupdate /tb/u_sha256/u_sha256_axir/cross_4kb
add wave -noupdate /tb/u_sha256/u_sha256_axir/cmd0_len
add wave -noupdate /tb/u_sha256/u_sha256_axir/cmd1_len
add wave -noupdate /tb/u_sha256/u_sha256_axir/cur_len
add wave -noupdate /tb/u_sha256/u_sha256_axir/axi_addr
add wave -noupdate /tb/u_sha256/u_sha256_axir/blk_len
add wave -noupdate -divider flow_ctl
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/clk
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/rstn
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/cfg_blk_sof
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/axi_bulk_end
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/ibuf_empty
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/ibuf_pop
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/ibuf_rdata
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/bulk_fir_ini
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/bulk_nxt_ini
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/msg_vld
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/msg_data
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/msg_dcnt
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/sha_blk_end
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/sta
add wave -noupdate /tb/u_sha256/u_sha256_flow_ctl/fir_blk
add wave -noupdate -divider cal_loop
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/clk
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/rstn
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/bulk_fir_ini
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/bulk_nxt_ini
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/msg_vld
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/cal_en
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/loop_cnt
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/k_lut
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/w
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/sha_blk_end
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/h0
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/h1
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/h2
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/h3
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/h4
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/h5
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/h6
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/h7
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/a
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/b
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/c
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/d
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/e
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/f
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/g
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/h
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/load_blk_final
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/t1
add wave -noupdate /tb/u_sha256/u_sha256_core/u_loop/t2
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {149036000 ps} 0} {{Cursor 2} {135431420 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 335
configure wave -valuecolwidth 126
configure wave -justifyvalue left
configure wave -signalnamewidth 2
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {129341220 ps} {152950320 ps}
