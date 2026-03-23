srcSourceCodeView
debImport "-f" "flist.f" "-2001" "-top" "tb"
srcResizeWindow 227 56 1462 1051
srcViewImportLogFile
debReload
srcHBSelect "tb" -win $_nTrace1
srcSelect -win $_nTrace1 -range {31 31 3 4 1 1}
srcHBSelect "tb.u_sha256" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256" -delim "."
srcHBSelect "tb.u_sha256.u_sha256_cfg" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_cfg" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "cfg_blk_sof" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "cfg_blk_sof" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "cfg_blk_sof" -win $_nTrace1
srcCopySignalFullPath -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "cfg_blk_sof" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "cfg_blk_sof" -win $_nTrace1
srcCopySignalFullPath -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_core" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_core" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_core" -delim "."
srcSearchString "w" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {47 47 3 3 1 2}
srcHBSelect "tb.u_sha256.u_sha256_core.u_loop" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_core.u_loop" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "w" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "w" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "w" -win $_nTrace1
srcCopySignalFullPath -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "a" -win $_nTrace1
srcAction -pos 72 8 0 -win $_nTrace1 -name "a" -ctrlKey off
srcHBSelect "tb.u_sha256.u_sha256_core.u_loop" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_core.u_loop" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "bulk_fir_ini" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "cal_en" -win $_nTrace1
srcTraceLoad "tb.u_sha256.u_sha256_core.u_loop.cal_en" -win $_nTrace1
debReload
srcHBSelect "tb.u_sha256.u_sha256_core.u_loop" -win $_nTrace1
srcSelect -win $_nTrace1 -range {26 26 3 4 1 1}
srcCloseWindow -win $_nTrace2
srcDeselectAll -win $_nTrace1
debReload
srcHBSelect "tb.u_sha256.u_sha256_core.u_loop" -win $_nTrace1
srcSelect -win $_nTrace1 -range {26 26 3 4 1 1}
srcHBSelect "tb.u_sha256_trc" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256_trc" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "fp" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "fp" -win $_nTrace1
srcCopySignalFullPath -win $_nTrace1
srcHBSelect "tb.u_apb_ms_model" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_apb_ms_model" -delim "."
srcResizeWindow 230 26 1554 1051
srcHBSelect "tb.u_sha256.u_sha256_core.u_w_reg.gen_w_mem\[0\]" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_core.u_w_reg" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_core.u_k_lut" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_core" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sync_fifo" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sync_fifo" -delim "."
srcHBSelect "tb.u_sha256" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_core" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_cfg" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_axir" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_axir" -delim "."
srcSearchString "arlen" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {43 43 2 3 1 1}
srcDeselectAll -win $_nTrace1
srcSelect -signal "arlen" -win $_nTrace1
srcAction -pos 42 1 3 -win $_nTrace1 -name "arlen" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "cur_len" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "cur_len" -win $_nTrace1
srcAction -pos 183 6 4 -win $_nTrace1 -name "cur_len" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "cmd1_len" -win $_nTrace1
srcAction -pos 121 18 3 -win $_nTrace1 -name "cmd1_len" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "cmd1_len" -win $_nTrace1
srcAction -pos 121 18 3 -win $_nTrace1 -name "cmd1_len" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "cmd1_len" -win $_nTrace1
srcAction -pos 121 18 3 -win $_nTrace1 -name "cmd1_len" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "cmd1_len" -win $_nTrace1
srcAction -pos 121 18 3 -win $_nTrace1 -name "cmd1_len" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "cmd1_len" -win $_nTrace1
srcAction -pos 121 18 3 -win $_nTrace1 -name "cmd1_len" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "cmd1_len" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "cmd1_len_w" -win $_nTrace1
srcTraceLoad "tb.u_sha256.u_sha256_axir.cmd1_len_w\[3:0\]" -win $_nTrace1
srcTraceLoad "tb.u_sha256.u_sha256_axir.cmd1_len_w\[3:0\]" -win $_nTrace1
debReload
srcSelect -win $_nTrace1 -range {28 28 3 4 1 1}
srcDeselectAll -win $_nTrace1
srcSelect -signal "cmd0_len_w" -win $_nTrace1
srcAction -pos 121 2 6 -win $_nTrace1 -name "cmd0_len_w" -ctrlKey off
srcTraceLoad "tb.u_sha256.u_sha256_axir.cmd0_len_w\[3:0\]" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "cmd0_len_w" -win $_nTrace1
srcAction -pos 182 5 3 -win $_nTrace1 -name "cmd0_len_w" -ctrlKey off
srcHBSelect "tb.u_sha256.u_sha256_flow_ctl" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_core" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_core" -delim "."
srcHBSelect "tb.u_sha256.u_sha256_core.u_loop" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_core.u_loop" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "bulk_fir_ini" -win $_nTrace1
srcAction -pos 26 1 4 -win $_nTrace1 -name "bulk_fir_ini" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcAction -pos 93 5 3 -win $_nTrace1 -name "msg_vld" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "ibuf_pop" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "ibuf_pop" -win $_nTrace1
srcAction -pos 91 6 5 -win $_nTrace1 -name "ibuf_pop" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcTraceLoad "tb.u_sha256.u_sha256_flow_ctl.msg_vld" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcAction -pos 91 2 5 -win $_nTrace1 -name "msg_vld" -ctrlKey off
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {92 92 3 4 1 1}
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {80 80 4 5 1 1}
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {62 62 5 6 1 1}
srcTraceLoad "tb.u_sha256.u_sha256_flow_ctl.msg_vld" -win $_nTrace1
srcSelect -win $_nTrace1 -range {66 66 24 25 1 1}
srcPrevTraced -scope
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {68 68 8 9 1 1}
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {45 45 15 15 15 22}
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {39 39 5 6 1 1}
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {26 26 2 3 1 1}
srcSelect -win $_nTrace1 -range {66 66 24 25 1 1}
srcNextTraced -scope
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {68 68 8 9 1 1}
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {45 45 15 15 15 22}
srcSearchString "msg_vld" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {39 39 5 6 1 1}
srcSelect -win $_nTrace1 -range {66 66 24 25 1 1}
srcNextTraced -scope
srcHBSelect "tb.u_sha256.u_sha256_flow_ctl" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_flow_ctl" -delim "."
srcSearchString "msg_vld" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {39 39 2 3 1 1}
srcSearchString "msg_vld" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {59 59 2 3 18 1}
srcHBSelect "tb.u_sha256.u_sha256_core.u_loop" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_core.u_loop" -delim "."
srcSearchString "msg_vld" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {29 29 2 3 1 1}
srcSearchString "msg_vld" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {52 52 5 6 1 1}
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcAction -pos 51 4 4 -win $_nTrace1 -name "msg_vld" -ctrlKey off
srcHBSelect "tb.u_sha256.u_sha256_flow_ctl" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_flow_ctl" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "bulk_fir_ini" -win $_nTrace1
srcSearchString "bulk_fir_ini" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {58 58 5 6 1 1}
srcSearchString "bulk_fir_ini" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {94 94 3 4 1 1}
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcAction -pos 91 2 2 -win $_nTrace1 -name "msg_vld" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "ibuf_pop" -win $_nTrace1
srcAction -pos 91 6 5 -win $_nTrace1 -name "ibuf_pop" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcAction -pos 91 2 4 -win $_nTrace1 -name "msg_vld" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcAction -pos 91 2 4 -win $_nTrace1 -name "msg_vld" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcAction -pos 91 2 4 -win $_nTrace1 -name "msg_vld" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcAction -pos 238 6 -cmdMessage -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcAction -pos 239 9 -cmdMessage -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcAction -pos 239 13 -cmdMessage -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcAction -pos 91 2 3 -win $_nTrace1 -name "msg_vld" -ctrlKey off
debReload
srcSelect -win $_nTrace1 -range {27 27 3 4 1 1}
srcDeselectAll -win $_nTrace1
srcSelect -signal "msg_vld" -win $_nTrace1
srcAction -pos 91 2 3 -win $_nTrace1 -name "msg_vld" -ctrlKey off
srcHBSelect "tb.u_sha256.u_sha256_cfg" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_cfg" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "axi_bulk_end" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "axi_bulk_end" -win $_nTrace1
srcAction -pos 39 1 6 -win $_nTrace1 -name "axi_bulk_end" -ctrlKey off
srcTraceLoad "tb.u_sha256.u_sha256_axir.axi_bulk_end" -win $_nTrace1
srcSelect -win $_nTrace1 -range {25 25 3 4 1 1}
srcPrevTraced -scope
srcDeselectAll -win $_nTrace1
srcSelect -signal "axi_bulk_end_d" -win $_nTrace1
srcAction -pos 87 8 7 -win $_nTrace1 -name "axi_bulk_end_d" -ctrlKey off
srcHBSelect "tb.u_sha256.u_sha256_axir" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_axir" -delim "."
srcSearchString "cross_4kb" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {107 107 3 3 1 10}
srcSearchString "cross_4kb" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {113 113 3 4 1 1}
srcSearchString "cross_4kb" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {119 119 3 3 1 10}
srcDeselectAll -win $_nTrace1
srcSelect -signal "cross_4kb" -win $_nTrace1
srcAction -pos 112 2 5 -win $_nTrace1 -name "cross_4kb" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "cross_4kb" -win $_nTrace1
srcAction -pos 112 2 6 -win $_nTrace1 -name "cross_4kb" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "cross_4kb" -win $_nTrace1
srcTraceLoad "tb.u_sha256.u_sha256_axir.cross_4kb" -win $_nTrace1
srcHBSelect "tb.u_sha256.u_sha256_cfg" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_sha256.u_sha256_cfg" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "prdata" -win $_nTrace1
srcAction -pos 32 1 3 -win $_nTrace1 -name "prdata" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcDeselectAll -win $_nTrace1
debReload
srcSelect -win $_nTrace1 -range {25 25 3 4 1 1}
srcResizeWindow 118 38 1554 1023
debExit
