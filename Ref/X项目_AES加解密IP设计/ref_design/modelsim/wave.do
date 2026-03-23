onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_aes/dut/clk
add wave -noupdate /tb_aes/dut/reset_n
add wave -noupdate /tb_aes/dut/cs
add wave -noupdate /tb_aes/dut/we
add wave -noupdate /tb_aes/dut/address
add wave -noupdate /tb_aes/dut/write_data
add wave -noupdate /tb_aes/dut/read_data
add wave -noupdate /tb_aes/dut/core/encdec
add wave -noupdate /tb_aes/dut/core/init
add wave -noupdate /tb_aes/dut/core/next
add wave -noupdate /tb_aes/dut/core/ready
add wave -noupdate /tb_aes/dut/core/key
add wave -noupdate /tb_aes/dut/core/keylen
add wave -noupdate /tb_aes/dut/core/block
add wave -noupdate /tb_aes/dut/core/result
add wave -noupdate /tb_aes/dut/core/result_valid
add wave -noupdate -divider sbox
add wave -noupdate /tb_aes/dut/core/sbox_inst/sboxw
add wave -noupdate /tb_aes/dut/core/sbox_inst/new_sboxw
add wave -noupdate -divider key_mem
add wave -noupdate /tb_aes/dut/core/keymem/clk
add wave -noupdate /tb_aes/dut/core/keymem/init
add wave -noupdate /tb_aes/dut/core/keymem/round
add wave -noupdate /tb_aes/dut/core/keymem/round_key
add wave -noupdate /tb_aes/dut/core/keymem/key_mem_we
add wave -noupdate /tb_aes/dut/core/keymem/round_ctr_we
add wave -noupdate /tb_aes/dut/core/keymem/round_ctr_rst
add wave -noupdate /tb_aes/dut/core/keymem/round_ctr_inc
add wave -noupdate /tb_aes/dut/core/keymem/round_ctr_reg
add wave -noupdate /tb_aes/dut/core/keymem/key_mem_ctrl_reg
add wave -noupdate /tb_aes/dut/core/keymem/round_key_update
add wave -noupdate /tb_aes/dut/core/keymem/rcon_set
add wave -noupdate /tb_aes/dut/core/keymem/rcon_next
add wave -noupdate /tb_aes/dut/core/keymem/rcon_reg
add wave -noupdate /tb_aes/dut/core/keymem/rcon_we
add wave -noupdate -divider encript
add wave -noupdate /tb_aes/dut/core/enc_block/enc_ctrl_reg
add wave -noupdate /tb_aes/dut/core/enc_block/round_ctr_reg
add wave -noupdate /tb_aes/dut/core/enc_block/block_w0_reg
add wave -noupdate /tb_aes/dut/core/enc_block/block_w1_reg
add wave -noupdate /tb_aes/dut/core/enc_block/block_w2_reg
add wave -noupdate /tb_aes/dut/core/enc_block/block_w3_reg
add wave -noupdate /tb_aes/dut/core/enc_block/sboxw
add wave -noupdate /tb_aes/dut/core/enc_block/new_sboxw
add wave -noupdate /tb_aes/dut/core/enc_block/update_type
add wave -noupdate /tb_aes/dut/core/enc_block/ready
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {605 ns} 0} {{Cursor 2} {501 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 245
configure wave -valuecolwidth 256
configure wave -justifyvalue left
configure wave -signalnamewidth 3
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
WaveRestoreZoom {585 ns} {707 ns}
