srcSourceCodeView
debImport "-f" "flist.f" "-2001" "-top" "tb"
srcResizeWindow 39 69 1678 1045
srcHBSelect "tb.u_aes_top" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_aes_top" -delim "."
srcHBSelect "tb.u_aes_top.u_aes_core" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_aes_top.u_aes_core" -delim "."
srcHBSelect "tb.u_aes_top.u_aes_flow_ctrl" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_aes_top.u_aes_flow_ctrl" -delim "."
srcSearchString "sta" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {31 31 2 2 11 14}
srcSearchString "sta" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {38 38 2 2 11 14}
srcSearchString "sta" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {60 60 9 9 12 15}
srcSearchString "sta" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {77 77 9 9 12 15}
srcSearchString "sta" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {85 85 9 10 1 1}
srcDeselectAll -win $_nTrace1
srcSelect -signal "sta" -win $_nTrace1
srcAction -pos 84 8 1 -win $_nTrace1 -name "sta" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "enc_blk_end" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "enc_ready" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "enc_ready" -win $_nTrace1
srcAction -pos 92 16 3 -win $_nTrace1 -name "enc_ready" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "muxed_ready" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "muxed_ready" -win $_nTrace1
srcAction -pos 167 7 7 -win $_nTrace1 -name "muxed_ready" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "enc_ready" -win $_nTrace1
srcAction -pos 208 5 3 -win $_nTrace1 -name "enc_ready" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "ready_reg" -win $_nTrace1
srcAction -pos 201 7 5 -win $_nTrace1 -name "ready_reg" -ctrlKey off
srcBackwardHistory -win $_nTrace1
srcBackwardHistory -win $_nTrace1
srcBackwardHistory -win $_nTrace1
srcBackwardHistory -win $_nTrace1
srcBackwardHistory -win $_nTrace1
srcHBSelect "tb.u_aes_top.u_aes_core" -win $_nTrace1
srcHBSelect "tb.u_aes_top.u_aes_core" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_aes_top.u_aes_core" -delim "."
srcHBSelect "tb.u_aes_top.u_aes_core" -win $_nTrace1
srcHBSelect "tb.u_aes_top.u_aes_core.enc_block" -win $_nTrace1
srcHBSelect "tb.u_aes_top.u_aes_core.dec_block" -win $_nTrace1
srcHBSelect "tb.u_aes_top.u_aes_core.dec_block" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb.u_aes_top.u_aes_core.dec_block" -delim "."
srcHBSelect "tb.u_aes_top.u_aes_core.dec_block" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcDeselectAll -win $_nTrace1
debExit
